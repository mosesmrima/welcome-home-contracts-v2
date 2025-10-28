// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/PropertyFactory.sol";

contract SimplePurchase is Script {
    PropertyFactory factory = PropertyFactory(0xb710E9Fe182B861434EBD0F8d90B4d78e6ea14Fe);

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("HEDERA_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deployer:", deployer);
        console.log("Attempting purchase from property 0");
        console.log("Token amount: 1 token (1e18)");
        console.log("Expected cost: 0.01 HBAR (10000000000000000 wei)");

        vm.startBroadcast(deployerPrivateKey);

        uint256 cost = 10000000000000000; // 0.01 HBAR

        factory.purchaseTokens{value: cost}(0, 1e18);

        console.log("Purchase successful!");

        vm.stopBroadcast();
    }
}
