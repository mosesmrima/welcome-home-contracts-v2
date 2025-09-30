// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./AccessControl.sol";
import "./OwnershipRegistry.sol";

contract PropertyToken is ERC20, ReentrancyGuard {
    uint256 public propertyId;
    address public propertyFactory;
    AccessControl public accessControl;
    OwnershipRegistry public ownershipRegistry;

    mapping(address => bool) public transferRestrictions;
    bool public tradingEnabled = true;

    uint256 public dividendPool;
    uint256 public totalDividendsDistributed;
    uint256 public lastDividendTimestamp;
    mapping(address => uint256) public lastDividendClaim;

    event TradingStatusChanged(bool enabled);
    event TransferRestrictionSet(address indexed user, bool restricted);
    event DividendsDistributed(uint256 amount, uint256 timestamp);
    event DividendsClaimed(address indexed user, uint256 amount);
    event AdminTransferExecuted(address indexed from, address indexed to, uint256 amount);

    modifier onlyFactory() {
        require(msg.sender == propertyFactory, "Not factory");
        _;
    }

    modifier onlyAdmin() {
        require(accessControl.isUserAdmin(msg.sender), "Not admin");
        _;
    }

    modifier onlyPropertyManager() {
        require(accessControl.isUserPropertyManager(msg.sender), "Not property manager");
        _;
    }

    modifier whenTradingEnabled() {
        require(tradingEnabled, "Trading disabled");
        _;
    }

    modifier whenNotPaused() {
        require(!accessControl.isSystemPaused(), "System paused");
        _;
    }

    modifier kycCheck(address user) {
        require(accessControl.isUserKYCed(user), "User not KYC verified");
        _;
    }

    modifier notRestricted(address user) {
        require(!transferRestrictions[user], "User transfer restricted");
        _;
    }

    constructor(
        string memory name,
        string memory symbol,
        uint256 totalSupply,
        uint256 _propertyId,
        address _accessControl,
        address _propertyFactory,
        address _ownershipRegistry
    ) ERC20(name, symbol) {
        require(_accessControl != address(0), "Invalid access control");
        require(_propertyFactory != address(0), "Invalid property factory");
        require(_ownershipRegistry != address(0), "Invalid ownership registry");
        require(totalSupply > 0, "Invalid total supply");

        propertyId = _propertyId;
        accessControl = AccessControl(_accessControl);
        propertyFactory = _propertyFactory;
        ownershipRegistry = OwnershipRegistry(_ownershipRegistry);

        _mint(msg.sender, totalSupply);
    }

    function transfer(address to, uint256 amount) public override
        whenNotPaused
        whenTradingEnabled
        kycCheck(msg.sender)
        kycCheck(to)
        notRestricted(msg.sender)
        notRestricted(to)
        returns (bool)
    {
        bool success = super.transfer(to, amount);
        if (success) {
            _updateOwnership(msg.sender);
            _updateOwnership(to);
        }
        return success;
    }

    function transferFrom(address from, address to, uint256 amount) public override
        whenNotPaused
        whenTradingEnabled
        kycCheck(from)
        kycCheck(to)
        notRestricted(from)
        notRestricted(to)
        returns (bool)
    {
        bool success = super.transferFrom(from, to, amount);
        if (success) {
            _updateOwnership(from);
            _updateOwnership(to);
        }
        return success;
    }

    function setTradingEnabled(bool enabled) external onlyAdmin {
        tradingEnabled = enabled;
        emit TradingStatusChanged(enabled);
    }

    function setTransferRestriction(address user, bool restricted) external onlyAdmin {
        require(user != address(0), "Invalid address");
        transferRestrictions[user] = restricted;
        emit TransferRestrictionSet(user, restricted);
    }

    function adminTransfer(address from, address to, uint256 amount) external onlyAdmin nonReentrant {
        require(from != address(0), "Invalid from address");
        require(to != address(0), "Invalid to address");
        require(amount > 0, "Invalid amount");
        require(balanceOf(from) >= amount, "Insufficient balance");

        _transfer(from, to, amount);
        _updateOwnership(from);
        _updateOwnership(to);

        emit AdminTransferExecuted(from, to, amount);
    }

    function distributeDividends() external payable onlyPropertyManager nonReentrant {
        require(msg.value > 0, "No dividends to distribute");
        require(totalSupply() > 0, "No tokens in circulation");

        dividendPool += msg.value;
        totalDividendsDistributed += msg.value;
        lastDividendTimestamp = block.timestamp;

        emit DividendsDistributed(msg.value, block.timestamp);
    }

    function claimDividends() external nonReentrant returns (uint256) {
        require(accessControl.isUserKYCed(msg.sender), "User not KYC verified");

        uint256 claimableAmount = getClaimableDividends(msg.sender);
        require(claimableAmount > 0, "No dividends to claim");

        lastDividendClaim[msg.sender] += claimableAmount;

        (bool success, ) = msg.sender.call{value: claimableAmount}("");
        require(success, "Dividend transfer failed");

        emit DividendsClaimed(msg.sender, claimableAmount);

        return claimableAmount;
    }

    function getClaimableDividends(address user) public view returns (uint256) {
        if (totalSupply() == 0 || balanceOf(user) == 0) {
            return 0;
        }

        uint256 userShare = (balanceOf(user) * 1e18) / totalSupply();
        uint256 totalClaimable = (totalDividendsDistributed * userShare) / 1e18;
        uint256 alreadyClaimed = lastDividendClaim[user];

        if (totalClaimable <= alreadyClaimed) {
            return 0;
        }

        return totalClaimable - alreadyClaimed;
    }

    function mint(address to, uint256 amount) external onlyFactory {
        require(to != address(0), "Invalid address");
        require(amount > 0, "Invalid amount");

        _mint(to, amount);
        _updateOwnership(to);
    }

    function burn(uint256 amount) external {
        require(amount > 0, "Invalid amount");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");

        _burn(msg.sender, amount);
        _updateOwnership(msg.sender);
    }

    function _updateOwnership(address user) internal {
        ownershipRegistry.updateOwnership(user, address(this), balanceOf(user));
    }

    function getTokenInfo() external view returns (
        uint256 _propertyId,
        uint256 _totalSupply,
        uint256 _dividendPool,
        uint256 _totalDividendsDistributed,
        bool _tradingEnabled
    ) {
        return (
            propertyId,
            totalSupply(),
            dividendPool,
            totalDividendsDistributed,
            tradingEnabled
        );
    }

    function getUserInfo(address user) external view returns (
        uint256 balance,
        uint256 claimableDividends,
        bool isRestricted,
        uint256 lastClaim
    ) {
        return (
            balanceOf(user),
            getClaimableDividends(user),
            transferRestrictions[user],
            lastDividendClaim[user]
        );
    }
}