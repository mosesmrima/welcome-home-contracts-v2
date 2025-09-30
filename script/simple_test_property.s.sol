// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import "../src/PropertyFactory.sol";

contract SimpleTestPropertyScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("HEDERA_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Read deployed contracts
        string memory deploymentData = vm.readFile("deployment_step_12.json");
        address propertyFactoryAddress = vm.parseJsonAddress(deploymentData, ".PropertyFactory");

        console.log("=== SIMPLE PROPERTY CREATION TEST ===");
        console.log("PropertyFactory:", propertyFactoryAddress);
        console.log("Deployer:", deployer);

        PropertyFactory factory = PropertyFactory(propertyFactoryAddress);

        vm.startBroadcast(deployerPrivateKey);

        // Create property
        uint256 propertyId = factory.createProperty(
            "Test Villa",
            "https://example.com/metadata.json",
            1000 ether, // 1000 ETH total value
            1000000 * 1e18, // 1M tokens
            0.001 ether // 0.001 ETH per token
        );

        vm.stopBroadcast();

        console.log("Property created with ID:", propertyId);
        console.log("SUCCESS: Property creation working!");
    }
}