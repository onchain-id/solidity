// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import { ClaimSignerHelper } from "../helpers/ClaimSignerHelper.sol";
import { OnchainIDSetup } from "../helpers/OnchainIDSetup.sol";
import { Identity } from "contracts/Identity.sol";
import { KeyManager } from "contracts/KeyManager.sol";
import { KeyPurposes } from "contracts/libraries/KeyPurposes.sol";
import { KeyTypes } from "contracts/libraries/KeyTypes.sol";

contract PendingExecutionsTest is OnchainIDSetup {

    // ========= Empty state =========

    function test_getPendingExecutionsBySelector_emptyInitially() public view {
        uint256[] memory ids = aliceIdentity.getPendingExecutionsBySelector(KeyManager.addKey.selector);
        assertEq(ids.length, 0);
    }

    // ========= Auto-approved executions are NOT indexed =========

    function test_autoApproved_managementKey_notIndexed() public {
        bytes32 newKey = keccak256(abi.encode(makeAddr("newKey")));
        bytes memory addKeyData = abi.encodeCall(KeyManager.addKey, (newKey, KeyPurposes.ACTION, KeyTypes.ECDSA));

        vm.prank(alice);
        aliceIdentity.execute(address(aliceIdentity), 0, addKeyData);

        uint256[] memory ids = aliceIdentity.getPendingExecutionsBySelector(KeyManager.addKey.selector);
        assertEq(ids.length, 0, "Auto-approved execution should not be in pending set");
    }

    function test_autoApproved_claimSignerKey_addClaim_notIndexed() public {
        // carol is already CLAIM_SIGNER on aliceIdentity (from setup)
        ClaimSignerHelper.Claim memory claim = ClaimSignerHelper.buildClaim(
            claimIssuerOwnerPk, address(aliceIdentity), address(claimIssuer), 42, hex"0042", "https://example.com"
        );
        bytes memory addClaimData = abi.encodeCall(
            Identity.addClaim, (claim.topic, claim.scheme, claim.issuer, claim.signature, claim.data, claim.uri)
        );

        vm.prank(carol);
        aliceIdentity.execute(address(aliceIdentity), 0, addClaimData);

        uint256[] memory ids = aliceIdentity.getPendingExecutionsBySelector(Identity.addClaim.selector);
        assertEq(ids.length, 0, "Auto-approved addClaim should not be in pending set");
    }

    function test_autoApproved_ethTransfer_notIndexed() public {
        vm.deal(alice, 1 ether);

        vm.prank(alice);
        aliceIdentity.execute{ value: 10 }(carol, 10, hex"");

        uint256[] memory ids = aliceIdentity.getPendingExecutionsBySelector(bytes4(0));
        assertEq(ids.length, 0, "Auto-approved ETH transfer should not be in pending set");
    }

    // ========= Pending executions ARE indexed =========

    function test_pendingExecution_addKey_indexed() public {
        // bob has no keys on aliceIdentity → creates pending request
        bytes32 newKey = keccak256(abi.encode(makeAddr("newKey")));
        bytes memory addKeyData = abi.encodeCall(KeyManager.addKey, (newKey, KeyPurposes.ACTION, KeyTypes.ECDSA));

        vm.prank(bob);
        uint256 execId = aliceIdentity.execute(address(aliceIdentity), 0, addKeyData);

        uint256[] memory ids = aliceIdentity.getPendingExecutionsBySelector(KeyManager.addKey.selector);
        assertEq(ids.length, 1);
        assertEq(ids[0], execId);
    }

    function test_pendingExecution_removeKey_indexed() public {
        bytes32 carolKey = keccak256(abi.encode(carol));
        bytes memory removeKeyData = abi.encodeCall(KeyManager.removeKey, (carolKey, KeyPurposes.CLAIM_SIGNER));

        vm.prank(bob);
        uint256 execId = aliceIdentity.execute(address(aliceIdentity), 0, removeKeyData);

        uint256[] memory ids = aliceIdentity.getPendingExecutionsBySelector(KeyManager.removeKey.selector);
        assertEq(ids.length, 1);
        assertEq(ids[0], execId);
    }

    function test_pendingExecution_emptyCalldata_indexedUnderZeroSelector() public {
        vm.deal(bob, 1 ether);

        vm.prank(bob);
        uint256 execId = aliceIdentity.execute{ value: 10 }(carol, 10, hex"");

        uint256[] memory ids = aliceIdentity.getPendingExecutionsBySelector(bytes4(0));
        assertEq(ids.length, 1);
        assertEq(ids[0], execId);
    }

    function test_pendingExecution_shortCalldata_indexedUnderZeroSelector() public {
        // Calldata with 1-3 bytes has no valid selector
        vm.prank(bob);
        uint256 execId = aliceIdentity.execute(address(aliceIdentity), 0, hex"aabb");

        uint256[] memory ids = aliceIdentity.getPendingExecutionsBySelector(bytes4(0));
        assertEq(ids.length, 1);
        assertEq(ids[0], execId);
    }

    // ========= Multiple pending executions =========

    function test_multiplePending_sameSelector() public {
        bytes32 key1 = keccak256(abi.encode(makeAddr("key1")));
        bytes32 key2 = keccak256(abi.encode(makeAddr("key2")));
        bytes memory data1 = abi.encodeCall(KeyManager.addKey, (key1, KeyPurposes.ACTION, KeyTypes.ECDSA));
        bytes memory data2 = abi.encodeCall(KeyManager.addKey, (key2, KeyPurposes.ACTION, KeyTypes.ECDSA));

        vm.startPrank(bob);
        uint256 execId1 = aliceIdentity.execute(address(aliceIdentity), 0, data1);
        uint256 execId2 = aliceIdentity.execute(address(aliceIdentity), 0, data2);
        vm.stopPrank();

        uint256[] memory ids = aliceIdentity.getPendingExecutionsBySelector(KeyManager.addKey.selector);
        assertEq(ids.length, 2);
        assertTrue(
            (ids[0] == execId1 && ids[1] == execId2) || (ids[0] == execId2 && ids[1] == execId1),
            "Both execution IDs should be in the set"
        );
    }

    function test_multiplePending_differentSelectors() public {
        bytes32 newKey = keccak256(abi.encode(makeAddr("newKey")));
        bytes32 carolKey = keccak256(abi.encode(carol));

        bytes memory addKeyData = abi.encodeCall(KeyManager.addKey, (newKey, KeyPurposes.ACTION, KeyTypes.ECDSA));
        bytes memory removeKeyData = abi.encodeCall(KeyManager.removeKey, (carolKey, KeyPurposes.CLAIM_SIGNER));

        vm.startPrank(bob);
        uint256 addExecId = aliceIdentity.execute(address(aliceIdentity), 0, addKeyData);
        uint256 removeExecId = aliceIdentity.execute(address(aliceIdentity), 0, removeKeyData);
        vm.stopPrank();

        uint256[] memory addKeyIds = aliceIdentity.getPendingExecutionsBySelector(KeyManager.addKey.selector);
        assertEq(addKeyIds.length, 1);
        assertEq(addKeyIds[0], addExecId);

        uint256[] memory removeKeyIds = aliceIdentity.getPendingExecutionsBySelector(KeyManager.removeKey.selector);
        assertEq(removeKeyIds.length, 1);
        assertEq(removeKeyIds[0], removeExecId);
    }

    // ========= Removal on successful execution =========

    function test_approvedSuccessfully_removedFromIndex() public {
        bytes32 newKey = keccak256(abi.encode(makeAddr("newKey")));
        bytes memory addKeyData = abi.encodeCall(KeyManager.addKey, (newKey, KeyPurposes.ACTION, KeyTypes.ECDSA));

        vm.prank(bob);
        aliceIdentity.execute(address(aliceIdentity), 0, addKeyData);

        // Verify it's in the set
        uint256[] memory idsBefore = aliceIdentity.getPendingExecutionsBySelector(KeyManager.addKey.selector);
        assertEq(idsBefore.length, 1);

        // Alice approves → execution succeeds → removed from set
        vm.prank(alice);
        aliceIdentity.approve(0, true);

        uint256[] memory idsAfter = aliceIdentity.getPendingExecutionsBySelector(KeyManager.addKey.selector);
        assertEq(idsAfter.length, 0, "Successfully executed should be removed from pending set");
    }

    function test_approvedSuccessfully_ethTransfer_removedFromIndex() public {
        vm.deal(address(aliceIdentity), 1 ether);

        vm.prank(bob);
        aliceIdentity.execute(carol, 10, hex"");

        uint256[] memory idsBefore = aliceIdentity.getPendingExecutionsBySelector(bytes4(0));
        assertEq(idsBefore.length, 1);

        // david has ACTION key → can approve external calls
        vm.prank(david);
        aliceIdentity.approve(0, true);

        uint256[] memory idsAfter = aliceIdentity.getPendingExecutionsBySelector(bytes4(0));
        assertEq(idsAfter.length, 0, "Successfully executed ETH transfer should be removed");
    }

    // ========= Stays in index on rejection and failure =========

    function test_rejected_removedFromIndex() public {
        bytes32 newKey = keccak256(abi.encode(makeAddr("newKey")));
        bytes memory addKeyData = abi.encodeCall(KeyManager.addKey, (newKey, KeyPurposes.ACTION, KeyTypes.ECDSA));

        vm.prank(bob);
        aliceIdentity.execute(address(aliceIdentity), 0, addKeyData);

        // Alice rejects → execution is finalized and removed from pending set
        vm.prank(alice);
        aliceIdentity.approve(0, false);

        uint256[] memory ids = aliceIdentity.getPendingExecutionsBySelector(KeyManager.addKey.selector);
        assertEq(ids.length, 0, "Rejected execution should be removed from pending set");
    }

    function test_approvedButCallFails_removedFromIndex() public {
        // Create execution that will fail: try to add a key that already has this purpose
        bytes32 aliceKey = keccak256(abi.encode(alice));
        bytes memory addKeyData = abi.encodeCall(KeyManager.addKey, (aliceKey, KeyPurposes.MANAGEMENT, KeyTypes.ECDSA));

        // Use an address with no keys to create pending request
        vm.prank(bob);
        aliceIdentity.execute(address(aliceIdentity), 0, addKeyData);

        // Alice approves → call fails (alice already has MANAGEMENT) → finalized and removed
        vm.prank(alice);
        aliceIdentity.approve(0, true);

        uint256[] memory ids = aliceIdentity.getPendingExecutionsBySelector(KeyManager.addKey.selector);
        assertEq(ids.length, 0, "Failed execution should be removed from pending set");
    }

    // ========= Removal preserves other entries =========

    function test_removalOfOne_preservesOthers() public {
        bytes32 key1 = keccak256(abi.encode(makeAddr("key1")));
        bytes32 key2 = keccak256(abi.encode(makeAddr("key2")));
        bytes32 key3 = keccak256(abi.encode(makeAddr("key3")));

        bytes memory data1 = abi.encodeCall(KeyManager.addKey, (key1, KeyPurposes.ACTION, KeyTypes.ECDSA));
        bytes memory data2 = abi.encodeCall(KeyManager.addKey, (key2, KeyPurposes.ACTION, KeyTypes.ECDSA));
        bytes memory data3 = abi.encodeCall(KeyManager.addKey, (key3, KeyPurposes.ACTION, KeyTypes.ECDSA));

        vm.startPrank(bob);
        uint256 execId1 = aliceIdentity.execute(address(aliceIdentity), 0, data1);
        uint256 execId2 = aliceIdentity.execute(address(aliceIdentity), 0, data2);
        uint256 execId3 = aliceIdentity.execute(address(aliceIdentity), 0, data3);
        vm.stopPrank();

        assertEq(aliceIdentity.getPendingExecutionsBySelector(KeyManager.addKey.selector).length, 3);

        // Approve execId2 (middle one) — should succeed and be removed
        vm.prank(alice);
        aliceIdentity.approve(execId2, true);

        uint256[] memory ids = aliceIdentity.getPendingExecutionsBySelector(KeyManager.addKey.selector);
        assertEq(ids.length, 2, "Should have 2 remaining after removing 1");

        // Verify the remaining IDs are execId1 and execId3
        bool hasId1 = false;
        bool hasId3 = false;
        for (uint256 i = 0; i < ids.length; i++) {
            if (ids[i] == execId1) hasId1 = true;
            if (ids[i] == execId3) hasId3 = true;
        }
        assertTrue(hasId1, "execId1 should still be in the set");
        assertTrue(hasId3, "execId3 should still be in the set");
    }

    // ========= Auto-approved failure case (management key, call fails) =========

    function test_autoApproved_callFails_notIndexed() public {
        // alice (MANAGEMENT) executes addKey with duplicate purpose → auto-approved but call fails
        bytes32 aliceKey = keccak256(abi.encode(alice));
        bytes memory addKeyData = abi.encodeCall(KeyManager.addKey, (aliceKey, KeyPurposes.MANAGEMENT, KeyTypes.ECDSA));

        vm.prank(alice);
        aliceIdentity.execute(address(aliceIdentity), 0, addKeyData);

        // Auto-approved, call failed → execution is finalized → not in pending set
        uint256[] memory ids = aliceIdentity.getPendingExecutionsBySelector(KeyManager.addKey.selector);
        assertEq(ids.length, 0, "Auto-approved but failed execution should not be in pending set");
    }

}
