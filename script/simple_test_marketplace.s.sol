// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import "../src/Marketplace.sol";
import "../src/PropertyFactory.sol";
import "../src/PropertyToken.sol";

contract SimpleTestMarketplaceScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("HEDERA_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Read deployed contracts
        string memory deploymentData = vm.readFile("deployment_step_12.json");
        address marketplaceAddress = vm.parseJsonAddress(deploymentData, ".Marketplace");
        address propertyFactoryAddress = vm.parseJsonAddress(deploymentData, ".PropertyFactory");

        console.log("=== SIMPLE MARKETPLACE TEST ===");
        console.log("Marketplace:", marketplaceAddress);
        console.log("PropertyFactory:", propertyFactoryAddress);

        PropertyFactory factory = PropertyFactory(propertyFactoryAddress);
        Marketplace marketplace = Marketplace(marketplaceAddress);

        // Check if properties exist
        uint256 activeCount = factory.getActivePropertyCount();
        console.log("Active properties:", activeCount);

        if (activeCount == 0) {
            console.log("No properties found. Run simple_test_property.s.sol first!");
            return;
        }

        // Get first property
        (, , , address tokenAddress, , , , , , ) = factory.properties(0);
        PropertyToken token = PropertyToken(tokenAddress);

        console.log("Testing with token:", tokenAddress);

        vm.startBroadcast(deployerPrivateKey);

        // Approve and create listing
        uint256 listingAmount = 1000 * 1e18; // 1000 tokens
        uint256 pricePerToken = 0.002 ether; // 0.002 ETH per token

        token.approve(marketplaceAddress, listingAmount);
        uint256 listingId = marketplace.createListing(tokenAddress, listingAmount, pricePerToken);

        vm.stopBroadcast();

        console.log("Created listing with ID:", listingId);
        console.log("SUCCESS: Marketplace listing working!");
    }
}