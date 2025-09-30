// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./AccessControl.sol";

contract OwnershipRegistry {
    struct OwnershipInfo {
        address tokenContract;
        uint256 propertyId;
        uint256 balance;
        uint256 lastUpdated;
    }

    struct TokenHolder {
        address holder;
        uint256 balance;
    }

    mapping(address => mapping(address => uint256)) public userTokenBalances; // user => token => balance
    mapping(address => address[]) public userOwnedTokens; // user => token contracts
    mapping(address => mapping(address => bool)) private userOwnsToken; // user => token => owns
    mapping(address => bool) public authorizedUpdaters; // contracts that can update ownership
    mapping(address => address[]) public tokenHolders; // token => holders
    mapping(address => mapping(address => bool)) private tokenHasHolder; // token => holder => exists

    uint256 public totalUniqueHolders;
    uint256 public totalTokenTypes;
    mapping(address => bool) private isUniqueHolder; // tracks if user has any tokens
    mapping(address => bool) private isRegisteredToken; // tracks registered token contracts

    AccessControl public accessControl;

    event OwnershipUpdated(
        address indexed user,
        address indexed tokenContract,
        uint256 oldBalance,
        uint256 newBalance
    );
    event OwnershipRemoved(address indexed user, address indexed tokenContract);
    event AuthorizedUpdaterSet(address indexed updater, bool authorized);

    modifier onlyAdmin() {
        require(accessControl.isUserAdmin(msg.sender), "Not admin");
        _;
    }

    modifier onlyAuthorized() {
        require(authorizedUpdaters[msg.sender], "Not authorized updater");
        _;
    }

    constructor(address _accessControl) {
        require(_accessControl != address(0), "Invalid access control");
        accessControl = AccessControl(_accessControl);
    }

    function updateOwnership(
        address user,
        address tokenContract,
        uint256 newBalance
    ) external onlyAuthorized {
        require(user != address(0), "Invalid user address");
        require(tokenContract != address(0), "Invalid token contract");

        uint256 oldBalance = userTokenBalances[user][tokenContract];

        if (newBalance == 0 && oldBalance > 0) {
            _removeOwnership(user, tokenContract);
        } else {
            userTokenBalances[user][tokenContract] = newBalance;

            if (oldBalance == 0 && newBalance > 0) {
                _addNewOwnership(user, tokenContract);
            }

            emit OwnershipUpdated(user, tokenContract, oldBalance, newBalance);
        }
    }

    function removeOwnership(address user, address tokenContract) external onlyAuthorized {
        require(user != address(0), "Invalid user address");
        require(tokenContract != address(0), "Invalid token contract");

        _removeOwnership(user, tokenContract);
    }

    function setAuthorizedUpdater(address updater, bool authorized) external onlyAdmin {
        require(updater != address(0), "Invalid updater address");
        authorizedUpdaters[updater] = authorized;

        emit AuthorizedUpdaterSet(updater, authorized);
    }

    function getUserPortfolio(address user) external view returns (OwnershipInfo[] memory) {
        require(user != address(0), "Invalid user address");

        address[] memory tokens = userOwnedTokens[user];
        uint256 activeCount = 0;

        for (uint256 i = 0; i < tokens.length; i++) {
            if (userTokenBalances[user][tokens[i]] > 0) {
                activeCount++;
            }
        }

        OwnershipInfo[] memory portfolio = new OwnershipInfo[](activeCount);
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < tokens.length; i++) {
            address token = tokens[i];
            uint256 balance = userTokenBalances[user][token];

            if (balance > 0) {
                portfolio[currentIndex] = OwnershipInfo({
                    tokenContract: token,
                    propertyId: _getPropertyId(token),
                    balance: balance,
                    lastUpdated: block.timestamp
                });
                currentIndex++;
            }
        }

        return portfolio;
    }

    function getUserTokenBalance(address user, address tokenContract) external view returns (uint256) {
        return userTokenBalances[user][tokenContract];
    }

    function getUserOwnedTokens(address user) external view returns (address[] memory) {
        require(user != address(0), "Invalid user address");

        address[] memory allTokens = userOwnedTokens[user];
        uint256 activeCount = 0;

        for (uint256 i = 0; i < allTokens.length; i++) {
            if (userTokenBalances[user][allTokens[i]] > 0) {
                activeCount++;
            }
        }

        address[] memory activeTokens = new address[](activeCount);
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < allTokens.length; i++) {
            if (userTokenBalances[user][allTokens[i]] > 0) {
                activeTokens[currentIndex] = allTokens[i];
                currentIndex++;
            }
        }

        return activeTokens;
    }

    function getTotalUniqueHolders() external view returns (uint256) {
        return totalUniqueHolders;
    }

    function getTokenHolders(address tokenContract) external view returns (address[] memory) {
        require(tokenContract != address(0), "Invalid token contract");

        address[] memory allHolders = tokenHolders[tokenContract];
        uint256 activeCount = 0;

        for (uint256 i = 0; i < allHolders.length; i++) {
            if (userTokenBalances[allHolders[i]][tokenContract] > 0) {
                activeCount++;
            }
        }

        address[] memory activeHolders = new address[](activeCount);
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < allHolders.length; i++) {
            address holder = allHolders[i];
            if (userTokenBalances[holder][tokenContract] > 0) {
                activeHolders[currentIndex] = holder;
                currentIndex++;
            }
        }

        return activeHolders;
    }

    function getUserTotalProperties(address user) external view returns (uint256) {
        require(user != address(0), "Invalid user address");

        address[] memory tokens = userOwnedTokens[user];
        uint256 count = 0;

        for (uint256 i = 0; i < tokens.length; i++) {
            if (userTokenBalances[user][tokens[i]] > 0) {
                count++;
            }
        }

        return count;
    }

    function getPropertyDistribution(address tokenContract) external view returns (
        address[] memory holders,
        uint256[] memory balances
    ) {
        require(tokenContract != address(0), "Invalid token contract");

        address[] memory allHolders = tokenHolders[tokenContract];
        uint256 activeCount = 0;

        for (uint256 i = 0; i < allHolders.length; i++) {
            if (userTokenBalances[allHolders[i]][tokenContract] > 0) {
                activeCount++;
            }
        }

        holders = new address[](activeCount);
        balances = new uint256[](activeCount);
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < allHolders.length; i++) {
            address holder = allHolders[i];
            uint256 balance = userTokenBalances[holder][tokenContract];

            if (balance > 0) {
                holders[currentIndex] = holder;
                balances[currentIndex] = balance;
                currentIndex++;
            }
        }

        return (holders, balances);
    }

    function getTokenHolderCount(address tokenContract) external view returns (uint256) {
        require(tokenContract != address(0), "Invalid token contract");

        address[] memory allHolders = tokenHolders[tokenContract];
        uint256 activeCount = 0;

        for (uint256 i = 0; i < allHolders.length; i++) {
            if (userTokenBalances[allHolders[i]][tokenContract] > 0) {
                activeCount++;
            }
        }

        return activeCount;
    }

    function isTokenHolder(address user, address tokenContract) external view returns (bool) {
        return userTokenBalances[user][tokenContract] > 0;
    }

    function _addNewOwnership(address user, address tokenContract) internal {
        if (!userOwnsToken[user][tokenContract]) {
            userOwnedTokens[user].push(tokenContract);
            userOwnsToken[user][tokenContract] = true;
        }

        if (!tokenHasHolder[tokenContract][user]) {
            tokenHolders[tokenContract].push(user);
            tokenHasHolder[tokenContract][user] = true;
        }

        // Track unique holders
        if (!isUniqueHolder[user]) {
            isUniqueHolder[user] = true;
            totalUniqueHolders++;
        }

        // Track token types
        if (!isRegisteredToken[tokenContract]) {
            isRegisteredToken[tokenContract] = true;
            totalTokenTypes++;
        }
    }

    function _removeOwnership(address user, address tokenContract) internal {
        uint256 oldBalance = userTokenBalances[user][tokenContract];
        require(oldBalance > 0, "No ownership to remove");

        userTokenBalances[user][tokenContract] = 0;

        // Check if user no longer holds any tokens
        bool hasAnyTokens = false;
        address[] memory userTokens = userOwnedTokens[user];
        for (uint256 i = 0; i < userTokens.length; i++) {
            if (userTokenBalances[user][userTokens[i]] > 0) {
                hasAnyTokens = true;
                break;
            }
        }

        // If user no longer holds any tokens, decrease unique holder count
        if (!hasAnyTokens && isUniqueHolder[user]) {
            isUniqueHolder[user] = false;
            totalUniqueHolders--;
        }

        emit OwnershipRemoved(user, tokenContract);
    }

    function _getPropertyId(address tokenContract) internal view returns (uint256) {
        (bool success, bytes memory data) = tokenContract.staticcall(
            abi.encodeWithSignature("propertyId()")
        );

        if (success && data.length >= 32) {
            return abi.decode(data, (uint256));
        }

        return 0;
    }

    function batchUpdateOwnership(
        address[] calldata users,
        address[] calldata tokens,
        uint256[] calldata balances
    ) external onlyAuthorized {
        require(users.length == tokens.length, "Array length mismatch");
        require(users.length == balances.length, "Array length mismatch");
        require(users.length <= 50, "Batch too large");

        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            address tokenContract = tokens[i];
            uint256 newBalance = balances[i];

            require(user != address(0), "Invalid user address");
            require(tokenContract != address(0), "Invalid token contract");

            uint256 oldBalance = userTokenBalances[user][tokenContract];

            if (newBalance == 0 && oldBalance > 0) {
                _removeOwnership(user, tokenContract);
            } else {
                userTokenBalances[user][tokenContract] = newBalance;

                if (oldBalance == 0 && newBalance > 0) {
                    _addNewOwnership(user, tokenContract);
                }

                emit OwnershipUpdated(user, tokenContract, oldBalance, newBalance);
            }
        }
    }

    function getRegistryStats() external view returns (
        uint256 _totalTokenTypes,
        uint256 _totalActiveHoldings
    ) {
        return (totalTokenTypes, totalUniqueHolders);
    }
}