// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import "../src/AccessControl.sol";
import "../src/OwnershipRegistry.sol";
import "../src/PropertyFactory.sol";
import "../src/Marketplace.sol";
import "../src/PropertyToken.sol";

contract VerifySystemStateScript is Script {
    function run() public view {
        address deployer = vm.addr(vm.envUint("HEDERA_PRIVATE_KEY"));

        // Read deployed contracts
        string memory deploymentData = vm.readFile("deployment_step_12.json");
        address accessControlAddress = vm.parseJsonAddress(deploymentData, ".AccessControl");
        address ownershipRegistryAddress = vm.parseJsonAddress(deploymentData, ".OwnershipRegistry");
        address propertyFactoryAddress = vm.parseJsonAddress(deploymentData, ".PropertyFactory");
        address marketplaceAddress = vm.parseJsonAddress(deploymentData, ".Marketplace");

        console.log("=== COMPREHENSIVE SYSTEM STATE VERIFICATION ===");
        console.log("Timestamp:", block.timestamp);
        console.log("Block Number:", block.number);
        console.log("Deployer:", deployer);
        console.log("");

        // Initialize contract instances
        AccessControl accessControl = AccessControl(accessControlAddress);
        OwnershipRegistry ownershipRegistry = OwnershipRegistry(ownershipRegistryAddress);
        PropertyFactory propertyFactory = PropertyFactory(propertyFactoryAddress);
        Marketplace marketplace = Marketplace(marketplaceAddress);

        // ===================
        // ACCESS CONTROL STATE
        // ===================
        console.log("1. ACCESS CONTROL STATE:");
        console.log("Address:", accessControlAddress);
        console.log("- System paused:", accessControl.isSystemPaused() ? "YES" : "NO");
        console.log("- Deployer is admin:", accessControl.isUserAdmin(deployer) ? "YES" : "NO");
        console.log("- Deployer is property manager:", accessControl.isUserPropertyManager(deployer) ? "YES" : "NO");
        console.log("- Deployer is KYC'd:", accessControl.isUserKYCed(deployer) ? "YES" : "NO");
        console.log("- PropertyFactory is admin:", accessControl.isUserAdmin(propertyFactoryAddress) ? "YES" : "NO");
        console.log("- PropertyFactory is KYC'd:", accessControl.isUserKYCed(propertyFactoryAddress) ? "YES" : "NO");
        console.log("- Marketplace is KYC'd:", accessControl.isUserKYCed(marketplaceAddress) ? "YES" : "NO");
        console.log("");

        // ===================
        // OWNERSHIP REGISTRY STATE
        // ===================
        console.log("2. OWNERSHIP REGISTRY STATE:");
        console.log("Address:", ownershipRegistryAddress);
        console.log("- Total unique holders:", ownershipRegistry.getTotalUniqueHolders());
        console.log("- PropertyFactory authorized:", ownershipRegistry.authorizedUpdaters(propertyFactoryAddress) ? "YES" : "NO");
        console.log("");

        // ===================
        // PROPERTY FACTORY STATE
        // ===================
        console.log("3. PROPERTY FACTORY STATE:");
        console.log("Address:", propertyFactoryAddress);
        console.log("- Next property ID:", propertyFactory.nextPropertyId());
        console.log("- Active property count:", propertyFactory.getActivePropertyCount());
        console.log("- AccessControl linked:", address(propertyFactory.accessControl()));
        console.log("- OwnershipRegistry linked:", address(propertyFactory.ownershipRegistry()));
        console.log("");

        // Check each property
        uint256 totalProperties = propertyFactory.nextPropertyId();
        for (uint256 i = 0; i < totalProperties; i++) {
            try propertyFactory.properties(i) returns (
                uint256 id,
                string memory name,
                string memory metadataURI,
                address tokenContract,
                uint256 totalValue,
                uint256 totalSupply,
                uint256 pricePerToken,
                bool isActive,
                address creator,
                uint256 createdAt
            ) {
                console.log("Property", i, "Details:");
                console.log("- Name:", name);
                console.log("- Token contract:", tokenContract);
                console.log("- Total value:", totalValue, "wei");
                console.log("- Total supply:", totalSupply / 1e18, "tokens");
                console.log("- Price per token:", pricePerToken, "wei");
                console.log("- Is active:", isActive ? "YES" : "NO");
                console.log("- Creator:", creator);
                console.log("- Created at:", createdAt);

                // Check token contract state
                if (tokenContract != address(0)) {
                    PropertyToken token = PropertyToken(tokenContract);
                    console.log("- Token name:", token.name());
                    console.log("- Token symbol:", token.symbol());
                    console.log("- Deployer balance:", token.balanceOf(deployer) / 1e18, "tokens");
                    console.log("- PropertyFactory balance:", token.balanceOf(propertyFactoryAddress) / 1e18, "tokens");
                    console.log("- Marketplace balance:", token.balanceOf(marketplaceAddress) / 1e18, "tokens");
                }
                console.log("");
            } catch {
                console.log("Property", i, ": Does not exist or error reading");
                console.log("");
            }
        }

        // ===================
        // MARKETPLACE STATE
        // ===================
        console.log("4. MARKETPLACE STATE:");
        console.log("Address:", marketplaceAddress);
        console.log("- Platform fee:", marketplace.platformFeePercent(), "basis points");
        console.log("- Fee collector:", marketplace.feeCollector());
        console.log("- Next listing ID:", marketplace.nextListingId());
        console.log("- Next offer ID:", marketplace.nextOfferId());
        console.log("- AccessControl linked:", address(marketplace.accessControl()));
        console.log("");

        // Check each listing
        uint256 totalListings = marketplace.nextListingId();
        for (uint256 i = 0; i < totalListings; i++) {
            try marketplace.listings(i) returns (
                uint256 id,
                address seller,
                address tokenContract,
                uint256 amount,
                uint256 pricePerToken,
                bool isActive,
                uint256 createdAt
            ) {
                console.log("Listing", i, "Details:");
                console.log("- Seller:", seller);
                console.log("- Token contract:", tokenContract);
                console.log("- Amount:", amount / 1e18, "tokens");
                console.log("- Price per token:", pricePerToken, "wei");
                console.log("- Total value:", (amount * pricePerToken) / 1e18, "ETH");
                console.log("- Is active:", isActive ? "YES" : "NO");
                console.log("- Created at:", createdAt);
                console.log("");
            } catch {
                console.log("Listing", i, ": Does not exist or error reading");
                console.log("");
            }
        }

        // ===================
        // SYSTEM HEALTH CHECK
        // ===================
        console.log("5. SYSTEM HEALTH CHECK:");
        bool systemHealthy = true;

        // Check critical conditions
        if (accessControl.isSystemPaused()) {
            console.log("ISSUE: System is paused");
            systemHealthy = false;
        }

        if (!accessControl.isUserAdmin(deployer)) {
            console.log("ISSUE: Deployer is not admin");
            systemHealthy = false;
        }

        if (!ownershipRegistry.authorizedUpdaters(propertyFactoryAddress)) {
            console.log("ISSUE: PropertyFactory not authorized in OwnershipRegistry");
            systemHealthy = false;
        }

        if (marketplace.platformFeePercent() != 250) {
            console.log("ISSUE: Platform fee is not 2.5%");
            systemHealthy = false;
        }

        if (systemHealthy) {
            console.log("SYSTEM STATUS: HEALTHY - All critical checks passed!");
        } else {
            console.log("SYSTEM STATUS: NEEDS ATTENTION - Issues found above");
        }

        console.log("");
        console.log("=== STATE VERIFICATION COMPLETE ===");
    }
}