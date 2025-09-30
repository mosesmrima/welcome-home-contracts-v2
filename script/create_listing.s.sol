// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import "../src/Marketplace.sol";
import "../src/PropertyFactory.sol";

contract CreateListingScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("HEDERA_PRIVATE_KEY");

        // Read deployed contracts
        string memory deploymentData = vm.readFile("deployment_step_12.json");
        address marketplaceAddress = vm.parseJsonAddress(deploymentData, ".Marketplace");
        address propertyFactoryAddress = vm.parseJsonAddress(deploymentData, ".PropertyFactory");

        console.log("=== CREATING MARKETPLACE LISTING ===");
        console.log("Marketplace:", marketplaceAddress);

        PropertyFactory factory = PropertyFactory(propertyFactoryAddress);
        Marketplace marketplace = Marketplace(marketplaceAddress);

        // Get first property token
        (, , , address tokenAddress, , , , , , ) = factory.properties(0);

        console.log("Token:", tokenAddress);

        vm.startBroadcast(deployerPrivateKey);

        // SINGLE TRANSACTION: Create listing
        uint256 listingAmount = 5000 * 1e18; // 5,000 tokens
        uint256 pricePerToken = 0.002 ether; // 0.002 ETH per token

        uint256 listingId = marketplace.createListing(tokenAddress, listingAmount, pricePerToken);

        vm.stopBroadcast();

        console.log("Created listing ID:", listingId);
        console.log("Amount:", listingAmount / 1e18, "tokens");
        console.log("Price:", pricePerToken, "ETH per token");
        console.log("SUCCESS: Marketplace listing created!");
    }
}