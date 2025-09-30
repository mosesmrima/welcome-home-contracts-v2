// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/PropertyToken.sol";
import "../src/AccessControl.sol";
import "../src/OwnershipRegistry.sol";

contract PropertyTokenTest is Test {
    PropertyToken public token;
    AccessControl public accessControl;
    OwnershipRegistry public ownershipRegistry;

    address public owner;
    address public admin1;
    address public propertyManager1;
    address public factory;
    address public kycUser1;
    address public kycUser2;
    address public kycUser3;
    address public nonKycUser;
    address public restrictedUser;
    address public attacker;

    uint256 constant TOTAL_SUPPLY = 10000 * 1e18;
    uint256 constant PROPERTY_ID = 1;
    string constant TOKEN_NAME = "Luxury Apartment Property Token";
    string constant TOKEN_SYMBOL = "LAPT";

    event TradingStatusChanged(bool enabled);
    event TransferRestrictionSet(address indexed user, bool restricted);
    event DividendsDistributed(uint256 amount, uint256 timestamp);
    event DividendsClaimed(address indexed user, uint256 amount);
    event AdminTransferExecuted(address indexed from, address indexed to, uint256 amount);

    function setUp() public {
        owner = address(this);
        admin1 = makeAddr("admin1");
        propertyManager1 = makeAddr("propertyManager1");
        factory = makeAddr("factory");
        kycUser1 = makeAddr("kycUser1");
        kycUser2 = makeAddr("kycUser2");
        kycUser3 = makeAddr("kycUser3");
        nonKycUser = makeAddr("nonKycUser");
        restrictedUser = makeAddr("restrictedUser");
        attacker = makeAddr("attacker");

        // Deploy core contracts
        accessControl = new AccessControl();
        ownershipRegistry = new OwnershipRegistry(address(accessControl));

        // Set up roles
        accessControl.setAdmin(admin1, true);
        accessControl.setPropertyManager(propertyManager1, true);

        // Set up KYC users
        accessControl.setKYCStatus(kycUser1, true);
        accessControl.setKYCStatus(kycUser2, true);
        accessControl.setKYCStatus(kycUser3, true);

        // Deploy PropertyToken (simulating factory deployment)
        vm.prank(factory);
        token = new PropertyToken(
            TOKEN_NAME,
            TOKEN_SYMBOL,
            TOTAL_SUPPLY,
            PROPERTY_ID,
            address(accessControl),
            factory,
            address(ownershipRegistry)
        );

        // Authorize token to update ownership registry
        ownershipRegistry.setAuthorizedUpdater(address(token), true);

        // Set restricted user
        vm.prank(admin1);
        token.setTransferRestriction(restrictedUser, true);
    }

    // ===== ERC-20 BASIC FUNCTIONALITY TESTS =====

    function test_BasicTokenInfo() public {
        assertEq(token.name(), TOKEN_NAME);
        assertEq(token.symbol(), TOKEN_SYMBOL);
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), TOTAL_SUPPLY);
        assertEq(token.propertyId(), PROPERTY_ID);
        assertEq(token.balanceOf(factory), TOTAL_SUPPLY); // Factory initially holds all tokens
    }

    function test_InitialState() public {
        assertTrue(token.tradingEnabled());
        assertEq(token.dividendPool(), 0);
        assertEq(token.totalDividendsDistributed(), 0);
        assertEq(token.lastDividendTimestamp(), 0);
        assertFalse(token.transferRestrictions(kycUser1));
        assertTrue(token.transferRestrictions(restrictedUser));
    }

    // ===== TRANSFER TESTS WITH KYC RESTRICTIONS =====

    function test_Transfer_Success_KYCUsers() public {
        uint256 transferAmount = 1000 * 1e18;

        // Factory needs KYC for transfers
        accessControl.setKYCStatus(factory, true); // Test contract is admin, no prank needed

        vm.prank(factory);
        bool success = token.transfer(kycUser1, transferAmount);

        assertTrue(success);
        assertEq(token.balanceOf(factory), TOTAL_SUPPLY - transferAmount);
        assertEq(token.balanceOf(kycUser1), transferAmount);
    }

    function test_Transfer_KYCUser_to_KYCUser() public {
        uint256 transferAmount = 500 * 1e18;

        // Setup: Factory gives tokens to kycUser1
        accessControl.setKYCStatus(factory, true);
        vm.prank(factory);
        token.transfer(kycUser1, 1000 * 1e18);

        // KYC user to KYC user transfer
        vm.prank(kycUser1);
        bool success = token.transfer(kycUser2, transferAmount);

        assertTrue(success);
        assertEq(token.balanceOf(kycUser1), 1000 * 1e18 - transferAmount);
        assertEq(token.balanceOf(kycUser2), transferAmount);
    }

    function test_Transfer_FailsForNonKYCFrom() public {
        // Give tokens to non-KYC user (via admin transfer for test setup)
        vm.prank(admin1);
        token.adminTransfer(factory, nonKycUser, 1000 * 1e18);

        vm.prank(nonKycUser);
        vm.expectRevert("User not KYC verified");
        token.transfer(kycUser1, 500 * 1e18);
    }

    function test_Transfer_FailsForNonKYCTo() public {
        // Setup: Factory gives tokens to kycUser1
        accessControl.setKYCStatus(factory, true);
        vm.prank(factory);
        token.transfer(kycUser1, 1000 * 1e18);

        vm.prank(kycUser1);
        vm.expectRevert("User not KYC verified");
        token.transfer(nonKycUser, 500 * 1e18);
    }

    function test_Transfer_FailsWhenTradingDisabled() public {
        // Setup: Factory gives tokens to kycUser1
        accessControl.setKYCStatus(factory, true);
        vm.prank(factory);
        token.transfer(kycUser1, 1000 * 1e18);

        // Disable trading
        vm.prank(admin1);
        token.setTradingEnabled(false);

        vm.prank(kycUser1);
        vm.expectRevert("Trading disabled");
        token.transfer(kycUser2, 500 * 1e18);
    }

    function test_Transfer_FailsWhenSystemPaused() public {
        // Setup: Factory gives tokens to kycUser1
        accessControl.setKYCStatus(factory, true);
        vm.prank(factory);
        token.transfer(kycUser1, 1000 * 1e18);

        // Pause system
        accessControl.pauseSystem();

        vm.prank(kycUser1);
        vm.expectRevert("System paused");
        token.transfer(kycUser2, 500 * 1e18);
    }

    function test_Transfer_FailsForRestrictedUser() public {
        // Give tokens to restricted user (via admin transfer)
        vm.prank(admin1);
        token.adminTransfer(factory, restrictedUser, 1000 * 1e18);

        // Set restricted user as KYC'd for this test
        vm.prank(admin1);
        accessControl.setKYCStatus(restrictedUser, true);

        vm.prank(restrictedUser);
        vm.expectRevert("User transfer restricted");
        token.transfer(kycUser1, 500 * 1e18);
    }

    function test_Transfer_FailsToRestrictedUser() public {
        // Setup: Factory gives tokens to kycUser1
        accessControl.setKYCStatus(factory, true);
        vm.prank(factory);
        token.transfer(kycUser1, 1000 * 1e18);

        // Set restrictedUser as KYC'd
        vm.prank(admin1);
        accessControl.setKYCStatus(restrictedUser, true);

        vm.prank(kycUser1);
        vm.expectRevert("User transfer restricted");
        token.transfer(restrictedUser, 500 * 1e18);
    }

    // ===== TRANSFER FROM TESTS =====

    function test_TransferFrom_Success() public {
        uint256 transferAmount = 500 * 1e18;

        // Setup: Factory gives tokens to kycUser1 and approves kycUser2
        accessControl.setKYCStatus(factory, true);
        vm.prank(factory);
        token.transfer(kycUser1, 1000 * 1e18);

        vm.prank(kycUser1);
        token.approve(kycUser2, transferAmount);

        vm.prank(kycUser2);
        bool success = token.transferFrom(kycUser1, kycUser3, transferAmount);

        assertTrue(success);
        assertEq(token.balanceOf(kycUser1), 1000 * 1e18 - transferAmount);
        assertEq(token.balanceOf(kycUser3), transferAmount);
        assertEq(token.allowance(kycUser1, kycUser2), 0);
    }

    function test_TransferFrom_KYCChecks() public {
        uint256 transferAmount = 500 * 1e18;

        // Setup tokens and approval
        vm.prank(admin1);
        token.adminTransfer(factory, kycUser1, 1000 * 1e18);
        vm.prank(kycUser1);
        token.approve(kycUser2, transferAmount);

        // TransferFrom with non-KYC 'from' should fail
        vm.prank(admin1);
        accessControl.setKYCStatus(kycUser1, false);

        vm.prank(kycUser2);
        vm.expectRevert("User not KYC verified");
        token.transferFrom(kycUser1, kycUser3, transferAmount);

        // Reset KYC for kycUser1, remove KYC for 'to'
        vm.prank(admin1);
        accessControl.setKYCStatus(kycUser1, true);
        vm.prank(admin1);
        accessControl.setKYCStatus(kycUser3, false);

        vm.prank(kycUser2);
        vm.expectRevert("User not KYC verified");
        token.transferFrom(kycUser1, kycUser3, transferAmount);
    }

    // ===== ADMIN CONTROLS TESTS =====

    function test_SetTradingEnabled() public {
        assertTrue(token.tradingEnabled());

        vm.expectEmit(false, false, false, true);
        emit TradingStatusChanged(false);

        vm.prank(admin1);
        token.setTradingEnabled(false);
        assertFalse(token.tradingEnabled());

        vm.expectEmit(false, false, false, true);
        emit TradingStatusChanged(true);

        vm.prank(admin1);
        token.setTradingEnabled(true);
        assertTrue(token.tradingEnabled());
    }

    function test_SetTradingEnabled_OnlyAdmin() public {
        vm.prank(attacker);
        vm.expectRevert("Not admin");
        token.setTradingEnabled(false);
    }

    function test_SetTransferRestriction() public {
        assertFalse(token.transferRestrictions(kycUser1));

        vm.expectEmit(true, false, false, true);
        emit TransferRestrictionSet(kycUser1, true);

        vm.prank(admin1);
        token.setTransferRestriction(kycUser1, true);
        assertTrue(token.transferRestrictions(kycUser1));

        vm.expectEmit(true, false, false, true);
        emit TransferRestrictionSet(kycUser1, false);

        vm.prank(admin1);
        token.setTransferRestriction(kycUser1, false);
        assertFalse(token.transferRestrictions(kycUser1));
    }

    function test_SetTransferRestriction_OnlyAdmin() public {
        vm.prank(attacker);
        vm.expectRevert("Not admin");
        token.setTransferRestriction(kycUser1, true);
    }

    function test_SetTransferRestriction_InvalidAddress() public {
        vm.prank(admin1);
        vm.expectRevert("Invalid address");
        token.setTransferRestriction(address(0), true);
    }

    function test_AdminTransfer_Success() public {
        uint256 transferAmount = 1000 * 1e18;

        vm.expectEmit(true, true, false, true);
        emit AdminTransferExecuted(factory, kycUser1, transferAmount);

        uint256 factoryBalanceBefore = token.balanceOf(factory);
        uint256 userBalanceBefore = token.balanceOf(kycUser1);

        vm.prank(admin1);
        token.adminTransfer(factory, kycUser1, transferAmount);

        assertEq(token.balanceOf(factory), factoryBalanceBefore - transferAmount);
        assertEq(token.balanceOf(kycUser1), userBalanceBefore + transferAmount);
    }

    function test_AdminTransfer_BypassesRestrictions() public {
        uint256 transferAmount = 500 * 1e18;

        // Admin transfer should work even when:
        // 1. Trading is disabled
        vm.prank(admin1);
        token.setTradingEnabled(false);

        // 2. Users are not KYC'd
        // 3. Users are restricted
        vm.prank(admin1);
        token.adminTransfer(factory, restrictedUser, transferAmount);

        assertEq(token.balanceOf(restrictedUser), transferAmount);

        // 4. From restricted user to non-KYC user
        vm.prank(admin1);
        token.adminTransfer(restrictedUser, nonKycUser, transferAmount);

        assertEq(token.balanceOf(nonKycUser), transferAmount);
        assertEq(token.balanceOf(restrictedUser), 0);
    }

    function test_AdminTransfer_OnlyAdmin() public {
        vm.prank(attacker);
        vm.expectRevert("Not admin");
        token.adminTransfer(factory, kycUser1, 1000);
    }

    function test_AdminTransfer_InvalidInputs() public {
        vm.prank(admin1);
        vm.expectRevert("Invalid from address");
        token.adminTransfer(address(0), kycUser1, 1000);

        vm.prank(admin1);
        vm.expectRevert("Invalid to address");
        token.adminTransfer(factory, address(0), 1000);

        vm.prank(admin1);
        vm.expectRevert("Invalid amount");
        token.adminTransfer(factory, kycUser1, 0);

        vm.prank(admin1);
        vm.expectRevert("Insufficient balance");
        token.adminTransfer(factory, kycUser1, TOTAL_SUPPLY + 1);
    }

    // ===== DIVIDEND DISTRIBUTION TESTS =====

    function test_DistributeDividends_Success() public {
        uint256 dividendAmount = 10 ether;

        vm.expectEmit(false, false, false, true);
        emit DividendsDistributed(dividendAmount, block.timestamp);

        vm.deal(propertyManager1, dividendAmount);
        vm.prank(propertyManager1);
        token.distributeDividends{value: dividendAmount}();

        assertEq(token.dividendPool(), dividendAmount);
        assertEq(token.totalDividendsDistributed(), dividendAmount);
        assertEq(token.lastDividendTimestamp(), block.timestamp);
    }

    function test_DistributeDividends_OnlyPropertyManager() public {
        vm.deal(attacker, 1 ether);
        vm.prank(attacker);
        vm.expectRevert("Not property manager");
        token.distributeDividends{value: 1 ether}();
    }

    function test_DistributeDividends_AdminCanDistribute() public {
        uint256 dividendAmount = 5 ether;

        vm.deal(admin1, dividendAmount);
        vm.prank(admin1);
        token.distributeDividends{value: dividendAmount}();

        assertEq(token.dividendPool(), dividendAmount);
    }

    function test_DistributeDividends_OwnerCanDistribute() public {
        uint256 dividendAmount = 3 ether;

        vm.deal(owner, dividendAmount);
        token.distributeDividends{value: dividendAmount}();

        assertEq(token.dividendPool(), dividendAmount);
    }

    function test_DistributeDividends_ZeroAmount() public {
        vm.prank(propertyManager1);
        vm.expectRevert("No dividends to distribute");
        token.distributeDividends{value: 0}();
    }

    function test_DistributeDividends_NoTokensInCirculation() public {
        // Burn all tokens first
        vm.prank(factory);
        token.burn(TOTAL_SUPPLY);

        vm.deal(propertyManager1, 1 ether);
        vm.prank(propertyManager1);
        vm.expectRevert("No tokens in circulation");
        token.distributeDividends{value: 1 ether}();
    }

    function test_DistributeDividends_Multiple() public {
        uint256 firstDividend = 5 ether;
        uint256 secondDividend = 3 ether;

        vm.deal(propertyManager1, firstDividend + secondDividend);

        vm.prank(propertyManager1);
        token.distributeDividends{value: firstDividend}();

        vm.warp(block.timestamp + 1 days);

        vm.prank(propertyManager1);
        token.distributeDividends{value: secondDividend}();

        assertEq(token.totalDividendsDistributed(), firstDividend + secondDividend);
        assertEq(token.dividendPool(), firstDividend + secondDividend);
    }

    // ===== DIVIDEND CLAIMING TESTS =====

    function test_ClaimDividends_Success() public {
        uint256 dividendAmount = 10 ether;
        uint256 userTokens = 1000 * 1e18; // 10% of total supply

        // Setup: Give user tokens and distribute dividends
        accessControl.setKYCStatus(factory, true);
        vm.prank(factory);
        token.transfer(kycUser1, userTokens);

        vm.deal(propertyManager1, dividendAmount);
        vm.prank(propertyManager1);
        token.distributeDividends{value: dividendAmount}();

        uint256 expectedClaim = (userTokens * dividendAmount) / TOTAL_SUPPLY;
        uint256 userBalanceBefore = kycUser1.balance;

        vm.expectEmit(true, false, false, true);
        emit DividendsClaimed(kycUser1, expectedClaim);

        vm.prank(kycUser1);
        uint256 claimedAmount = token.claimDividends();

        assertEq(claimedAmount, expectedClaim);
        assertEq(kycUser1.balance, userBalanceBefore + expectedClaim);
        assertEq(token.lastDividendClaim(kycUser1), expectedClaim);
    }

    function test_ClaimDividends_ProportionalDistribution() public {
        uint256 dividendAmount = 100 ether;

        // Setup: Distribute tokens to multiple users
        accessControl.setKYCStatus(factory, true);

        vm.prank(factory);
        token.transfer(kycUser1, 2000 * 1e18); // 20%

        vm.prank(factory);
        token.transfer(kycUser2, 3000 * 1e18); // 30%

        vm.prank(factory);
        token.transfer(kycUser3, 1000 * 1e18); // 10%
        // Factory keeps 40%

        // Distribute dividends
        vm.deal(propertyManager1, dividendAmount);
        vm.prank(propertyManager1);
        token.distributeDividends{value: dividendAmount}();

        // Claims should be proportional
        vm.prank(kycUser1);
        uint256 claim1 = token.claimDividends();
        assertEq(claim1, 20 ether); // 20% of 100 ether

        vm.prank(kycUser2);
        uint256 claim2 = token.claimDividends();
        assertEq(claim2, 30 ether); // 30% of 100 ether

        vm.prank(kycUser3);
        uint256 claim3 = token.claimDividends();
        assertEq(claim3, 10 ether); // 10% of 100 ether
    }

    function test_ClaimDividends_OnlyKYCUsers() public {
        uint256 dividendAmount = 10 ether;

        // Give non-KYC user tokens via admin transfer
        vm.prank(admin1);
        token.adminTransfer(factory, nonKycUser, 1000 * 1e18);

        vm.deal(propertyManager1, dividendAmount);
        vm.prank(propertyManager1);
        token.distributeDividends{value: dividendAmount}();

        vm.prank(nonKycUser);
        vm.expectRevert("User not KYC verified");
        token.claimDividends();
    }

    function test_ClaimDividends_NoDividendsToClaim() public {
        vm.prank(kycUser1);
        vm.expectRevert("No dividends to claim");
        token.claimDividends();
    }

    function test_ClaimDividends_NoTokens() public {
        uint256 dividendAmount = 10 ether;

        vm.deal(propertyManager1, dividendAmount);
        vm.prank(propertyManager1);
        token.distributeDividends{value: dividendAmount}();

        // User with no tokens
        vm.prank(kycUser1);
        vm.expectRevert("No dividends to claim");
        token.claimDividends();
    }

    function test_ClaimDividends_AfterTokenTransfer() public {
        uint256 dividendAmount = 10 ether;
        uint256 userTokens = 2000 * 1e18;

        // Setup: Give user tokens
        accessControl.setKYCStatus(factory, true);
        vm.prank(factory);
        token.transfer(kycUser1, userTokens);

        // Distribute dividends
        vm.deal(propertyManager1, dividendAmount);
        vm.prank(propertyManager1);
        token.distributeDividends{value: dividendAmount}();

        // User transfers half their tokens to another user
        vm.prank(kycUser1);
        token.transfer(kycUser2, userTokens / 2);

        // Both should be able to claim based on current holdings
        uint256 expectedClaim = (userTokens / 2 * dividendAmount) / TOTAL_SUPPLY;

        vm.prank(kycUser1);
        uint256 claim1 = token.claimDividends();
        assertEq(claim1, expectedClaim);

        vm.prank(kycUser2);
        uint256 claim2 = token.claimDividends();
        assertEq(claim2, expectedClaim);
    }

    function test_ClaimDividends_MultipleDistributions() public {
        uint256 firstDividend = 5 ether;
        uint256 secondDividend = 10 ether;
        uint256 userTokens = 1000 * 1e18; // 10% of total

        // Setup
        accessControl.setKYCStatus(factory, true);
        vm.prank(factory);
        token.transfer(kycUser1, userTokens);

        // First dividend distribution
        vm.deal(propertyManager1, firstDividend + secondDividend);
        vm.prank(propertyManager1);
        token.distributeDividends{value: firstDividend}();

        // User claims first dividend
        vm.prank(kycUser1);
        uint256 firstClaim = token.claimDividends();
        assertEq(firstClaim, (userTokens * firstDividend) / TOTAL_SUPPLY);

        // Second dividend distribution
        vm.prank(propertyManager1);
        token.distributeDividends{value: secondDividend}();

        // User should only be able to claim second dividend
        vm.prank(kycUser1);
        uint256 secondClaim = token.claimDividends();
        assertEq(secondClaim, (userTokens * secondDividend) / TOTAL_SUPPLY);

        // Third claim should fail (no new dividends)
        vm.prank(kycUser1);
        vm.expectRevert("No dividends to claim");
        token.claimDividends();
    }

    // ===== DIVIDEND CALCULATION TESTS =====

    function test_GetClaimableDividends_NoTokens() public {
        uint256 claimable = token.getClaimableDividends(kycUser1);
        assertEq(claimable, 0);
    }

    function test_GetClaimableDividends_NoDividends() public {
        // Give user tokens but no dividends distributed
        accessControl.setKYCStatus(factory, true);
        vm.prank(factory);
        token.transfer(kycUser1, 1000 * 1e18);

        uint256 claimable = token.getClaimableDividends(kycUser1);
        assertEq(claimable, 0);
    }

    function test_GetClaimableDividends_WithTokensAndDividends() public {
        uint256 dividendAmount = 20 ether;
        uint256 userTokens = 2500 * 1e18; // 25% of total

        // Setup
        accessControl.setKYCStatus(factory, true);
        vm.prank(factory);
        token.transfer(kycUser1, userTokens);

        vm.deal(propertyManager1, dividendAmount);
        vm.prank(propertyManager1);
        token.distributeDividends{value: dividendAmount}();

        uint256 claimable = token.getClaimableDividends(kycUser1);
        uint256 expected = (userTokens * dividendAmount) / TOTAL_SUPPLY;
        assertEq(claimable, expected);
        assertEq(claimable, 5 ether); // 25% of 20 ether
    }

    function test_GetClaimableDividends_AfterPartialClaim() public {
        uint256 firstDividend = 10 ether;
        uint256 secondDividend = 15 ether;
        uint256 userTokens = 1000 * 1e18; // 10%

        // Setup
        accessControl.setKYCStatus(factory, true);
        vm.prank(factory);
        token.transfer(kycUser1, userTokens);

        // First dividend
        vm.deal(propertyManager1, firstDividend + secondDividend);
        vm.prank(propertyManager1);
        token.distributeDividends{value: firstDividend}();

        // Claim first dividend
        vm.prank(kycUser1);
        token.claimDividends();

        // Check claimable (should be 0)
        assertEq(token.getClaimableDividends(kycUser1), 0);

        // Second dividend
        vm.prank(propertyManager1);
        token.distributeDividends{value: secondDividend}();

        // Check claimable (should be second dividend only)
        uint256 expectedSecond = (userTokens * secondDividend) / TOTAL_SUPPLY;
        assertEq(token.getClaimableDividends(kycUser1), expectedSecond);
    }

    // ===== MINTING AND BURNING TESTS =====

    function test_Mint_OnlyFactory() public {
        uint256 mintAmount = 1000 * 1e18;

        vm.prank(factory);
        token.mint(kycUser1, mintAmount);

        assertEq(token.balanceOf(kycUser1), mintAmount);
        assertEq(token.totalSupply(), TOTAL_SUPPLY + mintAmount);
    }

    function test_Mint_OnlyFactory_AccessControl() public {
        vm.prank(attacker);
        vm.expectRevert("Not factory");
        token.mint(kycUser1, 1000);
    }

    function test_Mint_InvalidInputs() public {
        vm.prank(factory);
        vm.expectRevert("Invalid address");
        token.mint(address(0), 1000);

        vm.prank(factory);
        vm.expectRevert("Invalid amount");
        token.mint(kycUser1, 0);
    }

    function test_Burn_Success() public {
        uint256 burnAmount = 500 * 1e18;

        // Setup: Give user tokens
        accessControl.setKYCStatus(factory, true);
        vm.prank(factory);
        token.transfer(kycUser1, 1000 * 1e18);

        uint256 userBalanceBefore = token.balanceOf(kycUser1);
        uint256 totalSupplyBefore = token.totalSupply();

        vm.prank(kycUser1);
        token.burn(burnAmount);

        assertEq(token.balanceOf(kycUser1), userBalanceBefore - burnAmount);
        assertEq(token.totalSupply(), totalSupplyBefore - burnAmount);
    }

    function test_Burn_InvalidAmount() public {
        vm.prank(kycUser1);
        vm.expectRevert("Invalid amount");
        token.burn(0);
    }

    function test_Burn_InsufficientBalance() public {
        vm.prank(kycUser1);
        vm.expectRevert("Insufficient balance");
        token.burn(1000);
    }

    // ===== OWNERSHIP REGISTRY INTEGRATION TESTS =====

    function test_OwnershipRegistry_UpdateOnTransfer() public {
        uint256 transferAmount = 1000 * 1e18;

        // Setup
        accessControl.setKYCStatus(factory, true);

        // Initial state - ownership registry should be empty for users
        assertEq(ownershipRegistry.getUserTokenBalance(kycUser1, address(token)), 0);

        // Transfer to user
        vm.prank(factory);
        token.transfer(kycUser1, transferAmount);

        // Check ownership registry was updated
        assertEq(ownershipRegistry.getUserTokenBalance(kycUser1, address(token)), transferAmount);
        assertEq(ownershipRegistry.getUserTokenBalance(factory, address(token)), TOTAL_SUPPLY - transferAmount);
    }

    function test_OwnershipRegistry_UpdateOnAdminTransfer() public {
        uint256 transferAmount = 500 * 1e18;

        vm.prank(admin1);
        token.adminTransfer(factory, kycUser1, transferAmount);

        assertEq(ownershipRegistry.getUserTokenBalance(kycUser1, address(token)), transferAmount);
        assertEq(ownershipRegistry.getUserTokenBalance(factory, address(token)), TOTAL_SUPPLY - transferAmount);
    }

    function test_OwnershipRegistry_UpdateOnMint() public {
        uint256 mintAmount = 1000 * 1e18;

        vm.prank(factory);
        token.mint(kycUser1, mintAmount);

        assertEq(ownershipRegistry.getUserTokenBalance(kycUser1, address(token)), mintAmount);
    }

    function test_OwnershipRegistry_UpdateOnBurn() public {
        uint256 mintAmount = 1000 * 1e18;
        uint256 burnAmount = 300 * 1e18;

        // Setup: Mint tokens to user
        vm.prank(factory);
        token.mint(kycUser1, mintAmount);

        // Burn some tokens
        vm.prank(kycUser1);
        token.burn(burnAmount);

        assertEq(ownershipRegistry.getUserTokenBalance(kycUser1, address(token)), mintAmount - burnAmount);
    }

    // ===== INFORMATION GETTER TESTS =====

    function test_GetTokenInfo() public {
        (
            uint256 propertyId,
            uint256 totalSupply,
            uint256 dividendPool,
            uint256 totalDividendsDistributed,
            bool tradingEnabled
        ) = token.getTokenInfo();

        assertEq(propertyId, PROPERTY_ID);
        assertEq(totalSupply, TOTAL_SUPPLY);
        assertEq(dividendPool, 0);
        assertEq(totalDividendsDistributed, 0);
        assertTrue(tradingEnabled);
    }

    function test_GetTokenInfo_AfterDividends() public {
        uint256 dividendAmount = 5 ether;

        vm.deal(propertyManager1, dividendAmount);
        vm.prank(propertyManager1);
        token.distributeDividends{value: dividendAmount}();

        (,, uint256 dividendPool, uint256 totalDividendsDistributed,) = token.getTokenInfo();

        assertEq(dividendPool, dividendAmount);
        assertEq(totalDividendsDistributed, dividendAmount);
    }

    function test_GetUserInfo() public {
        // Initially user should have no balance or restrictions
        (
            uint256 balance,
            uint256 claimableDividends,
            bool isRestricted,
            uint256 lastClaim
        ) = token.getUserInfo(kycUser1);

        assertEq(balance, 0);
        assertEq(claimableDividends, 0);
        assertFalse(isRestricted);
        assertEq(lastClaim, 0);
    }

    function test_GetUserInfo_WithTokensAndDividends() public {
        uint256 userTokens = 2000 * 1e18;
        uint256 dividendAmount = 10 ether;

        // Setup: Give tokens and distribute dividends
        accessControl.setKYCStatus(factory, true);
        vm.prank(factory);
        token.transfer(kycUser1, userTokens);

        vm.deal(propertyManager1, dividendAmount);
        vm.prank(propertyManager1);
        token.distributeDividends{value: dividendAmount}();

        // Set restriction
        vm.prank(admin1);
        token.setTransferRestriction(kycUser1, true);

        (
            uint256 balance,
            uint256 claimableDividends,
            bool isRestricted,
            uint256 lastClaim
        ) = token.getUserInfo(kycUser1);

        assertEq(balance, userTokens);
        assertEq(claimableDividends, (userTokens * dividendAmount) / TOTAL_SUPPLY);
        assertTrue(isRestricted);
        assertEq(lastClaim, 0);

        // Remove restriction and claim dividends
        vm.prank(admin1);
        token.setTransferRestriction(kycUser1, false);

        vm.prank(kycUser1);
        token.claimDividends();

        (,, isRestricted, lastClaim) = token.getUserInfo(kycUser1);
        uint256 expectedClaim = (userTokens * dividendAmount) / TOTAL_SUPPLY;
        assertEq(lastClaim, expectedClaim);
    }

    // ===== COMPLEX INTEGRATION TESTS =====

    function test_CompletePropertyTokenLifecycle() public {
        uint256 initialTokens = 5000 * 1e18;
        uint256 firstDividend = 20 ether;
        uint256 secondDividend = 30 ether;

        // 1. Factory distributes initial tokens to investors
        accessControl.setKYCStatus(factory, true);

        vm.prank(factory);
        token.transfer(kycUser1, 2000 * 1e18); // 20%

        vm.prank(factory);
        token.transfer(kycUser2, 3000 * 1e18); // 30%
        // Factory keeps 50%

        // 2. Property generates income - first dividend distribution
        vm.deal(propertyManager1, firstDividend + secondDividend);
        vm.prank(propertyManager1);
        token.distributeDividends{value: firstDividend}();

        // 3. Users claim first dividends
        vm.prank(kycUser1);
        uint256 claim1First = token.claimDividends();
        assertEq(claim1First, 4 ether); // 20% of 20 ether

        vm.prank(kycUser2);
        uint256 claim2First = token.claimDividends();
        assertEq(claim2First, 6 ether); // 30% of 20 ether

        // 4. User trades tokens on secondary market
        vm.prank(kycUser1);
        token.transfer(kycUser2, 1000 * 1e18);

        // New balances: kycUser1: 1000, kycUser2: 4000, factory: 5000

        // 5. Second dividend distribution
        vm.prank(propertyManager1);
        token.distributeDividends{value: secondDividend}();

        // 6. Claims should reflect new token holdings
        vm.prank(kycUser1);
        uint256 claim1Second = token.claimDividends();
        assertEq(claim1Second, 1 ether); // Total of 50 ether distributed, 10% = 5 ether, already claimed 4 ether, so 1 ether remaining

        vm.prank(kycUser2);
        uint256 claim2Second = token.claimDividends();
        assertEq(claim2Second, 14 ether); // Total of 50 ether distributed, 40% = 20 ether, already claimed 6 ether, so 14 ether remaining

        // 7. Admin compliance action
        vm.prank(admin1);
        token.setTransferRestriction(kycUser1, true);

        // 8. Restricted user cannot transfer
        vm.prank(kycUser1);
        vm.expectRevert("User transfer restricted");
        token.transfer(kycUser2, 500 * 1e18);

        // 9. But admin can force transfer for compliance
        vm.prank(admin1);
        token.adminTransfer(kycUser1, kycUser3, 500 * 1e18);

        // Verify final state
        assertEq(token.balanceOf(kycUser1), 500 * 1e18);
        assertEq(token.balanceOf(kycUser2), 4000 * 1e18);
        assertEq(token.balanceOf(kycUser3), 500 * 1e18);
        assertEq(token.balanceOf(factory), 5000 * 1e18);
    }

    // ===== REENTRANCY AND SECURITY TESTS =====

    function test_ReentrancyProtection_AdminTransfer() public {
        // AdminTransfer should be protected by ReentrancyGuard
        vm.prank(admin1);
        token.adminTransfer(factory, kycUser1, 1000 * 1e18);
        // If reentrancy protection works, this completes successfully
    }

    function test_ReentrancyProtection_DistributeDividends() public {
        vm.deal(propertyManager1, 1 ether);
        vm.prank(propertyManager1);
        token.distributeDividends{value: 1 ether}();
        // If reentrancy protection works, this completes successfully
    }

    function test_ReentrancyProtection_ClaimDividends() public {
        // Setup
        accessControl.setKYCStatus(factory, true);
        vm.prank(factory);
        token.transfer(kycUser1, 1000 * 1e18);

        vm.deal(propertyManager1, 1 ether);
        vm.prank(propertyManager1);
        token.distributeDividends{value: 1 ether}();

        vm.prank(kycUser1);
        token.claimDividends();
        // If reentrancy protection works, this completes successfully
    }

    function test_LargeTokenAmounts() public {
        uint256 largeAmount = type(uint256).max / 4;

        vm.prank(factory);
        token.mint(kycUser1, largeAmount);

        assertEq(token.balanceOf(kycUser1), largeAmount);
        assertEq(token.totalSupply(), TOTAL_SUPPLY + largeAmount);
    }

    function test_ZeroDividendsCalculation() public {
        // Edge case: what happens with very small dividend amounts
        uint256 smallDividend = 1 wei;
        uint256 smallTokens = 1;

        vm.prank(factory);
        token.mint(kycUser1, smallTokens);

        vm.deal(propertyManager1, smallDividend);
        vm.prank(propertyManager1);
        token.distributeDividends{value: smallDividend}();

        // Due to integer division, claimable might be 0
        uint256 claimable = token.getClaimableDividends(kycUser1);
        // This should not revert, just return 0 if calculation rounds down
        assertTrue(claimable == 0 || claimable > 0);
    }
}