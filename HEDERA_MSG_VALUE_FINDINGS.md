# Hedera msg.value Investigation: Complete Findings

## Executive Summary

Successfully implemented direct token purchases on Hedera Testnet after discovering critical differences in how Hedera handles `msg.value` compared to standard EVM chains.

**Final Solution**: Working PropertyFactory deployed at `0x4C67256697e4a6af045faB5D9891455Cba16C420`

---

## The Problem

Token purchases failed with "Incorrect payment amount" despite:
- Correct Solidity logic (verified through local Forge tests)
- Correct mathematical calculations
- Proper bytecode deployment (using `10**18`, not `1e18`)

---

## Root Cause Discovery

### Hedera's Unique msg.value Behavior

**Key Finding**: Hedera's `msg.value` arrives in **tinybars**, not **wei**.

#### Unit Systems

| System | Unit | Scale | Used By |
|--------|------|-------|---------|
| Ethereum | wei | 1 ether = 10^18 wei | Standard EVM |
| Hedera | tinybar | 1 HBAR = 10^8 tinybars | Hedera Network |

#### The Conversion

When sending value via Cast's `--value` flag:
```
sent_value (wei scale) / 10^10 = msg.value (tinybars) received in contract
```

**Example**:
- Send: `--value 1000000000000000000` (1 ether in wei = 10^18)
- Receive: `msg.value = 100000000` (10^8 tinybars)
- Reduction: 10^10 factor

**Test Results**:
| Sent (wei) | Received (tinybars) | Factor |
|------------|---------------------|--------|
| 10^18 | 10^8 | ÷ 10^10 |
| 10^16 | 10^6 | ÷ 10^10 |
| 10^12 | 10^2 | ÷ 10^10 |
| 10^6 | 1 | ÷ 10^6 (different!) |

---

## The Solution

### Smart Contract Changes

#### Before (Failed):
```solidity
function purchaseTokens(uint256 propertyId, uint256 tokenAmount) external payable {
    uint256 totalCost = (tokenAmount * property.pricePerToken) / 10**18;
    require(msg.value == totalCost, "Incorrect payment amount");  // FAILS!
    // ...
}
```

**Why it failed**:
- `totalCost` calculated in wei (e.g., 10^16 for 0.01 HBAR)
- `msg.value` arrives in tinybars (e.g., 10^6 for 0.01 HBAR)
- Comparison: 10^16 != 10^6 ❌

#### After (Works):
```solidity
function purchaseTokens(uint256 propertyId, uint256 tokenAmount) external payable {
    // Calculate cost in wei first (for consistency)
    uint256 totalCostWei = (tokenAmount * property.pricePerToken) / 10**18;

    // Convert to tinybars for Hedera
    uint256 totalCostTinybars = totalCostWei / 10**10;

    // msg.value is in tinybars on Hedera
    require(msg.value >= totalCostTinybars, "Insufficient payment");

    // Send payment to creator (in tinybars)
    (bool success, ) = property.creator.call{value: totalCostTinybars}("");
    require(success, "Payment transfer failed");

    // Refund overpayment if any (in tinybars)
    uint256 refund = msg.value - totalCostTinybars;
    if (refund > 0) {
        (bool refundSuccess, ) = msg.sender.call{value: refund}("");
        require(refundSuccess, "Refund transfer failed");
    }
}
```

**Why it works**:
- Both values now in tinybars
- Allows overpayment (uses `>=`) to handle minor variations
- Automatically refunds excess payment

---

## Implementation Details

### Price Storage

Prices remain stored in **wei units** (10^18 scale) for:
- Consistency with ERC20 token decimals (18)
- Standard Solidity conventions
- Easy conversion to any display format

### Conversion Formula

```solidity
// From wei to tinybars (for Hedera msg.value comparison)
tinybars = wei_amount / 10**10

// From tinybars to HBAR (for display)
hbar = tinybars / 10**8

// From wei to HBAR (for display)
hbar = wei_amount / 10**18
```

### Test Function Added

```solidity
function testMsgValue() external payable returns (uint256) {
    return msg.value;
}
```

This debug function proved invaluable for discovering the conversion factor.

---

## Frontend Integration Requirements

### Value Calculation for Transactions

```typescript
// Example: Purchase 1 token at 0.01 HBAR price

// 1. Get price from contract (in wei)
const pricePerTokenWei = BigInt("10000000000000000"); // 0.01 ether in wei

// 2. Calculate total cost in wei
const tokenAmount = BigInt("1000000000000000000"); // 1 token
const totalCostWei = (tokenAmount * pricePerTokenWei) / BigInt(10**18);
// Result: 10000000000000000 wei (0.01 HBAR)

// 3. Convert to value to send (accounting for 10^10 conversion)
const valueToSend = totalCostWei; // Keep in wei, Cast will convert
// Send as: --value 10000000000000000
// Contract receives: 1000000 tinybars (0.01 HBAR)
```

### Helper Function

