// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import "../src/AccessControl.sol";

contract KYCFactoryScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("HEDERA_PRIVATE_KEY");

        // Read deployed contracts
        string memory deploymentData = vm.readFile("deployment_step_12.json");
        address accessControlAddress = vm.parseJsonAddress(deploymentData, ".AccessControl");
        address propertyFactoryAddress = vm.parseJsonAddress(deploymentData, ".PropertyFactory");

        console.log("=== KYC VERIFYING PROPERTY FACTORY ===");
        console.log("AccessControl:", accessControlAddress);
        console.log("PropertyFactory:", propertyFactoryAddress);

        AccessControl accessControl = AccessControl(accessControlAddress);

        vm.startBroadcast(deployerPrivateKey);

        // KYC verify the PropertyFactory contract
        accessControl.setKYCStatus(propertyFactoryAddress, true);

        vm.stopBroadcast();

        console.log("PropertyFactory is now KYC verified!");
        console.log("Ready to distribute tokens!");
    }
}