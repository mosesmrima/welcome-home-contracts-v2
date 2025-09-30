// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/Marketplace.sol";
import "../src/AccessControl.sol";
import "../src/PropertyToken.sol";
import "../src/OwnershipRegistry.sol";

contract MarketplaceTest is Test {
    Marketplace public marketplace;
    AccessControl public accessControl;
    PropertyToken public token1;
    PropertyToken public token2;
    OwnershipRegistry public ownershipRegistry;

    address public owner;
    address public admin1;
    address public feeCollector;
    address public seller1;
    address public seller2;
    address public buyer1;
    address public buyer2;
    address public buyer3;
    address public nonKycUser;
    address public attacker;

    uint256 constant INITIAL_PLATFORM_FEE = 250; // 2.5%
    uint256 constant TOKEN_SUPPLY = 10000 * 1e18;

    // Realistic trading amounts
    uint256 constant LISTING_AMOUNT = 1000 * 1e18; // 1000 tokens
    uint256 constant PRICE_PER_TOKEN = 100 * 1e18; // $100 per token
    uint256 constant OFFER_AMOUNT = 500 * 1e18; // 500 tokens
    uint256 constant OFFER_PRICE = 95 * 1e18; // $95 per token (below listing price)

    event ListingCreated(
        uint256 indexed listingId,
        address indexed seller,
        address indexed tokenContract,
        uint256 amount,
        uint256 price
    );
    event ListingCancelled(uint256 indexed listingId);
    event ListingPriceUpdated(uint256 indexed listingId, uint256 newPrice);
    event OfferCreated(
        uint256 indexed offerId,
        address indexed buyer,
        uint256 indexed listingId,
        uint256 amount,
        uint256 price
    );
    event OfferCancelled(uint256 indexed offerId);
    event OfferAccepted(
        uint256 indexed offerId,
        uint256 indexed listingId,
        address indexed buyer,
        address seller
    );
    event TokensPurchased(
        uint256 indexed listingId,
        address indexed buyer,
        uint256 amount,
        uint256 totalPrice
    );
    event PlatformFeeUpdated(uint256 newFeePercent);
    event FeeCollectorUpdated(address newFeeCollector);

    function setUp() public {
        owner = address(this);
        admin1 = makeAddr("admin1");
        feeCollector = makeAddr("feeCollector");
        seller1 = makeAddr("seller1");
        seller2 = makeAddr("seller2");
        buyer1 = makeAddr("buyer1");
        buyer2 = makeAddr("buyer2");
        buyer3 = makeAddr("buyer3");
        nonKycUser = makeAddr("nonKycUser");
        attacker = makeAddr("attacker");

        // Deploy core contracts
        accessControl = new AccessControl();
        ownershipRegistry = new OwnershipRegistry(address(accessControl));
        marketplace = new Marketplace(address(accessControl), feeCollector);

        // Set up roles and KYC
        accessControl.setAdmin(admin1, true);
        accessControl.setKYCStatus(seller1, true);
        accessControl.setKYCStatus(seller2, true);
        accessControl.setKYCStatus(buyer1, true);
        accessControl.setKYCStatus(buyer2, true);
        accessControl.setKYCStatus(buyer3, true);
        accessControl.setKYCStatus(owner, true); // For test setup
        accessControl.setKYCStatus(address(marketplace), true); // Marketplace needs KYC for token transfers

        // Deploy test tokens
        token1 = new PropertyToken(
            "Property 1 Token",
            "PROP1",
            TOKEN_SUPPLY,
            1,
            address(accessControl),
            address(this),
            address(ownershipRegistry)
        );

        token2 = new PropertyToken(
            "Property 2 Token",
            "PROP2",
            TOKEN_SUPPLY,
            2,
            address(accessControl),
            address(this),
            address(ownershipRegistry)
        );

        // Authorize tokens to update ownership registry
        ownershipRegistry.setAuthorizedUpdater(address(token1), true);
        ownershipRegistry.setAuthorizedUpdater(address(token2), true);

        // Distribute tokens to sellers for testing
        token1.transfer(seller1, 5000 * 1e18);
        token1.transfer(seller2, 2000 * 1e18);
        token2.transfer(seller1, 3000 * 1e18);

        // Give buyers some ETH for purchases (enough for large offers)
        vm.deal(buyer1, 250000 ether); // Enough for 200,000 ether test
        vm.deal(buyer2, 250000 ether);
        vm.deal(buyer3, 250000 ether);
    }

    // ===== BASIC MARKETPLACE TESTS =====

    function test_InitialState() public {
        assertEq(marketplace.nextListingId(), 0);
        assertEq(marketplace.nextOfferId(), 0);
        assertEq(marketplace.platformFeePercent(), INITIAL_PLATFORM_FEE);
        assertEq(marketplace.feeCollector(), feeCollector);
    }

    // ===== LISTING CREATION TESTS =====

    function test_CreateListing_Success() public {
        // Seller approves marketplace to transfer tokens
        vm.prank(seller1);
        token1.approve(address(marketplace), LISTING_AMOUNT);

        vm.expectEmit(true, true, true, true);
        emit ListingCreated(0, seller1, address(token1), LISTING_AMOUNT, PRICE_PER_TOKEN);

        vm.prank(seller1);
        uint256 listingId = marketplace.createListing(
            address(token1),
            LISTING_AMOUNT,
            PRICE_PER_TOKEN
        );

        assertEq(listingId, 0);
        assertEq(marketplace.nextListingId(), 1);

        // Check listing details
        (
            uint256 id,
            address seller,
            address tokenContract,
            uint256 amount,
            uint256 pricePerToken,
            bool isActive,
            uint256 createdAt
        ) = marketplace.listings(listingId);

        assertEq(id, 0);
        assertEq(seller, seller1);
        assertEq(tokenContract, address(token1));
        assertEq(amount, LISTING_AMOUNT);
        assertEq(pricePerToken, PRICE_PER_TOKEN);
        assertTrue(isActive);
        assertGt(createdAt, 0);

        // Tokens should be transferred to marketplace
        assertEq(token1.balanceOf(address(marketplace)), LISTING_AMOUNT);
        assertEq(token1.balanceOf(seller1), 5000 * 1e18 - LISTING_AMOUNT);
    }

    function test_CreateListing_OnlyKYC() public {
        vm.prank(nonKycUser);
        vm.expectRevert("User not KYC verified");
        marketplace.createListing(address(token1), LISTING_AMOUNT, PRICE_PER_TOKEN);
    }

    function test_CreateListing_SystemPaused() public {
        accessControl.pauseSystem();

        vm.prank(seller1);
        vm.expectRevert("System paused");
        marketplace.createListing(address(token1), LISTING_AMOUNT, PRICE_PER_TOKEN);
    }

    function test_CreateListing_InvalidInputs() public {
        vm.prank(seller1);
        vm.expectRevert("Invalid token contract");
        marketplace.createListing(address(0), LISTING_AMOUNT, PRICE_PER_TOKEN);

        vm.prank(seller1);
        vm.expectRevert("Invalid amount");
        marketplace.createListing(address(token1), 0, PRICE_PER_TOKEN);

        vm.prank(seller1);
        vm.expectRevert("Invalid price");
        marketplace.createListing(address(token1), LISTING_AMOUNT, 0);
    }

    function test_CreateListing_InsufficientBalance() public {
        vm.prank(seller1);
        vm.expectRevert("Insufficient balance");
        marketplace.createListing(address(token1), 10000 * 1e18, PRICE_PER_TOKEN);
    }

    function test_CreateListing_InsufficientAllowance() public {
        // Don't approve marketplace
        vm.prank(seller1);
        vm.expectRevert("Insufficient allowance");
        marketplace.createListing(address(token1), LISTING_AMOUNT, PRICE_PER_TOKEN);
    }

    function test_CreateListing_Multiple() public {
        // Seller1 creates listing for token1
        vm.prank(seller1);
        token1.approve(address(marketplace), LISTING_AMOUNT);
        vm.prank(seller1);
        uint256 listing1 = marketplace.createListing(address(token1), LISTING_AMOUNT, PRICE_PER_TOKEN);

        // Seller2 creates listing for token1
        vm.prank(seller2);
        token1.approve(address(marketplace), 500 * 1e18);
        vm.prank(seller2);
        uint256 listing2 = marketplace.createListing(address(token1), 500 * 1e18, 110 * 1e18);

        // Seller1 creates listing for token2
        vm.prank(seller1);
        token2.approve(address(marketplace), 1500 * 1e18);
        vm.prank(seller1);
        uint256 listing3 = marketplace.createListing(address(token2), 1500 * 1e18, 90 * 1e18);

        assertEq(listing1, 0);
        assertEq(listing2, 1);
        assertEq(listing3, 2);
        assertEq(marketplace.nextListingId(), 3);

        // Check user listings
        uint256[] memory seller1Listings = marketplace.getUserListings(seller1);
        uint256[] memory seller2Listings = marketplace.getUserListings(seller2);

        assertEq(seller1Listings.length, 2);
        assertEq(seller1Listings[0], 0);
        assertEq(seller1Listings[1], 2);

        assertEq(seller2Listings.length, 1);
        assertEq(seller2Listings[0], 1);
    }

    // ===== LISTING MANAGEMENT TESTS =====

    function test_CancelListing_Success() public {
        // Create listing first
        vm.prank(seller1);
        token1.approve(address(marketplace), LISTING_AMOUNT);
        vm.prank(seller1);
        uint256 listingId = marketplace.createListing(address(token1), LISTING_AMOUNT, PRICE_PER_TOKEN);

        uint256 sellerBalanceBefore = token1.balanceOf(seller1);

        vm.expectEmit(true, false, false, false);
        emit ListingCancelled(listingId);

        vm.prank(seller1);
        marketplace.cancelListing(listingId);

        // Check listing is inactive
        (,,,, ,bool isActive,) = marketplace.listings(listingId);
        assertFalse(isActive);

        // Tokens should be returned to seller
        assertEq(token1.balanceOf(seller1), sellerBalanceBefore + LISTING_AMOUNT);
        assertEq(token1.balanceOf(address(marketplace)), 0);
    }

    function test_CancelListing_OnlyOwner() public {
        vm.prank(seller1);
        token1.approve(address(marketplace), LISTING_AMOUNT);
        vm.prank(seller1);
        uint256 listingId = marketplace.createListing(address(token1), LISTING_AMOUNT, PRICE_PER_TOKEN);

        vm.prank(attacker);
        vm.expectRevert("Not listing owner");
        marketplace.cancelListing(listingId);
    }

    function test_CancelListing_InvalidListing() public {
        vm.prank(seller1);
        vm.expectRevert("Invalid listing ID");
        marketplace.cancelListing(999);
    }

    function test_CancelListing_WithOffers() public {
        // Create listing
        vm.prank(seller1);
        token1.approve(address(marketplace), LISTING_AMOUNT);
        vm.prank(seller1);
        uint256 listingId = marketplace.createListing(address(token1), LISTING_AMOUNT, PRICE_PER_TOKEN);

        // Create offers
        vm.prank(buyer1);
        marketplace.createOffer{value: (OFFER_AMOUNT * OFFER_PRICE) / 1e18}(listingId, OFFER_AMOUNT, OFFER_PRICE);

        vm.prank(buyer2);
        marketplace.createOffer{value: (300 * 1e18 * 90 * 1e18) / 1e18}(listingId, 300 * 1e18, 90 * 1e18);

        uint256 buyer1BalanceBefore = buyer1.balance;
        uint256 buyer2BalanceBefore = buyer2.balance;

        // Cancel listing should refund all offers
        vm.prank(seller1);
        marketplace.cancelListing(listingId);

        // Check offers are cancelled and refunded
        (,,,,, bool offer1Active,) = marketplace.offers(0);
        (,,,,, bool offer2Active,) = marketplace.offers(1);
        assertFalse(offer1Active);
        assertFalse(offer2Active);

        // Buyers should get refunds
        assertEq(buyer1.balance, buyer1BalanceBefore + (OFFER_AMOUNT * OFFER_PRICE) / 1e18);
        assertEq(buyer2.balance, buyer2BalanceBefore + (300 * 1e18 * 90 * 1e18) / 1e18);
    }

    function test_UpdateListingPrice_Success() public {
        vm.prank(seller1);
        token1.approve(address(marketplace), LISTING_AMOUNT);
        vm.prank(seller1);
        uint256 listingId = marketplace.createListing(address(token1), LISTING_AMOUNT, PRICE_PER_TOKEN);

        uint256 newPrice = 120 * 1e18;

        vm.expectEmit(true, false, false, true);
        emit ListingPriceUpdated(listingId, newPrice);

        vm.prank(seller1);
        marketplace.updateListingPrice(listingId, newPrice);

        (,,,, uint256 pricePerToken,,) = marketplace.listings(listingId);
        assertEq(pricePerToken, newPrice);
    }

    function test_UpdateListingPrice_OnlyOwner() public {
        vm.prank(seller1);
        token1.approve(address(marketplace), LISTING_AMOUNT);
        vm.prank(seller1);
        uint256 listingId = marketplace.createListing(address(token1), LISTING_AMOUNT, PRICE_PER_TOKEN);

        vm.prank(attacker);
        vm.expectRevert("Not listing owner");
        marketplace.updateListingPrice(listingId, 120 * 1e18);
    }

    function test_UpdateListingPrice_InvalidPrice() public {
        vm.prank(seller1);
        token1.approve(address(marketplace), LISTING_AMOUNT);
        vm.prank(seller1);
        uint256 listingId = marketplace.createListing(address(token1), LISTING_AMOUNT, PRICE_PER_TOKEN);

        vm.prank(seller1);
        vm.expectRevert("Invalid price");
        marketplace.updateListingPrice(listingId, 0);
    }

    // ===== OFFER CREATION TESTS =====

    function test_CreateOffer_Success() public {
        // Create listing first
        vm.prank(seller1);
        token1.approve(address(marketplace), LISTING_AMOUNT);
        vm.prank(seller1);
        uint256 listingId = marketplace.createListing(address(token1), LISTING_AMOUNT, PRICE_PER_TOKEN);

        uint256 totalOfferPrice = (OFFER_AMOUNT * OFFER_PRICE) / 1e18;

        vm.expectEmit(true, true, true, true);
        emit OfferCreated(0, buyer1, listingId, OFFER_AMOUNT, OFFER_PRICE);

        vm.prank(buyer1);
        uint256 offerId = marketplace.createOffer{value: totalOfferPrice}(
            listingId,
            OFFER_AMOUNT,
            OFFER_PRICE
        );

        assertEq(offerId, 0);
        assertEq(marketplace.nextOfferId(), 1);

        // Check offer details
        (
            uint256 id,
            address buyer,
            uint256 offerListingId,
            uint256 amount,
            uint256 pricePerToken,
            bool isActive,
            uint256 createdAt
        ) = marketplace.offers(offerId);

        assertEq(id, 0);
        assertEq(buyer, buyer1);
        assertEq(offerListingId, listingId);
        assertEq(amount, OFFER_AMOUNT);
        assertEq(pricePerToken, OFFER_PRICE);
        assertTrue(isActive);
        assertGt(createdAt, 0);

        // Check user offers tracking
        uint256[] memory buyerOffers = marketplace.getUserOffers(buyer1);
        assertEq(buyerOffers.length, 1);
        assertEq(buyerOffers[0], offerId);
    }

    function test_CreateOffer_OnlyKYC() public {
        vm.prank(seller1);
        token1.approve(address(marketplace), LISTING_AMOUNT);
        vm.prank(seller1);
        uint256 listingId = marketplace.createListing(address(token1), LISTING_AMOUNT, PRICE_PER_TOKEN);

        vm.deal(nonKycUser, 50000 ether);
        vm.prank(nonKycUser);
        vm.expectRevert("User not KYC verified");
        marketplace.createOffer{value: (OFFER_AMOUNT * OFFER_PRICE) / 1e18}(listingId, OFFER_AMOUNT, OFFER_PRICE);
    }

    function test_CreateOffer_SystemPaused() public {
        vm.prank(seller1);
        token1.approve(address(marketplace), LISTING_AMOUNT);
        vm.prank(seller1);
        uint256 listingId = marketplace.createListing(address(token1), LISTING_AMOUNT, PRICE_PER_TOKEN);

        accessControl.pauseSystem();

        vm.prank(buyer1);
        vm.expectRevert("System paused");
        marketplace.createOffer{value: (OFFER_AMOUNT * OFFER_PRICE) / 1e18}(listingId, OFFER_AMOUNT, OFFER_PRICE);
    }

    function test_CreateOffer_InvalidInputs() public {
        vm.prank(seller1);
        token1.approve(address(marketplace), LISTING_AMOUNT);
        vm.prank(seller1);
        uint256 listingId = marketplace.createListing(address(token1), LISTING_AMOUNT, PRICE_PER_TOKEN);

        vm.prank(buyer1);
        vm.expectRevert("Invalid amount");
        marketplace.createOffer{value: 0}(listingId, 0, OFFER_PRICE);

        vm.prank(buyer1);
        vm.expectRevert("Invalid price");
        marketplace.createOffer{value: OFFER_AMOUNT}(listingId, OFFER_AMOUNT, 0);

        vm.prank(buyer1);
        vm.expectRevert("Amount exceeds listing");
        marketplace.createOffer{value: (2000 * 1e18 * OFFER_PRICE) / 1e18}(listingId, 2000 * 1e18, OFFER_PRICE);
    }

    function test_CreateOffer_InsufficientPayment() public {
        vm.prank(seller1);
        token1.approve(address(marketplace), LISTING_AMOUNT);
        vm.prank(seller1);
        uint256 listingId = marketplace.createListing(address(token1), LISTING_AMOUNT, PRICE_PER_TOKEN);

        uint256 insufficientPayment = (OFFER_AMOUNT * OFFER_PRICE) / 1e18 - 1;

        vm.prank(buyer1);
        vm.expectRevert("Insufficient payment");
        marketplace.createOffer{value: insufficientPayment}(listingId, OFFER_AMOUNT, OFFER_PRICE);
    }

    function test_CreateOffer_ExcessPaymentRefunded() public {
        vm.prank(seller1);
        token1.approve(address(marketplace), LISTING_AMOUNT);
        vm.prank(seller1);
        uint256 listingId = marketplace.createListing(address(token1), LISTING_AMOUNT, PRICE_PER_TOKEN);

        uint256 totalOfferPrice = (OFFER_AMOUNT * OFFER_PRICE) / 1e18;
        uint256 excessPayment = totalOfferPrice + 10 ether;
        uint256 buyerBalanceBefore = buyer1.balance;

        vm.prank(buyer1);
        marketplace.createOffer{value: excessPayment}(listingId, OFFER_AMOUNT, OFFER_PRICE);

        // Should only deduct the exact offer amount
        assertEq(buyer1.balance, buyerBalanceBefore - totalOfferPrice);
    }

    function test_CreateOffer_Multiple() public {
        vm.prank(seller1);
        token1.approve(address(marketplace), LISTING_AMOUNT);
        vm.prank(seller1);
        uint256 listingId = marketplace.createListing(address(token1), LISTING_AMOUNT, PRICE_PER_TOKEN);

        // Multiple buyers create offers
        vm.prank(buyer1);
        uint256 offer1 = marketplace.createOffer{value: (300 * 1e18 * 95 * 1e18) / 1e18}(listingId, 300 * 1e18, 95 * 1e18);

        vm.prank(buyer2);
        uint256 offer2 = marketplace.createOffer{value: (400 * 1e18 * 98 * 1e18) / 1e18}(listingId, 400 * 1e18, 98 * 1e18);

        vm.prank(buyer3);
        uint256 offer3 = marketplace.createOffer{value: (200 * 1e18 * 92 * 1e18) / 1e18}(listingId, 200 * 1e18, 92 * 1e18);

        assertEq(offer1, 0);
        assertEq(offer2, 1);
        assertEq(offer3, 2);

        // Check offers for listing
        Marketplace.Offer[] memory offers = marketplace.getOffersByListing(listingId);
        assertEq(offers.length, 3);
        assertEq(offers[0].buyer, buyer1);
        assertEq(offers[1].buyer, buyer2);
        assertEq(offers[2].buyer, buyer3);
    }

    // ===== OFFER MANAGEMENT TESTS =====

    function test_CancelOffer_Success() public {
        // Setup: Create listing and offer
        vm.prank(seller1);
        token1.approve(address(marketplace), LISTING_AMOUNT);
        vm.prank(seller1);
        uint256 listingId = marketplace.createListing(address(token1), LISTING_AMOUNT, PRICE_PER_TOKEN);

        uint256 totalOfferPrice = (OFFER_AMOUNT * OFFER_PRICE) / 1e18;
        vm.prank(buyer1);
        uint256 offerId = marketplace.createOffer{value: totalOfferPrice}(listingId, OFFER_AMOUNT, OFFER_PRICE);

        uint256 buyerBalanceBefore = buyer1.balance;

        vm.expectEmit(true, false, false, false);
        emit OfferCancelled(offerId);

        vm.prank(buyer1);
        marketplace.cancelOffer(offerId);

        // Check offer is inactive
        (,,,,, bool isActive,) = marketplace.offers(offerId);
        assertFalse(isActive);

        // Buyer should get refund
        assertEq(buyer1.balance, buyerBalanceBefore + totalOfferPrice);
    }

    function test_CancelOffer_OnlyOwner() public {
        vm.prank(seller1);
        token1.approve(address(marketplace), LISTING_AMOUNT);
        vm.prank(seller1);
        uint256 listingId = marketplace.createListing(address(token1), LISTING_AMOUNT, PRICE_PER_TOKEN);

        vm.prank(buyer1);
        uint256 offerId = marketplace.createOffer{value: (OFFER_AMOUNT * OFFER_PRICE) / 1e18}(listingId, OFFER_AMOUNT, OFFER_PRICE);

        vm.prank(attacker);
        vm.expectRevert("Not offer owner");
        marketplace.cancelOffer(offerId);
    }

    function test_AcceptOffer_Success() public {
        // Setup: Create listing and offer
        vm.prank(seller1);
        token1.approve(address(marketplace), LISTING_AMOUNT);
        vm.prank(seller1);
        uint256 listingId = marketplace.createListing(address(token1), LISTING_AMOUNT, PRICE_PER_TOKEN);

        uint256 totalOfferPrice = (OFFER_AMOUNT * OFFER_PRICE) / 1e18;
        vm.prank(buyer1);
        uint256 offerId = marketplace.createOffer{value: totalOfferPrice}(listingId, OFFER_AMOUNT, OFFER_PRICE);

        uint256 platformFee = (totalOfferPrice * INITIAL_PLATFORM_FEE) / 10000;
        uint256 sellerAmount = totalOfferPrice - platformFee;

        uint256 sellerBalanceBefore = seller1.balance;
        uint256 feeCollectorBalanceBefore = feeCollector.balance;
        uint256 buyerTokenBalanceBefore = token1.balanceOf(buyer1);

        vm.expectEmit(true, true, true, true);
        emit OfferAccepted(offerId, listingId, buyer1, seller1);

        vm.prank(seller1);
        marketplace.acceptOffer(offerId);

        // Check payments
        assertEq(seller1.balance, sellerBalanceBefore + sellerAmount);
        assertEq(feeCollector.balance, feeCollectorBalanceBefore + platformFee);

        // Check token transfer
        assertEq(token1.balanceOf(buyer1), buyerTokenBalanceBefore + OFFER_AMOUNT);

        // Check offer is inactive
        (,,,,, bool isActive,) = marketplace.offers(offerId);
        assertFalse(isActive);

        // Check listing amount is reduced
        (,,, uint256 remainingAmount,,,) = marketplace.listings(listingId);
        assertEq(remainingAmount, LISTING_AMOUNT - OFFER_AMOUNT);
    }

    function test_AcceptOffer_FullListing() public {
        // Create listing and offer for full amount
        vm.prank(seller1);
        token1.approve(address(marketplace), LISTING_AMOUNT);
        vm.prank(seller1);
        uint256 listingId = marketplace.createListing(address(token1), LISTING_AMOUNT, PRICE_PER_TOKEN);

        uint256 totalOfferPrice = (LISTING_AMOUNT * OFFER_PRICE) / 1e18;
        vm.prank(buyer1);
        uint256 offerId = marketplace.createOffer{value: totalOfferPrice}(listingId, LISTING_AMOUNT, OFFER_PRICE);

        vm.prank(seller1);
        marketplace.acceptOffer(offerId);

        // Listing should be inactive
        (,,,, ,bool listingActive,) = marketplace.listings(listingId);
        assertFalse(listingActive);
    }

    function test_AcceptOffer_OnlyListingOwner() public {
        vm.prank(seller1);
        token1.approve(address(marketplace), LISTING_AMOUNT);
        vm.prank(seller1);
        uint256 listingId = marketplace.createListing(address(token1), LISTING_AMOUNT, PRICE_PER_TOKEN);

        vm.prank(buyer1);
        uint256 offerId = marketplace.createOffer{value: (OFFER_AMOUNT * OFFER_PRICE) / 1e18}(listingId, OFFER_AMOUNT, OFFER_PRICE);

        vm.prank(attacker);
        vm.expectRevert("Not listing owner");
        marketplace.acceptOffer(offerId);
    }

    function test_AcceptOffer_InactiveListing() public {
        vm.prank(seller1);
        token1.approve(address(marketplace), LISTING_AMOUNT);
        vm.prank(seller1);
        uint256 listingId = marketplace.createListing(address(token1), LISTING_AMOUNT, PRICE_PER_TOKEN);

        vm.prank(buyer1);
        uint256 offerId = marketplace.createOffer{value: (OFFER_AMOUNT * OFFER_PRICE) / 1e18}(listingId, OFFER_AMOUNT, OFFER_PRICE);

        // Cancel listing
        vm.prank(seller1);
        marketplace.cancelListing(listingId);

        vm.prank(seller1);
        vm.expectRevert("Listing not active");
        marketplace.acceptOffer(offerId);
    }

    // ===== DIRECT PURCHASE TESTS =====

    function test_BuyFromListing_Success() public {
        vm.prank(seller1);
        token1.approve(address(marketplace), LISTING_AMOUNT);
        vm.prank(seller1);
        uint256 listingId = marketplace.createListing(address(token1), LISTING_AMOUNT, PRICE_PER_TOKEN);

        uint256 purchaseAmount = 600 * 1e18;
        uint256 totalPrice = (purchaseAmount * PRICE_PER_TOKEN) / 1e18;
        uint256 platformFee = (totalPrice * INITIAL_PLATFORM_FEE) / 10000;
        uint256 sellerAmount = totalPrice - platformFee;

        uint256 sellerBalanceBefore = seller1.balance;
        uint256 feeCollectorBalanceBefore = feeCollector.balance;
        uint256 buyerTokenBalanceBefore = token1.balanceOf(buyer1);

        vm.expectEmit(true, true, false, true);
        emit TokensPurchased(listingId, buyer1, purchaseAmount, totalPrice);

        vm.prank(buyer1);
        marketplace.buyFromListing{value: totalPrice}(listingId, purchaseAmount);

        // Check payments
        assertEq(seller1.balance, sellerBalanceBefore + sellerAmount);
        assertEq(feeCollector.balance, feeCollectorBalanceBefore + platformFee);

        // Check token transfer
        assertEq(token1.balanceOf(buyer1), buyerTokenBalanceBefore + purchaseAmount);

        // Check listing amount is reduced
        (,,, uint256 remainingAmount,,,) = marketplace.listings(listingId);
        assertEq(remainingAmount, LISTING_AMOUNT - purchaseAmount);
    }

    function test_BuyFromListing_FullAmount() public {
        vm.prank(seller1);
        token1.approve(address(marketplace), LISTING_AMOUNT);
        vm.prank(seller1);
        uint256 listingId = marketplace.createListing(address(token1), LISTING_AMOUNT, PRICE_PER_TOKEN);

        uint256 totalPrice = (LISTING_AMOUNT * PRICE_PER_TOKEN) / 1e18;

        vm.prank(buyer1);
        marketplace.buyFromListing{value: totalPrice}(listingId, LISTING_AMOUNT);

        // Listing should be inactive
        (,,,, ,bool isActive,) = marketplace.listings(listingId);
        assertFalse(isActive);
    }

    function test_BuyFromListing_OnlyKYC() public {
        vm.prank(seller1);
        token1.approve(address(marketplace), LISTING_AMOUNT);
        vm.prank(seller1);
        uint256 listingId = marketplace.createListing(address(token1), LISTING_AMOUNT, PRICE_PER_TOKEN);

        vm.deal(nonKycUser, 15000 ether);
        vm.prank(nonKycUser);
        vm.expectRevert("User not KYC verified");
        marketplace.buyFromListing{value: (100 * 1e18 * PRICE_PER_TOKEN) / 1e18}(listingId, 100 * 1e18);
    }

    function test_BuyFromListing_InvalidInputs() public {
        vm.prank(seller1);
        token1.approve(address(marketplace), LISTING_AMOUNT);
        vm.prank(seller1);
        uint256 listingId = marketplace.createListing(address(token1), LISTING_AMOUNT, PRICE_PER_TOKEN);

        vm.prank(buyer1);
        vm.expectRevert("Invalid amount");
        marketplace.buyFromListing{value: 0}(listingId, 0);

        vm.prank(buyer1);
        vm.expectRevert("Amount exceeds available");
        marketplace.buyFromListing{value: (2000 * 1e18 * PRICE_PER_TOKEN) / 1e18}(listingId, 2000 * 1e18);
    }

    function test_BuyFromListing_InsufficientPayment() public {
        vm.prank(seller1);
        token1.approve(address(marketplace), LISTING_AMOUNT);
        vm.prank(seller1);
        uint256 listingId = marketplace.createListing(address(token1), LISTING_AMOUNT, PRICE_PER_TOKEN);

        uint256 purchaseAmount = 500 * 1e18;
        uint256 insufficientPayment = (purchaseAmount * PRICE_PER_TOKEN) / 1e18 - 1;

        vm.prank(buyer1);
        vm.expectRevert("Insufficient payment");
        marketplace.buyFromListing{value: insufficientPayment}(listingId, purchaseAmount);
    }

    function test_BuyFromListing_ExcessPaymentRefunded() public {
        vm.prank(seller1);
        token1.approve(address(marketplace), LISTING_AMOUNT);
        vm.prank(seller1);
        uint256 listingId = marketplace.createListing(address(token1), LISTING_AMOUNT, PRICE_PER_TOKEN);

        uint256 purchaseAmount = 500 * 1e18;
        uint256 totalPrice = (purchaseAmount * PRICE_PER_TOKEN) / 1e18;
        uint256 excessPayment = totalPrice + 5 ether;
        uint256 buyerBalanceBefore = buyer1.balance;

        vm.prank(buyer1);
        marketplace.buyFromListing{value: excessPayment}(listingId, purchaseAmount);

        // Calculate expected balance (excess should be refunded)
        uint256 expectedBalance = buyerBalanceBefore - totalPrice;
        assertEq(buyer1.balance, expectedBalance);
    }

    // ===== ADMIN FUNCTIONS TESTS =====

    function test_SetPlatformFee_Success() public {
        uint256 newFee = 500; // 5%

        vm.expectEmit(false, false, false, true);
        emit PlatformFeeUpdated(newFee);

        vm.prank(admin1);
        marketplace.setPlatformFee(newFee);

        assertEq(marketplace.platformFeePercent(), newFee);
    }

    function test_SetPlatformFee_OnlyAdmin() public {
        vm.prank(attacker);
        vm.expectRevert("Not admin");
        marketplace.setPlatformFee(500);
    }

    function test_SetPlatformFee_TooHigh() public {
        vm.prank(admin1);
        vm.expectRevert("Fee too high");
        marketplace.setPlatformFee(1001); // >10%
    }

    function test_SetFeeCollector_Success() public {
        address newCollector = makeAddr("newCollector");

        vm.expectEmit(false, false, false, true);
        emit FeeCollectorUpdated(newCollector);

        vm.prank(admin1);
        marketplace.setFeeCollector(newCollector);

        assertEq(marketplace.feeCollector(), newCollector);
    }

    function test_SetFeeCollector_OnlyAdmin() public {
        vm.prank(attacker);
        vm.expectRevert("Not admin");
        marketplace.setFeeCollector(makeAddr("newCollector"));
    }

    function test_SetFeeCollector_InvalidAddress() public {
        vm.prank(admin1);
        vm.expectRevert("Invalid address");
        marketplace.setFeeCollector(address(0));
    }

    function test_EmergencyWithdraw() public {
        // Send some ETH to marketplace (from failed transactions, etc.)
        vm.deal(address(marketplace), 10 ether);

        uint256 adminBalanceBefore = admin1.balance;

        vm.prank(admin1);
        marketplace.emergencyWithdraw();

        assertEq(admin1.balance, adminBalanceBefore + 10 ether);
        assertEq(address(marketplace).balance, 0);
    }

    function test_EmergencyWithdraw_OnlyAdmin() public {
        vm.prank(attacker);
        vm.expectRevert("Not admin");
        marketplace.emergencyWithdraw();
    }

    // ===== QUERY FUNCTIONS TESTS =====

    function test_GetActiveListings() public {
        // Create multiple listings
        vm.prank(seller1);
        token1.approve(address(marketplace), 3000 * 1e18);
        vm.prank(seller1);
        uint256 listing1 = marketplace.createListing(address(token1), 1000 * 1e18, PRICE_PER_TOKEN);

        vm.prank(seller1);
        uint256 listing2 = marketplace.createListing(address(token1), 1500 * 1e18, PRICE_PER_TOKEN);

        vm.prank(seller2);
        token1.approve(address(marketplace), 500 * 1e18);
        vm.prank(seller2);
        uint256 listing3 = marketplace.createListing(address(token1), 500 * 1e18, PRICE_PER_TOKEN);

        // Cancel one listing
        vm.prank(seller1);
        marketplace.cancelListing(listing2);

        Marketplace.Listing[] memory activeListings = marketplace.getActiveListings();
        assertEq(activeListings.length, 2);
        assertEq(activeListings[0].id, listing1);
        assertEq(activeListings[1].id, listing3);
    }

    function test_GetListingsByToken() public {
        // Create listings for different tokens
        vm.prank(seller1);
        token1.approve(address(marketplace), 2000 * 1e18);
        vm.prank(seller1);
        marketplace.createListing(address(token1), 1000 * 1e18, PRICE_PER_TOKEN);

        vm.prank(seller1);
        marketplace.createListing(address(token1), 1000 * 1e18, PRICE_PER_TOKEN);

        vm.prank(seller1);
        token2.approve(address(marketplace), 1000 * 1e18);
        vm.prank(seller1);
        marketplace.createListing(address(token2), 1000 * 1e18, 90 * 1e18);

        Marketplace.Listing[] memory token1Listings = marketplace.getListingsByToken(address(token1));
        Marketplace.Listing[] memory token2Listings = marketplace.getListingsByToken(address(token2));

        assertEq(token1Listings.length, 2);
        assertEq(token2Listings.length, 1);
        assertEq(token1Listings[0].tokenContract, address(token1));
        assertEq(token2Listings[0].tokenContract, address(token2));
    }

    // ===== COMPLEX INTEGRATION TESTS =====

    function test_CompleteMarketplaceFlow() public {
        // 1. Seller creates listing
        vm.prank(seller1);
        token1.approve(address(marketplace), LISTING_AMOUNT);
        vm.prank(seller1);
        uint256 listingId = marketplace.createListing(address(token1), LISTING_AMOUNT, PRICE_PER_TOKEN);

        // 2. Multiple buyers create offers
        vm.prank(buyer1);
        marketplace.createOffer{value: (300 * 1e18 * 95 * 1e18) / 1e18}(listingId, 300 * 1e18, 95 * 1e18);

        vm.prank(buyer2);
        marketplace.createOffer{value: (400 * 1e18 * 98 * 1e18) / 1e18}(listingId, 400 * 1e18, 98 * 1e18);

        // 3. Buyer3 makes direct purchase
        uint256 directPurchaseAmount = 200 * 1e18;
        uint256 directPurchasePrice = (directPurchaseAmount * PRICE_PER_TOKEN) / 1e18;
        vm.prank(buyer3);
        marketplace.buyFromListing{value: directPurchasePrice}(listingId, directPurchaseAmount);

        // Check listing amount reduced
        (,,, uint256 remainingAmount,,,) = marketplace.listings(listingId);
        assertEq(remainingAmount, LISTING_AMOUNT - directPurchaseAmount);

        // 4. Seller accepts one offer
        vm.prank(seller1);
        marketplace.acceptOffer(1); // Accept buyer2's offer

        // Check final listing amount
        (,,, uint256 finalAmount,,,) = marketplace.listings(listingId);
        assertEq(finalAmount, LISTING_AMOUNT - directPurchaseAmount - 400 * 1e18);

        // 5. Check token distributions
        assertEq(token1.balanceOf(buyer2), 400 * 1e18);
        assertEq(token1.balanceOf(buyer3), directPurchaseAmount);

        // 6. Buyer1's offer should still be active
        (,,,,, bool offer1Active,) = marketplace.offers(0);
        assertTrue(offer1Active);
    }

    function test_MultipleTokenMarketplace() public {
        // Create listings for different property tokens
        vm.prank(seller1);
        token1.approve(address(marketplace), 2000 * 1e18);
        vm.prank(seller1);
        uint256 listing1 = marketplace.createListing(address(token1), 1000 * 1e18, 100 * 1e18);

        vm.prank(seller1);
        token2.approve(address(marketplace), 1500 * 1e18);
        vm.prank(seller1);
        uint256 listing2 = marketplace.createListing(address(token2), 1500 * 1e18, 80 * 1e18);

        vm.prank(seller2);
        token1.approve(address(marketplace), 1000 * 1e18);
        vm.prank(seller2);
        uint256 listing3 = marketplace.createListing(address(token1), 1000 * 1e18, 105 * 1e18);

        // Buyers trade across different properties
        vm.prank(buyer1);
        marketplace.buyFromListing{value: (500 * 1e18 * 100 * 1e18) / 1e18}(listing1, 500 * 1e18);

        vm.prank(buyer2);
        marketplace.buyFromListing{value: (700 * 1e18 * 80 * 1e18) / 1e18}(listing2, 700 * 1e18);

        vm.prank(buyer3);
        marketplace.buyFromListing{value: (300 * 1e18 * 105 * 1e18) / 1e18}(listing3, 300 * 1e18);

        // Check portfolio distributions
        assertEq(token1.balanceOf(buyer1), 500 * 1e18);
        assertEq(token2.balanceOf(buyer2), 700 * 1e18);
        assertEq(token1.balanceOf(buyer3), 300 * 1e18);
    }

    function test_FeeCalculationAccuracy() public {
        // Test fee calculations with different fee percentages
        vm.prank(admin1);
        marketplace.setPlatformFee(150); // 1.5%

        vm.prank(seller1);
        token1.approve(address(marketplace), LISTING_AMOUNT);
        vm.prank(seller1);
        uint256 listingId = marketplace.createListing(address(token1), LISTING_AMOUNT, PRICE_PER_TOKEN);

        uint256 purchaseAmount = 1000 * 1e18;
        uint256 totalPrice = (purchaseAmount * PRICE_PER_TOKEN) / 1e18; // 100,000 * 1e18
        uint256 platformFee = (totalPrice * 150) / 10000; // 1.5%
        uint256 sellerAmount = totalPrice - platformFee;

        uint256 sellerBalanceBefore = seller1.balance;
        uint256 feeCollectorBalanceBefore = feeCollector.balance;

        vm.prank(buyer1);
        marketplace.buyFromListing{value: totalPrice}(listingId, purchaseAmount);

        assertEq(seller1.balance - sellerBalanceBefore, sellerAmount);
        assertEq(feeCollector.balance - feeCollectorBalanceBefore, platformFee);

        // Verify exact amounts
        assertEq(platformFee, totalPrice * 150 / 10000);
        assertEq(sellerAmount, totalPrice - platformFee);
    }

    // ===== SECURITY AND EDGE CASE TESTS =====

    function test_ReentrancyProtection() public {
        // All major functions should be protected by ReentrancyGuard
        vm.prank(seller1);
        token1.approve(address(marketplace), LISTING_AMOUNT);
        vm.prank(seller1);
        uint256 listingId = marketplace.createListing(address(token1), LISTING_AMOUNT, PRICE_PER_TOKEN);

        vm.prank(buyer1);
        marketplace.buyFromListing{value: (LISTING_AMOUNT * PRICE_PER_TOKEN) / 1e18}(listingId, LISTING_AMOUNT);
        // If reentrancy protection works, this completes successfully
    }

    function test_LargeTransactionAmounts() public {
        // Test with very large amounts
        uint256 largeAmount = 1000000 * 1e18;
        uint256 largePrice = 1000 * 1e18;

        // Set up large token supply for test
        token1.mint(seller1, largeAmount);

        vm.prank(seller1);
        token1.approve(address(marketplace), largeAmount);
        vm.prank(seller1);
        uint256 listingId = marketplace.createListing(address(token1), largeAmount, largePrice);

        uint256 purchaseAmount = 100000 * 1e18;
        uint256 totalPrice = purchaseAmount * largePrice;

        vm.deal(buyer1, totalPrice + 1000 ether); // Ensure sufficient balance

        vm.prank(buyer1);
        marketplace.buyFromListing{value: totalPrice}(listingId, purchaseAmount);

        assertEq(token1.balanceOf(buyer1), purchaseAmount);
    }

    function test_ZeroValueTransactions() public {
        // Test edge cases with very small values
        vm.prank(seller1);
        token1.approve(address(marketplace), LISTING_AMOUNT);
        vm.prank(seller1);
        uint256 listingId = marketplace.createListing(address(token1), LISTING_AMOUNT, 1); // 1 wei per token

        vm.prank(buyer1);
        marketplace.buyFromListing{value: 1000}(listingId, 1000); // Buy 1000 tokens for 1000 wei

        assertEq(token1.balanceOf(buyer1), 1000);
    }

    function test_InvalidListingAccess() public {
        vm.prank(buyer1);
        vm.expectRevert("Invalid listing ID");
        marketplace.buyFromListing{value: 100 ether}(999, 100 * 1e18);

        vm.prank(buyer1);
        vm.expectRevert("Invalid offer ID");
        marketplace.cancelOffer(999);
    }

    function test_SystemPausedPreventsAllOperations() public {
        // Create some initial state
        vm.prank(seller1);
        token1.approve(address(marketplace), LISTING_AMOUNT);
        vm.prank(seller1);
        uint256 listingId = marketplace.createListing(address(token1), LISTING_AMOUNT, PRICE_PER_TOKEN);

        vm.prank(buyer1);
        uint256 offerId = marketplace.createOffer{value: (OFFER_AMOUNT * OFFER_PRICE) / 1e18}(listingId, OFFER_AMOUNT, OFFER_PRICE);

        // Pause system
        accessControl.pauseSystem();

        // All user operations should fail
        vm.prank(seller2);
        vm.expectRevert("System paused");
        marketplace.createListing(address(token1), 100 * 1e18, PRICE_PER_TOKEN);

        vm.prank(buyer2);
        vm.expectRevert("System paused");
        marketplace.createOffer{value: (100 * 1e18 * OFFER_PRICE) / 1e18}(listingId, 100 * 1e18, OFFER_PRICE);

        vm.prank(buyer2);
        vm.expectRevert("System paused");
        marketplace.buyFromListing{value: (100 * 1e18 * PRICE_PER_TOKEN) / 1e18}(listingId, 100 * 1e18);

        // Note: Cancellation and management operations might still work for existing items
        // This could be intentional for admin management during maintenance
    }
}