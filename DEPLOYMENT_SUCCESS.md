# PropertyFactory Upgrade - Deployment Success

## Deployment Summary

**Status**: SUCCESSFULLY DEPLOYED
**Date**: October 26, 2025
**Network**: Hedera Testnet (Chain ID: 296)
**Deployment Time**: 1 minute 33 seconds
**Gas Used**: ~2.92 ETH equivalent

---

## Deployed Contracts

### Upgraded PropertyFactory
- **Address**: `0x2eE30e1d5C9E40819FFD7a64d3bbD8e07Dd3C173`
- **HashScan**: https://hashscan.io/testnet/contract/0x2eE30e1d5C9E40819FFD7a64d3bbD8e07Dd3C173
- **Status**: Active and Authorized
- **New Feature**: Direct token purchases with HBAR

### Supporting Contracts (Unchanged)
- **AccessControl**: `0xDDAE60c136ea61552c1e6acF3c7Ab8beBd02eF69`
- **OwnershipRegistry**: `0x4Eb9F441eA43141572BC49a4e8Fdf53f44B5C99C`
- **Marketplace**: `0x74347e6046819f6cbc64eb301746c7AaDA614Dec`

### Deployer Account
- **Address**: `0xD1B156294aFa63d7d174D06D5A83e547d7a5abA9`
- **Roles**: Owner, Admin, Property Manager, KYC Verified

---

## What Changed

### Smart Contract Changes

**Previous PropertyFactory**: `0x366e65Ca8645086478454c89C3616Ba0bAf15A35` (now deprecated)

**New PropertyFactory**: `0x2eE30e1d5C9E40819FFD7a64d3bbD8e07Dd3C173`

**Added Function**:
```solidity
function purchaseTokens(uint256 propertyId, uint256 tokenAmount)
    external payable
    validProperty(propertyId)
    whenNotPaused
    nonReentrant
```

**Features**:
1. Users can purchase tokens directly by sending HBAR
2. Payments automatically routed to property creators
3. KYC verification enforced (buyers must be verified)
4. Exact payment validation (msg.value must equal tokenAmount × pricePerToken)
5. Reentrancy protection via OpenZeppelin's ReentrancyGuard
6. Emits `TokensPurchased` event for tracking

**Added Event**:
```solidity
event TokensPurchased(
    uint256 indexed propertyId,
    address indexed buyer,
    uint256 amount,
    uint256 totalCost
)
```

### Frontend Changes

**Updated Files**:
1. `app/lib/web3/addresses.ts` - Updated PROPERTY_FACTORY address
2. `app/lib/web3/abi.ts` - Added purchaseTokens function and event (done previously)
3. `app/lib/web3/hooks/use-property-factory.ts` - Added purchase hook (done previously)
4. `app/components/property/purchase-form.tsx` - Added purchase UI (done previously)

**User Experience**:
- Property managers see tabbed interface: Purchase + Distribute
- Regular users see simplified purchase-only interface
- Real-time cost calculation
- Transaction status tracking
- HashScan transaction links

---

## Deployment Steps Executed

### Step 1: Deploy Upgraded PropertyFactory
- **Script**: `script/14_deploy_upgraded_property_factory.s.sol`
- **Transaction**: Deployed new PropertyFactory contract
- **Gas**: 5,765,297 units (~2.88 ETH)
- **Output**: `deployment_step_14.json`
- **Result**: SUCCESS

### Step 2: Authorize in OwnershipRegistry
- **Script**: `script/15_authorize_upgraded_factory.s.sol`
- **Transaction**: Called `setAuthorizedUpdater(newFactory, true)`
- **Gas**: 78,265 units (~0.04 ETH)
- **Output**: `deployment_step_15.json`
- **Result**: SUCCESS

**Total Cost**: ~2.92 ETH equivalent in HBAR

---

## Verification

### On-Chain Verification

**PropertyFactory Deployment**:
```bash
# Check deployment
cast call 0x2eE30e1d5C9E40819FFD7a64d3bbD8e07Dd3C173 \
  "getPropertyCount()" \
  --rpc-url https://testnet.hashio.io/api
```

