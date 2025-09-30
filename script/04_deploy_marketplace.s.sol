// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import "../src/Marketplace.sol";

contract DeployMarketplaceScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("HEDERA_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Read contract addresses from previous deployments
        string memory step3Data = vm.readFile("deployment_step_3.json");
        address accessControlAddress = vm.parseJsonAddress(step3Data, ".AccessControl");

        // Fee collector will be the deployer for now (can be changed later)
        address feeCollector = deployer;

        console.log("=== DEPLOYING MARKETPLACE TO HEDERA TESTNET ===");
        console.log("Deployer address:", deployer);
        console.log("AccessControl address:", accessControlAddress);
        console.log("Fee collector:", feeCollector);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy Marketplace - this is the ONLY transaction in this script
        Marketplace marketplace = new Marketplace(
            accessControlAddress,
            feeCollector
        );

        vm.stopBroadcast();

        console.log("Marketplace deployed successfully!");
        console.log("Address:", address(marketplace));
        console.log("Default platform fee: 2.5% (250 basis points)");

        // Update deployment info with all contracts
        string memory deploymentInfo = string(abi.encodePacked(
            '{"AccessControl":"',
            vm.toString(accessControlAddress),
            '","OwnershipRegistry":"',
            vm.toString(vm.parseJsonAddress(step3Data, ".OwnershipRegistry")),
            '","PropertyFactory":"',
            vm.toString(vm.parseJsonAddress(step3Data, ".PropertyFactory")),
            '","Marketplace":"',
            vm.toString(address(marketplace)),
            '","deployer":"',
            vm.toString(deployer),
            '"}'
        ));

        vm.writeFile("deployment_step_4.json", deploymentInfo);

        console.log("Deployment info saved to deployment_step_4.json");
        console.log("ALL CONTRACTS DEPLOYED! Now starting setup phase...");
        console.log("Next: Run 05_authorize_factory.s.sol");
    }
}