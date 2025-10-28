// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/PropertyFactory.sol";
import "../src/AccessControl.sol";
import "../src/PropertyToken.sol";

/**
 * @title Test Purchase Script
 * @notice Direct test of property creation and token purchase on testnet
 * @dev This script will:
 *      1. Create a property with distinct parameter values
 *      2. Verify the stored values match what was sent
 *      3. Attempt a token purchase
 *      4. Log all results for debugging
 */
contract TestPurchase is Script {
    // Contract addresses from deployment_step_14.json
    AccessControl accessControl = AccessControl(0xDDAE60c136ea61552c1e6acF3c7Ab8beBd02eF69);
    PropertyFactory propertyFactory = PropertyFactory(0xb710E9Fe182B861434EBD0F8d90B4d78e6ea14Fe);

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("HEDERA_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== Test Purchase Script ===");
        console.log("Deployer:", deployer);
        console.log("PropertyFactory:", address(propertyFactory));
        console.log("");

        vm.startBroadcast(deployerPrivateKey);

        // Step 1: Create property with VERY DISTINCT values to identify any swap
        console.log("Step 1: Creating property with distinct values");
        console.log("  totalValue:     111 ether");
        console.log("  totalSupply:    222 tokens");
        console.log("  pricePerToken:  0.333 HBAR");
        console.log("");

        uint256 propertyId = propertyFactory.createProperty(
            "Test Purchase Property",
            "https://ipfs.io/ipfs/QmTestPurchase",
            111 ether,      // totalValue - distinct value 111
            222 * 1e18,     // totalSupply - distinct value 222
            0.333 ether     // pricePerToken - distinct value 0.333
        );

        console.log("Property created, ID:");
        console.log(propertyId);
        console.log("");

        // Step 2: Read back property data
        console.log("Step 2: Reading property data from chain");
        PropertyFactory.Property memory property = propertyFactory.getProperty(propertyId);

        console.log("Stored values:");
        console.log("  name:", property.name);
        console.log("  totalValue:");
        console.log(property.totalValue);
        console.log("  totalSupply:");
        console.log(property.totalSupply);
        console.log("  pricePerToken:");
        console.log(property.pricePerToken);
        console.log("  tokenContract:", property.tokenContract);
        console.log("  isActive:", property.isActive);
        console.log("");

        // Step 3: Verify values match
        console.log("Step 3: Verifying values");
        bool totalValueMatch = property.totalValue == 111 ether;
        bool totalSupplyMatch = property.totalSupply == 222 * 1e18;
        bool pricePerTokenMatch = property.pricePerToken == 0.333 ether;

        console.log("  totalValue match:", totalValueMatch);
        console.log("  totalSupply match:", totalSupplyMatch);
        console.log("  pricePerToken match:", pricePerTokenMatch);
        console.log("");

        if (!totalValueMatch || !totalSupplyMatch || !pricePerTokenMatch) {
            console.log("ERROR: Parameter mismatch detected!");
            console.log("totalValue got:");
            console.log(property.totalValue);
            console.log("totalSupply got:");
            console.log(property.totalSupply);
            console.log("pricePerToken got:");
            console.log(property.pricePerToken);
            console.log("");
        }

        // Step 4: Check token contract total supply
        PropertyToken token = PropertyToken(property.tokenContract);
        uint256 tokenTotalSupply = token.totalSupply();
        console.log("Step 4: Token contract verification");
        console.log("  Token totalSupply:");
        console.log(tokenTotalSupply);
        console.log("  Match:", tokenTotalSupply == 222 * 1e18);
        console.log("");

        // Step 5: Calculate purchase cost
        console.log("Step 5: Calculating purchase cost for 1 token");
        uint256 tokenAmount = 1 * 1e18; // 1 token
        uint256 expectedCost = (tokenAmount * property.pricePerToken) / 10**18;
        console.log("  Expected cost:");
        console.log(expectedCost);
        console.log("");

        // Step 6: Attempt purchase
        console.log("Step 6: Attempting purchase of 1 token");
        console.log("  Sending HBAR:");
        console.log(expectedCost);

        try propertyFactory.purchaseTokens{value: expectedCost}(propertyId, tokenAmount) {
            console.log("SUCCESS: Purchase completed!");

            // Check buyer balance
            uint256 buyerBalance = token.balanceOf(deployer);
            console.log("  Buyer token balance:");
            console.log(buyerBalance);
            console.log("  Match:", buyerBalance == tokenAmount);
        } catch Error(string memory reason) {
            console.log("FAILED: Purchase reverted");
            console.log("  Reason:", reason);
        } catch (bytes memory lowLevelData) {
            console.log("FAILED: Purchase reverted with low-level error");
            console.logBytes(lowLevelData);
        }

        vm.stopBroadcast();

        console.log("");
        console.log("=== Test Complete ===");
    }
}
