// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./AccessControl.sol";

contract Marketplace is ReentrancyGuard {
    struct Listing {
        uint256 id;
        address seller;
        address tokenContract;
        uint256 amount;
        uint256 pricePerToken;
        bool isActive;
        uint256 createdAt;
    }

    struct Offer {
        uint256 id;
        address buyer;
        uint256 listingId;
        uint256 amount;
        uint256 pricePerToken;
        bool isActive;
        uint256 createdAt;
    }

    mapping(uint256 => Listing) public listings;
    mapping(uint256 => Offer) public offers;
    mapping(address => uint256[]) public listingsBySeller;
    mapping(address => uint256[]) public offersByBuyer;
    mapping(uint256 => uint256[]) public offersByListing;

    uint256 public nextListingId;
    uint256 public nextOfferId;
    uint256 public platformFeePercent = 250; // 2.5% in basis points
    address public feeCollector;

    AccessControl public accessControl;

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

    modifier onlyAdmin() {
        require(accessControl.isUserAdmin(msg.sender), "Not admin");
        _;
    }

    modifier onlyKYC() {
        require(accessControl.isUserKYCed(msg.sender), "User not KYC verified");
        _;
    }

    modifier whenNotPaused() {
        require(!accessControl.isSystemPaused(), "System paused");
        _;
    }

    modifier validListing(uint256 listingId) {
        require(listingId < nextListingId, "Invalid listing ID");
        require(listings[listingId].isActive, "Listing not active");
        _;
    }

    modifier validOffer(uint256 offerId) {
        require(offerId < nextOfferId, "Invalid offer ID");
        require(offers[offerId].isActive, "Offer not active");
        _;
    }

    modifier onlyListingOwner(uint256 listingId) {
        require(listings[listingId].seller == msg.sender, "Not listing owner");
        _;
    }

    modifier onlyOfferOwner(uint256 offerId) {
        require(offers[offerId].buyer == msg.sender, "Not offer owner");
        _;
    }

    constructor(address _accessControl, address _feeCollector) {
        require(_accessControl != address(0), "Invalid access control");
        require(_feeCollector != address(0), "Invalid fee collector");

        accessControl = AccessControl(_accessControl);
        feeCollector = _feeCollector;
    }

    function createListing(
        address tokenContract,
        uint256 amount,
        uint256 pricePerToken
    ) external onlyKYC whenNotPaused nonReentrant returns (uint256) {
        require(tokenContract != address(0), "Invalid token contract");
        require(amount > 0, "Invalid amount");
        require(pricePerToken > 0, "Invalid price");

        IERC20 token = IERC20(tokenContract);
        require(token.balanceOf(msg.sender) >= amount, "Insufficient balance");
        require(token.allowance(msg.sender, address(this)) >= amount, "Insufficient allowance");

        uint256 listingId = nextListingId++;

        listings[listingId] = Listing({
            id: listingId,
            seller: msg.sender,
            tokenContract: tokenContract,
            amount: amount,
            pricePerToken: pricePerToken,
            isActive: true,
            createdAt: block.timestamp
        });

        listingsBySeller[msg.sender].push(listingId);

        token.transferFrom(msg.sender, address(this), amount);

        emit ListingCreated(listingId, msg.sender, tokenContract, amount, pricePerToken);

        return listingId;
    }

    function cancelListing(uint256 listingId) external validListing(listingId) onlyListingOwner(listingId) nonReentrant {
        Listing storage listing = listings[listingId];
        listing.isActive = false;

        IERC20(listing.tokenContract).transfer(listing.seller, listing.amount);

        for (uint256 i = 0; i < offersByListing[listingId].length; i++) {
            uint256 offerId = offersByListing[listingId][i];
            if (offers[offerId].isActive) {
                _cancelOffer(offerId);
            }
        }

        emit ListingCancelled(listingId);
    }

    function updateListingPrice(uint256 listingId, uint256 newPrice) external
        validListing(listingId)
        onlyListingOwner(listingId)
    {
        require(newPrice > 0, "Invalid price");

        listings[listingId].pricePerToken = newPrice;

        emit ListingPriceUpdated(listingId, newPrice);
    }

    function createOffer(
        uint256 listingId,
        uint256 amount,
        uint256 pricePerToken
    ) external payable onlyKYC whenNotPaused validListing(listingId) nonReentrant returns (uint256) {
        require(amount > 0, "Invalid amount");
        require(pricePerToken > 0, "Invalid price");
        require(amount <= listings[listingId].amount, "Amount exceeds listing");

        uint256 totalPrice = (amount * pricePerToken) / 1e18; // Correct calculation: wei * wei / 1e18 = wei
        require(msg.value >= totalPrice, "Insufficient payment");

        uint256 offerId = nextOfferId++;

        offers[offerId] = Offer({
            id: offerId,
            buyer: msg.sender,
            listingId: listingId,
            amount: amount,
            pricePerToken: pricePerToken,
            isActive: true,
            createdAt: block.timestamp
        });

        offersByBuyer[msg.sender].push(offerId);
        offersByListing[listingId].push(offerId);

        if (msg.value > totalPrice) {
            (bool success, ) = msg.sender.call{value: msg.value - totalPrice}("");
            require(success, "Refund failed");
        }

        emit OfferCreated(offerId, msg.sender, listingId, amount, pricePerToken);

        return offerId;
    }

    function cancelOffer(uint256 offerId) external validOffer(offerId) onlyOfferOwner(offerId) nonReentrant {
        _cancelOffer(offerId);
    }

    function acceptOffer(uint256 offerId) external nonReentrant {
        require(offerId < nextOfferId, "Invalid offer ID");

        Offer storage offer = offers[offerId];
        Listing storage listing = listings[offer.listingId];

        require(listing.seller == msg.sender, "Not listing owner");
        require(listing.isActive, "Listing not active");
        require(offer.isActive, "Offer not active");

        offer.isActive = false;

        uint256 totalPrice = (offer.amount * offer.pricePerToken) / 1e18;
        uint256 platformFee = (totalPrice * platformFeePercent) / 10000;
        uint256 sellerAmount = totalPrice - platformFee;

        IERC20(listing.tokenContract).transfer(offer.buyer, offer.amount);

        (bool success1, ) = listing.seller.call{value: sellerAmount}("");
        require(success1, "Seller payment failed");

        (bool success2, ) = feeCollector.call{value: platformFee}("");
        require(success2, "Fee payment failed");

        if (offer.amount == listing.amount) {
            listing.isActive = false;
        } else {
            listing.amount -= offer.amount;
        }

        emit OfferAccepted(offerId, offer.listingId, offer.buyer, listing.seller);
    }

    function buyFromListing(uint256 listingId, uint256 amount) external payable
        onlyKYC
        whenNotPaused
        validListing(listingId)
        nonReentrant
    {
        Listing storage listing = listings[listingId];
        require(amount > 0, "Invalid amount");
        require(amount <= listing.amount, "Amount exceeds available");

        uint256 totalPrice = (amount * listing.pricePerToken) / 1e18; // Correct calculation: wei * wei / 1e18 = wei
        require(msg.value >= totalPrice, "Insufficient payment");

        uint256 platformFee = (totalPrice * platformFeePercent) / 10000;
        uint256 sellerAmount = totalPrice - platformFee;

        IERC20(listing.tokenContract).transfer(msg.sender, amount);

        (bool success1, ) = listing.seller.call{value: sellerAmount}("");
        require(success1, "Seller payment failed");

        (bool success2, ) = feeCollector.call{value: platformFee}("");
        require(success2, "Fee payment failed");

        if (msg.value > totalPrice) {
            (bool success3, ) = msg.sender.call{value: msg.value - totalPrice}("");
            require(success3, "Refund failed");
        }

        if (amount == listing.amount) {
            listing.isActive = false;
        } else {
            listing.amount -= amount;
        }

        emit TokensPurchased(listingId, msg.sender, amount, totalPrice);
    }

    function setPlatformFee(uint256 feePercent) external onlyAdmin {
        require(feePercent <= 1000, "Fee too high"); // Max 10%
        platformFeePercent = feePercent;
        emit PlatformFeeUpdated(feePercent);
    }

    function setFeeCollector(address collector) external onlyAdmin {
        require(collector != address(0), "Invalid address");
        feeCollector = collector;
        emit FeeCollectorUpdated(collector);
    }

    function emergencyWithdraw() external onlyAdmin {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "Withdrawal failed");
    }

    function _cancelOffer(uint256 offerId) internal {
        Offer storage offer = offers[offerId];
        offer.isActive = false;

        uint256 refundAmount = (offer.amount * offer.pricePerToken) / 1e18;
        (bool success, ) = offer.buyer.call{value: refundAmount}("");
        require(success, "Refund failed");

        emit OfferCancelled(offerId);
    }

    function getActiveListings() external view returns (Listing[] memory) {
        uint256 activeCount = 0;
        for (uint256 i = 0; i < nextListingId; i++) {
            if (listings[i].isActive) {
                activeCount++;
            }
        }

        Listing[] memory activeListings = new Listing[](activeCount);
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < nextListingId; i++) {
            if (listings[i].isActive) {
                activeListings[currentIndex] = listings[i];
                currentIndex++;
            }
        }

        return activeListings;
    }

    function getListingsByToken(address tokenContract) external view returns (Listing[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < nextListingId; i++) {
            if (listings[i].tokenContract == tokenContract && listings[i].isActive) {
                count++;
            }
        }

        Listing[] memory tokenListings = new Listing[](count);
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < nextListingId; i++) {
            if (listings[i].tokenContract == tokenContract && listings[i].isActive) {
                tokenListings[currentIndex] = listings[i];
                currentIndex++;
            }
        }

        return tokenListings;
    }

    function getOffersByListing(uint256 listingId) external view returns (Offer[] memory) {
        uint256[] memory offerIds = offersByListing[listingId];
        uint256 activeCount = 0;

        for (uint256 i = 0; i < offerIds.length; i++) {
            if (offers[offerIds[i]].isActive) {
                activeCount++;
            }
        }

        Offer[] memory activeOffers = new Offer[](activeCount);
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < offerIds.length; i++) {
            if (offers[offerIds[i]].isActive) {
                activeOffers[currentIndex] = offers[offerIds[i]];
                currentIndex++;
            }
        }

        return activeOffers;
    }

    function getUserListings(address user) external view returns (uint256[] memory) {
        return listingsBySeller[user];
    }

    function getUserOffers(address user) external view returns (uint256[] memory) {
        return offersByBuyer[user];
    }
}