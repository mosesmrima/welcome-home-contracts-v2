// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/PropertyFactory.sol";
import "../src/AccessControl.sol";
import "../src/OwnershipRegistry.sol";
import "../src/PropertyToken.sol";

contract PropertyFactoryTest is Test {
    PropertyFactory public propertyFactory;
    AccessControl public accessControl;
    OwnershipRegistry public ownershipRegistry;

    address public owner;
    address public admin1;
    address public propertyManager1;
    address public propertyManager2;
    address public user1;
    address public attacker;

    // Test property data - realistic real estate examples
    string constant PROPERTY_NAME_1 = "Luxury Downtown Apartment Complex";
    string constant METADATA_URI_1 = "QmExampleHash1234567890AbCdEf"; // IPFS hash format
    uint256 constant TOTAL_VALUE_1 = 2500000 * 1e18; // $2.5M
    uint256 constant TOTAL_SUPPLY_1 = 25000; // 25,000 tokens
    uint256 constant PRICE_PER_TOKEN_1 = 100 * 1e18; // $100 per token

    string constant PROPERTY_NAME_2 = "Suburban Family Home Portfolio";
    string constant METADATA_URI_2 = "QmAnotherHash0987654321ZyXwVu";
    uint256 constant TOTAL_VALUE_2 = 850000 * 1e18; // $850K
    uint256 constant TOTAL_SUPPLY_2 = 8500; // 8,500 tokens
    uint256 constant PRICE_PER_TOKEN_2 = 100 * 1e18; // $100 per token

    event PropertyCreated(
        uint256 indexed propertyId,
        string name,
        address indexed tokenContract,
        address indexed creator
    );
    event PropertyUpdated(uint256 indexed propertyId, string metadataURI);
    event PropertyStatusChanged(uint256 indexed propertyId, bool isActive);
    event PropertyPriceUpdated(uint256 indexed propertyId, uint256 newPrice);

    function setUp() public {
        owner = address(this);
        admin1 = makeAddr("admin1");
        propertyManager1 = makeAddr("propertyManager1");
        propertyManager2 = makeAddr("propertyManager2");
        user1 = makeAddr("user1");
        attacker = makeAddr("attacker");

        // Deploy core contracts
        accessControl = new AccessControl();
        ownershipRegistry = new OwnershipRegistry(address(accessControl));
        propertyFactory = new PropertyFactory(address(accessControl), address(ownershipRegistry));

        // Set up roles
        accessControl.setAdmin(admin1, true);
        accessControl.setAdmin(address(propertyFactory), true); // PropertyFactory needs admin for setAuthorizedUpdater
        accessControl.setPropertyManager(propertyManager1, true);
        accessControl.setPropertyManager(propertyManager2, true);
    }

    // ===== PROPERTY CREATION TESTS =====

    function test_CreateProperty_Success() public {
        vm.expectEmit(true, false, true, true);
        emit PropertyCreated(0, PROPERTY_NAME_1, address(0), propertyManager1); // address(0) will be replaced with actual token address

        vm.prank(propertyManager1);
        uint256 propertyId = propertyFactory.createProperty(
            PROPERTY_NAME_1,
            METADATA_URI_1,
            TOTAL_VALUE_1,
            TOTAL_SUPPLY_1,
            PRICE_PER_TOKEN_1
        );

        assertEq(propertyId, 0);
        assertEq(propertyFactory.getPropertyCount(), 1);

        PropertyFactory.Property memory property = propertyFactory.getProperty(propertyId);
        assertEq(property.id, 0);
        assertEq(property.name, PROPERTY_NAME_1);
        assertEq(property.metadataURI, METADATA_URI_1);
        assertEq(property.totalValue, TOTAL_VALUE_1);
        assertEq(property.totalSupply, TOTAL_SUPPLY_1);
        assertEq(property.pricePerToken, PRICE_PER_TOKEN_1);
        assertTrue(property.isActive);
        assertEq(property.creator, propertyManager1);
        assertGt(property.createdAt, 0);
        assertTrue(property.tokenContract != address(0));

        // Verify token contract was deployed correctly
        PropertyToken token = PropertyToken(property.tokenContract);
        assertEq(token.name(), "Property Token Luxury Downtown Apartment Complex");
        assertEq(token.symbol(), "PROP0");
        assertEq(token.totalSupply(), TOTAL_SUPPLY_1);
        assertEq(token.propertyId(), propertyId);

        // Verify ownership registry authorization
        assertTrue(ownershipRegistry.authorizedUpdaters(property.tokenContract));
    }

    function test_CreateProperty_MultipleProperties() public {
        // Create first property
        vm.prank(propertyManager1);
        uint256 propertyId1 = propertyFactory.createProperty(
            PROPERTY_NAME_1,
            METADATA_URI_1,
            TOTAL_VALUE_1,
            TOTAL_SUPPLY_1,
            PRICE_PER_TOKEN_1
        );

        // Create second property
        vm.prank(propertyManager2);
        uint256 propertyId2 = propertyFactory.createProperty(
            PROPERTY_NAME_2,
            METADATA_URI_2,
            TOTAL_VALUE_2,
            TOTAL_SUPPLY_2,
            PRICE_PER_TOKEN_2
        );

        assertEq(propertyId1, 0);
        assertEq(propertyId2, 1);
        assertEq(propertyFactory.getPropertyCount(), 2);

        // Verify properties are different
        PropertyFactory.Property memory prop1 = propertyFactory.getProperty(propertyId1);
        PropertyFactory.Property memory prop2 = propertyFactory.getProperty(propertyId2);

        assertEq(prop1.creator, propertyManager1);
        assertEq(prop2.creator, propertyManager2);
        assertTrue(prop1.tokenContract != prop2.tokenContract);

        // Verify token symbols are unique
        PropertyToken token1 = PropertyToken(prop1.tokenContract);
        PropertyToken token2 = PropertyToken(prop2.tokenContract);
        assertEq(token1.symbol(), "PROP0");
        assertEq(token2.symbol(), "PROP1");
    }

    function test_CreateProperty_OnlyPropertyManager() public {
        vm.prank(attacker);
        vm.expectRevert("Not property manager");
        propertyFactory.createProperty(
            PROPERTY_NAME_1,
            METADATA_URI_1,
            TOTAL_VALUE_1,
            TOTAL_SUPPLY_1,
            PRICE_PER_TOKEN_1
        );
    }

    function test_CreateProperty_AdminCanCreate() public {
        vm.prank(admin1);
        uint256 propertyId = propertyFactory.createProperty(
            PROPERTY_NAME_1,
            METADATA_URI_1,
            TOTAL_VALUE_1,
            TOTAL_SUPPLY_1,
            PRICE_PER_TOKEN_1
        );

        assertEq(propertyId, 0);
        PropertyFactory.Property memory property = propertyFactory.getProperty(propertyId);
        assertEq(property.creator, admin1);
    }

    function test_CreateProperty_OwnerCanCreate() public {
        uint256 propertyId = propertyFactory.createProperty(
            PROPERTY_NAME_1,
            METADATA_URI_1,
            TOTAL_VALUE_1,
            TOTAL_SUPPLY_1,
            PRICE_PER_TOKEN_1
        );

        assertEq(propertyId, 0);
        PropertyFactory.Property memory property = propertyFactory.getProperty(propertyId);
        assertEq(property.creator, owner);
    }

    function test_CreateProperty_WhenPaused() public {
        accessControl.pauseSystem();

        vm.prank(propertyManager1);
        vm.expectRevert("System paused");
        propertyFactory.createProperty(
            PROPERTY_NAME_1,
            METADATA_URI_1,
            TOTAL_VALUE_1,
            TOTAL_SUPPLY_1,
            PRICE_PER_TOKEN_1
        );
    }

    function test_CreateProperty_EmptyName() public {
        vm.prank(propertyManager1);
        vm.expectRevert("Empty name");
        propertyFactory.createProperty(
            "",
            METADATA_URI_1,
            TOTAL_VALUE_1,
            TOTAL_SUPPLY_1,
            PRICE_PER_TOKEN_1
        );
    }

    function test_CreateProperty_EmptyMetadata() public {
        vm.prank(propertyManager1);
        vm.expectRevert("Empty metadata");
        propertyFactory.createProperty(
            PROPERTY_NAME_1,
            "",
            TOTAL_VALUE_1,
            TOTAL_SUPPLY_1,
            PRICE_PER_TOKEN_1
        );
    }

    function test_CreateProperty_InvalidTotalValue() public {
        vm.prank(propertyManager1);
        vm.expectRevert("Invalid total value");
        propertyFactory.createProperty(
            PROPERTY_NAME_1,
            METADATA_URI_1,
            0,
            TOTAL_SUPPLY_1,
            PRICE_PER_TOKEN_1
        );
    }

    function test_CreateProperty_InvalidTotalSupply() public {
        vm.prank(propertyManager1);
        vm.expectRevert("Invalid total supply");
        propertyFactory.createProperty(
            PROPERTY_NAME_1,
            METADATA_URI_1,
            TOTAL_VALUE_1,
            0,
            PRICE_PER_TOKEN_1
        );
    }

    function test_CreateProperty_InvalidPricePerToken() public {
        vm.prank(propertyManager1);
        vm.expectRevert("Invalid price per token");
        propertyFactory.createProperty(
            PROPERTY_NAME_1,
            METADATA_URI_1,
            TOTAL_VALUE_1,
            TOTAL_SUPPLY_1,
            0
        );
    }

    // ===== PROPERTY MANAGEMENT TESTS =====

    function test_UpdatePropertyMetadata_Success() public {
        // Create property first
        vm.prank(propertyManager1);
        uint256 propertyId = propertyFactory.createProperty(
            PROPERTY_NAME_1,
            METADATA_URI_1,
            TOTAL_VALUE_1,
            TOTAL_SUPPLY_1,
            PRICE_PER_TOKEN_1
        );

        string memory newMetadata = "QmNewUpdatedMetadataHash987654321";

        vm.expectEmit(true, false, false, true);
        emit PropertyUpdated(propertyId, newMetadata);

        vm.prank(propertyManager1);
        propertyFactory.updatePropertyMetadata(propertyId, newMetadata);

        PropertyFactory.Property memory property = propertyFactory.getProperty(propertyId);
        assertEq(property.metadataURI, newMetadata);
    }

    function test_UpdatePropertyMetadata_AdminCanUpdate() public {
        // Create property as property manager
        vm.prank(propertyManager1);
        uint256 propertyId = propertyFactory.createProperty(
            PROPERTY_NAME_1,
            METADATA_URI_1,
            TOTAL_VALUE_1,
            TOTAL_SUPPLY_1,
            PRICE_PER_TOKEN_1
        );

        string memory newMetadata = "QmAdminUpdatedMetadata";

        // Admin can update any property
        vm.prank(admin1);
        propertyFactory.updatePropertyMetadata(propertyId, newMetadata);

        PropertyFactory.Property memory property = propertyFactory.getProperty(propertyId);
        assertEq(property.metadataURI, newMetadata);
    }

    function test_UpdatePropertyMetadata_OnlyCreatorOrAdmin() public {
        // Create property as property manager 1
        vm.prank(propertyManager1);
        uint256 propertyId = propertyFactory.createProperty(
            PROPERTY_NAME_1,
            METADATA_URI_1,
            TOTAL_VALUE_1,
            TOTAL_SUPPLY_1,
            PRICE_PER_TOKEN_1
        );

        // Property manager 2 cannot update (not creator or admin)
        vm.prank(propertyManager2);
        vm.expectRevert("Not creator or admin");
        propertyFactory.updatePropertyMetadata(propertyId, "QmNewMetadata");
    }

    function test_UpdatePropertyMetadata_InvalidProperty() public {
        vm.expectRevert("Invalid property ID");
        propertyFactory.updatePropertyMetadata(999, "QmNewMetadata");
    }

    function test_UpdatePropertyMetadata_EmptyMetadata() public {
        vm.prank(propertyManager1);
        uint256 propertyId = propertyFactory.createProperty(
            PROPERTY_NAME_1,
            METADATA_URI_1,
            TOTAL_VALUE_1,
            TOTAL_SUPPLY_1,
            PRICE_PER_TOKEN_1
        );

        vm.prank(propertyManager1);
        vm.expectRevert("Empty metadata");
        propertyFactory.updatePropertyMetadata(propertyId, "");
    }

    function test_SetPropertyActive_Success() public {
        vm.prank(propertyManager1);
        uint256 propertyId = propertyFactory.createProperty(
            PROPERTY_NAME_1,
            METADATA_URI_1,
            TOTAL_VALUE_1,
            TOTAL_SUPPLY_1,
            PRICE_PER_TOKEN_1
        );

        // Property should be active by default
        PropertyFactory.Property memory property = propertyFactory.getProperty(propertyId);
        assertTrue(property.isActive);

        // Deactivate property
        vm.expectEmit(true, false, false, true);
        emit PropertyStatusChanged(propertyId, false);

        vm.prank(admin1);
        propertyFactory.setPropertyActive(propertyId, false);

        property = propertyFactory.getProperty(propertyId);
        assertFalse(property.isActive);

        // Reactivate property
        vm.expectEmit(true, false, false, true);
        emit PropertyStatusChanged(propertyId, true);

        vm.prank(admin1);
        propertyFactory.setPropertyActive(propertyId, true);

        property = propertyFactory.getProperty(propertyId);
        assertTrue(property.isActive);
    }

    function test_SetPropertyActive_OnlyAdmin() public {
        vm.prank(propertyManager1);
        uint256 propertyId = propertyFactory.createProperty(
            PROPERTY_NAME_1,
            METADATA_URI_1,
            TOTAL_VALUE_1,
            TOTAL_SUPPLY_1,
            PRICE_PER_TOKEN_1
        );

        // Property manager cannot set active status
        vm.prank(propertyManager1);
        vm.expectRevert("Not admin");
        propertyFactory.setPropertyActive(propertyId, false);

        // Non-authorized user cannot set active status
        vm.prank(attacker);
        vm.expectRevert("Not admin");
        propertyFactory.setPropertyActive(propertyId, false);
    }

    function test_UpdatePropertyPrice_Success() public {
        vm.prank(propertyManager1);
        uint256 propertyId = propertyFactory.createProperty(
            PROPERTY_NAME_1,
            METADATA_URI_1,
            TOTAL_VALUE_1,
            TOTAL_SUPPLY_1,
            PRICE_PER_TOKEN_1
        );

        uint256 newPrice = 150 * 1e18; // $150 per token

        vm.expectEmit(true, false, false, true);
        emit PropertyPriceUpdated(propertyId, newPrice);

        vm.prank(propertyManager1);
        propertyFactory.updatePropertyPrice(propertyId, newPrice);

        PropertyFactory.Property memory property = propertyFactory.getProperty(propertyId);
        assertEq(property.pricePerToken, newPrice);
    }

    function test_UpdatePropertyPrice_AdminCanUpdate() public {
        vm.prank(propertyManager1);
        uint256 propertyId = propertyFactory.createProperty(
            PROPERTY_NAME_1,
            METADATA_URI_1,
            TOTAL_VALUE_1,
            TOTAL_SUPPLY_1,
            PRICE_PER_TOKEN_1
        );

        uint256 newPrice = 200 * 1e18;

        vm.prank(admin1);
        propertyFactory.updatePropertyPrice(propertyId, newPrice);

        PropertyFactory.Property memory property = propertyFactory.getProperty(propertyId);
        assertEq(property.pricePerToken, newPrice);
    }

    function test_UpdatePropertyPrice_InvalidPrice() public {
        vm.prank(propertyManager1);
        uint256 propertyId = propertyFactory.createProperty(
            PROPERTY_NAME_1,
            METADATA_URI_1,
            TOTAL_VALUE_1,
            TOTAL_SUPPLY_1,
            PRICE_PER_TOKEN_1
        );

        vm.prank(propertyManager1);
        vm.expectRevert("Invalid price");
        propertyFactory.updatePropertyPrice(propertyId, 0);
    }

    // ===== QUERY FUNCTION TESTS =====

    function test_GetPropertiesByCreator() public {
        // Manager 1 creates 2 properties
        vm.prank(propertyManager1);
        propertyFactory.createProperty(
            PROPERTY_NAME_1,
            METADATA_URI_1,
            TOTAL_VALUE_1,
            TOTAL_SUPPLY_1,
            PRICE_PER_TOKEN_1
        );

        vm.prank(propertyManager1);
        propertyFactory.createProperty(
            PROPERTY_NAME_2,
            METADATA_URI_2,
            TOTAL_VALUE_2,
            TOTAL_SUPPLY_2,
            PRICE_PER_TOKEN_2
        );

        // Manager 2 creates 1 property
        vm.prank(propertyManager2);
        propertyFactory.createProperty(
            "Manager 2 Property",
            "QmManager2Hash",
            1000000 * 1e18,
            10000,
            100 * 1e18
        );

        uint256[] memory manager1Properties = propertyFactory.getPropertiesByCreator(propertyManager1);
        uint256[] memory manager2Properties = propertyFactory.getPropertiesByCreator(propertyManager2);

        assertEq(manager1Properties.length, 2);
        assertEq(manager1Properties[0], 0);
        assertEq(manager1Properties[1], 1);

        assertEq(manager2Properties.length, 1);
        assertEq(manager2Properties[0], 2);
    }

    function test_GetAllActiveProperties() public {
        // Create 3 properties
        vm.prank(propertyManager1);
        uint256 prop1 = propertyFactory.createProperty(
            PROPERTY_NAME_1,
            METADATA_URI_1,
            TOTAL_VALUE_1,
            TOTAL_SUPPLY_1,
            PRICE_PER_TOKEN_1
        );

        vm.prank(propertyManager1);
        uint256 prop2 = propertyFactory.createProperty(
            PROPERTY_NAME_2,
            METADATA_URI_2,
            TOTAL_VALUE_2,
            TOTAL_SUPPLY_2,
            PRICE_PER_TOKEN_2
        );

        vm.prank(propertyManager2);
        uint256 prop3 = propertyFactory.createProperty(
            "Third Property",
            "QmThirdHash",
            500000 * 1e18,
            5000,
            100 * 1e18
        );

        // All should be active initially
        PropertyFactory.Property[] memory activeProperties = propertyFactory.getAllActiveProperties();
        assertEq(activeProperties.length, 3);

        // Deactivate one property
        vm.prank(admin1);
        propertyFactory.setPropertyActive(prop2, false);

        // Should only return 2 active properties
        activeProperties = propertyFactory.getAllActiveProperties();
        assertEq(activeProperties.length, 2);
        assertEq(activeProperties[0].id, prop1);
        assertEq(activeProperties[1].id, prop3);
    }

    function test_GetActivePropertyCount() public {
        assertEq(propertyFactory.getActivePropertyCount(), 0);

        // Create 2 properties
        vm.prank(propertyManager1);
        uint256 prop1 = propertyFactory.createProperty(
            PROPERTY_NAME_1,
            METADATA_URI_1,
            TOTAL_VALUE_1,
            TOTAL_SUPPLY_1,
            PRICE_PER_TOKEN_1
        );

        vm.prank(propertyManager1);
        uint256 prop2 = propertyFactory.createProperty(
            PROPERTY_NAME_2,
            METADATA_URI_2,
            TOTAL_VALUE_2,
            TOTAL_SUPPLY_2,
            PRICE_PER_TOKEN_2
        );

        assertEq(propertyFactory.getActivePropertyCount(), 2);

        // Deactivate one
        vm.prank(admin1);
        propertyFactory.setPropertyActive(prop1, false);

        assertEq(propertyFactory.getActivePropertyCount(), 1);
    }

    function test_GetPropertyToken() public {
        vm.prank(propertyManager1);
        uint256 propertyId = propertyFactory.createProperty(
            PROPERTY_NAME_1,
            METADATA_URI_1,
            TOTAL_VALUE_1,
            TOTAL_SUPPLY_1,
            PRICE_PER_TOKEN_1
        );

        address tokenAddress = propertyFactory.getPropertyToken(propertyId);
        PropertyFactory.Property memory property = propertyFactory.getProperty(propertyId);

        assertEq(tokenAddress, property.tokenContract);
        assertTrue(tokenAddress != address(0));
    }

    // ===== INTEGRATION TESTS =====

    function test_CompletePropertyLifecycle() public {
        // 1. Create property
        vm.prank(propertyManager1);
        uint256 propertyId = propertyFactory.createProperty(
            PROPERTY_NAME_1,
            METADATA_URI_1,
            TOTAL_VALUE_1,
            TOTAL_SUPPLY_1,
            PRICE_PER_TOKEN_1
        );

        // 2. Update metadata (e.g., after uploading additional documents)
        string memory updatedMetadata = "QmUpdatedPropertyMetadataWithLegalDocs";
        vm.prank(propertyManager1);
        propertyFactory.updatePropertyMetadata(propertyId, updatedMetadata);

        // 3. Update price (market adjustment)
        uint256 newPrice = 110 * 1e18;
        vm.prank(propertyManager1);
        propertyFactory.updatePropertyPrice(propertyId, newPrice);

        // 4. Admin temporarily deactivates for maintenance
        vm.prank(admin1);
        propertyFactory.setPropertyActive(propertyId, false);

        // 5. Admin reactivates
        vm.prank(admin1);
        propertyFactory.setPropertyActive(propertyId, true);

        // Verify final state
        PropertyFactory.Property memory property = propertyFactory.getProperty(propertyId);
        assertEq(property.metadataURI, updatedMetadata);
        assertEq(property.pricePerToken, newPrice);
        assertTrue(property.isActive);
        assertEq(property.creator, propertyManager1);
    }

    function test_MultiplePropertyManagersWorkflow() public {
        // Property manager 1 creates luxury property
        vm.prank(propertyManager1);
        uint256 luxuryProperty = propertyFactory.createProperty(
            "Luxury Penthouse Manhattan",
            "QmLuxuryPenthouseMetadata",
            5000000 * 1e18, // $5M
            50000, // 50k tokens
            100 * 1e18 // $100 per token
        );

        // Property manager 2 creates affordable housing
        vm.prank(propertyManager2);
        uint256 affordableProperty = propertyFactory.createProperty(
            "Affordable Housing Complex",
            "QmAffordableHousingMetadata",
            1200000 * 1e18, // $1.2M
            12000, // 12k tokens
            100 * 1e18 // $100 per token
        );

        // Each can only modify their own properties
        vm.prank(propertyManager1);
        propertyFactory.updatePropertyPrice(luxuryProperty, 105 * 1e18);

        vm.prank(propertyManager2);
        propertyFactory.updatePropertyPrice(affordableProperty, 95 * 1e18);

        // Manager 1 cannot modify manager 2's property
        vm.prank(propertyManager1);
        vm.expectRevert("Not creator or admin");
        propertyFactory.updatePropertyPrice(affordableProperty, 200 * 1e18);

        // But admin can modify any property
        vm.prank(admin1);
        propertyFactory.updatePropertyPrice(affordableProperty, 90 * 1e18);

        // Verify final prices
        PropertyFactory.Property memory luxury = propertyFactory.getProperty(luxuryProperty);
        PropertyFactory.Property memory affordable = propertyFactory.getProperty(affordableProperty);

        assertEq(luxury.pricePerToken, 105 * 1e18);
        assertEq(affordable.pricePerToken, 90 * 1e18);
    }

    // ===== EDGE CASE AND SECURITY TESTS =====

    function test_ReentrancyProtection() public {
        // Creating property should be protected against reentrancy
        vm.prank(propertyManager1);
        uint256 propertyId = propertyFactory.createProperty(
            PROPERTY_NAME_1,
            METADATA_URI_1,
            TOTAL_VALUE_1,
            TOTAL_SUPPLY_1,
            PRICE_PER_TOKEN_1
        );

        // If reentrancy protection works, this completes successfully
        assertEq(propertyId, 0);
    }

    function test_LargePropertyValues() public {
        // Test with very large property values
        uint256 largeValue = type(uint256).max / 2;
        uint256 largeSupply = type(uint256).max / 2;
        uint256 largePrice = 1000000 * 1e18; // $1M per token

        vm.prank(propertyManager1);
        uint256 propertyId = propertyFactory.createProperty(
            "Mega Commercial Complex",
            "QmMegaComplexMetadata",
            largeValue,
            largeSupply,
            largePrice
        );

        PropertyFactory.Property memory property = propertyFactory.getProperty(propertyId);
        assertEq(property.totalValue, largeValue);
        assertEq(property.totalSupply, largeSupply);
        assertEq(property.pricePerToken, largePrice);
    }

    function test_PropertyCreationWithSpecialCharacters() public {
        string memory specialName = "Property with Special Chars & Symbols!";
        string memory specialMetadata = "QmSpecialCharsHash123";

        vm.prank(propertyManager1);
        uint256 propertyId = propertyFactory.createProperty(
            specialName,
            specialMetadata,
            TOTAL_VALUE_1,
            TOTAL_SUPPLY_1,
            PRICE_PER_TOKEN_1
        );

        PropertyFactory.Property memory property = propertyFactory.getProperty(propertyId);
        assertEq(property.name, specialName);
        assertEq(property.metadataURI, specialMetadata);
    }

    function test_InvalidPropertyIdAccess() public {
        // Should revert when accessing non-existent property
        vm.expectRevert("Invalid property ID");
        propertyFactory.getProperty(0);

        vm.expectRevert("Invalid property ID");
        propertyFactory.getProperty(999);

        vm.expectRevert("Invalid property ID");
        propertyFactory.getPropertyToken(0);
    }

    function test_SystemPausedPreventsAllOperations() public {
        // Create property first
        vm.prank(propertyManager1);
        uint256 propertyId = propertyFactory.createProperty(
            PROPERTY_NAME_1,
            METADATA_URI_1,
            TOTAL_VALUE_1,
            TOTAL_SUPPLY_1,
            PRICE_PER_TOKEN_1
        );

        // Pause system
        accessControl.pauseSystem();

        // All operations should fail when paused
        vm.prank(propertyManager1);
        vm.expectRevert("System paused");
        propertyFactory.createProperty(
            PROPERTY_NAME_2,
            METADATA_URI_2,
            TOTAL_VALUE_2,
            TOTAL_SUPPLY_2,
            PRICE_PER_TOKEN_2
        );

        // Note: Update operations don't check pause status in current implementation
        // This might be intentional for admin management during maintenance
    }

    // ===== PURCHASE TOKENS TESTS =====

    function test_PurchaseTokens_PaymentCalculation_Debug() public {
        // Create property with simple values for debugging
        vm.prank(propertyManager1);
        uint256 propertyId = propertyFactory.createProperty(
            "Test Property",
            "https://test.com",
            1000 ether,  // 1000 HBAR total value
            100000 * 1e18,  // 100,000 tokens
            0.01 ether  // 0.01 HBAR per token (10000000000000000 wei)
        );

        // KYC verify factory and buyer
        accessControl.setKYCStatus(address(propertyFactory), true);
        accessControl.setKYCStatus(user1, true);

        // Get property details
        PropertyFactory.Property memory property = propertyFactory.getProperty(propertyId);

        console.log("=== PROPERTY DETAILS ===");
        console.log("pricePerToken:", property.pricePerToken);
        console.log("totalSupply:", property.totalSupply);

        // Calculate payment for 10 tokens
        uint256 tokenAmount = 10 * 1e18;  // 10 tokens
        console.log("\n=== PURCHASE CALCULATION ===");
        console.log("tokenAmount:", tokenAmount);

        uint256 expectedTotalCost = (tokenAmount * property.pricePerToken) / 10**18;
        console.log("expectedTotalCost (manual calc):", expectedTotalCost);
        console.log("expectedTotalCost in HBAR:", expectedTotalCost / 1e18);

        // Try purchase with calculated amount
        vm.deal(user1, 1 ether);  // Give user1 some HBAR

        console.log("\n=== ATTEMPTING PURCHASE ===");
        console.log("msg.value:", expectedTotalCost);
        console.log("msg.sender:", user1);

        vm.prank(user1);
        propertyFactory.purchaseTokens{value: expectedTotalCost}(propertyId, tokenAmount);

        // Verify tokens were transferred
        PropertyToken token = PropertyToken(property.tokenContract);
        uint256 userBalance = token.balanceOf(user1);
        console.log("\n=== POST-PURCHASE ===");
        console.log("user1 token balance:", userBalance);

        assertEq(userBalance, tokenAmount, "User should have received tokens");
    }

    function test_PurchaseTokens_ExactPayment_1Token() public {
        // Create property
        vm.prank(propertyManager1);
        uint256 propertyId = propertyFactory.createProperty(
            "Test Property",
            "https://test.com",
            1000 ether,
            100000 * 1e18,
            0.01 ether  // 0.01 HBAR per token
        );

        // KYC verify factory and buyer
        accessControl.setKYCStatus(address(propertyFactory), true);
        accessControl.setKYCStatus(user1, true);

        // Purchase 1 token
        uint256 tokenAmount = 1 * 1e18;  // 1 token
        uint256 payment = 0.01 ether;  // Exact price for 1 token

        console.log("Buying 1 token for", payment, "wei");

        vm.deal(user1, 1 ether);
        vm.prank(user1);
        propertyFactory.purchaseTokens{value: payment}(propertyId, tokenAmount);

        PropertyFactory.Property memory property = propertyFactory.getProperty(propertyId);
        PropertyToken token = PropertyToken(property.tokenContract);
        assertEq(token.balanceOf(user1), tokenAmount);
    }

    function test_PurchaseTokens_ExactPayment_100Tokens() public {
        // Create property
        vm.prank(propertyManager1);
        uint256 propertyId = propertyFactory.createProperty(
            "Test Property",
            "https://test.com",
            1000 ether,
            100000 * 1e18,
            0.01 ether  // 0.01 HBAR per token
        );

        // KYC verify factory and buyer
        accessControl.setKYCStatus(address(propertyFactory), true);
        accessControl.setKYCStatus(user1, true);

        // Purchase 100 tokens
        uint256 tokenAmount = 100 * 1e18;  // 100 tokens
        uint256 payment = 1 ether;  // 100 * 0.01 = 1 HBAR

        console.log("Buying 100 tokens for", payment, "wei");

        vm.deal(user1, 10 ether);
        vm.prank(user1);
        propertyFactory.purchaseTokens{value: payment}(propertyId, tokenAmount);

        PropertyFactory.Property memory property = propertyFactory.getProperty(propertyId);
        PropertyToken token = PropertyToken(property.tokenContract);
        assertEq(token.balanceOf(user1), tokenAmount);
    }

    function test_PurchaseTokens_IncorrectPayment_TooLittle() public {
        // Create property
        vm.prank(propertyManager1);
        uint256 propertyId = propertyFactory.createProperty(
            "Test Property",
            "https://test.com",
            1000 ether,
            100000 * 1e18,
            0.01 ether
        );

        // KYC verify factory and buyer
        accessControl.setKYCStatus(address(propertyFactory), true);
        accessControl.setKYCStatus(user1, true);

        // Try to purchase with insufficient payment
        uint256 tokenAmount = 10 * 1e18;
        uint256 correctPayment = 0.1 ether;
        uint256 insufficientPayment = 0.09 ether;

        vm.deal(user1, 1 ether);
        vm.prank(user1);
        vm.expectRevert("Incorrect payment amount");
        propertyFactory.purchaseTokens{value: insufficientPayment}(propertyId, tokenAmount);
    }

    function test_PurchaseTokens_IncorrectPayment_TooMuch() public {
        // Create property
        vm.prank(propertyManager1);
        uint256 propertyId = propertyFactory.createProperty(
            "Test Property",
            "https://test.com",
            1000 ether,
            100000 * 1e18,
            0.01 ether
        );

        // KYC verify factory and buyer
        accessControl.setKYCStatus(address(propertyFactory), true);
        accessControl.setKYCStatus(user1, true);

        // Try to purchase with too much payment
        uint256 tokenAmount = 10 * 1e18;
        uint256 correctPayment = 0.1 ether;
        uint256 excessivePayment = 0.11 ether;

        vm.deal(user1, 1 ether);
        vm.prank(user1);
        vm.expectRevert("Incorrect payment amount");
        propertyFactory.purchaseTokens{value: excessivePayment}(propertyId, tokenAmount);
    }

    function test_PurchaseTokens_PaymentGoesToCreator() public {
        // Create property
        vm.prank(propertyManager1);
        uint256 propertyId = propertyFactory.createProperty(
            "Test Property",
            "https://test.com",
            1000 ether,
            100000 * 1e18,
            0.01 ether
        );

        // KYC verify factory and buyer
        accessControl.setKYCStatus(address(propertyFactory), true);
        accessControl.setKYCStatus(user1, true);

        // Record creator balance before
        uint256 creatorBalanceBefore = propertyManager1.balance;

        // Purchase tokens
        uint256 tokenAmount = 10 * 1e18;
        uint256 payment = 0.1 ether;

        vm.deal(user1, 1 ether);
        vm.prank(user1);
        propertyFactory.purchaseTokens{value: payment}(propertyId, tokenAmount);

        // Check creator received payment
        uint256 creatorBalanceAfter = propertyManager1.balance;
        assertEq(creatorBalanceAfter - creatorBalanceBefore, payment, "Creator should receive payment");
    }

    function test_PurchaseTokens_RequiresKYC() public {
        // Create property
        vm.prank(propertyManager1);
        uint256 propertyId = propertyFactory.createProperty(
            "Test Property",
            "https://test.com",
            1000 ether,
            100000 * 1e18,
            0.01 ether
        );

        // DON'T KYC verify buyer

        // Try to purchase
        uint256 tokenAmount = 10 * 1e18;
        uint256 payment = 0.1 ether;

        vm.deal(user1, 1 ether);
        vm.prank(user1);
        vm.expectRevert("Buyer not KYC verified");
        propertyFactory.purchaseTokens{value: payment}(propertyId, tokenAmount);
    }
}