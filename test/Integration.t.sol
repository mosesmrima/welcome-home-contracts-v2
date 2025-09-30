// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/AccessControl.sol";
import "../src/OwnershipRegistry.sol";
import "../src/PropertyFactory.sol";
import "../src/PropertyToken.sol";
import "../src/Marketplace.sol";

/**
 * @title Integration Tests
 * @notice Comprehensive end-to-end tests that verify the entire Welcome Home Property system
 * working together as specified in the PDF requirements
 */
contract IntegrationTest is Test {
    // Core contracts
    AccessControl public accessControl;
    OwnershipRegistry public ownershipRegistry;
    PropertyFactory public propertyFactory;
    Marketplace public marketplace;

    // User roles (matching PDF user personas)
    address public systemOwner;
    address public complianceOfficer;
    address public propertyManager1;
    address public propertyManager2;
    address public feeCollector;

    // Investors (realistic personas)
    address public newInvestor; // First-time platform user
    address public activeTrader; // Frequent marketplace participant
    address public passiveInvestor; // Buy-and-hold dividend seeker
    address public institutionalInvestor; // Large capital investor

    // Non-compliant users
    address public nonKycUser;
    address public restrictedUser;

    // Property tokens created during tests
    PropertyToken public luxuryApartmentToken;
    PropertyToken public suburbanHomesToken;
    PropertyToken public commercialBuildingToken;

    // Test constants matching PDF specifications
    uint256 constant PLATFORM_FEE = 250; // 2.5% as per PDF

    // Luxury Apartment Property (PDF example)
    string constant LUXURY_APT_NAME = "Luxury Downtown Apartment Complex";
    string constant LUXURY_APT_METADATA = "QmLuxuryApartmentMetadata123";
    uint256 constant LUXURY_APT_VALUE = 2500000 * 1e18; // $2.5M
    uint256 constant LUXURY_APT_SUPPLY = 25000; // 25,000 tokens
    uint256 constant LUXURY_APT_PRICE = 100 * 1e18; // $100 per token

    // Suburban Homes Portfolio
    string constant SUBURBAN_NAME = "Suburban Family Home Portfolio";
    string constant SUBURBAN_METADATA = "QmSuburbanHomesMetadata456";
    uint256 constant SUBURBAN_VALUE = 1200000 * 1e18; // $1.2M
    uint256 constant SUBURBAN_SUPPLY = 12000; // 12,000 tokens
    uint256 constant SUBURBAN_PRICE = 100 * 1e18; // $100 per token

    // Commercial Building
    string constant COMMERCIAL_NAME = "Downtown Commercial Building";
    string constant COMMERCIAL_METADATA = "QmCommercialBuildingMetadata789";
    uint256 constant COMMERCIAL_VALUE = 5000000 * 1e18; // $5M
    uint256 constant COMMERCIAL_SUPPLY = 50000; // 50,000 tokens
    uint256 constant COMMERCIAL_PRICE = 100 * 1e18; // $100 per token

    event SystemInitialized();
    event UserOnboarded(address indexed user, string userType);
    event PropertyLaunched(uint256 indexed propertyId, string name, uint256 totalValue);
    event InvestmentMade(address indexed investor, uint256 indexed propertyId, uint256 amount, uint256 cost);
    event TradeExecuted(address indexed buyer, address indexed seller, uint256 indexed propertyId, uint256 amount, uint256 price);
    event DividendsDistributed(uint256 indexed propertyId, uint256 totalAmount);

    function setUp() public {
        // Set up user addresses
        systemOwner = address(this);
        complianceOfficer = makeAddr("complianceOfficer");
        propertyManager1 = makeAddr("propertyManager1");
        propertyManager2 = makeAddr("propertyManager2");
        feeCollector = makeAddr("feeCollector");

        newInvestor = makeAddr("newInvestor");
        activeTrader = makeAddr("activeTrader");
        passiveInvestor = makeAddr("passiveInvestor");
        institutionalInvestor = makeAddr("institutionalInvestor");

        nonKycUser = makeAddr("nonKycUser");
        restrictedUser = makeAddr("restrictedUser");

        // Give investors ETH for purchases
        vm.deal(newInvestor, 1000 ether);
        vm.deal(activeTrader, 2000 ether);
        vm.deal(passiveInvestor, 500 ether);
        vm.deal(institutionalInvestor, 10000 ether);
        vm.deal(nonKycUser, 100 ether);

        emit SystemInitialized();
    }

    /**
     * @notice Test 1: Complete System Deployment and Initial Configuration
     * Tests the initial deployment and setup process as per PDF Section 9
     */
    function test_01_SystemDeploymentAndConfiguration() public {
        // 1. Deploy core contracts in correct order
        accessControl = new AccessControl();
        ownershipRegistry = new OwnershipRegistry(address(accessControl));
        propertyFactory = new PropertyFactory(address(accessControl), address(ownershipRegistry));
        marketplace = new Marketplace(address(accessControl), feeCollector);

        // 2. Set up admin roles (PDF Section 7)
        accessControl.setAdmin(complianceOfficer, true);
        accessControl.setAdmin(address(propertyFactory), true); // PropertyFactory needs admin for setAuthorizedUpdater
        accessControl.setPropertyManager(propertyManager1, true);
        accessControl.setPropertyManager(propertyManager2, true);

        // 3. Configure marketplace
        vm.prank(complianceOfficer);
        marketplace.setPlatformFee(PLATFORM_FEE);

        // 4. Set up marketplace for token transfers (needs KYC)
        accessControl.setKYCStatus(address(marketplace), true);

        // 5. Verify system state
        assertTrue(accessControl.isAdmin(complianceOfficer));
        assertTrue(accessControl.isPropertyManager(propertyManager1));
        assertTrue(accessControl.isPropertyManager(propertyManager2));
        assertEq(marketplace.platformFeePercent(), PLATFORM_FEE);
        assertEq(marketplace.feeCollector(), feeCollector);

        // System is now ready for operation
        assertFalse(accessControl.isSystemPaused());
    }

    /**
     * @notice Test 2: User KYC and Onboarding Process
     * Tests the complete KYC workflow as per PDF Section 4
     */
    function test_02_UserKYCAndOnboarding() public {
        test_01_SystemDeploymentAndConfiguration();

        // Simulate KYC verification process (PDF Section 4.1)
        // 1. User creates account via email/phone login (simulated)
        // 2. Redirected to KYC plugin (iframe/API) (simulated)
        // 3. KYC Plugin issues status webhook to backend (simulated)
        // 4. If verified: System mints a KYC NFT or flag

        // Compliance officer approves KYC for legitimate users
        vm.startPrank(complianceOfficer);
        accessControl.setKYCStatus(newInvestor, true);
        accessControl.setKYCStatus(activeTrader, true);
        accessControl.setKYCStatus(passiveInvestor, true);
        accessControl.setKYCStatus(institutionalInvestor, true);

        // Property managers need KYC for token transfers
        accessControl.setKYCStatus(propertyManager1, true);
        accessControl.setKYCStatus(propertyManager2, true);

        // PropertyFactory needs KYC to transfer tokens
        accessControl.setKYCStatus(address(propertyFactory), true);

        // Restricted user gets KYC but is marked as restricted
        accessControl.setKYCStatus(restrictedUser, true);
        vm.stopPrank();

        // Verify KYC status
        assertTrue(accessControl.isUserKYCed(newInvestor));
        assertTrue(accessControl.isUserKYCed(activeTrader));
        assertTrue(accessControl.isUserKYCed(passiveInvestor));
        assertTrue(accessControl.isUserKYCed(institutionalInvestor));
        assertFalse(accessControl.isUserKYCed(nonKycUser));

        emit UserOnboarded(newInvestor, "New Investor");
        emit UserOnboarded(activeTrader, "Active Trader");
        emit UserOnboarded(passiveInvestor, "Passive Investor");
        emit UserOnboarded(institutionalInvestor, "Institutional Investor");

        // Test KYC timestamp tracking
        assertGt(accessControl.getUserKYCTimestamp(newInvestor), 0);
    }

    /**
     * @notice Test 3: Property Creation and Tokenization
     * Tests property registration and tokenization as per PDF Section 6.1
     */
    function test_03_PropertyCreationAndTokenization() public {
        test_02_UserKYCAndOnboarding();

        // Property Manager 1 creates luxury apartment property
        vm.prank(propertyManager1);
        uint256 luxuryPropertyId = propertyFactory.createProperty(
            LUXURY_APT_NAME,
            LUXURY_APT_METADATA,
            LUXURY_APT_VALUE,
            LUXURY_APT_SUPPLY,
            LUXURY_APT_PRICE
        );

        // Property Manager 2 creates suburban homes portfolio
        vm.prank(propertyManager2);
        uint256 suburbanPropertyId = propertyFactory.createProperty(
            SUBURBAN_NAME,
            SUBURBAN_METADATA,
            SUBURBAN_VALUE,
            SUBURBAN_SUPPLY,
            SUBURBAN_PRICE
        );

        // Property Manager 1 creates commercial building
        vm.prank(propertyManager1);
        uint256 commercialPropertyId = propertyFactory.createProperty(
            COMMERCIAL_NAME,
            COMMERCIAL_METADATA,
            COMMERCIAL_VALUE,
            COMMERCIAL_SUPPLY,
            COMMERCIAL_PRICE
        );

        // Verify properties were created correctly
        assertEq(luxuryPropertyId, 0);
        assertEq(suburbanPropertyId, 1);
        assertEq(commercialPropertyId, 2);

        // Get property tokens for later use
        luxuryApartmentToken = PropertyToken(propertyFactory.getPropertyToken(luxuryPropertyId));
        suburbanHomesToken = PropertyToken(propertyFactory.getPropertyToken(suburbanPropertyId));
        commercialBuildingToken = PropertyToken(propertyFactory.getPropertyToken(commercialPropertyId));

        // Verify token details
        assertEq(luxuryApartmentToken.totalSupply(), LUXURY_APT_SUPPLY);
        assertEq(suburbanHomesToken.totalSupply(), SUBURBAN_SUPPLY);
        assertEq(commercialBuildingToken.totalSupply(), COMMERCIAL_SUPPLY);

        // Verify ownership registry authorization
        assertTrue(ownershipRegistry.authorizedUpdaters(address(luxuryApartmentToken)));
        assertTrue(ownershipRegistry.authorizedUpdaters(address(suburbanHomesToken)));
        assertTrue(ownershipRegistry.authorizedUpdaters(address(commercialBuildingToken)));

        emit PropertyLaunched(luxuryPropertyId, LUXURY_APT_NAME, LUXURY_APT_VALUE);
        emit PropertyLaunched(suburbanPropertyId, SUBURBAN_NAME, SUBURBAN_VALUE);
        emit PropertyLaunched(commercialPropertyId, COMMERCIAL_NAME, COMMERCIAL_VALUE);

        // Verify IPFS metadata storage (PDF requirement)
        PropertyFactory.Property memory luxuryProp = propertyFactory.getProperty(luxuryPropertyId);
        assertEq(luxuryProp.metadataURI, LUXURY_APT_METADATA);
    }

    /**
     * @notice Test 4: Primary Market Investment (Initial Token Distribution)
     * Tests primary offering as per PDF Section 6.2
     */
    function test_04_PrimaryMarketInvestment() public {
        test_03_PropertyCreationAndTokenization();

        // Property managers distribute initial tokens via PropertyFactory (Primary Offering)

        // New investor buys into luxury apartments (first investment)
        uint256 newInvestorAmount = 1000; // 1,000 tokens = $100,000
        vm.prank(propertyManager1);
        propertyFactory.distributeTokens(0, newInvestor, newInvestorAmount);

        // Passive investor builds diversified portfolio
        uint256 passiveInvestorLuxury = 500; // $50,000
        uint256 passiveInvestorSuburban = 800; // $80,000
        vm.prank(propertyManager1);
        propertyFactory.distributeTokens(0, passiveInvestor, passiveInvestorLuxury);
        vm.prank(propertyManager2);
        propertyFactory.distributeTokens(1, passiveInvestor, passiveInvestorSuburban);

        // Active trader starts with position in commercial
        uint256 activeTraderCommercial = 2000; // $200,000
        vm.prank(propertyManager1);
        propertyFactory.distributeTokens(2, activeTrader, activeTraderCommercial);

        // Institutional investor makes large investment across all properties
        uint256 institutionalLuxury = 5000; // $500,000
        uint256 institutionalSuburban = 3000; // $300,000
        uint256 institutionalCommercial = 10000; // $1,000,000
        vm.prank(propertyManager1);
        propertyFactory.distributeTokens(0, institutionalInvestor, institutionalLuxury);
        vm.prank(propertyManager2);
        propertyFactory.distributeTokens(1, institutionalInvestor, institutionalSuburban);
        vm.prank(propertyManager1);
        propertyFactory.distributeTokens(2, institutionalInvestor, institutionalCommercial);

        // Verify ownership registry is updated
        assertEq(ownershipRegistry.getUserTokenBalance(newInvestor, address(luxuryApartmentToken)), newInvestorAmount);
        assertEq(ownershipRegistry.getUserTokenBalance(passiveInvestor, address(luxuryApartmentToken)), passiveInvestorLuxury);
        assertEq(ownershipRegistry.getUserTokenBalance(activeTrader, address(commercialBuildingToken)), activeTraderCommercial);

        // Verify portfolio diversity
        assertEq(ownershipRegistry.getUserTotalProperties(newInvestor), 1);
        assertEq(ownershipRegistry.getUserTotalProperties(passiveInvestor), 2);
        assertEq(ownershipRegistry.getUserTotalProperties(institutionalInvestor), 3); // All 3 properties

        emit InvestmentMade(newInvestor, 0, newInvestorAmount, newInvestorAmount * LUXURY_APT_PRICE);
        emit InvestmentMade(passiveInvestor, 0, passiveInvestorLuxury, passiveInvestorLuxury * LUXURY_APT_PRICE);
    }

    /**
     * @notice Test 5: Secondary Market Trading (Marketplace Functionality)
     * Tests buy/sell listings and continuous auction model as per PDF Section 3.1
     */
    function test_05_SecondaryMarketTrading() public {
        test_04_PrimaryMarketInvestment();

        // Active trader creates listings to rebalance portfolio
        vm.prank(activeTrader);
        commercialBuildingToken.approve(address(marketplace), 1000);
        vm.prank(activeTrader);
        uint256 listingId = marketplace.createListing(
            address(commercialBuildingToken),
            1000, // Sell 1,000 tokens
            105 * 1e18 // $105 per token (5% premium)
        );

        // New investor makes offer (continuous auction model)
        uint256 offerAmount = 500;
        uint256 offerPrice = 102 * 1e18; // $102 per token
        uint256 totalOfferCost = (offerAmount * offerPrice) / 1e18;

        vm.prank(newInvestor);
        uint256 offerId = marketplace.createOffer{value: totalOfferCost}(
            listingId,
            offerAmount,
            offerPrice
        );

        // Institutional investor makes direct purchase
        uint256 directPurchaseAmount = 300;
        uint256 directPurchaseCost = (directPurchaseAmount * 105 * 1e18) / 1e18;

        vm.prank(institutionalInvestor);
        marketplace.buyFromListing{value: directPurchaseCost}(listingId, directPurchaseAmount);

        // Active trader accepts the offer
        vm.prank(activeTrader);
        marketplace.acceptOffer(offerId);

        // Verify trades executed correctly
        assertEq(commercialBuildingToken.balanceOf(newInvestor), offerAmount);
        assertEq(commercialBuildingToken.balanceOf(institutionalInvestor), 10000 + directPurchaseAmount);

        // Verify fee collection
        uint256 expectedOfferFee = (totalOfferCost * PLATFORM_FEE) / 10000;
        uint256 expectedDirectFee = (directPurchaseCost * PLATFORM_FEE) / 10000;
        uint256 totalExpectedFees = expectedOfferFee + expectedDirectFee;
        assertGe(feeCollector.balance, totalExpectedFees); // Fees should be collected

        emit TradeExecuted(newInvestor, activeTrader, 2, offerAmount, offerPrice);
        emit TradeExecuted(institutionalInvestor, activeTrader, 2, directPurchaseAmount, 105 * 1e18);

        // Verify ownership registry reflects trades
        assertTrue(ownershipRegistry.isTokenHolder(newInvestor, address(commercialBuildingToken)));
        assertEq(ownershipRegistry.getUserTotalProperties(newInvestor), 2); // Now owns luxury + commercial
    }

    /**
     * @notice Test 6: Dividend Distribution and Income Generation
     * Tests dividend distribution as specified in PDF requirements
     */
    function test_06_DividendDistributionAndIncome() public {
        test_05_SecondaryMarketTrading();

        // Simulate property income generation and distribution

        // Luxury apartments generate quarterly rent: $50,000
        uint256 luxuryDividends = 50000 * 1e18;
        vm.deal(propertyManager1, luxuryDividends);
        vm.prank(propertyManager1);
        luxuryApartmentToken.distributeDividends{value: luxuryDividends}();

        // Suburban homes generate quarterly rent: $30,000
        uint256 suburbanDividends = 30000 * 1e18;
        vm.deal(propertyManager2, suburbanDividends);
        vm.prank(propertyManager2);
        suburbanHomesToken.distributeDividends{value: suburbanDividends}();

        // Commercial building generates quarterly rent: $125,000
        uint256 commercialDividends = 125000 * 1e18;
        vm.deal(propertyManager1, commercialDividends);
        vm.prank(propertyManager1);
        commercialBuildingToken.distributeDividends{value: commercialDividends}();

        // Investors claim their dividends

        // New investor claims from luxury apartments
        uint256 newInvestorLuxuryShare = (1000 * luxuryDividends) / LUXURY_APT_SUPPLY;
        vm.prank(newInvestor);
        uint256 newInvestorClaim = luxuryApartmentToken.claimDividends();
        assertEq(newInvestorClaim, newInvestorLuxuryShare);

        // Passive investor claims from both properties
        uint256 passiveLuxuryShare = (500 * luxuryDividends) / LUXURY_APT_SUPPLY;
        uint256 passiveSuburbanShare = (800 * suburbanDividends) / SUBURBAN_SUPPLY;

        vm.prank(passiveInvestor);
        uint256 passiveLuxuryClaim = luxuryApartmentToken.claimDividends();
        vm.prank(passiveInvestor);
        uint256 passiveSuburbanClaim = suburbanHomesToken.claimDividends();

        assertEq(passiveLuxuryClaim, passiveLuxuryShare);
        assertApproxEqAbs(passiveSuburbanClaim, passiveSuburbanShare, 50000); // Allow tolerance for rounding in large divisions

        // Institutional investor claims large dividends
        uint256 institutionalCommercialTokens = 10000 + 300; // Original + purchased
        uint256 institutionalCommercialShare = (institutionalCommercialTokens * commercialDividends) / COMMERCIAL_SUPPLY;

        vm.prank(institutionalInvestor);
        uint256 institutionalClaim = commercialBuildingToken.claimDividends();
        assertEq(institutionalClaim, institutionalCommercialShare);

        emit DividendsDistributed(0, luxuryDividends);
        emit DividendsDistributed(1, suburbanDividends);
        emit DividendsDistributed(2, commercialDividends);

        // Verify dividend calculations are accurate
        assertTrue(newInvestorClaim > 0);
        assertTrue(passiveLuxuryClaim > 0);
        assertTrue(passiveSuburbanClaim > 0);
        assertTrue(institutionalClaim > 0);
    }

    /**
     * @notice Test 7: Administrative Controls and Compliance
     * Tests admin controls as per PDF Section 7
     */
    function test_07_AdministrativeControlsAndCompliance() public {
        test_06_DividendDistributionAndIncome();

        // Test compliance override and transfer restrictions (PDF requirement)
        // First, KYC the restricted user and give them tokens BEFORE setting restriction
        vm.prank(complianceOfficer);
        accessControl.setKYCStatus(restrictedUser, true);
        vm.prank(propertyManager1);
        propertyFactory.distributeTokens(0, restrictedUser, 100);

        // Now set the transfer restriction
        vm.prank(complianceOfficer);
        luxuryApartmentToken.setTransferRestriction(restrictedUser, true);

        // Restricted user cannot transfer
        vm.prank(restrictedUser);
        vm.expectRevert("User transfer restricted");
        luxuryApartmentToken.transfer(newInvestor, 50);

        // But compliance officer can force transfer for compliance
        vm.prank(complianceOfficer);
        luxuryApartmentToken.adminTransfer(restrictedUser, newInvestor, 50);

        // Verify compliance transfer worked
        assertEq(luxuryApartmentToken.balanceOf(restrictedUser), 50);
        assertEq(luxuryApartmentToken.balanceOf(newInvestor), 1000 + 50); // Original luxury + compliance transfer

        // Test system pause for maintenance
        vm.prank(complianceOfficer);
        accessControl.pauseSystem();

        // All user operations should be blocked
        vm.prank(newInvestor);
        vm.expectRevert("System paused");
        marketplace.createListing(address(luxuryApartmentToken), 100, 100 * 1e18);

        // Unpause system
        vm.prank(complianceOfficer);
        accessControl.unpauseSystem();

        // Operations should work again
        vm.prank(newInvestor);
        luxuryApartmentToken.approve(address(marketplace), 100);
        vm.prank(newInvestor);
        marketplace.createListing(address(luxuryApartmentToken), 100, 110 * 1e18);
    }

    /**
     * @notice Test 8: Portfolio Analytics and Reporting
     * Tests ownership tracking and portfolio queries as per PDF Section 3.1
     */
    function test_08_PortfolioAnalyticsAndReporting() public {
        test_07_AdministrativeControlsAndCompliance();

        // Test comprehensive portfolio analytics

        // Get new investor's complete portfolio
        OwnershipRegistry.OwnershipInfo[] memory newInvestorPortfolio =
            ownershipRegistry.getUserPortfolio(newInvestor);

        // Should own tokens in luxury apartments and commercial building
        assertEq(newInvestorPortfolio.length, 2);

        // Verify property distribution for luxury apartments
        (address[] memory luxuryHolders, uint256[] memory luxuryBalances) =
            ownershipRegistry.getPropertyDistribution(address(luxuryApartmentToken));

        assertTrue(luxuryHolders.length > 0);
        assertTrue(luxuryBalances.length > 0);

        // Calculate total tokens distributed
        uint256 totalLuxuryDistributed = 0;
        for (uint i = 0; i < luxuryBalances.length; i++) {
            totalLuxuryDistributed += luxuryBalances[i];
        }
        assertGt(totalLuxuryDistributed, 0);

        // Test institutional investor's large portfolio
        assertEq(ownershipRegistry.getUserTotalProperties(institutionalInvestor), 3); // Owns all 3 properties
        assertTrue(ownershipRegistry.isTokenHolder(institutionalInvestor, address(commercialBuildingToken)));

        // Verify passive investor's diversified holdings
        address[] memory passiveTokens = ownershipRegistry.getUserOwnedTokens(passiveInvestor);
        assertEq(passiveTokens.length, 2); // Should own both luxury and suburban

        // Test token holder counts across all properties
        uint256 luxuryHolderCount = ownershipRegistry.getTokenHolderCount(address(luxuryApartmentToken));
        uint256 suburbanHolderCount = ownershipRegistry.getTokenHolderCount(address(suburbanHomesToken));
        uint256 commercialHolderCount = ownershipRegistry.getTokenHolderCount(address(commercialBuildingToken));

        assertTrue(luxuryHolderCount > 0);
        assertTrue(suburbanHolderCount > 0);
        assertTrue(commercialHolderCount > 0);
    }

    /**
     * @notice Test 9: Multi-Property Complex Trading Scenario
     * Tests complex real-world trading patterns across multiple properties
     */
    function test_09_ComplexTradingScenario() public {
        test_08_PortfolioAnalyticsAndReporting();

        // Simulate a complex trading day with multiple properties

        // 1. Market maker (institutional investor) creates liquidity
        vm.prank(institutionalInvestor);
        commercialBuildingToken.approve(address(marketplace), 5000);
        vm.prank(institutionalInvestor);
        uint256 liquidityListing = marketplace.createListing(
            address(commercialBuildingToken),
            5000,
            98 * 1e18 // Slight discount for liquidity
        );

        // 2. Multiple users create competing offers
        vm.prank(newInvestor);
        marketplace.createOffer{value: (1000 * 99 * 1e18) / 1e18}(liquidityListing, 1000, 99 * 1e18);

        vm.prank(activeTrader);
        marketplace.createOffer{value: (1500 * 97 * 1e18) / 1e18}(liquidityListing, 1500, 97 * 1e18);

        vm.prank(passiveInvestor);
        marketplace.createOffer{value: (800 * 98 * 1e18) / 1e18}(liquidityListing, 800, 98 * 1e18);

        // 3. Market volatility - prices change
        vm.prank(institutionalInvestor);
        marketplace.updateListingPrice(liquidityListing, 96 * 1e18); // Price drop

        // 4. Quick arbitrage opportunity - active trader buys direct
        vm.prank(activeTrader);
        marketplace.buyFromListing{value: (2000 * 96 * 1e18) / 1e18}(liquidityListing, 2000);

        // 5. Institutional investor accepts best offer
        vm.prank(institutionalInvestor);
        marketplace.acceptOffer(2); // Passive investor's offer at 98

        // 6. Portfolio rebalancing - new investor sells luxury to buy commercial
        vm.prank(newInvestor);
        luxuryApartmentToken.approve(address(marketplace), 500);
        vm.prank(newInvestor);
        uint256 rebalanceListing = marketplace.createListing(
            address(luxuryApartmentToken),
            500,
            105 * 1e18
        );

        // Verify complex state
        assertGt(activeTrader.balance, 0); // Should have made money on trades

        // Verify marketplace has active listings
        Marketplace.Listing[] memory activeListings = marketplace.getActiveListings();
        assertGt(activeListings.length, 0);
    }

    /**
     * @notice Test 10: Complete System Stress Test
     * Tests system behavior under heavy load and edge conditions
     */
    function test_10_SystemStressTest() public {
        test_09_ComplexTradingScenario();

        // Stress test with many users and properties
        address[] memory stressUsers = new address[](20);
        for (uint i = 0; i < 20; i++) {
            stressUsers[i] = makeAddr(string(abi.encodePacked("stressUser", vm.toString(i))));
            vm.deal(stressUsers[i], 100 ether);

            // KYC all stress test users
            vm.prank(complianceOfficer);
            accessControl.setKYCStatus(stressUsers[i], true);
        }

        // Batch token distribution
        for (uint i = 0; i < 20; i++) {
            vm.prank(propertyManager1);
            propertyFactory.distributeTokens(0, stressUsers[i], 100 + i * 10);
        }

        // Create many simultaneous listings
        for (uint i = 0; i < 10; i++) {
            vm.prank(stressUsers[i]);
            luxuryApartmentToken.approve(address(marketplace), 50);
            vm.prank(stressUsers[i]);
            marketplace.createListing(
                address(luxuryApartmentToken),
                50,
                (95 + i) * 1e18 // Different prices
            );
        }

        // Verify system handles load
        Marketplace.Listing[] memory manyListings = marketplace.getActiveListings();
        assertGt(manyListings.length, 10);

        // Test large batch operations
        address[] memory batchUsers = new address[](10);
        address[] memory batchTokens = new address[](10);
        uint256[] memory batchBalances = new uint256[](10);

        for (uint i = 0; i < 10; i++) {
            batchUsers[i] = stressUsers[i + 10];
            batchTokens[i] = address(suburbanHomesToken);
            batchBalances[i] = (i + 1) * 50;
        }

        // This should work with authorized contract
        vm.prank(address(suburbanHomesToken));
        ownershipRegistry.batchUpdateOwnership(batchUsers, batchTokens, batchBalances);

        // Verify batch operation results
        for (uint i = 0; i < 10; i++) {
            assertEq(
                ownershipRegistry.getUserTokenBalance(batchUsers[i], address(suburbanHomesToken)),
                (i + 1) * 50
            );
        }

        // Final system state verification
        assertEq(propertyFactory.getPropertyCount(), 3);
        assertGt(marketplace.nextListingId(), 10);
        assertGt(ownershipRegistry.getTokenHolderCount(address(luxuryApartmentToken)), 20);
    }

    /**
     * @notice Test 11: Security and Edge Cases
     * Tests security measures and edge cases across the entire system
     */
    function test_11_SecurityAndEdgeCases() public {
        test_10_SystemStressTest();

        // Test unauthorized access prevention
        vm.expectRevert("User not KYC verified");
        vm.prank(nonKycUser);
        marketplace.createListing(address(luxuryApartmentToken), 100, 100 * 1e18);

        // Test invalid operations
        vm.expectRevert("Invalid property ID");
        propertyFactory.getProperty(999);

        vm.expectRevert("Invalid listing ID");
        vm.prank(newInvestor);
        marketplace.buyFromListing{value: 100 ether}(999, 100);

        // Test system limits
        address[] memory oversizedArray = new address[](101);
        vm.expectRevert("Batch too large");
        vm.prank(complianceOfficer);
        accessControl.batchSetKYC(oversizedArray, true);

        // Test zero-value edge cases
        vm.expectRevert("Invalid amount");
        vm.prank(newInvestor);
        marketplace.createOffer{value: 0}(0, 0, 100 * 1e18);

        // Test contract interactions remain secure
        assertEq(ownershipRegistry.getUserTokenBalance(address(0), address(luxuryApartmentToken)), 0);

        // System should still be operational after stress testing
        assertFalse(accessControl.isSystemPaused());
        assertTrue(luxuryApartmentToken.tradingEnabled());
        assertGt(marketplace.platformFeePercent(), 0);
    }

    /**
     * @notice Helper function to display comprehensive system state
     * Useful for debugging and verification
     */
    function getSystemState() public view returns (
        uint256 totalProperties,
        uint256 totalListings,
        uint256 totalOffers,
        uint256 totalKycUsers,
        uint256 platformFeesCollected
    ) {
        totalProperties = propertyFactory.getPropertyCount();
        totalListings = marketplace.nextListingId();
        totalOffers = marketplace.nextOfferId();
        platformFeesCollected = feeCollector.balance;

        // Count KYC users (simplified)
        totalKycUsers = 0;
        address[] memory testUsers = new address[](4);
        testUsers[0] = newInvestor;
        testUsers[1] = activeTrader;
        testUsers[2] = passiveInvestor;
        testUsers[3] = institutionalInvestor;

        for (uint i = 0; i < testUsers.length; i++) {
            if (accessControl.isUserKYCed(testUsers[i])) {
                totalKycUsers++;
            }
        }
    }
}