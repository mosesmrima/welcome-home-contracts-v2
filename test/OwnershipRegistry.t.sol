// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/OwnershipRegistry.sol";
import "../src/AccessControl.sol";

contract OwnershipRegistryTest is Test {
    OwnershipRegistry public ownershipRegistry;
    AccessControl public accessControl;

    address public owner;
    address public admin1;
    address public admin2;
    address public tokenContract1;
    address public tokenContract2;
    address public tokenContract3;
    address public user1;
    address public user2;
    address public user3;
    address public user4;
    address public attacker;
    address public unauthorizedUpdater;

    event OwnershipUpdated(
        address indexed user,
        address indexed tokenContract,
        uint256 oldBalance,
        uint256 newBalance
    );
    event OwnershipRemoved(address indexed user, address indexed tokenContract);
    event AuthorizedUpdaterSet(address indexed updater, bool authorized);

    function setUp() public {
        owner = address(this);
        admin1 = makeAddr("admin1");
        admin2 = makeAddr("admin2");
        tokenContract1 = makeAddr("tokenContract1");
        tokenContract2 = makeAddr("tokenContract2");
        tokenContract3 = makeAddr("tokenContract3");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        user4 = makeAddr("user4");
        attacker = makeAddr("attacker");
        unauthorizedUpdater = makeAddr("unauthorizedUpdater");

        // Deploy contracts
        accessControl = new AccessControl();
        ownershipRegistry = new OwnershipRegistry(address(accessControl));

        // Set up roles
        accessControl.setAdmin(admin1, true);
        accessControl.setAdmin(admin2, true);

        // Authorize token contracts as updaters
        ownershipRegistry.setAuthorizedUpdater(tokenContract1, true);
        ownershipRegistry.setAuthorizedUpdater(tokenContract2, true);
        ownershipRegistry.setAuthorizedUpdater(tokenContract3, true);

        // Mock property IDs for tokens
        vm.mockCall(
            tokenContract1,
            abi.encodeWithSignature("propertyId()"),
            abi.encode(1)
        );
        vm.mockCall(
            tokenContract2,
            abi.encodeWithSignature("propertyId()"),
            abi.encode(2)
        );
        vm.mockCall(
            tokenContract3,
            abi.encodeWithSignature("propertyId()"),
            abi.encode(3)
        );
    }

    // ===== AUTHORIZATION TESTS =====

    function test_InitialState() public {
        // Non-authorized addresses should not be authorized
        assertFalse(ownershipRegistry.authorizedUpdaters(attacker));

        // But our setup should have authorized the token contracts
        assertTrue(ownershipRegistry.authorizedUpdaters(tokenContract1));
        assertTrue(ownershipRegistry.authorizedUpdaters(tokenContract2));
        assertTrue(ownershipRegistry.authorizedUpdaters(tokenContract3));
    }

    function test_SetAuthorizedUpdater_Success() public {
        address newUpdater = makeAddr("newUpdater");

        vm.expectEmit(true, false, false, true);
        emit AuthorizedUpdaterSet(newUpdater, true);

        vm.prank(admin1);
        ownershipRegistry.setAuthorizedUpdater(newUpdater, true);

        assertTrue(ownershipRegistry.authorizedUpdaters(newUpdater));
    }

    function test_SetAuthorizedUpdater_Remove() public {
        vm.expectEmit(true, false, false, true);
        emit AuthorizedUpdaterSet(tokenContract1, false);

        vm.prank(admin1);
        ownershipRegistry.setAuthorizedUpdater(tokenContract1, false);

        assertFalse(ownershipRegistry.authorizedUpdaters(tokenContract1));
    }

    function test_SetAuthorizedUpdater_OnlyAdmin() public {
        vm.prank(attacker);
        vm.expectRevert("Not admin");
        ownershipRegistry.setAuthorizedUpdater(unauthorizedUpdater, true);
    }

    function test_SetAuthorizedUpdater_InvalidAddress() public {
        vm.prank(admin1);
        vm.expectRevert("Invalid updater address");
        ownershipRegistry.setAuthorizedUpdater(address(0), true);
    }

    // ===== OWNERSHIP UPDATE TESTS =====

    function test_UpdateOwnership_Success() public {
        uint256 balance = 1000 * 1e18;

        vm.expectEmit(true, true, false, true);
        emit OwnershipUpdated(user1, tokenContract1, 0, balance);

        vm.prank(tokenContract1);
        ownershipRegistry.updateOwnership(user1, tokenContract1, balance);

        assertEq(ownershipRegistry.getUserTokenBalance(user1, tokenContract1), balance);
    }

    function test_UpdateOwnership_OnlyAuthorized() public {
        vm.prank(unauthorizedUpdater);
        vm.expectRevert("Not authorized updater");
        ownershipRegistry.updateOwnership(user1, tokenContract1, 1000 * 1e18);
    }

    function test_UpdateOwnership_InvalidUser() public {
        vm.prank(tokenContract1);
        vm.expectRevert("Invalid user address");
        ownershipRegistry.updateOwnership(address(0), tokenContract1, 1000 * 1e18);
    }

    function test_UpdateOwnership_InvalidToken() public {
        vm.prank(tokenContract1);
        vm.expectRevert("Invalid token contract");
        ownershipRegistry.updateOwnership(user1, address(0), 1000 * 1e18);
    }

    function test_UpdateOwnership_FromZeroBalance() public {
        uint256 newBalance = 500 * 1e18;

        // Initial balance should be 0
        assertEq(ownershipRegistry.getUserTokenBalance(user1, tokenContract1), 0);

        vm.prank(tokenContract1);
        ownershipRegistry.updateOwnership(user1, tokenContract1, newBalance);

        assertEq(ownershipRegistry.getUserTokenBalance(user1, tokenContract1), newBalance);

        // Check user's owned tokens list
        address[] memory ownedTokens = ownershipRegistry.getUserOwnedTokens(user1);
        assertEq(ownedTokens.length, 1);
        assertEq(ownedTokens[0], tokenContract1);
    }

    function test_UpdateOwnership_IncreaseBalance() public {
        uint256 initialBalance = 500 * 1e18;
        uint256 newBalance = 1000 * 1e18;

        // Set initial balance
        vm.prank(tokenContract1);
        ownershipRegistry.updateOwnership(user1, tokenContract1, initialBalance);

        vm.expectEmit(true, true, false, true);
        emit OwnershipUpdated(user1, tokenContract1, initialBalance, newBalance);

        // Update to new balance
        vm.prank(tokenContract1);
        ownershipRegistry.updateOwnership(user1, tokenContract1, newBalance);

        assertEq(ownershipRegistry.getUserTokenBalance(user1, tokenContract1), newBalance);
    }

    function test_UpdateOwnership_DecreaseBalance() public {
        uint256 initialBalance = 1000 * 1e18;
        uint256 newBalance = 300 * 1e18;

        // Set initial balance
        vm.prank(tokenContract1);
        ownershipRegistry.updateOwnership(user1, tokenContract1, initialBalance);

        // Decrease balance
        vm.prank(tokenContract1);
        ownershipRegistry.updateOwnership(user1, tokenContract1, newBalance);

        assertEq(ownershipRegistry.getUserTokenBalance(user1, tokenContract1), newBalance);
    }

    function test_UpdateOwnership_ToZeroBalance() public {
        uint256 initialBalance = 500 * 1e18;

        // Set initial balance
        vm.prank(tokenContract1);
        ownershipRegistry.updateOwnership(user1, tokenContract1, initialBalance);

        vm.expectEmit(true, true, false, false);
        emit OwnershipRemoved(user1, tokenContract1);

        // Update to zero (should trigger removal)
        vm.prank(tokenContract1);
        ownershipRegistry.updateOwnership(user1, tokenContract1, 0);

        assertEq(ownershipRegistry.getUserTokenBalance(user1, tokenContract1), 0);
    }

    function test_RemoveOwnership_Success() public {
        uint256 balance = 750 * 1e18;

        // Set initial balance
        vm.prank(tokenContract1);
        ownershipRegistry.updateOwnership(user1, tokenContract1, balance);

        vm.expectEmit(true, true, false, false);
        emit OwnershipRemoved(user1, tokenContract1);

        // Remove ownership
        vm.prank(tokenContract1);
        ownershipRegistry.removeOwnership(user1, tokenContract1);

        assertEq(ownershipRegistry.getUserTokenBalance(user1, tokenContract1), 0);
    }

    function test_RemoveOwnership_OnlyAuthorized() public {
        vm.prank(unauthorizedUpdater);
        vm.expectRevert("Not authorized updater");
        ownershipRegistry.removeOwnership(user1, tokenContract1);
    }

    function test_RemoveOwnership_InvalidAddresses() public {
        vm.prank(tokenContract1);
        vm.expectRevert("Invalid user address");
        ownershipRegistry.removeOwnership(address(0), tokenContract1);

        vm.prank(tokenContract1);
        vm.expectRevert("Invalid token contract");
        ownershipRegistry.removeOwnership(user1, address(0));
    }

    function test_RemoveOwnership_NoOwnership() public {
        // Try to remove ownership when user has no tokens
        vm.prank(tokenContract1);
        vm.expectRevert("No ownership to remove");
        ownershipRegistry.removeOwnership(user1, tokenContract1);
    }

    // ===== PORTFOLIO QUERY TESTS =====

    function test_GetUserPortfolio_Empty() public {
        OwnershipRegistry.OwnershipInfo[] memory portfolio = ownershipRegistry.getUserPortfolio(user1);
        assertEq(portfolio.length, 0);
    }

    function test_GetUserPortfolio_SingleToken() public {
        uint256 balance = 1500 * 1e18;

        vm.prank(tokenContract1);
        ownershipRegistry.updateOwnership(user1, tokenContract1, balance);

        OwnershipRegistry.OwnershipInfo[] memory portfolio = ownershipRegistry.getUserPortfolio(user1);
        assertEq(portfolio.length, 1);
        assertEq(portfolio[0].tokenContract, tokenContract1);
        assertEq(portfolio[0].propertyId, 1);
        assertEq(portfolio[0].balance, balance);
        assertGt(portfolio[0].lastUpdated, 0);
    }

    function test_GetUserPortfolio_MultipleTokens() public {
        uint256 balance1 = 1000 * 1e18;
        uint256 balance2 = 2000 * 1e18;
        uint256 balance3 = 500 * 1e18;

        // Add multiple token ownerships
        vm.prank(tokenContract1);
        ownershipRegistry.updateOwnership(user1, tokenContract1, balance1);

        vm.prank(tokenContract2);
        ownershipRegistry.updateOwnership(user1, tokenContract2, balance2);

        vm.prank(tokenContract3);
        ownershipRegistry.updateOwnership(user1, tokenContract3, balance3);

        OwnershipRegistry.OwnershipInfo[] memory portfolio = ownershipRegistry.getUserPortfolio(user1);
        assertEq(portfolio.length, 3);

        // Check each entry (order might vary)
        bool found1 = false;
        bool found2 = false;
        bool found3 = false;
        for (uint i = 0; i < portfolio.length; i++) {
            if (portfolio[i].tokenContract == tokenContract1) {
                assertEq(portfolio[i].balance, balance1);
                assertEq(portfolio[i].propertyId, 1);
                found1 = true;
            } else if (portfolio[i].tokenContract == tokenContract2) {
                assertEq(portfolio[i].balance, balance2);
                assertEq(portfolio[i].propertyId, 2);
                found2 = true;
            } else if (portfolio[i].tokenContract == tokenContract3) {
                assertEq(portfolio[i].balance, balance3);
                assertEq(portfolio[i].propertyId, 3);
                found3 = true;
            }
        }
        assertTrue(found1 && found2 && found3);
    }

    function test_GetUserPortfolio_ExcludesZeroBalances() public {
        uint256 balance1 = 1000 * 1e18;
        uint256 balance2 = 2000 * 1e18;

        // Add multiple tokens
        vm.prank(tokenContract1);
        ownershipRegistry.updateOwnership(user1, tokenContract1, balance1);

        vm.prank(tokenContract2);
        ownershipRegistry.updateOwnership(user1, tokenContract2, balance2);

        vm.prank(tokenContract3);
        ownershipRegistry.updateOwnership(user1, tokenContract3, 500 * 1e18);

        // Remove one token (set to zero)
        vm.prank(tokenContract3);
        ownershipRegistry.updateOwnership(user1, tokenContract3, 0);

        OwnershipRegistry.OwnershipInfo[] memory portfolio = ownershipRegistry.getUserPortfolio(user1);
        assertEq(portfolio.length, 2); // Should only include non-zero balances
    }

    function test_GetUserPortfolio_InvalidUser() public {
        vm.expectRevert("Invalid user address");
        ownershipRegistry.getUserPortfolio(address(0));
    }

    function test_GetUserOwnedTokens() public {
        // Initially empty
        address[] memory ownedTokens = ownershipRegistry.getUserOwnedTokens(user1);
        assertEq(ownedTokens.length, 0);

        // Add tokens
        vm.prank(tokenContract1);
        ownershipRegistry.updateOwnership(user1, tokenContract1, 1000 * 1e18);

        vm.prank(tokenContract2);
        ownershipRegistry.updateOwnership(user1, tokenContract2, 500 * 1e18);

        ownedTokens = ownershipRegistry.getUserOwnedTokens(user1);
        assertEq(ownedTokens.length, 2);

        // Zero out one token
        vm.prank(tokenContract1);
        ownershipRegistry.updateOwnership(user1, tokenContract1, 0);

        ownedTokens = ownershipRegistry.getUserOwnedTokens(user1);
        assertEq(ownedTokens.length, 1);
        assertEq(ownedTokens[0], tokenContract2);
    }

    function test_GetUserTotalProperties() public {
        assertEq(ownershipRegistry.getUserTotalProperties(user1), 0);

        // Add properties
        vm.prank(tokenContract1);
        ownershipRegistry.updateOwnership(user1, tokenContract1, 1000 * 1e18);

        vm.prank(tokenContract2);
        ownershipRegistry.updateOwnership(user1, tokenContract2, 500 * 1e18);

        assertEq(ownershipRegistry.getUserTotalProperties(user1), 2);

        // Remove one
        vm.prank(tokenContract1);
        ownershipRegistry.updateOwnership(user1, tokenContract1, 0);

        assertEq(ownershipRegistry.getUserTotalProperties(user1), 1);
    }

    function test_GetUserTotalProperties_InvalidUser() public {
        vm.expectRevert("Invalid user address");
        ownershipRegistry.getUserTotalProperties(address(0));
    }

    // ===== TOKEN HOLDER TRACKING TESTS =====

    function test_GetTokenHolders() public {
        // Initially no holders
        address[] memory holders = ownershipRegistry.getTokenHolders(tokenContract1);
        assertEq(holders.length, 0);

        // Add holders
        vm.prank(tokenContract1);
        ownershipRegistry.updateOwnership(user1, tokenContract1, 1000 * 1e18);

        vm.prank(tokenContract1);
        ownershipRegistry.updateOwnership(user2, tokenContract1, 500 * 1e18);

        vm.prank(tokenContract1);
        ownershipRegistry.updateOwnership(user3, tokenContract1, 2000 * 1e18);

        holders = ownershipRegistry.getTokenHolders(tokenContract1);
        assertEq(holders.length, 3);

        // Remove one holder
        vm.prank(tokenContract1);
        ownershipRegistry.updateOwnership(user2, tokenContract1, 0);

        holders = ownershipRegistry.getTokenHolders(tokenContract1);
        assertEq(holders.length, 2);
    }

    function test_GetTokenHolders_InvalidToken() public {
        vm.expectRevert("Invalid token contract");
        ownershipRegistry.getTokenHolders(address(0));
    }

    function test_GetTokenHolderCount() public {
        assertEq(ownershipRegistry.getTokenHolderCount(tokenContract1), 0);

        // Add holders
        vm.prank(tokenContract1);
        ownershipRegistry.updateOwnership(user1, tokenContract1, 1000 * 1e18);

        vm.prank(tokenContract1);
        ownershipRegistry.updateOwnership(user2, tokenContract1, 500 * 1e18);

        assertEq(ownershipRegistry.getTokenHolderCount(tokenContract1), 2);
    }

    function test_IsTokenHolder() public {
        assertFalse(ownershipRegistry.isTokenHolder(user1, tokenContract1));

        vm.prank(tokenContract1);
        ownershipRegistry.updateOwnership(user1, tokenContract1, 1000 * 1e18);

        assertTrue(ownershipRegistry.isTokenHolder(user1, tokenContract1));

        vm.prank(tokenContract1);
        ownershipRegistry.updateOwnership(user1, tokenContract1, 0);

        assertFalse(ownershipRegistry.isTokenHolder(user1, tokenContract1));
    }

    function test_GetPropertyDistribution() public {
        // Add multiple holders with different balances
        vm.prank(tokenContract1);
        ownershipRegistry.updateOwnership(user1, tokenContract1, 1000 * 1e18);

        vm.prank(tokenContract1);
        ownershipRegistry.updateOwnership(user2, tokenContract1, 2500 * 1e18);

        vm.prank(tokenContract1);
        ownershipRegistry.updateOwnership(user3, tokenContract1, 500 * 1e18);

        (address[] memory holders, uint256[] memory balances) = ownershipRegistry.getPropertyDistribution(tokenContract1);

        assertEq(holders.length, 3);
        assertEq(balances.length, 3);

        // Verify the mapping is correct
        for (uint i = 0; i < holders.length; i++) {
            uint256 expectedBalance = ownershipRegistry.getUserTokenBalance(holders[i], tokenContract1);
            assertEq(balances[i], expectedBalance);
            assertTrue(balances[i] > 0);
        }
    }

    function test_GetPropertyDistribution_InvalidToken() public {
        vm.expectRevert("Invalid token contract");
        ownershipRegistry.getPropertyDistribution(address(0));
    }

    // ===== BATCH OPERATIONS TESTS =====

    function test_BatchUpdateOwnership_Success() public {
        address[] memory users = new address[](3);
        address[] memory tokens = new address[](3);
        uint256[] memory balances = new uint256[](3);

        users[0] = user1;
        users[1] = user2;
        users[2] = user3;
        tokens[0] = tokenContract1;
        tokens[1] = tokenContract1;
        tokens[2] = tokenContract2;
        balances[0] = 1000 * 1e18;
        balances[1] = 1500 * 1e18;
        balances[2] = 800 * 1e18;

        // Execute batch update
        vm.prank(tokenContract1);
        ownershipRegistry.batchUpdateOwnership(users, tokens, balances);

        // Verify results
        assertEq(ownershipRegistry.getUserTokenBalance(user1, tokenContract1), 1000 * 1e18);
        assertEq(ownershipRegistry.getUserTokenBalance(user2, tokenContract1), 1500 * 1e18);
        assertEq(ownershipRegistry.getUserTokenBalance(user3, tokenContract2), 800 * 1e18);
    }

    function test_BatchUpdateOwnership_OnlyAuthorized() public {
        address[] memory users = new address[](1);
        address[] memory tokens = new address[](1);
        uint256[] memory balances = new uint256[](1);

        users[0] = user1;
        tokens[0] = tokenContract1;
        balances[0] = 1000 * 1e18;

        vm.prank(unauthorizedUpdater);
        vm.expectRevert("Not authorized updater");
        ownershipRegistry.batchUpdateOwnership(users, tokens, balances);
    }

    function test_BatchUpdateOwnership_ArrayLengthMismatch() public {
        address[] memory users = new address[](2);
        address[] memory tokens = new address[](3);
        uint256[] memory balances = new uint256[](2);

        vm.prank(tokenContract1);
        vm.expectRevert("Array length mismatch");
        ownershipRegistry.batchUpdateOwnership(users, tokens, balances);
    }

    function test_BatchUpdateOwnership_TooLarge() public {
        address[] memory users = new address[](51);
        address[] memory tokens = new address[](51);
        uint256[] memory balances = new uint256[](51);

        vm.prank(tokenContract1);
        vm.expectRevert("Batch too large");
        ownershipRegistry.batchUpdateOwnership(users, tokens, balances);
    }

    function test_BatchUpdateOwnership_InvalidAddresses() public {
        address[] memory users = new address[](2);
        address[] memory tokens = new address[](2);
        uint256[] memory balances = new uint256[](2);

        users[0] = address(0); // Invalid user
        users[1] = user1;
        tokens[0] = tokenContract1;
        tokens[1] = tokenContract1;
        balances[0] = 1000 * 1e18;
        balances[1] = 500 * 1e18;

        vm.prank(tokenContract1);
        vm.expectRevert("Invalid user address");
        ownershipRegistry.batchUpdateOwnership(users, tokens, balances);
    }

    // ===== COMPLEX INTEGRATION TESTS =====

    function test_MultiUserMultiTokenScenario() public {
        // Create a complex ownership scenario across multiple users and tokens

        // User1: Owns tokens in all three properties
        vm.prank(tokenContract1);
        ownershipRegistry.updateOwnership(user1, tokenContract1, 1000 * 1e18);
        vm.prank(tokenContract2);
        ownershipRegistry.updateOwnership(user1, tokenContract2, 2000 * 1e18);
        vm.prank(tokenContract3);
        ownershipRegistry.updateOwnership(user1, tokenContract3, 500 * 1e18);

        // User2: Owns tokens in two properties
        vm.prank(tokenContract1);
        ownershipRegistry.updateOwnership(user2, tokenContract1, 1500 * 1e18);
        vm.prank(tokenContract3);
        ownershipRegistry.updateOwnership(user2, tokenContract3, 3000 * 1e18);

        // User3: Owns tokens in one property
        vm.prank(tokenContract2);
        ownershipRegistry.updateOwnership(user3, tokenContract2, 800 * 1e18);

        // User4: Owns large amount in one property
        vm.prank(tokenContract1);
        ownershipRegistry.updateOwnership(user4, tokenContract1, 10000 * 1e18);

        // Verify portfolios
        assertEq(ownershipRegistry.getUserTotalProperties(user1), 3);
        assertEq(ownershipRegistry.getUserTotalProperties(user2), 2);
        assertEq(ownershipRegistry.getUserTotalProperties(user3), 1);
        assertEq(ownershipRegistry.getUserTotalProperties(user4), 1);

        // Verify token distributions
        assertEq(ownershipRegistry.getTokenHolderCount(tokenContract1), 3); // user1, user2, user4
        assertEq(ownershipRegistry.getTokenHolderCount(tokenContract2), 2); // user1, user3
        assertEq(ownershipRegistry.getTokenHolderCount(tokenContract3), 2); // user1, user2

        // Test property distribution for tokenContract1
        (address[] memory holders, uint256[] memory balances) = ownershipRegistry.getPropertyDistribution(tokenContract1);
        assertEq(holders.length, 3);

        uint256 totalBalance = 0;
        for (uint i = 0; i < balances.length; i++) {
            totalBalance += balances[i];
        }
        assertEq(totalBalance, 12500 * 1e18); // 1000 + 1500 + 10000
    }

    function test_OwnershipTransitions() public {
        // Test various ownership transition scenarios

        // 1. New ownership
        vm.prank(tokenContract1);
        ownershipRegistry.updateOwnership(user1, tokenContract1, 1000 * 1e18);

        assertTrue(ownershipRegistry.isTokenHolder(user1, tokenContract1));
        assertEq(ownershipRegistry.getUserTotalProperties(user1), 1);

        // 2. Increase ownership
        vm.prank(tokenContract1);
        ownershipRegistry.updateOwnership(user1, tokenContract1, 2000 * 1e18);

        assertEq(ownershipRegistry.getUserTokenBalance(user1, tokenContract1), 2000 * 1e18);
        assertEq(ownershipRegistry.getUserTotalProperties(user1), 1);

        // 3. Partial reduction
        vm.prank(tokenContract1);
        ownershipRegistry.updateOwnership(user1, tokenContract1, 500 * 1e18);

        assertEq(ownershipRegistry.getUserTokenBalance(user1, tokenContract1), 500 * 1e18);
        assertTrue(ownershipRegistry.isTokenHolder(user1, tokenContract1));

        // 4. Complete removal
        vm.prank(tokenContract1);
        ownershipRegistry.updateOwnership(user1, tokenContract1, 0);

        assertFalse(ownershipRegistry.isTokenHolder(user1, tokenContract1));
        assertEq(ownershipRegistry.getUserTotalProperties(user1), 0);

        // 5. Re-acquisition
        vm.prank(tokenContract1);
        ownershipRegistry.updateOwnership(user1, tokenContract1, 750 * 1e18);

        assertTrue(ownershipRegistry.isTokenHolder(user1, tokenContract1));
        assertEq(ownershipRegistry.getUserTotalProperties(user1), 1);
    }

    function test_DataConsistency() public {
        // Test that all data structures remain consistent through various operations

        // Set up initial state
        vm.prank(tokenContract1);
        ownershipRegistry.updateOwnership(user1, tokenContract1, 1000 * 1e18);
        vm.prank(tokenContract2);
        ownershipRegistry.updateOwnership(user1, tokenContract2, 500 * 1e18);
        vm.prank(tokenContract1);
        ownershipRegistry.updateOwnership(user2, tokenContract1, 2000 * 1e18);

        // Verify consistency
        assertEq(ownershipRegistry.getUserTotalProperties(user1), 2);
        assertEq(ownershipRegistry.getTokenHolderCount(tokenContract1), 2);
        assertEq(ownershipRegistry.getTokenHolderCount(tokenContract2), 1);

        // Transfer scenario: user1 transfers all of token1 to user3
        vm.prank(tokenContract1);
        ownershipRegistry.updateOwnership(user1, tokenContract1, 0);
        vm.prank(tokenContract1);
        ownershipRegistry.updateOwnership(user3, tokenContract1, 1000 * 1e18);

        // Verify consistency after transfer
        assertEq(ownershipRegistry.getUserTotalProperties(user1), 1); // Only token2 left
        assertEq(ownershipRegistry.getUserTotalProperties(user3), 1); // New holder
        assertEq(ownershipRegistry.getTokenHolderCount(tokenContract1), 2); // user2, user3

        address[] memory token1Holders = ownershipRegistry.getTokenHolders(tokenContract1);
        assertEq(token1Holders.length, 2);

        // user1 should not be in token1 holders anymore
        bool user1Found = false;
        for (uint i = 0; i < token1Holders.length; i++) {
            if (token1Holders[i] == user1) {
                user1Found = true;
                break;
            }
        }
        assertFalse(user1Found);
    }

    // ===== EDGE CASES AND SECURITY TESTS =====

    function test_LargeBalanceAmounts() public {
        uint256 largeBalance = type(uint256).max / 4;

        vm.prank(tokenContract1);
        ownershipRegistry.updateOwnership(user1, tokenContract1, largeBalance);

        assertEq(ownershipRegistry.getUserTokenBalance(user1, tokenContract1), largeBalance);
    }

    function test_ManyTokensPerUser() public {
        // Create many mock token contracts
        address[] memory manyTokens = new address[](20);
        for (uint i = 0; i < 20; i++) {
            manyTokens[i] = makeAddr(string(abi.encodePacked("token", vm.toString(i))));

            // Authorize and mock each token
            vm.prank(admin1);
            ownershipRegistry.setAuthorizedUpdater(manyTokens[i], true);

            vm.mockCall(
                manyTokens[i],
                abi.encodeWithSignature("propertyId()"),
                abi.encode(i + 10)
            );

            // Add ownership
            vm.prank(manyTokens[i]);
            ownershipRegistry.updateOwnership(user1, manyTokens[i], (i + 1) * 100 * 1e18);
        }

        assertEq(ownershipRegistry.getUserTotalProperties(user1), 20);

        OwnershipRegistry.OwnershipInfo[] memory portfolio = ownershipRegistry.getUserPortfolio(user1);
        assertEq(portfolio.length, 20);
    }

    function test_ManyHoldersPerToken() public {
        // Create many mock users
        address[] memory manyUsers = new address[](50);
        for (uint i = 0; i < 50; i++) {
            manyUsers[i] = makeAddr(string(abi.encodePacked("user", vm.toString(i))));

            vm.prank(tokenContract1);
            ownershipRegistry.updateOwnership(manyUsers[i], tokenContract1, (i + 1) * 10 * 1e18);
        }

        assertEq(ownershipRegistry.getTokenHolderCount(tokenContract1), 50);

        address[] memory holders = ownershipRegistry.getTokenHolders(tokenContract1);
        assertEq(holders.length, 50);
    }

    function test_UnauthorizedAccessPrevention() public {
        address[] memory unauthorizedUsers = new address[](3);
        unauthorizedUsers[0] = user1;
        unauthorizedUsers[1] = attacker;
        unauthorizedUsers[2] = unauthorizedUpdater;

        for (uint i = 0; i < unauthorizedUsers.length; i++) {
            address unauthorizedUser = unauthorizedUsers[i];

            // Cannot update ownership
            vm.prank(unauthorizedUser);
            vm.expectRevert("Not authorized updater");
            ownershipRegistry.updateOwnership(user1, tokenContract1, 1000 * 1e18);

            // Cannot remove ownership
            vm.prank(unauthorizedUser);
            vm.expectRevert("Not authorized updater");
            ownershipRegistry.removeOwnership(user1, tokenContract1);

            // Cannot set authorized updater (unless admin)
            if (!accessControl.isUserAdmin(unauthorizedUser)) {
                vm.prank(unauthorizedUser);
                vm.expectRevert("Not admin");
                ownershipRegistry.setAuthorizedUpdater(tokenContract1, false);
            }
        }
    }

    function test_PropertyIdRetrieval() public {
        // Test the internal _getPropertyId function through portfolio queries
        vm.prank(tokenContract1);
        ownershipRegistry.updateOwnership(user1, tokenContract1, 1000 * 1e18);

        OwnershipRegistry.OwnershipInfo[] memory portfolio = ownershipRegistry.getUserPortfolio(user1);
        assertEq(portfolio.length, 1);
        assertEq(portfolio[0].propertyId, 1); // As mocked in setUp
    }

    function test_PropertyIdRetrieval_FailureHandling() public {
        // Test with a token that doesn't implement propertyId()
        address badToken = makeAddr("badToken");

        vm.prank(admin1);
        ownershipRegistry.setAuthorizedUpdater(badToken, true);

        // Don't mock propertyId() for this token
        vm.prank(badToken);
        ownershipRegistry.updateOwnership(user1, badToken, 1000 * 1e18);

        OwnershipRegistry.OwnershipInfo[] memory portfolio = ownershipRegistry.getUserPortfolio(user1);
        assertEq(portfolio.length, 1);
        assertEq(portfolio[0].propertyId, 0); // Should return 0 when call fails
    }

    function test_GetRegistryStats() public {
        // Test the placeholder registry stats function
        (uint256 totalTokenTypes, uint256 totalActiveHoldings) = ownershipRegistry.getRegistryStats();

        // Current implementation returns placeholders
        assertEq(totalTokenTypes, 0);
        assertEq(totalActiveHoldings, 0);
    }
}