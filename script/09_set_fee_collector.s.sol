// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import "../src/Marketplace.sol";

contract SetFeeCollectorScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("HEDERA_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Read contract addresses from previous deployments
        string memory step8Data = vm.readFile("deployment_step_8.json");
        address marketplaceAddress = vm.parseJsonAddress(step8Data, ".Marketplace");

        // For testnet, deployer will be the fee collector
        // In production, this could be a treasury or multisig
        address newFeeCollector = deployer;

        console.log("=== SETTING FEE COLLECTOR ===");
        console.log("Deployer address:", deployer);
        console.log("Marketplace address:", marketplaceAddress);
        console.log("Fee collector address:", newFeeCollector);

        Marketplace marketplace = Marketplace(marketplaceAddress);

        // Check current fee collector
        address currentFeeCollector = marketplace.feeCollector();
        console.log("Current fee collector:", currentFeeCollector);

        vm.startBroadcast(deployerPrivateKey);

        // Set fee collector - this is the ONLY transaction
        // (This may be redundant if already set correctly during deployment)
        marketplace.setFeeCollector(newFeeCollector);

        vm.stopBroadcast();

        console.log("Fee collector confirmed/updated successfully!");
        console.log("All marketplace fees will go to:", newFeeCollector);

        // Copy deployment file to next step
        vm.writeFile("deployment_step_9.json", step8Data);

        console.log("Setup step completed");
        console.log("Next: Run 10_kyc_deployer.s.sol");
    }
}