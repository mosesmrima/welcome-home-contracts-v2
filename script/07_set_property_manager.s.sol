// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import "../src/AccessControl.sol";

contract SetPropertyManagerScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("HEDERA_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Read contract addresses from previous deployments
        string memory step6Data = vm.readFile("deployment_step_6.json");
        address accessControlAddress = vm.parseJsonAddress(step6Data, ".AccessControl");

        // For testnet, deployer will also be the property manager
        // In production, this would be a separate address
        address propertyManager = deployer;

        console.log("=== SETTING PROPERTY MANAGER ROLE ===");
        console.log("Deployer address:", deployer);
        console.log("AccessControl address:", accessControlAddress);
        console.log("Property manager address:", propertyManager);

        AccessControl accessControl = AccessControl(accessControlAddress);

        vm.startBroadcast(deployerPrivateKey);

        // Set deployer as property manager - this is the ONLY transaction
        accessControl.setPropertyManager(propertyManager, true);

        vm.stopBroadcast();

        console.log("Property manager role set successfully!");
        console.log("Property manager can now create properties and distribute tokens");

        // Copy deployment file to next step
        vm.writeFile("deployment_step_7.json", step6Data);

        console.log("Setup step completed");
        console.log("Next: Run 08_set_marketplace_fee.s.sol");
    }
}