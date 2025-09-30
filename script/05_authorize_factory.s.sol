// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import "../src/OwnershipRegistry.sol";

contract AuthorizeFactoryScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("HEDERA_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Read contract addresses from previous deployments
        string memory step4Data = vm.readFile("deployment_step_4.json");
        address ownershipRegistryAddress = vm.parseJsonAddress(step4Data, ".OwnershipRegistry");
        address propertyFactoryAddress = vm.parseJsonAddress(step4Data, ".PropertyFactory");

        console.log("=== AUTHORIZING PROPERTY FACTORY IN OWNERSHIP REGISTRY ===");
        console.log("Deployer address:", deployer);
        console.log("OwnershipRegistry address:", ownershipRegistryAddress);
        console.log("PropertyFactory address:", propertyFactoryAddress);

        OwnershipRegistry ownershipRegistry = OwnershipRegistry(ownershipRegistryAddress);

        vm.startBroadcast(deployerPrivateKey);

        // Authorize PropertyFactory to update ownership - this is the ONLY transaction
        ownershipRegistry.setAuthorizedUpdater(propertyFactoryAddress, true);

        vm.stopBroadcast();

        console.log("PropertyFactory authorized successfully!");
        console.log("PropertyFactory can now update ownership records");

        // Copy deployment file to next step
        vm.writeFile("deployment_step_5.json", step4Data);

        console.log("Setup step completed");
        console.log("Next: Run 06_set_admin.s.sol");
    }
}