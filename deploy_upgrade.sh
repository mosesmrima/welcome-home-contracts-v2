#!/bin/bash

# Hedera Testnet PropertyFactory Upgrade Deployment
# Deploys upgraded PropertyFactory with purchaseTokens() function

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

echo -e "${BLUE}🚀 PROPERTY FACTORY UPGRADE DEPLOYMENT${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""
echo "This script will deploy the upgraded PropertyFactory with purchaseTokens() function"
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

# Check if previous deployment exists
if [ ! -f "deployment_step_4.json" ]; then
    echo -e "${RED}❌ Error: deployment_step_4.json not found. Please run full deployment first.${NC}"
    exit 1
fi

# Deployment steps
declare -a STEPS=(
    "14_deploy_upgraded_property_factory.s.sol:Deploy Upgraded PropertyFactory"
    "15_authorize_upgraded_factory.s.sol:Authorize Upgraded Factory"
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

# Show what will be upgraded
echo -e "${BLUE}📦 UPGRADE DETAILS:${NC}"
echo ""
echo "New Feature: Direct Token Purchase"
echo "  • Users can now purchase property tokens directly with HBAR"
echo "  • No need for manual distribution by property managers"
echo "  • Payments automatically sent to property creators"
echo "  • KYC verification still enforced for security"
echo ""
echo "Technical Changes:"
echo "  • Added purchaseTokens(uint256 propertyId, uint256 tokenAmount) payable function"
echo "  • Added TokensPurchased event for transaction tracking"
echo "  • Maintains all existing functionality (distributeTokens, etc.)"
echo ""

# Confirm deployment
echo -e "${YELLOW}⚠️  WARNING: This will deploy a new PropertyFactory to Hedera Testnet and cost HBAR.${NC}"
echo -e "${YELLOW}⚠️  The old PropertyFactory will remain deployed but frontend will use the new one.${NC}"
read -p "Do you want to proceed? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi

echo ""
echo -e "${BLUE}🏁 Starting upgrade deployment...${NC}"
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

echo -e "${GREEN}🎉 UPGRADE DEPLOYMENT COMPLETED SUCCESSFULLY!${NC}"
echo ""
echo -e "${GREEN}📊 DEPLOYMENT SUMMARY:${NC}"
echo "• Total steps: ${total_steps}"
echo "• Total time: ${minutes}m ${seconds}s"
echo "• Network: Hedera Testnet (Chain ID: 296)"
echo ""

# Show deployment info
if [ -f "deployment_step_15.json" ]; then
    echo -e "${BLUE}📄 Deployment info saved to: deployment_step_15.json${NC}"
    echo ""

    # Extract the new PropertyFactory address
    if command -v jq &> /dev/null; then
        NEW_FACTORY=$(jq -r '.PropertyFactory' deployment_step_15.json)
        echo -e "${GREEN}🏭 New PropertyFactory Address:${NC}"
        echo "   ${NEW_FACTORY}"
        echo ""
        echo -e "${BLUE}📋 HashScan Explorer:${NC}"
        echo "   https://hashscan.io/testnet/contract/${NEW_FACTORY}"
    fi
fi

echo ""
echo -e "${GREEN}🔗 Next Steps:${NC}"
echo "1. Update frontend contract address in app/lib/web3/addresses.ts"
echo "   PROPERTY_FACTORY: '<new address from above>'"
echo ""
echo "2. Test the new purchase functionality:"
echo "   • Go to marketplace in the frontend"
echo "   • Select a property"
echo "   • Try purchasing tokens directly with HBAR"
echo ""
echo "3. Verify the transaction on HashScan"
echo ""
echo -e "${BLUE}Happy testing! 🏠${NC}"
