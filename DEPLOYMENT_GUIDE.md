# Hedera Testnet Deployment Guide

## Overview

This guide provides step-by-step instructions for deploying the Welcome Home Property platform to Hedera Testnet. The deployment consists of 13 individual scripts, each sending exactly **1 transaction** to avoid mempool drops.

## Prerequisites

### 1. Environment Setup
- **Foundry**: Ensure `forge` is installed and working
- **HBAR**: Fund your deployer account with sufficient HBAR for gas fees
- **Environment Variables**: Configure your `.env` file

### 2. Required Environment Variables

Create/verify your `.env` file contains:

```bash
HEDERA_PRIVATE_KEY=0x... # Your private key (starts with 0x)
HEDERA_RPC_URL=https://testnet.hashio.io/api # Optional, uses default if not set
```

### 3. Pre-Deployment Verification

```bash
# Verify compilation works
forge build

# Verify all tests pass (optional but recommended)
forge test
```

## Deployment Methods

### Method 1: Automated Deployment (Recommended)

Use the provided deployment runner script:

```bash
# Make the script executable (if not already)
chmod +x deploy_all.sh

# Run the automated deployment
./deploy_all.sh
```

The script will:
- Execute all 13 deployment scripts sequentially
- Add 5-second delays between scripts to prevent mempool drops
- Display progress and status for each step
- Generate a final deployment summary

### Method 2: Manual Step-by-Step Deployment

If you prefer manual control or need to debug issues, run each script individually:

#### Phase 1: Core Contract Deployment (Steps 1-4)

```bash
# Step 1: Deploy AccessControl
forge script script/01_deploy_access_control.s.sol --rpc-url https://testnet.hashio.io/api --broadcast --legacy
# Wait 5 seconds
sleep 5

# Step 2: Deploy OwnershipRegistry
forge script script/02_deploy_ownership_registry.s.sol --rpc-url https://testnet.hashio.io/api --broadcast --legacy
# Wait 5 seconds
sleep 5

# Step 3: Deploy PropertyFactory
forge script script/03_deploy_property_factory.s.sol --rpc-url https://testnet.hashio.io/api --broadcast --legacy
# Wait 5 seconds
sleep 5

# Step 4: Deploy Marketplace
forge script script/04_deploy_marketplace.s.sol --rpc-url https://testnet.hashio.io/api --broadcast --legacy
# Wait 5 seconds
sleep 5
```

#### Phase 2: Contract Authorization & Configuration (Steps 5-9)

```bash
# Step 5: Authorize PropertyFactory in OwnershipRegistry
forge script script/05_authorize_factory.s.sol --rpc-url https://testnet.hashio.io/api --broadcast --legacy
sleep 5

# Step 6: Set Deployer as Admin
forge script script/06_set_admin.s.sol --rpc-url https://testnet.hashio.io/api --broadcast --legacy
sleep 5

# Step 7: Set Deployer as Property Manager
forge script script/07_set_property_manager.s.sol --rpc-url https://testnet.hashio.io/api --broadcast --legacy
sleep 5

# Step 8: Set Marketplace Platform Fee (2.5%)
forge script script/08_set_marketplace_fee.s.sol --rpc-url https://testnet.hashio.io/api --broadcast --legacy
sleep 5

# Step 9: Set Fee Collector
forge script script/09_set_fee_collector.s.sol --rpc-url https://testnet.hashio.io/api --broadcast --legacy
sleep 5
```

#### Phase 3: KYC Setup (Steps 10-12)

```bash
# Step 10: KYC Verify Deployer
forge script script/10_kyc_deployer.s.sol --rpc-url https://testnet.hashio.io/api --broadcast --legacy
sleep 5

# Step 11: KYC Verify Property Manager
forge script script/11_kyc_property_manager.s.sol --rpc-url https://testnet.hashio.io/api --broadcast --legacy
sleep 5

# Step 12: KYC Verify Test Users (placeholder addresses)
forge script script/12_kyc_test_users.s.sol --rpc-url https://testnet.hashio.io/api --broadcast --legacy
sleep 5
```

#### Phase 4: Verification (Step 13)