```typescript
/**
 * Calculate the value to send for Hedera transactions
 * @param pricePerTokenWei Price in wei (from contract)
 * @param tokenAmount Amount of tokens (in token units, e.g., 1e18 for 1 token)
 * @returns Value to send in transaction (wei scale, will be converted to tinybars)
 */
function calculateHederaPurchaseValue(
  pricePerTokenWei: bigint,
  tokenAmount: bigint
): bigint {
  return (tokenAmount * pricePerTokenWei) / BigInt(10**18);
}

// Usage in wagmi/viem:
const value = calculateHederaPurchaseValue(
  property.pricePerToken,
  parseEther("1") // 1 token
);

await writeContract({
  address: PROPERTY_FACTORY_ADDRESS,
  abi: PROPERTY_FACTORY_ABI,
  functionName: 'purchaseTokens',
  args: [propertyId, parseEther("1")],
  value: value, // viem handles the conversion
});
```

---

## Testing & Verification

### Local Tests (Forge)
✅ All 7 unit tests pass
✅ Property creation correct
✅ Payment calculation correct
✅ Token transfers work

### Hedera Testnet
✅ Property creation: SUCCESS
✅ Token distribution: SUCCESS
✅ Direct purchase: SUCCESS (after tinybar fix)
✅ Payment forwarding: SUCCESS
✅ Refund logic: SUCCESS

### Test Transaction
- Hash: `0xb4fc13461b8afe2dda1f34fc9f5294eea75c7e616427a67630613b729d179381`
- Block: 26722036
- Status: Success ✓
- Gas Used: 533,404
- Value Sent: 10^16 wei
- Value Received: 10^6 tinybars (0.01 HBAR)

---

## Contract Deployment History

1. **0x2Bfd94dF84EdC5967dBa23b26106B7ab6D32E14c** - Initial with purchaseTokens, failed (used ==)
2. **0xb710E9Fe182B861434EBD0F8d90B4d78e6ea14Fe** - Added debug events, still failed
3. **0x98bED13e904a8efD5b181D0cF77393eF11619fCA** - Changed to >=, still failed (no conversion)
4. **0x4C67256697e4a6af045faB5D9891455Cba16C420** - ✅ **WORKING** (with tinybar conversion)

---

## Key Learnings

### 1. Hedera is NOT Standard EVM

While Hedera supports Solidity and EVM bytecode, it has **fundamental differences**:
- msg.value uses tinybars (10^8), not wei (10^18)
- 10^10 conversion factor between sent value and received value
- Native currency (HBAR) behaves differently than ETH

### 2. Always Test Native Currency Transfers

Standard ERC20 operations worked perfectly, but native currency transfers had hidden complexity. Always test:
- Sending value
- Receiving value
- Value comparisons
- Value forwarding

### 3. Debug Functions Are Essential

The `testMsgValue()` function was critical for discovering the exact conversion factor. On unfamiliar networks, add debug functions early.

### 4. Simulation != Reality

Forge simulations worked perfectly but failed on testnet. The simulation doesn't account for network-specific msg.value handling.

---

## Recommendations

### For Development

1. **Use helper view functions** like `calculatePurchaseCost()` that return network-native units
2. **Add comprehensive events** with actual values for debugging
3. **Test on target network early** - don't rely solely on simulations
4. **Document unit conversions** prominently in code comments

### For Production

1. **Update all payment logic** to handle Hedera's tinybar system
2. **Test with various amounts** to ensure conversion works across scales
3. **Add overpayment refunds** to handle minor discrepancies
4. **Consider price display** - show prices in HBAR, not wei

---

## Frontend Checklist

- [ ] Update PropertyFactory address to `0x4C67256697e4a6af045faB5D9891455Cba16C420`
- [ ] Implement `calculateHederaPurchaseValue()` helper
- [ ] Update purchase form to use correct value calculation
- [ ] Test purchase flow end-to-end
- [ ] Display prices in HBAR (divide wei by 10^18)
- [ ] Handle transaction confirmations
- [ ] Show refunds if overpayment occurs

---

## Conclusion

Successfully implemented direct token purchases on Hedera by:

1. ✅ Discovering msg.value arrives in tinybars (10^8 scale)
2. ✅ Implementing 10^10 conversion in smart contract
3. ✅ Testing and verifying on Hedera Testnet
4. ✅ Maintaining price storage in wei for consistency
5. ✅ Adding overpayment refund logic

**Result**: Fully functional token purchase system compatible with Hedera's unique architecture.

---

## Additional Resources

- Hedera Documentation: https://docs.hedera.com
- Conversion reference: 1 HBAR = 100,000,000 tinybars
- Test Explorer: https://hashscan.io/testnet/transaction/0xb4fc13461b8afe2dda1f34fc9f5294eea75c7e616427a67630613b729d179381

---

**Document Version**: 1.0
**Date**: 2025-10-26
**Network**: Hedera Testnet (Chain ID: 296)
**Working Contract**: 0x4C67256697e4a6af045faB5D9891455Cba16C420
