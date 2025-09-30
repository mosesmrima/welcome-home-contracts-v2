// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import "../src/Marketplace.sol";

contract SetMarketplaceFeeScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("HEDERA_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Read contract addresses from previous deployments
        string memory step7Data = vm.readFile("deployment_step_7.json");
        address marketplaceAddress = vm.parseJsonAddress(step7Data, ".Marketplace");

        // Set platform fee to 2.5% (250 basis points)
        // 250 basis points = 2.5% (10000 basis points = 100%)
        uint256 platformFeePercent = 250;

        console.log("=== CONFIGURING MARKETPLACE FEE ===");
        console.log("Deployer address:", deployer);
        console.log("Marketplace address:", marketplaceAddress);
        console.log("Setting platform fee to:", platformFeePercent, "basis points (2.5%)");

        Marketplace marketplace = Marketplace(marketplaceAddress);

        vm.startBroadcast(deployerPrivateKey);

        // Set platform fee - this is the ONLY transaction
        // Note: Marketplace already defaults to 250 (2.5%), but setting explicitly
        marketplace.setPlatformFee(platformFeePercent);

        vm.stopBroadcast();

        console.log("Marketplace fee configured successfully!");
        console.log("Platform fee: 2.5% of each transaction");

        // Copy deployment file to next step
        vm.writeFile("deployment_step_8.json", step7Data);

        console.log("Setup step completed");
        console.log("Next: Run 09_set_fee_collector.s.sol");
    }
}