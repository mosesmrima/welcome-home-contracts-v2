// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import "../src/PropertyFactory.sol";
import "../src/PropertyToken.sol";

contract ApproveMarketplaceScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("HEDERA_PRIVATE_KEY");

        // Read deployed contracts
        string memory deploymentData = vm.readFile("deployment_step_12.json");
        address marketplaceAddress = vm.parseJsonAddress(deploymentData, ".Marketplace");
        address propertyFactoryAddress = vm.parseJsonAddress(deploymentData, ".PropertyFactory");

        console.log("=== APPROVING MARKETPLACE FOR TOKEN TRANSFERS ===");
        console.log("Marketplace:", marketplaceAddress);

        PropertyFactory factory = PropertyFactory(propertyFactoryAddress);

        // Get first property token
        (, , , address tokenAddress, , , , , , ) = factory.properties(0);
        PropertyToken token = PropertyToken(tokenAddress);

        console.log("Token:", tokenAddress);

        vm.startBroadcast(deployerPrivateKey);

        // SINGLE TRANSACTION: Approve marketplace
        uint256 approveAmount = 10000 * 1e18; // 10,000 tokens
        token.approve(marketplaceAddress, approveAmount);

        vm.stopBroadcast();

        console.log("Approved", approveAmount / 1e18, "tokens for marketplace");
        console.log("SUCCESS: Ready to create listing!");
    }
}