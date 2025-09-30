// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import "../src/AccessControl.sol";

contract DeployAccessControlScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("HEDERA_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== DEPLOYING ACCESS CONTROL TO HEDERA TESTNET ===");
        console.log("Deployer address:", deployer);
        console.log("Network: Hedera Testnet (hashio.io)");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy AccessControl - this is the ONLY transaction in this script
        AccessControl accessControl = new AccessControl();

        vm.stopBroadcast();

        console.log("AccessControl deployed successfully!");
        console.log("Address:", address(accessControl));

        // Save deployment info
        string memory deploymentInfo = string(abi.encodePacked(
            '{"AccessControl":"',
            vm.toString(address(accessControl)),
            '"}'
        ));

        vm.writeFile("deployment_step_1.json", deploymentInfo);

        console.log("Deployment info saved to deployment_step_1.json");
        console.log("Next: Run 02_deploy_ownership_registry.s.sol");
    }
}