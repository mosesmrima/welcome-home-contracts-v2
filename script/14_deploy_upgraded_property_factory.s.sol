// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import "../src/PropertyFactory.sol";

contract DeployUpgradedPropertyFactoryScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("HEDERA_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Read contract addresses from previous deployments
        string memory step4Data = vm.readFile("deployment_step_4.json");

        // Parse JSON to extract addresses
        address accessControlAddress = vm.parseJsonAddress(step4Data, ".AccessControl");
        address ownershipRegistryAddress = vm.parseJsonAddress(step4Data, ".OwnershipRegistry");
        address marketplaceAddress = vm.parseJsonAddress(step4Data, ".Marketplace");

        console.log("=== DEPLOYING UPGRADED PROPERTY FACTORY TO HEDERA TESTNET ===");
        console.log("Deployer address:", deployer);
        console.log("AccessControl address:", accessControlAddress);
        console.log("OwnershipRegistry address:", ownershipRegistryAddress);
        console.log("");
        console.log("UPGRADE: Adding purchaseTokens() function for direct user purchases");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy upgraded PropertyFactory with purchaseTokens() function
        // This is the ONLY transaction in this script
        PropertyFactory propertyFactory = new PropertyFactory(
            accessControlAddress,
            ownershipRegistryAddress
        );

        vm.stopBroadcast();

        console.log("");
        console.log("Upgraded PropertyFactory deployed successfully!");
        console.log("New Address:", address(propertyFactory));
        console.log("");
        console.log("New Features:");
        console.log("- Users can now purchase tokens directly with HBAR");
        console.log("- Payments sent automatically to property creators");
        console.log("- KYC verification still enforced");

        // Update deployment info with new PropertyFactory address
        string memory deploymentInfo = string(abi.encodePacked(
            '{"AccessControl":"',
            vm.toString(accessControlAddress),
            '","OwnershipRegistry":"',
            vm.toString(ownershipRegistryAddress),
            '","PropertyFactory":"',
            vm.toString(address(propertyFactory)),
            '","Marketplace":"',
            vm.toString(marketplaceAddress),
            '","deployer":"',
            vm.toString(deployer),
            '"}'
        ));

        vm.writeFile("deployment_step_14.json", deploymentInfo);

        console.log("");
        console.log("Deployment info saved to deployment_step_14.json");
        console.log("Next: Run 15_authorize_upgraded_factory.s.sol");
    }
}
