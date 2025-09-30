// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import "../src/PropertyFactory.sol";

contract DeployPropertyFactoryScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("HEDERA_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Read contract addresses from previous deployments
        string memory step2Data = vm.readFile("deployment_step_2.json");

        // Parse JSON to extract addresses
        address accessControlAddress = vm.parseJsonAddress(step2Data, ".AccessControl");
        address ownershipRegistryAddress = vm.parseJsonAddress(step2Data, ".OwnershipRegistry");

        console.log("=== DEPLOYING PROPERTY FACTORY TO HEDERA TESTNET ===");
        console.log("Deployer address:", deployer);
        console.log("AccessControl address:", accessControlAddress);
        console.log("OwnershipRegistry address:", ownershipRegistryAddress);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy PropertyFactory - this is the ONLY transaction in this script
        PropertyFactory propertyFactory = new PropertyFactory(
            accessControlAddress,
            ownershipRegistryAddress
        );

        vm.stopBroadcast();

        console.log("PropertyFactory deployed successfully!");
        console.log("Address:", address(propertyFactory));

        // Update deployment info
        string memory deploymentInfo = string(abi.encodePacked(
            '{"AccessControl":"',
            vm.toString(accessControlAddress),
            '","OwnershipRegistry":"',
            vm.toString(ownershipRegistryAddress),
            '","PropertyFactory":"',
            vm.toString(address(propertyFactory)),
            '"}'
        ));

        vm.writeFile("deployment_step_3.json", deploymentInfo);

        console.log("Deployment info saved to deployment_step_3.json");
        console.log("Next: Run 04_deploy_marketplace.s.sol");
    }
}