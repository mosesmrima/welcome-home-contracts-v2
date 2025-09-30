// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import "../src/OwnershipRegistry.sol";

contract DeployOwnershipRegistryScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("HEDERA_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Read AccessControl address from previous deployment
        string memory step1Data = vm.readFile("deployment_step_1.json");
        bytes memory step1Bytes = vm.parseJson(step1Data);
        address accessControlAddress = abi.decode(step1Bytes, (address));

        console.log("=== DEPLOYING OWNERSHIP REGISTRY TO HEDERA TESTNET ===");
        console.log("Deployer address:", deployer);
        console.log("AccessControl address:", accessControlAddress);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy OwnershipRegistry - this is the ONLY transaction in this script
        OwnershipRegistry ownershipRegistry = new OwnershipRegistry(accessControlAddress);

        vm.stopBroadcast();

        console.log("OwnershipRegistry deployed successfully!");
        console.log("Address:", address(ownershipRegistry));

        // Update deployment info
        string memory deploymentInfo = string(abi.encodePacked(
            '{"AccessControl":"',
            vm.toString(accessControlAddress),
            '","OwnershipRegistry":"',
            vm.toString(address(ownershipRegistry)),
            '"}'
        ));

        vm.writeFile("deployment_step_2.json", deploymentInfo);

        console.log("Deployment info saved to deployment_step_2.json");
        console.log("Next: Run 03_deploy_property_factory.s.sol");
    }
}