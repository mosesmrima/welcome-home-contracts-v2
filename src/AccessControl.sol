// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract AccessControl is Ownable, ReentrancyGuard {
    mapping(address => bool) public isKYCVerified;
    mapping(address => bool) public isAdmin;
    mapping(address => bool) public isPropertyManager;
    mapping(address => uint256) public kycTimestamp;

    bool public systemPaused;

    event KYCStatusUpdated(address indexed user, bool verified, uint256 timestamp);
    event AdminAdded(address indexed admin);
    event AdminRemoved(address indexed admin);
    event PropertyManagerAdded(address indexed manager);
    event PropertyManagerRemoved(address indexed manager);
    event SystemPauseStatusChanged(bool paused);
    event EmergencyTransferExecuted(
        address indexed token,
        address indexed from,
        address indexed to,
        uint256 amount
    );

    modifier onlyAdmin() {
        require(isAdmin[msg.sender] || msg.sender == owner(), "Not admin");
        _;
    }

    modifier onlyPropertyManager() {
        require(
            isPropertyManager[msg.sender] ||
            isAdmin[msg.sender] ||
            msg.sender == owner(),
            "Not property manager"
        );
        _;
    }

    modifier whenNotPaused() {
        require(!systemPaused, "System paused");
        _;
    }

    modifier onlyKYCVerified(address user) {
        require(isKYCVerified[user], "User not KYC verified");
        _;
    }

    constructor() Ownable(msg.sender) {
        isAdmin[msg.sender] = true;
        isPropertyManager[msg.sender] = true;
    }

    function setAdmin(address user, bool status) external onlyOwner {
        require(user != address(0), "Invalid address");
        isAdmin[user] = status;

        if (status) {
            emit AdminAdded(user);
        } else {
            emit AdminRemoved(user);
        }
    }

    function setPropertyManager(address user, bool status) external onlyAdmin {
        require(user != address(0), "Invalid address");
        isPropertyManager[user] = status;

        if (status) {
            emit PropertyManagerAdded(user);
        } else {
            emit PropertyManagerRemoved(user);
        }
    }

    function setKYCStatus(address user, bool verified) external onlyAdmin {
        require(user != address(0), "Invalid address");
        isKYCVerified[user] = verified;
        kycTimestamp[user] = block.timestamp;

        emit KYCStatusUpdated(user, verified, block.timestamp);
    }

    function batchSetKYC(address[] calldata users, bool verified) external onlyAdmin {
        uint256 length = users.length;
        require(length > 0, "Empty array");
        require(length <= 100, "Batch too large");

        for (uint256 i = 0; i < length; i++) {
            address user = users[i];
            require(user != address(0), "Invalid address");

            isKYCVerified[user] = verified;
            kycTimestamp[user] = block.timestamp;

            emit KYCStatusUpdated(user, verified, block.timestamp);
        }
    }

    function pauseSystem() external onlyAdmin {
        systemPaused = true;
        emit SystemPauseStatusChanged(true);
    }

    function unpauseSystem() external onlyAdmin {
        systemPaused = false;
        emit SystemPauseStatusChanged(false);
    }

    function emergencyTransferOverride(
        address token,
        address from,
        address to,
        uint256 amount
    ) external onlyAdmin nonReentrant {
        require(token != address(0), "Invalid token");
        require(from != address(0), "Invalid from");
        require(to != address(0), "Invalid to");
        require(amount > 0, "Invalid amount");

        (bool success, ) = token.call(
            abi.encodeWithSignature(
                "adminTransfer(address,address,uint256)",
                from,
                to,
                amount
            )
        );
        require(success, "Emergency transfer failed");

        emit EmergencyTransferExecuted(token, from, to, amount);
    }

    function isUserKYCed(address user) external view returns (bool) {
        return isKYCVerified[user];
    }

    function getUserKYCTimestamp(address user) external view returns (uint256) {
        return kycTimestamp[user];
    }

    function isSystemPaused() external view returns (bool) {
        return systemPaused;
    }

    function isUserAdmin(address user) external view returns (bool) {
        return isAdmin[user] || user == owner();
    }

    function isUserPropertyManager(address user) external view returns (bool) {
        return isPropertyManager[user] || isAdmin[user] || user == owner();
    }
}