**Authorization Check**:
```bash
# Verify factory is authorized
cast call 0x4Eb9F441eA43141572BC49a4e8Fdf53f44B5C99C \
  "authorizedUpdaters(address)" \
  0x2eE30e1d5C9E40819FFD7a64d3bbD8e07Dd3C173 \
  --rpc-url https://testnet.hashio.io/api
```

**Expected**: Returns `true` (0x0000000000000000000000000000000000000000000000000000000000000001)

### Frontend Verification

**Contract Address Updated**:
- Location: `/home/mrima/welcome/welcomehome/app/lib/web3/addresses.ts`
- PROPERTY_FACTORY: `0x2eE30e1d5C9E40819FFD7a64d3bbD8e07Dd3C173`
- Status: UPDATED

**ABI Configuration**:
- Location: `/home/mrima/welcome/welcomehome/app/lib/web3/abi.ts`
- purchaseTokens function: PRESENT
- TokensPurchased event: PRESENT

**Hook Configuration**:
- Location: `/home/mrima/welcome/welcomehome/app/lib/web3/hooks/use-property-factory.ts`
- purchaseTokens function: IMPLEMENTED
- Transaction state management: IMPLEMENTED

**UI Configuration**:
- Location: `/home/mrima/welcome/welcomehome/app/components/property/purchase-form.tsx`
- Purchase interface: IMPLEMENTED
- Cost calculation: IMPLEMENTED

---

## Testing Instructions

### Prerequisites

1. **Wallet Setup**
   - MetaMask or compatible wallet
   - Connected to Hedera Testnet (Chain ID: 296)
   - RPC: https://testnet.hashio.io/api
   - Funded with testnet HBAR

2. **User KYC Status**
   - Test user must be KYC verified in AccessControl contract
   - Deployer (0xD1B156294aFa63d7d174D06D5A83e547d7a5abA9) is already verified

3. **Property Availability**
   - At least one active property must exist with available tokens
   - Property must have tokens in PropertyFactory balance

### Test Scenarios

#### Test 1: Successful Token Purchase

