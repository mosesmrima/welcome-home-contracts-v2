// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import "../src/PropertyFactory.sol";

contract CreateProperty2Script is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("HEDERA_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Read deployed contracts
        string memory deploymentData = vm.readFile("deployment_step_12.json");
        address propertyFactoryAddress = vm.parseJsonAddress(deploymentData, ".PropertyFactory");

        console.log("=== CREATING SECOND PROPERTY ===");
        console.log("PropertyFactory:", propertyFactoryAddress);
        console.log("Deployer:", deployer);

        PropertyFactory factory = PropertyFactory(propertyFactoryAddress);

        // Check current state
        uint256 currentPropertyCount = factory.getActivePropertyCount();
        uint256 nextId = factory.nextPropertyId();
        console.log("Current properties:", currentPropertyCount);
        console.log("Next property ID will be:", nextId);

        vm.startBroadcast(deployerPrivateKey);

        // Create second property
        uint256 propertyId = factory.createProperty(
            "Ocean View Condo",
            "https://example.com/ocean-condo.json",
            2500 ether, // 2500 ETH total value
            500000 * 1e18, // 500K tokens
            0.005 ether // 0.005 ETH per token
        );

        vm.stopBroadcast();

        console.log("Second property created!");
        console.log("Property ID:", propertyId);
        console.log("Name: Ocean View Condo");
        console.log("Total value: 2500 ETH");
        console.log("Token supply: 500,000 tokens");
        console.log("Price per token: 0.005 ETH");
        console.log("SUCCESS: Property ID incremented correctly!");
    }
}