# PropertyFactory Upgrade Guide

## Overview

This guide covers the upgrade of the PropertyFactory contract to add direct token purchase functionality. This upgrade allows users to purchase property tokens directly with HBAR, eliminating the need for manual distribution by property managers.

## What's New

### Direct Token Purchase Feature

**New Function**: `purchaseTokens(uint256 propertyId, uint256 tokenAmount) payable`

**How it Works**:
1. User selects a property and specifies how many tokens to purchase
2. User sends exact HBAR amount (tokenAmount × pricePerToken)
3. Smart contract validates:
   - User is KYC verified
   - Property is active
   - Factory has enough tokens available
   - Payment amount is exact
4. Tokens transferred to user
5. Payment sent to property creator
6. `TokensPurchased` event emitted

**Benefits**:
- Immediate token purchase without admin intervention
- Automated payment distribution to creators
- Maintains KYC compliance
- Lower operational overhead

### Existing Functionality Preserved

All existing functions remain intact:
- `createProperty()` - Create new tokenized properties
- `distributeTokens()` - Manual distribution by property managers
- `updatePropertyMetadata()` - Update property details
- `setPropertyActive()` - Enable/disable properties
- `updatePropertyPrice()` - Adjust token prices

## Deployment Process

### Prerequisites

1. **Existing Deployment**
   - Must have previously deployed the full platform
   - Requires `deployment_step_4.json` file
   - AccessControl and OwnershipRegistry must be deployed

2. **Environment Setup**
   ```bash
   # Ensure .env file exists with:
   HEDERA_PRIVATE_KEY=0xYOUR_PRIVATE_KEY
   HEDERA_RPC_URL=https://testnet.hashio.io/api
   ```

3. **Foundry Installation**
   ```bash
   # Install Foundry if not already installed
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   ```

### Step-by-Step Deployment

#### Option 1: Automated Deployment (Recommended)

```bash
# Navigate to contract directory
cd /home/mrima/welcome/buner-welcome

# Run the upgrade deployment script
./deploy_upgrade.sh
```

The script will:
1. Verify prerequisites (`.env`, previous deployment)
2. Display upgrade details
3. Ask for confirmation
4. Deploy upgraded PropertyFactory (Step 14)
5. Wait 5 seconds (Hedera mempool delay)
6. Authorize factory in OwnershipRegistry (Step 15)
7. Save deployment info to `deployment_step_15.json`
8. Display new contract address and next steps

#### Option 2: Manual Deployment

```bash
# Step 1: Deploy upgraded PropertyFactory
forge script script/14_deploy_upgraded_property_factory.s.sol \
  --rpc-url $HEDERA_RPC_URL \
  --broadcast \
  --legacy

# Wait 5 seconds
sleep 5

# Step 2: Authorize in OwnershipRegistry
forge script script/15_authorize_upgraded_factory.s.sol \
  --rpc-url $HEDERA_RPC_URL \
  --broadcast \
  --legacy
```

### Deployment Files

**Script Files**:
- `script/14_deploy_upgraded_property_factory.s.sol` - Deploys new PropertyFactory
- `script/15_authorize_upgraded_factory.s.sol` - Authorizes factory in registry
- `deploy_upgrade.sh` - Automated deployment runner

**Tracking Files**:
- `deployment_step_14.json` - After factory deployment
- `deployment_step_15.json` - Final upgrade state (includes new factory address)

## Frontend Integration

### Step 1: Update Contract Address

After successful deployment, update the frontend contract address:

**File**: `/home/mrima/welcome/welcomehome/app/lib/web3/addresses.ts`

```typescript
export const CONTRACT_ADDRESSES = {
  ACCESS_CONTROL: '0xDDAE60c136ea61552c1e6acF3c7Ab8beBd02eF69',
  OWNERSHIP_REGISTRY: '0x4Eb9F441eA43141572BC49a4e8Fdf53f44B5C99C',
  PROPERTY_FACTORY: '0x<NEW_ADDRESS_FROM_DEPLOYMENT>', // Update this
  MARKETPLACE: '0x74347e6046819f6cbc64eb301746c7AaDA614Dec',
}
```

