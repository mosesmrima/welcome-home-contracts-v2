// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import "../src/OwnershipRegistry.sol";

contract AuthorizeUpgradedFactoryScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("HEDERA_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Read contract addresses from previous deployment
        string memory step14Data = vm.readFile("deployment_step_14.json");
        address ownershipRegistryAddress = vm.parseJsonAddress(step14Data, ".OwnershipRegistry");
        address propertyFactoryAddress = vm.parseJsonAddress(step14Data, ".PropertyFactory");

        console.log("=== AUTHORIZING UPGRADED PROPERTY FACTORY ===");
        console.log("Deployer address:", deployer);
        console.log("OwnershipRegistry address:", ownershipRegistryAddress);
        console.log("Upgraded PropertyFactory address:", propertyFactoryAddress);

        OwnershipRegistry ownershipRegistry = OwnershipRegistry(ownershipRegistryAddress);

        vm.startBroadcast(deployerPrivateKey);

        // Authorize upgraded PropertyFactory to update ownership
        // This is the ONLY transaction in this script
        ownershipRegistry.setAuthorizedUpdater(propertyFactoryAddress, true);

        vm.stopBroadcast();

        console.log("");
        console.log("Upgraded PropertyFactory authorized successfully!");
        console.log("PropertyFactory can now update ownership records");

        // Copy deployment file to next step
        vm.writeFile("deployment_step_15.json", step14Data);

        console.log("");
        console.log("Setup step completed");
        console.log("Next: Update frontend contract addresses in app/lib/web3/addresses.ts");
    }
}
