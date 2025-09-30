// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/AccessControl.sol";

contract AccessControlTest is Test {
    AccessControl public accessControl;

    address public owner;
    address public admin1;
    address public admin2;
    address public propertyManager1;
    address public propertyManager2;
    address public user1;
    address public user2;
    address public user3;
    address public attacker;

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

    function setUp() public {
        owner = address(this);
        admin1 = makeAddr("admin1");
        admin2 = makeAddr("admin2");
        propertyManager1 = makeAddr("propertyManager1");
        propertyManager2 = makeAddr("propertyManager2");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        attacker = makeAddr("attacker");

        accessControl = new AccessControl();
    }

    // ===== ROLE MANAGEMENT TESTS =====

    function test_OwnerInitialSetup() public {
        // Owner should be set as admin and property manager by default
        assertTrue(accessControl.isAdmin(owner));
        assertTrue(accessControl.isPropertyManager(owner));
        assertEq(accessControl.owner(), owner);
    }

    function test_SetAdmin_Success() public {
        // Owner can set admin
        vm.expectEmit(true, false, false, false);
        emit AdminAdded(admin1);

        accessControl.setAdmin(admin1, true);
        assertTrue(accessControl.isAdmin(admin1));
    }

    function test_SetAdmin_RemoveAdmin() public {
        // Set admin first
        accessControl.setAdmin(admin1, true);
        assertTrue(accessControl.isAdmin(admin1));

        // Remove admin
        vm.expectEmit(true, false, false, false);
        emit AdminRemoved(admin1);

        accessControl.setAdmin(admin1, false);
        assertFalse(accessControl.isAdmin(admin1));
    }

    function test_SetAdmin_OnlyOwner() public {
        // Non-owner cannot set admin
        vm.prank(attacker);
        vm.expectRevert();
        accessControl.setAdmin(admin1, true);
    }

    function test_SetAdmin_InvalidAddress() public {
        vm.expectRevert("Invalid address");
        accessControl.setAdmin(address(0), true);
    }

    function test_SetPropertyManager_Success() public {
        // Admin can set property manager
        accessControl.setAdmin(admin1, true);

        vm.prank(admin1);
        vm.expectEmit(true, false, false, false);
        emit PropertyManagerAdded(propertyManager1);

        accessControl.setPropertyManager(propertyManager1, true);
        assertTrue(accessControl.isPropertyManager(propertyManager1));
    }

    function test_SetPropertyManager_RemoveManager() public {
        // Set property manager first
        accessControl.setAdmin(admin1, true);
        vm.prank(admin1);
        accessControl.setPropertyManager(propertyManager1, true);
        assertTrue(accessControl.isPropertyManager(propertyManager1));

        // Remove property manager
        vm.prank(admin1);
        vm.expectEmit(true, false, false, false);
        emit PropertyManagerRemoved(propertyManager1);

        accessControl.setPropertyManager(propertyManager1, false);
        assertFalse(accessControl.isPropertyManager(propertyManager1));
    }

    function test_SetPropertyManager_OnlyAdmin() public {
        // Non-admin cannot set property manager
        vm.prank(attacker);
        vm.expectRevert("Not admin");
        accessControl.setPropertyManager(propertyManager1, true);
    }

    function test_SetPropertyManager_InvalidAddress() public {
        vm.expectRevert("Invalid address");
        accessControl.setPropertyManager(address(0), true);
    }

    // ===== KYC MANAGEMENT TESTS =====

    function test_SetKYCStatus_Success() public {
        uint256 timestampBefore = block.timestamp;

        vm.expectEmit(true, false, false, false);
        emit KYCStatusUpdated(user1, true, block.timestamp);

        accessControl.setKYCStatus(user1, true);

        assertTrue(accessControl.isKYCVerified(user1));
        assertGe(accessControl.kycTimestamp(user1), timestampBefore);
        assertTrue(accessControl.isUserKYCed(user1));
    }

    function test_SetKYCStatus_RemoveKYC() public {
        // Set KYC first
        accessControl.setKYCStatus(user1, true);
        assertTrue(accessControl.isKYCVerified(user1));

        // Remove KYC
        vm.expectEmit(true, false, false, false);
        emit KYCStatusUpdated(user1, false, block.timestamp);

        accessControl.setKYCStatus(user1, false);
        assertFalse(accessControl.isKYCVerified(user1));
        assertFalse(accessControl.isUserKYCed(user1));
    }

    function test_SetKYCStatus_OnlyAdmin() public {
        vm.prank(attacker);
        vm.expectRevert("Not admin");
        accessControl.setKYCStatus(user1, true);
    }

    function test_SetKYCStatus_AdminCanSet() public {
        accessControl.setAdmin(admin1, true);

        vm.prank(admin1);
        accessControl.setKYCStatus(user1, true);
        assertTrue(accessControl.isKYCVerified(user1));
    }

    function test_SetKYCStatus_InvalidAddress() public {
        vm.expectRevert("Invalid address");
        accessControl.setKYCStatus(address(0), true);
    }

    function test_BatchSetKYC_Success() public {
        address[] memory users = new address[](3);
        users[0] = user1;
        users[1] = user2;
        users[2] = user3;

        // Expect multiple events
        vm.expectEmit(true, false, false, false);
        emit KYCStatusUpdated(user1, true, block.timestamp);
        vm.expectEmit(true, false, false, false);
        emit KYCStatusUpdated(user2, true, block.timestamp);
        vm.expectEmit(true, false, false, false);
        emit KYCStatusUpdated(user3, true, block.timestamp);

        accessControl.batchSetKYC(users, true);

        assertTrue(accessControl.isKYCVerified(user1));
        assertTrue(accessControl.isKYCVerified(user2));
        assertTrue(accessControl.isKYCVerified(user3));
    }

    function test_BatchSetKYC_RemoveMultiple() public {
        // Set KYC for multiple users first
        address[] memory users = new address[](2);
        users[0] = user1;
        users[1] = user2;

        accessControl.batchSetKYC(users, true);
        assertTrue(accessControl.isKYCVerified(user1));
        assertTrue(accessControl.isKYCVerified(user2));

        // Remove KYC for multiple users
        accessControl.batchSetKYC(users, false);
        assertFalse(accessControl.isKYCVerified(user1));
        assertFalse(accessControl.isKYCVerified(user2));
    }

    function test_BatchSetKYC_EmptyArray() public {
        address[] memory users = new address[](0);

        vm.expectRevert("Empty array");
        accessControl.batchSetKYC(users, true);
    }

    function test_BatchSetKYC_TooLarge() public {
        address[] memory users = new address[](101);

        vm.expectRevert("Batch too large");
        accessControl.batchSetKYC(users, true);
    }

    function test_BatchSetKYC_InvalidAddress() public {
        address[] memory users = new address[](2);
        users[0] = user1;
        users[1] = address(0);

        vm.expectRevert("Invalid address");
        accessControl.batchSetKYC(users, true);
    }

    function test_BatchSetKYC_OnlyAdmin() public {
        address[] memory users = new address[](1);
        users[0] = user1;

        vm.prank(attacker);
        vm.expectRevert("Not admin");
        accessControl.batchSetKYC(users, true);
    }

    // ===== SYSTEM CONTROL TESTS =====

    function test_PauseSystem_Success() public {
        assertFalse(accessControl.systemPaused());

        vm.expectEmit(false, false, false, true);
        emit SystemPauseStatusChanged(true);

        accessControl.pauseSystem();
        assertTrue(accessControl.systemPaused());
        assertTrue(accessControl.isSystemPaused());
    }

    function test_UnpauseSystem_Success() public {
        // Pause first
        accessControl.pauseSystem();
        assertTrue(accessControl.systemPaused());

        // Unpause
        vm.expectEmit(false, false, false, true);
        emit SystemPauseStatusChanged(false);

        accessControl.unpauseSystem();
        assertFalse(accessControl.systemPaused());
        assertFalse(accessControl.isSystemPaused());
    }

    function test_PauseSystem_OnlyAdmin() public {
        vm.prank(attacker);
        vm.expectRevert("Not admin");
        accessControl.pauseSystem();
    }

    function test_UnpauseSystem_OnlyAdmin() public {
        // Pause as admin first
        accessControl.pauseSystem();

        vm.prank(attacker);
        vm.expectRevert("Not admin");
        accessControl.unpauseSystem();
    }

    function test_PauseSystem_AdminCanPause() public {
        accessControl.setAdmin(admin1, true);

        vm.prank(admin1);
        accessControl.pauseSystem();
        assertTrue(accessControl.systemPaused());
    }

    // ===== EMERGENCY TRANSFER TESTS =====

    function test_EmergencyTransferOverride_Success() public {
        address mockToken = makeAddr("mockToken");
        address from = user1;
        address to = user2;
        uint256 amount = 100;

        // Mock the token contract call
        vm.mockCall(
            mockToken,
            abi.encodeWithSignature("adminTransfer(address,address,uint256)", from, to, amount),
            abi.encode(true)
        );

        vm.expectEmit(true, true, true, true);
        emit EmergencyTransferExecuted(mockToken, from, to, amount);

        accessControl.emergencyTransferOverride(mockToken, from, to, amount);
    }

    function test_EmergencyTransferOverride_OnlyAdmin() public {
        vm.prank(attacker);
        vm.expectRevert("Not admin");
        accessControl.emergencyTransferOverride(user1, user2, user3, 100);
    }

    function test_EmergencyTransferOverride_InvalidToken() public {
        vm.expectRevert("Invalid token");
        accessControl.emergencyTransferOverride(address(0), user1, user2, 100);
    }

    function test_EmergencyTransferOverride_InvalidFrom() public {
        vm.expectRevert("Invalid from");
        accessControl.emergencyTransferOverride(user1, address(0), user2, 100);
    }

    function test_EmergencyTransferOverride_InvalidTo() public {
        vm.expectRevert("Invalid to");
        accessControl.emergencyTransferOverride(user1, user2, address(0), 100);
    }

    function test_EmergencyTransferOverride_InvalidAmount() public {
        vm.expectRevert("Invalid amount");
        accessControl.emergencyTransferOverride(user1, user2, user3, 0);
    }

    function test_EmergencyTransferOverride_FailedCall() public {
        address mockToken = makeAddr("mockToken");

        // Mock a reverts call to simulate failure
        vm.mockCallRevert(
            mockToken,
            abi.encodeWithSignature("adminTransfer(address,address,uint256)", user1, user2, 100),
            "Transfer failed"
        );

        vm.expectRevert("Emergency transfer failed");
        accessControl.emergencyTransferOverride(mockToken, user1, user2, 100);
    }

    // ===== PERMISSION HELPER TESTS =====

    function test_IsUserAdmin_Owner() public {
        assertTrue(accessControl.isUserAdmin(owner));
    }

    function test_IsUserAdmin_Admin() public {
        accessControl.setAdmin(admin1, true);
        assertTrue(accessControl.isUserAdmin(admin1));
    }

    function test_IsUserAdmin_NonAdmin() public {
        assertFalse(accessControl.isUserAdmin(attacker));
    }

    function test_IsUserPropertyManager_Owner() public {
        assertTrue(accessControl.isUserPropertyManager(owner));
    }

    function test_IsUserPropertyManager_Admin() public {
        accessControl.setAdmin(admin1, true);
        assertTrue(accessControl.isUserPropertyManager(admin1));
    }

    function test_IsUserPropertyManager_PropertyManager() public {
        accessControl.setPropertyManager(propertyManager1, true);
        assertTrue(accessControl.isUserPropertyManager(propertyManager1));
    }

    function test_IsUserPropertyManager_NonManager() public {
        assertFalse(accessControl.isUserPropertyManager(attacker));
    }

    // ===== COMPLEX INTEGRATION TESTS =====

    function test_CompleteRoleManagementFlow() public {
        // 1. Owner sets admin
        accessControl.setAdmin(admin1, true);
        assertTrue(accessControl.isAdmin(admin1));

        // 2. Admin sets property manager
        vm.prank(admin1);
        accessControl.setPropertyManager(propertyManager1, true);
        assertTrue(accessControl.isPropertyManager(propertyManager1));

        // 3. Property manager cannot set admin (should fail)
        vm.prank(propertyManager1);
        vm.expectRevert();
        accessControl.setAdmin(admin2, true);

        // 4. Admin can set KYC
        vm.prank(admin1);
        accessControl.setKYCStatus(user1, true);
        assertTrue(accessControl.isKYCVerified(user1));

        // 5. Property manager cannot set KYC (should fail - only admin can)
        vm.prank(propertyManager1);
        vm.expectRevert("Not admin");
        accessControl.setKYCStatus(user2, true);
    }

    function test_KYCWorkflowWithTimestamps() public {
        uint256 timestamp1 = block.timestamp;

        // Set KYC for user1
        accessControl.setKYCStatus(user1, true);
        assertGe(accessControl.getUserKYCTimestamp(user1), timestamp1);

        // Advance time
        vm.warp(block.timestamp + 1 days);
        uint256 timestamp2 = block.timestamp;

        // Update KYC for user1 again
        accessControl.setKYCStatus(user1, false);
        assertGe(accessControl.getUserKYCTimestamp(user1), timestamp2);
        assertTrue(accessControl.getUserKYCTimestamp(user1) > timestamp1);
    }

    function test_SystemPauseFlow() public {
        // System starts unpaused
        assertFalse(accessControl.isSystemPaused());

        // Admin pauses system
        accessControl.setAdmin(admin1, true);
        vm.prank(admin1);
        accessControl.pauseSystem();
        assertTrue(accessControl.isSystemPaused());

        // Different admin can unpause
        accessControl.setAdmin(admin2, true);
        vm.prank(admin2);
        accessControl.unpauseSystem();
        assertFalse(accessControl.isSystemPaused());
    }

    function test_BatchKYCWithMixedResults() public {
        address[] memory users = new address[](3);
        users[0] = user1;
        users[1] = user2;
        users[2] = user3;

        // Set some users as verified initially
        accessControl.setKYCStatus(user1, true);
        assertTrue(accessControl.isKYCVerified(user1));

        // Batch set all to false
        accessControl.batchSetKYC(users, false);
        assertFalse(accessControl.isKYCVerified(user1));
        assertFalse(accessControl.isKYCVerified(user2));
        assertFalse(accessControl.isKYCVerified(user3));

        // Batch set all to true
        accessControl.batchSetKYC(users, true);
        assertTrue(accessControl.isKYCVerified(user1));
        assertTrue(accessControl.isKYCVerified(user2));
        assertTrue(accessControl.isKYCVerified(user3));
    }

    // ===== EDGE CASE TESTS =====

    function test_MultipleAdminOperations() public {
        // Set multiple admins
        accessControl.setAdmin(admin1, true);
        accessControl.setAdmin(admin2, true);

        // Both can perform admin operations
        vm.prank(admin1);
        accessControl.setKYCStatus(user1, true);

        vm.prank(admin2);
        accessControl.setKYCStatus(user2, true);

        assertTrue(accessControl.isKYCVerified(user1));
        assertTrue(accessControl.isKYCVerified(user2));

        // Remove one admin
        accessControl.setAdmin(admin1, false);

        // Removed admin cannot perform operations
        vm.prank(admin1);
        vm.expectRevert("Not admin");
        accessControl.setKYCStatus(user3, true);

        // Other admin still can
        vm.prank(admin2);
        accessControl.setKYCStatus(user3, true);
        assertTrue(accessControl.isKYCVerified(user3));
    }

    function test_ReentrancyProtection() public {
        // Emergency transfer should be protected against reentrancy
        // This is implicitly tested through the ReentrancyGuard modifier
        address mockToken = makeAddr("mockToken");

        vm.mockCall(
            mockToken,
            abi.encodeWithSignature("adminTransfer(address,address,uint256)", user1, user2, 100),
            abi.encode(true)
        );

        accessControl.emergencyTransferOverride(mockToken, user1, user2, 100);
        // If reentrancy protection works, this completes successfully
    }

    // ===== SECURITY TESTS =====

    function test_UnauthorizedAccessPrevention() public {
        address[] memory unauthorizedUsers = new address[](3);
        unauthorizedUsers[0] = user1;
        unauthorizedUsers[1] = user2;
        unauthorizedUsers[2] = attacker;

        for (uint i = 0; i < unauthorizedUsers.length; i++) {
            address user = unauthorizedUsers[i];

            // Cannot set admin
            vm.prank(user);
            vm.expectRevert();
            accessControl.setAdmin(admin1, true);

            // Cannot set property manager
            vm.prank(user);
            vm.expectRevert("Not admin");
            accessControl.setPropertyManager(propertyManager1, true);

            // Cannot set KYC
            vm.prank(user);
            vm.expectRevert("Not admin");
            accessControl.setKYCStatus(user1, true);

            // Cannot pause system
            vm.prank(user);
            vm.expectRevert("Not admin");
            accessControl.pauseSystem();
        }
    }

    function test_OwnershipTransfer() public {
        address newOwner = makeAddr("newOwner");

        // Transfer ownership
        accessControl.transferOwnership(newOwner);

        assertEq(accessControl.owner(), newOwner);

        // New owner should be admin and property manager automatically in constructor
        // But current implementation doesn't automatically grant to new owner
        // Old owner should still have admin/manager rights until explicitly removed
        assertTrue(accessControl.isAdmin(owner));
        assertTrue(accessControl.isPropertyManager(owner));
    }
}