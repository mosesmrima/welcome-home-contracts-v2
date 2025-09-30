// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./AccessControl.sol";
import "./PropertyToken.sol";
import "./OwnershipRegistry.sol";

contract PropertyFactory is ReentrancyGuard {
    struct Property {
        uint256 id;
        string name;
        string metadataURI;
        address tokenContract;
        uint256 totalValue;
        uint256 totalSupply;
        uint256 pricePerToken;
        bool isActive;
        address creator;
        uint256 createdAt;
    }

    mapping(uint256 => Property) public properties;
    mapping(address => uint256[]) public propertiesByCreator;
    uint256 public nextPropertyId;

    AccessControl public accessControl;
    OwnershipRegistry public ownershipRegistry;

    event PropertyCreated(
        uint256 indexed propertyId,
        string name,
        address indexed tokenContract,
        address indexed creator
    );
    event PropertyUpdated(uint256 indexed propertyId, string metadataURI);
    event PropertyStatusChanged(uint256 indexed propertyId, bool isActive);
    event PropertyPriceUpdated(uint256 indexed propertyId, uint256 newPrice);
    event TokensDistributed(
        uint256 indexed propertyId,
        address indexed to,
        uint256 amount
    );

    modifier onlyAdmin() {
        require(accessControl.isUserAdmin(msg.sender), "Not admin");
        _;
    }

    modifier onlyPropertyManager() {
        require(accessControl.isUserPropertyManager(msg.sender), "Not property manager");
        _;
    }

    modifier whenNotPaused() {
        require(!accessControl.isSystemPaused(), "System paused");
        _;
    }

    modifier onlyCreatorOrAdmin(uint256 propertyId) {
        require(
            properties[propertyId].creator == msg.sender ||
            accessControl.isUserAdmin(msg.sender),
            "Not creator or admin"
        );
        _;
    }

    modifier validProperty(uint256 propertyId) {
        require(propertyId < nextPropertyId, "Invalid property ID");
        _;
    }

    constructor(address _accessControl, address _ownershipRegistry) {
        require(_accessControl != address(0), "Invalid access control");
        require(_ownershipRegistry != address(0), "Invalid ownership registry");

        accessControl = AccessControl(_accessControl);
        ownershipRegistry = OwnershipRegistry(_ownershipRegistry);
    }

    function createProperty(
        string calldata name,
        string calldata metadataURI,
        uint256 totalValue,
        uint256 totalSupply,
        uint256 pricePerToken
    ) external onlyPropertyManager whenNotPaused nonReentrant returns (uint256) {
        require(bytes(name).length > 0, "Empty name");
        require(bytes(metadataURI).length > 0, "Empty metadata");
        require(totalValue > 0, "Invalid total value");
        require(totalSupply > 0, "Invalid total supply");
        require(pricePerToken > 0, "Invalid price per token");

        uint256 propertyId = nextPropertyId++;

        address tokenAddress = address(new PropertyToken(
            string(abi.encodePacked("Property Token ", name)),
            string(abi.encodePacked("PROP", _toString(propertyId))),
            totalSupply,
            propertyId,
            address(accessControl),
            address(this),
            address(ownershipRegistry)
        ));

        properties[propertyId] = Property({
            id: propertyId,
            name: name,
            metadataURI: metadataURI,
            tokenContract: tokenAddress,
            totalValue: totalValue,
            totalSupply: totalSupply,
            pricePerToken: pricePerToken,
            isActive: true,
            creator: msg.sender,
            createdAt: block.timestamp
        });

        propertiesByCreator[msg.sender].push(propertyId);

        ownershipRegistry.setAuthorizedUpdater(tokenAddress, true);

        emit PropertyCreated(propertyId, name, tokenAddress, msg.sender);

        return propertyId;
    }

    function updatePropertyMetadata(
        uint256 propertyId,
        string calldata newMetadataURI
    ) external validProperty(propertyId) onlyCreatorOrAdmin(propertyId) {
        require(bytes(newMetadataURI).length > 0, "Empty metadata");

        properties[propertyId].metadataURI = newMetadataURI;

        emit PropertyUpdated(propertyId, newMetadataURI);
    }

    function setPropertyActive(
        uint256 propertyId,
        bool active
    ) external validProperty(propertyId) onlyAdmin {
        properties[propertyId].isActive = active;

        emit PropertyStatusChanged(propertyId, active);
    }

    function updatePropertyPrice(
        uint256 propertyId,
        uint256 newPrice
    ) external validProperty(propertyId) onlyCreatorOrAdmin(propertyId) {
        require(newPrice > 0, "Invalid price");

        properties[propertyId].pricePerToken = newPrice;

        emit PropertyPriceUpdated(propertyId, newPrice);
    }

    /**
     * @notice Distribute tokens from PropertyFactory to KYC'd users (Primary Offering)
     * @dev Only property managers can distribute tokens for primary offerings
     * @param propertyId The ID of the property
     * @param to The recipient address (must be KYC'd)
     * @param amount The amount of tokens to distribute
     */
    function distributeTokens(
        uint256 propertyId,
        address to,
        uint256 amount
    ) external validProperty(propertyId) onlyPropertyManager whenNotPaused nonReentrant {
        require(to != address(0), "Invalid recipient");
        require(amount > 0, "Invalid amount");
        require(accessControl.isUserKYCed(to), "Recipient not KYC verified");

        Property memory property = properties[propertyId];
        require(property.isActive, "Property not active");

        PropertyToken token = PropertyToken(property.tokenContract);

        // Transfer tokens from factory to recipient
        require(token.transfer(to, amount), "Token transfer failed");

        emit TokensDistributed(propertyId, to, amount);
    }

    function getProperty(uint256 propertyId) external view validProperty(propertyId) returns (Property memory) {
        return properties[propertyId];
    }

    function getPropertiesByCreator(address creator) external view returns (uint256[] memory) {
        return propertiesByCreator[creator];
    }

    function getAllActiveProperties() external view returns (Property[] memory) {
        uint256 activeCount = 0;

        for (uint256 i = 0; i < nextPropertyId; i++) {
            if (properties[i].isActive) {
                activeCount++;
            }
        }

        Property[] memory activeProperties = new Property[](activeCount);
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < nextPropertyId; i++) {
            if (properties[i].isActive) {
                activeProperties[currentIndex] = properties[i];
                currentIndex++;
            }
        }

        return activeProperties;
    }

    function getPropertyCount() external view returns (uint256) {
        return nextPropertyId;
    }

    function getActivePropertyCount() external view returns (uint256) {
        uint256 activeCount = 0;

        for (uint256 i = 0; i < nextPropertyId; i++) {
            if (properties[i].isActive) {
                activeCount++;
            }
        }

        return activeCount;
    }

    function getPropertyToken(uint256 propertyId) external view validProperty(propertyId) returns (address) {
        return properties[propertyId].tokenContract;
    }

    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}