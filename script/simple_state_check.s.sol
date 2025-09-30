// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import "../src/AccessControl.sol";
import "../src/OwnershipRegistry.sol";
import "../src/PropertyFactory.sol";
import "../src/Marketplace.sol";

contract SimpleStateCheckScript is Script {
    function run() public view {
        address deployer = vm.addr(vm.envUint("HEDERA_PRIVATE_KEY"));

        // Read deployed contracts
        string memory deploymentData = vm.readFile("deployment_step_12.json");
        address accessControlAddress = vm.parseJsonAddress(deploymentData, ".AccessControl");
        address ownershipRegistryAddress = vm.parseJsonAddress(deploymentData, ".OwnershipRegistry");
        address propertyFactoryAddress = vm.parseJsonAddress(deploymentData, ".PropertyFactory");
        address marketplaceAddress = vm.parseJsonAddress(deploymentData, ".Marketplace");

        console.log("=== SYSTEM STATE CHECK ===");
        console.log("");

        // Contract instances
        AccessControl accessControl = AccessControl(accessControlAddress);
        OwnershipRegistry ownershipRegistry = OwnershipRegistry(ownershipRegistryAddress);
        PropertyFactory propertyFactory = PropertyFactory(propertyFactoryAddress);
        Marketplace marketplace = Marketplace(marketplaceAddress);

        // ACCESS CONTROL
        console.log("ACCESS CONTROL:");
        console.log("- System paused:", accessControl.isSystemPaused() ? "YES" : "NO");
        console.log("- Deployer is admin:", accessControl.isUserAdmin(deployer) ? "YES" : "NO");
        console.log("- Deployer KYC'd:", accessControl.isUserKYCed(deployer) ? "YES" : "NO");
        console.log("");

        // PROPERTY FACTORY
        console.log("PROPERTY FACTORY:");
        console.log("- Next property ID:", propertyFactory.nextPropertyId());
        console.log("- Active properties:", propertyFactory.getActivePropertyCount());
        console.log("");

        // MARKETPLACE
        console.log("MARKETPLACE:");
        console.log("- Platform fee:", marketplace.platformFeePercent(), "basis points");
        console.log("- Next listing ID:", marketplace.nextListingId());
        console.log("- Next offer ID:", marketplace.nextOfferId());
        console.log("");

        // OWNERSHIP REGISTRY
        console.log("OWNERSHIP REGISTRY:");
        console.log("- Total unique holders:", ownershipRegistry.getTotalUniqueHolders());
        console.log("- Factory authorized:", ownershipRegistry.authorizedUpdaters(propertyFactoryAddress) ? "YES" : "NO");
        console.log("");

        console.log("=== STATE CHECK COMPLETE ===");
    }
}