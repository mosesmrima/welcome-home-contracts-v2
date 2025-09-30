// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import "../src/AccessControl.sol";

contract KYCDeployerScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("HEDERA_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Read contract addresses from previous deployments
        string memory step9Data = vm.readFile("deployment_step_9.json");
        address accessControlAddress = vm.parseJsonAddress(step9Data, ".AccessControl");

        console.log("=== SETTING KYC STATUS FOR DEPLOYER ===");
        console.log("Deployer address:", deployer);
        console.log("AccessControl address:", accessControlAddress);
        console.log("Setting deployer as KYC verified...");

        AccessControl accessControl = AccessControl(accessControlAddress);

        vm.startBroadcast(deployerPrivateKey);

        // Set deployer as KYC verified - this is the ONLY transaction
        accessControl.setKYCStatus(deployer, true);

        vm.stopBroadcast();

        console.log("Deployer KYC status set successfully!");
        console.log("Deployer can now participate in token transfers and marketplace");

        // Copy deployment file to next step
        vm.writeFile("deployment_step_10.json", step9Data);

        console.log("Setup step completed");
        console.log("Next: Run 11_kyc_property_manager.s.sol");
    }
}