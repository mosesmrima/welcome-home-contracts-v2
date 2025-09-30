// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import "../src/Marketplace.sol";

contract CheckListingsScript is Script {
    function run() public view {
        // Read deployed contracts
        string memory deploymentData = vm.readFile("deployment_step_12.json");
        address marketplaceAddress = vm.parseJsonAddress(deploymentData, ".Marketplace");

        console.log("=== MARKETPLACE LISTINGS CHECK ===");
        console.log("");

        Marketplace marketplace = Marketplace(marketplaceAddress);
        uint256 totalListings = marketplace.nextListingId();

        console.log("Total listings created:", totalListings);
        console.log("");

        // Check listing 0
        if (totalListings > 0) {
            (, address seller0, address token0, uint256 amount0, uint256 price0, bool active0,) = marketplace.listings(0);
            console.log("LISTING 0:");
            console.log("- Seller:", seller0);
            console.log("- Token:", token0);
            console.log("- Amount:", amount0 / 1e18, "tokens");
            console.log("- Price:", price0, "wei per token");
            console.log("- Active:", active0 ? "YES" : "NO");
            console.log("");
        }

        // Check listing 1
        if (totalListings > 1) {
            (, address seller1, address token1, uint256 amount1, uint256 price1, bool active1,) = marketplace.listings(1);
            console.log("LISTING 1:");
            console.log("- Seller:", seller1);
            console.log("- Token:", token1);
            console.log("- Amount:", amount1 / 1e18, "tokens");
            console.log("- Price:", price1, "wei per token");
            console.log("- Active:", active1 ? "YES" : "NO");
            console.log("");
        }

        console.log("=== LISTINGS CHECK COMPLETE ===");
    }
}