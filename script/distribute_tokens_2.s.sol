// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import "../src/PropertyFactory.sol";

contract DistributeTokens2Script is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("HEDERA_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Read deployed contracts
        string memory deploymentData = vm.readFile("deployment_step_12.json");
        address propertyFactoryAddress = vm.parseJsonAddress(deploymentData, ".PropertyFactory");

        console.log("=== DISTRIBUTING TOKENS FROM PROPERTY 1 ===");
        console.log("PropertyFactory:", propertyFactoryAddress);

        PropertyFactory factory = PropertyFactory(propertyFactoryAddress);

        vm.startBroadcast(deployerPrivateKey);

        // Distribute tokens from property ID 2 to deployer
        uint256 propertyId = 2;
        uint256 tokensToDistribute = 50000 * 1e18; // 50,000 tokens

        factory.distributeTokens(propertyId, deployer, tokensToDistribute);

        vm.stopBroadcast();

        console.log("Distributed", tokensToDistribute / 1e18, "tokens from property 1");
        console.log("SUCCESS: Ready for marketplace listing!");
    }
}