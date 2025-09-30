// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import "../src/AccessControl.sol";

contract KYCTestUsersScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("HEDERA_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Read contract addresses from previous deployments
        string memory step11Data = vm.readFile("deployment_step_11.json");
        address accessControlAddress = vm.parseJsonAddress(step11Data, ".AccessControl");

        // Define test user addresses (these would be real test accounts in production)
        address testUser1 = address(0x1111111111111111111111111111111111111111);
        address testUser2 = address(0x2222222222222222222222222222222222222222);
        address testUser3 = address(0x3333333333333333333333333333333333333333);

        console.log("=== SETTING KYC STATUS FOR TEST USERS ===");
        console.log("Deployer address:", deployer);
        console.log("AccessControl address:", accessControlAddress);
        console.log("Test user 1:", testUser1);
        console.log("Test user 2:", testUser2);
        console.log("Test user 3:", testUser3);

        AccessControl accessControl = AccessControl(accessControlAddress);

        // NOTE: This script demonstrates KYC setup for testing
        // In production, you would replace these addresses with real test accounts
        console.log("WARNING: Using placeholder addresses for demonstration");
        console.log("Replace with real test account addresses before deployment");

        vm.startBroadcast(deployerPrivateKey);

        // KYC test users - this is the ONLY transaction in this script
        // Using batch KYC for efficiency
        address[] memory testUsers = new address[](3);
        testUsers[0] = testUser1;
        testUsers[1] = testUser2;
        testUsers[2] = testUser3;

        accessControl.batchSetKYC(testUsers, true);

        vm.stopBroadcast();

        console.log("Test users KYC status set successfully!");
        console.log("Test users can now participate in marketplace");

        // Copy deployment file to next step (test users are just for demonstration)
        vm.writeFile("deployment_step_12.json", step11Data);

        console.log("Setup step completed");
        console.log("Next: Run 13_verify_deployment.s.sol");
    }
}