// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import "../src/PropertyFactory.sol";

contract CheckPropertiesScript is Script {
    function run() public view {
        // Read deployed contracts
        string memory deploymentData = vm.readFile("deployment_step_12.json");
        address propertyFactoryAddress = vm.parseJsonAddress(deploymentData, ".PropertyFactory");

        console.log("=== PROPERTY DETAILS CHECK ===");
        console.log("");

        PropertyFactory propertyFactory = PropertyFactory(propertyFactoryAddress);
        uint256 totalProperties = propertyFactory.nextPropertyId();

        console.log("Total properties created:", totalProperties);
        console.log("");

        // Check property 0
        if (totalProperties > 0) {
            (, string memory name0, , address token0, uint256 value0, uint256 supply0, uint256 price0, bool active0, ,) = propertyFactory.properties(0);
            console.log("PROPERTY 0:");
            console.log("- Name:", name0);
            console.log("- Token:", token0);
            console.log("- Value:", value0, "wei");
            console.log("- Supply:", supply0 / 1e18, "tokens");
            console.log("- Price:", price0, "wei");
            console.log("- Active:", active0 ? "YES" : "NO");
            console.log("");
        }

        // Check property 2 (our second property)
        if (totalProperties > 2) {
            (, string memory name2, , address token2, uint256 value2, uint256 supply2, uint256 price2, bool active2, ,) = propertyFactory.properties(2);
            console.log("PROPERTY 2:");
            console.log("- Name:", name2);
            console.log("- Token:", token2);
            console.log("- Value:", value2, "wei");
            console.log("- Supply:", supply2 / 1e18, "tokens");
            console.log("- Price:", price2, "wei");
            console.log("- Active:", active2 ? "YES" : "NO");
            console.log("");
        }

        console.log("=== PROPERTIES CHECK COMPLETE ===");
    }
}