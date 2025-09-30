#!/bin/bash

# Hedera Testnet Deployment Runner
# Executes all deployment scripts sequentially with delays to prevent mempool drops

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DELAY_SECONDS=5
SCRIPT_DIR="script"

echo -e "${BLUE}🚀 HEDERA TESTNET DEPLOYMENT RUNNER${NC}"
echo -e "${BLUE}===================================${NC}"
echo ""
echo "This script will deploy the Welcome Home Property platform to Hedera Testnet"
echo "Each script sends exactly 1 transaction with ${DELAY_SECONDS}s delays between scripts"
echo ""

# Check if .env exists
if [ ! -f ".env" ]; then
    echo -e "${RED}❌ Error: .env file not found. Please ensure HEDERA_PRIVATE_KEY is set.${NC}"
    exit 1
fi

# Check if forge is available
if ! command -v forge &> /dev/null; then
    echo -e "${RED}❌ Error: forge not found. Please install Foundry.${NC}"
    exit 1
fi

# Deployment steps
declare -a STEPS=(
    "01_deploy_access_control.s.sol:Deploy AccessControl Contract"
    "02_deploy_ownership_registry.s.sol:Deploy OwnershipRegistry Contract"
    "03_deploy_property_factory.s.sol:Deploy PropertyFactory Contract"
    "04_deploy_marketplace.s.sol:Deploy Marketplace Contract"
    "05_authorize_factory.s.sol:Authorize PropertyFactory in Registry"
    "06_set_admin.s.sol:Set Deployer as Admin"
    "07_set_property_manager.s.sol:Set Deployer as Property Manager"
    "08_set_marketplace_fee.s.sol:Set Marketplace Platform Fee"
    "09_set_fee_collector.s.sol:Set Marketplace Fee Collector"
    "10_kyc_deployer.s.sol:KYC Verify Deployer"
    "11_kyc_property_manager.s.sol:KYC Verify Property Manager"
    "12_kyc_test_users.s.sol:KYC Verify Test Users"
    "13_verify_deployment.s.sol:Verify Complete Deployment"
)

# Function to run a deployment step
run_deployment_step() {
    local step_file=$1
    local step_description=$2
    local step_number=$3
    local total_steps=$4

    echo -e "${BLUE}📋 Step ${step_number}/${total_steps}: ${step_description}${NC}"
    echo "Script: ${step_file}"
    echo ""

    # Run the forge script
    if forge script ${SCRIPT_DIR}/${step_file} --rpc-url ${RPC_URL} --broadcast --legacy; then
        echo -e "${GREEN}✅ Step ${step_number} completed successfully!${NC}"

        # Add delay between steps (except for the last step)
        if [ $step_number -lt $total_steps ]; then
            echo -e "${YELLOW}⏳ Waiting ${DELAY_SECONDS}s before next step...${NC}"
            sleep $DELAY_SECONDS
        fi
        echo ""
    else
        echo -e "${RED}❌ Step ${step_number} failed!${NC}"
        echo -e "${RED}Deployment stopped at: ${step_description}${NC}"
        exit 1
    fi
}

# Get RPC URL from .env or use default
if grep -q "HEDERA_RPC_URL" .env; then
    export RPC_URL=$(grep HEDERA_RPC_URL .env | cut -d '=' -f2 | tr -d '"')
else
    export RPC_URL="https://testnet.hashio.io/api"
    echo -e "${YELLOW}⚠️  Using default RPC URL: ${RPC_URL}${NC}"
fi

echo "RPC URL: ${RPC_URL}"
echo ""

# Confirm deployment
echo -e "${YELLOW}⚠️  WARNING: This will deploy contracts to Hedera Testnet and cost HBAR.${NC}"
read -p "Do you want to proceed? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi

echo ""
echo -e "${BLUE}🏁 Starting deployment...${NC}"
echo ""

# Track deployment start time
start_time=$(date +%s)

# Execute all deployment steps
total_steps=${#STEPS[@]}
for i in "${!STEPS[@]}"; do
    IFS=':' read -r step_file step_description <<< "${STEPS[$i]}"
    step_number=$((i + 1))

    run_deployment_step "$step_file" "$step_description" "$step_number" "$total_steps"
done

# Calculate total deployment time
end_time=$(date +%s)
total_time=$((end_time - start_time))
minutes=$((total_time / 60))
seconds=$((total_time % 60))

echo -e "${GREEN}🎉 DEPLOYMENT COMPLETED SUCCESSFULLY!${NC}"
echo ""
echo -e "${GREEN}📊 DEPLOYMENT SUMMARY:${NC}"
echo "• Total steps: ${total_steps}"
echo "• Total time: ${minutes}m ${seconds}s"
echo "• Network: Hedera Testnet (Chain ID: 296)"
echo ""

# Show final deployment file if it exists
if [ -f "deployment_final.json" ]; then
    echo -e "${BLUE}📄 Final deployment summary saved to: deployment_final.json${NC}"
    echo ""
    echo -e "${BLUE}Contract addresses:${NC}"
    if command -v jq &> /dev/null; then
        jq '.contracts' deployment_final.json 2>/dev/null || echo "Unable to parse deployment_final.json"
    else
        echo "Install 'jq' to view formatted contract addresses"
        echo "Raw file content available in deployment_final.json"
    fi
fi

echo ""
echo -e "${GREEN}🔗 Next Steps:${NC}"
echo "1. Fund your deployer account with HBAR for testing"
echo "2. Create test properties via PropertyFactory"
echo "3. Test marketplace functionality"
echo "4. Verify contracts on Hashscan (commands provided in verification script)"
echo ""
echo -e "${BLUE}Happy testing! 🏠${NC}"