```bash
# Step 13: Verify Complete Deployment
forge script script/13_verify_deployment.s.sol --rpc-url https://testnet.hashio.io/api --legacy
```

**Note**: The verification script does not use `--broadcast` as it only reads blockchain state.

## Deployment Tracking

Each script generates JSON files to track deployment progress:

- `deployment_step_1.json` → `deployment_step_12.json`: Contract addresses after each step
- `deployment_final.json`: Final deployment summary with health status

## Troubleshooting

### Common Issues

#### 1. Compilation Errors
```bash
# If you see Unicode character errors:
Error (8936): Invalid character in string
```
**Solution**: All emoji characters have been removed from the scripts. Ensure you're using the latest versions.

#### 2. Insufficient HBAR
```bash
# If transactions fail due to insufficient funds:
Error: insufficient funds for gas * price + value
```
**Solution**: Fund your deployer account with more HBAR from the [Hedera Testnet Faucet](https://portal.hedera.com/faucet).

#### 3. Mempool Drops
```bash
# If transactions get dropped:
Error: transaction not found
```
**Solution**: The deployment scripts are designed to prevent this with single transactions per script and delays. If it still occurs, increase the delay between scripts.

#### 4. JSON File Missing
```bash
# If a step can't find the previous deployment file:
Error: file not found: deployment_step_X.json
```
**Solution**: Ensure previous steps completed successfully. Check that JSON files exist in your project root.

### Recovery Procedures

#### Partial Deployment Recovery
If deployment fails at any step, you can resume from that step:

1. **Identify the last successful step** by checking which `deployment_step_X.json` files exist
2. **Run remaining scripts starting from the failed step**
3. **Do not re-run successful steps** as this will create duplicate contracts

#### Complete Restart
If you need to start over:

```bash
# Remove all deployment tracking files
rm deployment_step_*.json deployment_final.json

# Start from step 1
forge script script/01_deploy_access_control.s.sol --rpc-url https://testnet.hashio.io/api --broadcast --legacy
```

## Post-Deployment Verification

### 1. Check Deployment Health

The verification script (step 13) will display:

- ✅ **HEALTHY**: All systems operational
- ⚠️ **NEEDS ATTENTION**: Some configurations failed

### 2. Contract Verification on Hashscan (Optional)

After deployment, you can verify your contracts on Hashscan:

```bash
# Example for AccessControl (replace with your actual address)
forge verify-contract 0xYourAccessControlAddress src/AccessControl.sol:AccessControl \
  --chain-id 296 --verifier sourcify \
  --verifier-url "https://server-verify.hashscan.io/"
```

### 3. View Deployed Contracts

Check your contracts on [Hashscan Testnet](https://hashscan.io/testnet) using the addresses from `deployment_final.json`.

## Next Steps

After successful deployment:

1. **Fund your deployer account** with HBAR for testing
2. **Create test properties** via PropertyFactory
3. **Test marketplace functionality**
4. **Set up frontend integration** using the deployed contract addresses

## Network Information

- **Network**: Hedera Testnet
- **Chain ID**: 296
- **RPC URL**: https://testnet.hashio.io/api
- **Explorer**: https://hashscan.io/testnet
- **Faucet**: https://portal.hedera.com/faucet

## Contract Addresses

After deployment, your contract addresses will be saved in `deployment_final.json`. The typical deployment includes:

- **AccessControl**: Core permission system
- **OwnershipRegistry**: Token holder tracking
- **PropertyFactory**: Property token creation
- **Marketplace**: Trading platform

## Security Notes

- **Private Key**: Never commit your private key to version control
- **Testnet Only**: These instructions are for Hedera Testnet only
- **Mainnet Deployment**: For mainnet, review all configurations and security parameters
- **KYC Addresses**: Replace placeholder test user addresses with real accounts before production use

---

## Support

If you encounter issues not covered in this guide:

1. Check the console output for specific error messages
2. Verify your HBAR balance and RPC connectivity
3. Ensure all prerequisites are met
4. Review the deployment tracking JSON files for clues

**Remember**: Each script sends exactly 1 transaction to prevent mempool issues on Hedera. This architecture ensures reliable deployment even with network congestion.