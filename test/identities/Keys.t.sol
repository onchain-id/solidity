// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import {ClaimSignerHelper} from "../helpers/ClaimSignerHelper.sol";
import {OnchainIDSetup} from "../helpers/OnchainIDSetup.sol";
import {Errors} from "contracts/libraries/Errors.sol";
import {KeyPurposes} from "contracts/libraries/KeyPurposes.sol";
import {KeyTypes} from "contracts/libraries/KeyTypes.sol";

/// @notice Tests for Identity Key Management (ERC-734)
contract KeysTest is OnchainIDSetup {
    bytes32 public aliceKeyHash;
    bytes32 public bobKeyHash;

    function setUp() public override {
        super.setUp();

        aliceKeyHash = ClaimSignerHelper.addressToKey(alice);
        bobKeyHash = ClaimSignerHelper.addressToKey(bob);
    }

    // ============ Read key methods ============

    function test_RetrieveExistingKey() public view {
        (uint256[] memory purposes, uint256 keyType, bytes32 key) = aliceIdentity.getKey(aliceKeyHash);

        assertEq(key, aliceKeyHash);
        assertEq(purposes.length, 1);
        assertEq(purposes[0], KeyPurposes.MANAGEMENT);
        assertEq(keyType, KeyTypes.ECDSA);
    }

    function test_RetrieveExistingKeyPurposes() public view {
        uint256[] memory purposes = aliceIdentity.getKeyPurposes(aliceKeyHash);

        assertEq(purposes.length, 1);
        assertEq(purposes[0], KeyPurposes.MANAGEMENT);
    }

    function test_RetrieveExistingKeysWithGivenPurpose() public view {
        bytes32[] memory keys = aliceIdentity.getKeysByPurpose(KeyPurposes.MANAGEMENT);

        assertEq(keys.length, 1);
        assertEq(keys[0], aliceKeyHash);
    }

    function test_ReturnTrueIfKeyHasGivenPurpose() public view {
        bool hasPurpose = aliceIdentity.keyHasPurpose(aliceKeyHash, KeyPurposes.MANAGEMENT);

        assertTrue(hasPurpose);
    }

    function test_ReturnTrueIfKeyIsManagementKeyButNotGivenPurpose() public view {
        // MANAGEMENT keys have universal permissions, so they return true for any purpose
        bool hasPurpose = aliceIdentity.keyHasPurpose(aliceKeyHash, KeyPurposes.ACTION);

        assertTrue(hasPurpose);
    }

    function test_ReturnFalseIfKeyDoesNotHaveGivenPurpose() public view {
        bool hasPurpose = aliceIdentity.keyHasPurpose(bobKeyHash, KeyPurposes.ACTION);

        assertFalse(hasPurpose);
    }

    // ============ Add key methods - Non-Management key ============

    function test_RevertAddKey_WhenCallerIsNotManagementKey() public {
        vm.expectRevert(Errors.SenderDoesNotHaveManagementKey.selector);
        vm.prank(bob);
        aliceIdentity.addKey(bobKeyHash, KeyPurposes.MANAGEMENT, KeyTypes.ECDSA);
    }

    // ============ Add key methods - Management key ============

    function test_AddPurposeToExistingKey() public {
        vm.prank(alice);
        aliceIdentity.addKey(aliceKeyHash, KeyPurposes.ACTION, KeyTypes.ECDSA);

        (uint256[] memory purposes, uint256 keyType, bytes32 key) = aliceIdentity.getKey(aliceKeyHash);

        assertEq(key, aliceKeyHash);
        assertEq(purposes.length, 2);
        assertEq(purposes[0], KeyPurposes.MANAGEMENT);
        assertEq(purposes[1], KeyPurposes.ACTION);
        assertEq(keyType, KeyTypes.ECDSA);
    }

    function test_AddNewKeyWithPurpose() public {
        vm.prank(alice);
        aliceIdentity.addKey(bobKeyHash, KeyPurposes.MANAGEMENT, KeyTypes.ECDSA);

        (uint256[] memory purposes, uint256 keyType, bytes32 key) = aliceIdentity.getKey(bobKeyHash);

        assertEq(key, bobKeyHash);
        assertEq(purposes.length, 1);
        assertEq(purposes[0], KeyPurposes.MANAGEMENT);
        assertEq(keyType, KeyTypes.ECDSA);
    }

    function test_RevertAddKey_WhenKeyAlreadyHasPurpose() public {
        vm.expectRevert(
            abi.encodeWithSelector(Errors.KeyAlreadyHasPurpose.selector, aliceKeyHash, KeyPurposes.MANAGEMENT)
        );
        vm.prank(alice);
        aliceIdentity.addKey(aliceKeyHash, KeyPurposes.MANAGEMENT, KeyTypes.ECDSA);
    }

    // ============ Remove key methods - Non-Management key ============

    function test_RevertRemoveKey_WhenCallerIsNotManagementKey() public {
        vm.expectRevert(Errors.SenderDoesNotHaveManagementKey.selector);
        vm.prank(bob);
        aliceIdentity.removeKey(aliceKeyHash, KeyPurposes.MANAGEMENT);
    }

    // ============ Remove key methods - Management key ============

    function test_RemovePurposeFromExistingKey() public {
        vm.prank(alice);
        aliceIdentity.removeKey(aliceKeyHash, KeyPurposes.MANAGEMENT);

        (uint256[] memory purposes, uint256 keyType, bytes32 key) = aliceIdentity.getKey(aliceKeyHash);

        assertEq(key, bytes32(0));
        assertEq(purposes.length, 0);
        assertEq(keyType, 0);
    }

    function test_RevertRemoveKey_WhenKeyDoesNotExist() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.KeyNotRegistered.selector, bobKeyHash));
        vm.prank(alice);
        aliceIdentity.removeKey(bobKeyHash, KeyPurposes.ACTION);
    }

    function test_RevertRemoveKey_WhenKeyDoesNotHavePurpose() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.KeyDoesNotHavePurpose.selector, aliceKeyHash, KeyPurposes.ACTION));
        vm.prank(alice);
        aliceIdentity.removeKey(aliceKeyHash, KeyPurposes.ACTION);
    }

    function test_RemoveKeyFromPurposeArray() public {
        // Add bob as MANAGEMENT + ACTION key
        vm.startPrank(alice);
        aliceIdentity.addKey(bobKeyHash, KeyPurposes.MANAGEMENT, KeyTypes.ECDSA);
        aliceIdentity.addKey(bobKeyHash, KeyPurposes.ACTION, KeyTypes.ECDSA);

        // Remove MANAGEMENT purpose
        aliceIdentity.removeKey(bobKeyHash, KeyPurposes.MANAGEMENT);
        vm.stopPrank();

        // Verify the key still has ACTION purpose only
        (uint256[] memory purposes, uint256 keyType, bytes32 key) = aliceIdentity.getKey(bobKeyHash);

        assertEq(key, bobKeyHash);
        assertEq(purposes.length, 1);
        assertEq(purposes[0], KeyPurposes.ACTION);
        assertEq(keyType, KeyTypes.ECDSA);
    }

    // ============ Remove key - edge cases ============

    /// @notice Remove the only key for a given purpose
    function test_RemoveOnlyKeyForPurpose() public {
        // carol has CLAIM_SIGNER only on aliceIdentity (added in setUp)
        bytes32 carolKeyHash = ClaimSignerHelper.addressToKey(carol);

        // Remove carol's CLAIM_SIGNER purpose
        vm.prank(alice);
        aliceIdentity.removeKey(carolKeyHash, KeyPurposes.CLAIM_SIGNER);

        // Verify carol no longer has CLAIM_SIGNER purpose
        assertFalse(aliceIdentity.keyHasPurpose(carolKeyHash, KeyPurposes.CLAIM_SIGNER));
    }

    /// @notice Remove a key's only purpose — key should be fully deleted
    function test_RemoveKeyWithSinglePurpose() public {
        // david has ACTION only on aliceIdentity (added in setUp)
        bytes32 davidKeyHash = ClaimSignerHelper.addressToKey(david);

        // david has exactly one purpose (ACTION)
        uint256[] memory purposes = aliceIdentity.getKeyPurposes(davidKeyHash);
        assertEq(purposes.length, 1, "David should have exactly 1 purpose");

        // Remove ACTION purpose
        vm.prank(alice);
        aliceIdentity.removeKey(davidKeyHash, KeyPurposes.ACTION);

        // Key should be fully deleted
        (, uint256 keyType2, bytes32 key2) = aliceIdentity.getKey(davidKeyHash);
        assertEq(key2, bytes32(0), "Key should be deleted");
        assertEq(keyType2, 0, "Key type should be 0");
    }
}