**Steps**:
1. Start frontend: `cd /home/mrima/welcome/welcomehome && npm run dev`
2. Navigate to marketplace
3. Connect wallet (use KYC'd address)
4. Select an active property
5. Click "Purchase" tab
6. Enter token quantity (e.g., 10 tokens)
7. Review total cost calculation
8. Click "Purchase Tokens"
9. Approve transaction in wallet
10. Wait for confirmation

**Expected Result**:
- Transaction succeeds
- Tokens transferred to buyer
- HBAR payment sent to property creator
- Success message displayed
- HashScan link provided
- Property list updates with new available supply

**Verification**:
```bash
# Check buyer's token balance
cast call <PROPERTY_TOKEN_ADDRESS> \
  "balanceOf(address)" \
  <BUYER_ADDRESS> \
  --rpc-url https://testnet.hashio.io/api
```

#### Test 2: Non-KYC User Rejection

**Steps**:
1. Connect with non-KYC'd wallet
2. Attempt to purchase tokens

**Expected Result**:
- Transaction reverts with "Buyer not KYC verified"
- No tokens transferred
- No payment sent

#### Test 3: Incorrect Payment Amount

**Steps**:
1. Connect with KYC'd wallet
2. Manually modify payment amount (requires direct contract interaction)

**Expected Result**:
- Transaction reverts with "Incorrect payment amount"
- No tokens transferred
- No payment sent

#### Test 4: Inactive Property

**Steps**:
1. Admin deactivates property: `setPropertyActive(propertyId, false)`
2. Attempt to purchase tokens from inactive property

**Expected Result**:
- Transaction reverts with "Property not active"
- No tokens transferred

#### Test 5: Insufficient Supply

**Steps**:
1. Attempt to purchase more tokens than available in factory

**Expected Result**:
- Transaction reverts with "Insufficient tokens available"
- No tokens transferred

#### Test 6: Property Manager Distribution (Existing Flow)

**Steps**:
1. Connect as property manager
2. Go to purchase form
3. Click "Distribute" tab
4. Enter recipient address and amount
5. Click "Distribute Tokens"

**Expected Result**:
- Still works as before
- Tokens distributed to recipient
- No payment required (admin action)

---

## Next Steps

### Immediate Actions

1. **Test Purchase Flow**
   - Follow test scenarios above
   - Verify all success and rejection cases
   - Monitor gas costs

2. **Create Test Properties**
   - Deploy diverse property types
   - Different price points
   - Various token supplies

3. **Monitor Transactions**
   - Watch for TokensPurchased events
   - Track payment flows
   - Analyze user behavior

### Future Enhancements

1. **Purchase Limits**
   - Per-user purchase caps
   - Time-based restrictions
   - Whitelisted investors

2. **Partial Purchases**
   - Allow purchasing less than full amount
   - Dynamic pricing
   - Bulk discounts

3. **Payment Options**
   - Support ERC20 stablecoins
   - Multiple payment tokens
   - Fiat on-ramp integration

4. **Analytics Dashboard**
   - Purchase volume tracking
   - Revenue analytics
   - User acquisition metrics

---

## Rollback Procedure

If critical issues are discovered:

### Option 1: Frontend Rollback (Quick)

Update frontend to use old factory:

```typescript
// app/lib/web3/addresses.ts
const DEPLOYED_ADDRESSES = {
  PROPERTY_FACTORY: '0x366e65Ca8645086478454c89C3616Ba0bAf15A35', // Old address
  // ... other addresses
}
```

**Impact**:
- Instant rollback
- Users revert to manual distribution flow
- New contract remains deployed but unused

### Option 2: Deauthorize New Factory

```bash
# As AccessControl owner
cast send 0x4Eb9F441eA43141572BC49a4e8Fdf53f44B5C99C \
  "setAuthorizedUpdater(address,bool)" \
  0x2eE30e1d5C9E40819FFD7a64d3bbD8e07Dd3C173 \
  false \
  --rpc-url https://testnet.hashio.io/api \
  --private-key $PRIVATE_KEY
```

**Impact**:
- Prevents new factory from updating ownership registry
- Preserves new factory deployment for future use
- Can re-authorize when issues resolved

---

## Support Resources

### Documentation
- Smart Contract Code: `/home/mrima/welcome/buner-welcome/src/PropertyFactory.sol`
- Deployment Scripts: `/home/mrima/welcome/buner-welcome/script/14_*.s.sol`
- Upgrade Guide: `/home/mrima/welcome/buner-welcome/UPGRADE_GUIDE.md`
- Frontend Integration: `/home/mrima/welcome/welcomehome/app/components/property/purchase-form.tsx`

### Blockchain Resources
- HashScan Explorer: https://hashscan.io/testnet
- Hedera Testnet RPC: https://testnet.hashio.io/api
- Hedera Faucet: https://portal.hedera.com/faucet

### Development Tools
- Foundry Documentation: https://book.getfoundry.sh/
- Wagmi Documentation: https://wagmi.sh/
- Viem Documentation: https://viem.sh/

---

## Deployment Artifacts

**Configuration Files**:
- `deployment_step_14.json` - After factory deployment
- `deployment_step_15.json` - Final deployment state

**Transaction Logs**:
- `/home/mrima/welcome/buner-welcome/broadcast/14_deploy_upgraded_property_factory.s.sol/296/run-latest.json`
- `/home/mrima/welcome/buner-welcome/broadcast/15_authorize_upgraded_factory.s.sol/296/run-latest.json`

**Deployment Scripts**:
- `script/14_deploy_upgraded_property_factory.s.sol`
- `script/15_authorize_upgraded_factory.s.sol`
- `deploy_upgrade.sh`

---

## Success Metrics

The deployment was successful based on:

- Smart contract compiled without errors
- All transactions confirmed on Hedera Testnet
- Factory authorized in OwnershipRegistry
- Frontend address updated correctly
- No runtime errors during deployment
- Gas costs within expected range
- All deployment artifacts generated correctly

## Deployment Status: COMPLETE

All required tasks have been completed:
- Smart contract upgraded with purchaseTokens() function
- Deployed to Hedera Testnet successfully
- Frontend updated with new contract address
- ABI and hooks configured correctly
- UI component supports purchase flow
- Documentation and guides created

**The system is ready for testing.**

---

**Generated**: October 26, 2025
**Deployer**: Welcome Home Property Platform Team
