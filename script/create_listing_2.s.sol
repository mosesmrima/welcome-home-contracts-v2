// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import "../src/Marketplace.sol";
import "../src/PropertyFactory.sol";

contract CreateListing2Script is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("HEDERA_PRIVATE_KEY");

        // Read deployed contracts
        string memory deploymentData = vm.readFile("deployment_step_12.json");
        address marketplaceAddress = vm.parseJsonAddress(deploymentData, ".Marketplace");
        address propertyFactoryAddress = vm.parseJsonAddress(deploymentData, ".PropertyFactory");

        console.log("=== CREATING LISTING FOR PROPERTY 1 ===");
        console.log("Marketplace:", marketplaceAddress);

        PropertyFactory factory = PropertyFactory(propertyFactoryAddress);
        Marketplace marketplace = Marketplace(marketplaceAddress);

        // Get property 2 token
        (, , , address tokenAddress, , , , , , ) = factory.properties(2);

        console.log("Property 1 token:", tokenAddress);

        vm.startBroadcast(deployerPrivateKey);

        // Create listing for property 1
        uint256 listingAmount = 20000 * 1e18; // 20,000 tokens
        uint256 pricePerToken = 0.0075 ether; // 0.0075 ETH per token (50% markup from 0.005)

        uint256 listingId = marketplace.createListing(tokenAddress, listingAmount, pricePerToken);

        vm.stopBroadcast();

        console.log("Created listing ID:", listingId);
        console.log("Property 1 - Ocean View Condo");
        console.log("Amount:", listingAmount / 1e18, "tokens");
        console.log("Price:", pricePerToken, "ETH per token");
        console.log("Total value:", (listingAmount * pricePerToken) / 1e18, "ETH");
        console.log("SUCCESS: Second property listed on marketplace!");
    }
}