Get the new address from:
- Console output after deployment
- `deployment_step_15.json` file
- HashScan explorer

### Step 2: Verify Frontend Updates (Already Complete)

The following frontend files have been updated to support direct purchases:

✅ **ABI Updated**: `app/lib/web3/abi.ts`
- Added `purchaseTokens` function signature
- Added `TokensPurchased` event

✅ **Hook Updated**: `app/lib/web3/hooks/use-property-factory.ts`
- Added `PurchaseTokensParams` interface
- Added `purchaseTokens()` function
- Added transaction state management
- Added auto-refetch after purchase

✅ **UI Updated**: `app/components/property/purchase-form.tsx`
- Complete rewrite with purchase interface
- Dual mode: Purchase (users) + Distribute (admins)
- Real-time cost calculation
- Error handling and success states
- HashScan transaction link

### Step 3: Test the Integration

1. **Start Frontend**
   ```bash
   cd /home/mrima/welcome/welcomehome
   npm run dev
   ```

2. **Connect Wallet**
   - Navigate to marketplace
   - Connect MetaMask/WalletConnect

3. **Test Purchase Flow**
   - Select a property
   - Click "Purchase" tab
   - Enter token quantity
   - Review total cost in HBAR
   - Click "Purchase Tokens"
   - Confirm transaction in wallet
   - Wait for confirmation
   - Verify success message
   - Check transaction on HashScan

## Security Considerations

### Smart Contract Security

1. **KYC Enforcement**
   ```solidity
   require(accessControl.isUserKYCed(msg.sender), "Buyer not KYC verified");
   ```
   Only KYC-verified users can purchase tokens

2. **Exact Payment Validation**
   ```solidity
   uint256 totalCost = tokenAmount * property.pricePerToken;
   require(msg.value == totalCost, "Incorrect payment amount");
   ```
   Prevents over/underpayment exploits

3. **Reentrancy Protection**
   ```solidity
   nonReentrant modifier
   ```
   Uses OpenZeppelin's ReentrancyGuard

4. **Supply Validation**
   ```solidity
   require(token.balanceOf(address(this)) >= tokenAmount, "Insufficient tokens available");
   ```
   Ensures factory has tokens before transfer

5. **Active Property Check**
   ```solidity
   require(property.isActive, "Property not active");
   ```
   Prevents purchases of inactive properties

### Payment Flow Security

1. **Direct Creator Payment**
   ```solidity
   (bool success, ) = property.creator.call{value: msg.value}("");
   require(success, "Payment transfer failed");
   ```
   HBAR sent directly to creator (no middleman)

2. **Atomic Transaction**
   - Token transfer and payment happen in same transaction
   - Either both succeed or both revert
   - No partial state changes

## Testing Checklist

### Smart Contract Tests

- [ ] Compile contracts without errors
  ```bash
  forge build
  ```

- [ ] Run existing test suite
  ```bash
  forge test
  ```

- [ ] Deploy to testnet successfully
  ```bash
  ./deploy_upgrade.sh
  ```

### Frontend Tests

- [ ] Property list displays correctly
- [ ] Purchase form renders for users
- [ ] Distribute form renders for property managers
- [ ] Token quantity input validates correctly
- [ ] Total cost calculation accurate
- [ ] Insufficient balance detected
- [ ] Exceeding available supply prevented
- [ ] Transaction signing works
- [ ] Success state displays
- [ ] Error handling works
- [ ] HashScan link correct

### Integration Tests

- [ ] **Successful Purchase**
  - User is KYC verified
  - Property is active
  - User sends exact HBAR amount
  - Tokens received by user
  - Payment received by creator
  - Event emitted correctly
  - Frontend updates properly

