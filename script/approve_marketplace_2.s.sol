// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import "../src/PropertyFactory.sol";
import "../src/PropertyToken.sol";

contract ApproveMarketplace2Script is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("HEDERA_PRIVATE_KEY");

        // Read deployed contracts
        string memory deploymentData = vm.readFile("deployment_step_12.json");
        address marketplaceAddress = vm.parseJsonAddress(deploymentData, ".Marketplace");
        address propertyFactoryAddress = vm.parseJsonAddress(deploymentData, ".PropertyFactory");

        console.log("=== APPROVING MARKETPLACE FOR PROPERTY 1 TOKENS ===");
        console.log("Marketplace:", marketplaceAddress);

        PropertyFactory factory = PropertyFactory(propertyFactoryAddress);

        // Get property 2 token (the Ocean View Condo)
        (, , , address tokenAddress, , , , , , ) = factory.properties(2);
        PropertyToken token = PropertyToken(tokenAddress);

        console.log("Property 1 token:", tokenAddress);

        vm.startBroadcast(deployerPrivateKey);

        // Approve marketplace for property 1 tokens
        uint256 approveAmount = 25000 * 1e18; // 25,000 tokens
        token.approve(marketplaceAddress, approveAmount);

        vm.stopBroadcast();

        console.log("Approved", approveAmount / 1e18, "tokens for marketplace");
        console.log("SUCCESS: Ready to create listing for property 1!");
    }
}