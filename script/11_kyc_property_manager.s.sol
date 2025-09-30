// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import "../src/AccessControl.sol";

contract KYCPropertyManagerScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("HEDERA_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Read contract addresses from previous deployments
        string memory step10Data = vm.readFile("deployment_step_10.json");
        address accessControlAddress = vm.parseJsonAddress(step10Data, ".AccessControl");

        // For testnet, deployer is also the property manager
        // In production, this might be a different address
        address propertyManager = deployer;

        console.log("=== SETTING KYC STATUS FOR PROPERTY MANAGER ===");
        console.log("Deployer address:", deployer);
        console.log("AccessControl address:", accessControlAddress);
        console.log("Property manager address:", propertyManager);

        AccessControl accessControl = AccessControl(accessControlAddress);

        // Check if already KYC'd (might be same as deployer)
        bool isAlreadyKYC = accessControl.isKYCVerified(propertyManager);
        console.log("Is property manager already KYC'd?", isAlreadyKYC);

        if (isAlreadyKYC) {
            console.log("Property manager is already KYC verified - skipping");
            // Still copy the file
            vm.writeFile("deployment_step_11.json", step10Data);
        } else {
            vm.startBroadcast(deployerPrivateKey);

            // Set property manager as KYC verified - this is the ONLY transaction
            accessControl.setKYCStatus(propertyManager, true);

            vm.stopBroadcast();

            console.log("Property manager KYC status set successfully!");

            // Copy deployment file to next step
            vm.writeFile("deployment_step_11.json", step10Data);
        }

        console.log("Property manager can now create and manage properties");
        console.log("Setup step completed");
        console.log("Next: Run 12_kyc_test_users.s.sol");
    }
}