- [ ] **Rejected Scenarios**
  - Non-KYC user attempts purchase → Rejected
  - Inactive property → Rejected
  - Incorrect payment amount → Rejected
  - Insufficient tokens available → Rejected
  - Zero token amount → Rejected

## Rollback Plan

If issues arise after deployment:

### Option 1: Revert Frontend Address

Update frontend to use old factory address:

```typescript
// app/lib/web3/addresses.ts
export const CONTRACT_ADDRESSES = {
  PROPERTY_FACTORY: '0x366e65Ca8645086478454c89C3616Ba0bAf15A35', // Old address
  // ... other addresses
}
```

This preserves existing functionality while keeping new contract deployed.

### Option 2: Deauthorize New Factory

```bash
# Run as AccessControl owner
cast send $OWNERSHIP_REGISTRY \
  "setAuthorizedUpdater(address,bool)" \
  $NEW_FACTORY_ADDRESS \
  false \
  --rpc-url $HEDERA_RPC_URL \
  --private-key $PRIVATE_KEY
```

This prevents new factory from updating ownership records.

## Monitoring

### On-Chain Monitoring

1. **Check Factory Balance**
   ```bash
   cast call $PROPERTY_FACTORY "getPropertyCount()" --rpc-url $HEDERA_RPC_URL
   ```

2. **Check Authorization**
   ```bash
   cast call $OWNERSHIP_REGISTRY "authorizedUpdaters(address)" $PROPERTY_FACTORY --rpc-url $HEDERA_RPC_URL
   ```

3. **Monitor Events**
   - TokensPurchased events
   - TokensDistributed events
   - PropertyCreated events

### HashScan Explorer

Monitor contract activity:
- https://hashscan.io/testnet/contract/`<PROPERTY_FACTORY_ADDRESS>`

## Support and Troubleshooting

### Common Issues

**Issue**: Deployment fails at Step 14
- **Cause**: Insufficient HBAR for deployment
- **Fix**: Fund deployer account with testnet HBAR

**Issue**: Authorization fails at Step 15
- **Cause**: Deployer not authorized to call setAuthorizedUpdater
- **Fix**: Ensure deployer is owner of OwnershipRegistry

**Issue**: Frontend shows old contract
- **Cause**: Contract address not updated
- **Fix**: Update `app/lib/web3/addresses.ts` with new address

**Issue**: Purchase fails with "Buyer not KYC verified"
- **Cause**: User not KYC'd in AccessControl
- **Fix**: Admin must call `setKYCStatus(userAddress, true)`

**Issue**: Purchase fails with "Incorrect payment amount"
- **Cause**: msg.value doesn't match totalCost
- **Fix**: Frontend calculates: tokenAmount × pricePerToken exactly

## Version History

### v2.0.0 (Current - Upgraded Factory)
- ✅ Added `purchaseTokens()` function
- ✅ Added `TokensPurchased` event
- ✅ Direct HBAR payments to creators
- ✅ KYC-gated purchases
- ✅ Exact payment validation

### v1.0.0 (Original)
- Property creation
- Manual token distribution
- Metadata management
- Role-based access control

## Next Steps

After successful deployment and testing:

1. **Create Test Properties**
   - Use property manager account
   - Create diverse property types
   - Test different price points

2. **KYC Test Users**
   - Verify multiple test accounts
   - Test purchase flow with different users
   - Verify payment distribution

3. **Monitor Usage**
   - Track TokensPurchased events
   - Monitor gas usage
   - Collect user feedback

4. **Consider Enhancements**
   - Partial purchases
   - Purchase limits per user
   - Whitelisted investors
   - Tiered pricing

## Contact

For issues or questions:
- Review smart contract code in `/src/PropertyFactory.sol`
- Check frontend implementation in `/app/components/property/purchase-form.tsx`
- Review deployment scripts in `/script/14_*.s.sol` and `/script/15_*.s.sol`
