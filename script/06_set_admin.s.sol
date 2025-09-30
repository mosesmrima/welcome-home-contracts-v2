// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import "../src/AccessControl.sol";

contract SetAdminScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("HEDERA_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Read contract addresses from previous deployments
        string memory step5Data = vm.readFile("deployment_step_5.json");
        address accessControlAddress = vm.parseJsonAddress(step5Data, ".AccessControl");

        console.log("=== SETTING ADMIN ROLE ===");
        console.log("Deployer address:", deployer);
        console.log("AccessControl address:", accessControlAddress);
        console.log("Setting deployer as admin...");

        AccessControl accessControl = AccessControl(accessControlAddress);

        vm.startBroadcast(deployerPrivateKey);

        // Set deployer as admin - this is the ONLY transaction
        accessControl.setAdmin(deployer, true);

        vm.stopBroadcast();

        console.log("Admin role set successfully!");
        console.log("Deployer is now an admin");

        // Copy deployment file to next step
        vm.writeFile("deployment_step_6.json", step5Data);

        console.log("Setup step completed");
        console.log("Next: Run 07_set_property_manager.s.sol");
    }
}