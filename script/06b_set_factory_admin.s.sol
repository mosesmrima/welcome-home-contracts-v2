// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import "../src/AccessControl.sol";

contract SetFactoryAdminScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("HEDERA_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Read contract addresses from previous deployments
        string memory step6Data = vm.readFile("deployment_step_6.json");
        address accessControlAddress = vm.parseJsonAddress(step6Data, ".AccessControl");
        address propertyFactoryAddress = vm.parseJsonAddress(step6Data, ".PropertyFactory");

        console.log("=== SETTING PROPERTY FACTORY AS ADMIN ===");
        console.log("Deployer address:", deployer);
        console.log("AccessControl address:", accessControlAddress);
        console.log("PropertyFactory address:", propertyFactoryAddress);
        console.log("");
        console.log("IMPORTANT: PropertyFactory MUST be admin because it calls");
        console.log("ownershipRegistry.setAuthorizedUpdater() when creating properties.");
        console.log("This function requires onlyAdmin modifier.");
        console.log("");

        AccessControl accessControl = AccessControl(accessControlAddress);

        vm.startBroadcast(deployerPrivateKey);

        // Set PropertyFactory as admin - this is the ONLY transaction
        accessControl.setAdmin(propertyFactoryAddress, true);

        vm.stopBroadcast();

        console.log("PropertyFactory admin role set successfully!");
        console.log("PropertyFactory can now authorize new property tokens");

        // Copy deployment file to next step (keeping the chain going)
        vm.writeFile("deployment_step_6b.json", step6Data);

        console.log("Setup step completed");
        console.log("Next: Run 07_set_property_manager.s.sol");
    }
}
