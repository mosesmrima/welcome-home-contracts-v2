// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import "../src/AccessControl.sol";
import "../src/OwnershipRegistry.sol";
import "../src/PropertyFactory.sol";
import "../src/Marketplace.sol";

contract VerifyDeploymentScript is Script {
    function run() public {
        // Read final deployment data
        string memory step12Data = vm.readFile("deployment_step_12.json");

        address accessControlAddress = vm.parseJsonAddress(step12Data, ".AccessControl");
        address ownershipRegistryAddress = vm.parseJsonAddress(step12Data, ".OwnershipRegistry");
        address propertyFactoryAddress = vm.parseJsonAddress(step12Data, ".PropertyFactory");
        address marketplaceAddress = vm.parseJsonAddress(step12Data, ".Marketplace");
        address deployerAddress = vm.parseJsonAddress(step12Data, ".deployer");

        console.log("=== HEDERA TESTNET DEPLOYMENT VERIFICATION ===");
        console.log("Network: Hedera Testnet (Chain ID: 296)");
        console.log("Deployer:", deployerAddress);
        console.log("");

        console.log("CONTRACT ADDRESSES:");
        console.log("AccessControl:     ", accessControlAddress);
        console.log("OwnershipRegistry: ", ownershipRegistryAddress);
        console.log("PropertyFactory:   ", propertyFactoryAddress);
        console.log("Marketplace:       ", marketplaceAddress);
        console.log("");

        // Initialize contract instances
        AccessControl accessControl = AccessControl(accessControlAddress);
        OwnershipRegistry ownershipRegistry = OwnershipRegistry(ownershipRegistryAddress);
        PropertyFactory propertyFactory = PropertyFactory(propertyFactoryAddress);
        Marketplace marketplace = Marketplace(marketplaceAddress);

        console.log("VERIFICATION CHECKS:");

        // Check AccessControl
        bool deployerIsAdmin = accessControl.isUserAdmin(deployerAddress);
        bool deployerIsPropertyManager = accessControl.isUserPropertyManager(deployerAddress);
        bool deployerIsKYC = accessControl.isUserKYCed(deployerAddress);
        bool systemNotPaused = !accessControl.isSystemPaused();

        console.log("AccessControl:");
        console.log("  - Deployer is admin:", deployerIsAdmin ? "YES" : "NO");
        console.log("  - Deployer is property manager:", deployerIsPropertyManager ? "YES" : "NO");
        console.log("  - Deployer is KYC'd:", deployerIsKYC ? "YES" : "NO");
        console.log("  - System not paused:", systemNotPaused ? "YES" : "NO");

        // Check OwnershipRegistry
        bool factoryAuthorized = ownershipRegistry.authorizedUpdaters(propertyFactoryAddress);

        console.log("OwnershipRegistry:");
        console.log("  - PropertyFactory authorized:", factoryAuthorized ? "YES" : "NO");
        console.log("  - Total unique holders:", ownershipRegistry.getTotalUniqueHolders());

        // Check PropertyFactory
        uint256 nextPropertyId = propertyFactory.nextPropertyId();
        uint256 activePropertyCount = propertyFactory.getActivePropertyCount();

        console.log("PropertyFactory:");
        console.log("  - Next property ID:", nextPropertyId);
        console.log("  - Active properties:", activePropertyCount);
        console.log("  - AccessControl linked:", address(propertyFactory.accessControl()));
        console.log("  - OwnershipRegistry linked:", address(propertyFactory.ownershipRegistry()));

        // Check Marketplace
        uint256 platformFee = marketplace.platformFeePercent();
        address feeCollector = marketplace.feeCollector();

        console.log("Marketplace:");
        console.log("  - Platform fee:", platformFee, "basis points");
        console.log("  - Fee collector:", feeCollector);
        console.log("  - AccessControl linked:", address(marketplace.accessControl()));
        console.log("  - Next listing ID:", marketplace.nextListingId());

        console.log("");
        console.log("DEPLOYMENT VERIFICATION COMPLETE!");

        // Determine if deployment is healthy
        bool deploymentHealthy = deployerIsAdmin &&
                               deployerIsPropertyManager &&
                               deployerIsKYC &&
                               systemNotPaused &&
                               factoryAuthorized &&
                               platformFee == 250;

        if (deploymentHealthy) {
            console.log("STATUS: HEALTHY - All systems operational!");
            console.log("");
            console.log("NEXT STEPS:");
            console.log("1. Fund deployer account with HBAR for testing");
            console.log("2. Create test properties via PropertyFactory");
            console.log("3. Test marketplace functionality");
            console.log("4. Verify contracts on Hashscan (optional)");
        } else {
            console.log("STATUS: NEEDS ATTENTION - Check failed verifications above");
        }

        // Save final deployment summary (simplified to avoid stack depth)
        string memory status = deploymentHealthy ? "healthy" : "needs-attention";
        string memory finalSummary = string(abi.encodePacked(
            '{"network":"hedera-testnet","chainId":296,"status":"',
            status,
            '"}'
        ));

        vm.writeFile("deployment_final.json", finalSummary);
        console.log("Final deployment summary saved to deployment_final.json");
    }
}