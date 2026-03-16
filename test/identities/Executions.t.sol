// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import { ClaimSignerHelper } from "../helpers/ClaimSignerHelper.sol";
import { OnchainIDSetup } from "../helpers/OnchainIDSetup.sol";
import { Identity } from "contracts/Identity.sol";
import { KeyManager } from "contracts/KeyManager.sol";
import { IERC734 } from "contracts/interface/IERC734.sol";
import { IERC735 } from "contracts/interface/IERC735.sol";
import { Errors } from "contracts/libraries/Errors.sol";
import { KeyPurposes } from "contracts/libraries/KeyPurposes.sol";
import { KeyTypes } from "contracts/libraries/KeyTypes.sol";
import { Structs } from "contracts/storage/Structs.sol";

contract ExecutionsTest is OnchainIDSetup {

    function test_getCurrentNonce_newIdentityReturnsZero() public view {
        assertEq(aliceIdentity.getCurrentNonce(), 0);
    }

    function test_getCurrentNonce_incrementsAfterExecutions() public {
        vm.deal(alice, 1 ether);

        vm.prank(alice);
        aliceIdentity.execute{ value: 10 }(carol, 10, hex"");
        assertEq(aliceIdentity.getCurrentNonce(), 1);

        vm.prank(alice);
        aliceIdentity.execute{ value: 5 }(carol, 5, hex"");
        assertEq(aliceIdentity.getCurrentNonce(), 2);
    }

    function test_getExecutionData_validExecutionId() public {
        vm.deal(alice, 1 ether);

        uint256 executionId = aliceIdentity.getCurrentNonce();
        vm.prank(alice);
        aliceIdentity.execute{ value: 10 }(carol, 10, hex"123456");

        Structs.Execution memory exec = aliceIdentity.getExecutionData(executionId);

        assertEq(exec.to, carol);
        assertEq(exec.value, 10);
        assertEq(exec.data, hex"123456");
        assertTrue(exec.approved);
        assertTrue(exec.executed);
    }

    function test_getExecutionData_pendingExecution() public {
        vm.deal(bob, 1 ether);

        // Give bob a PROPOSER key on alice's identity so he can call execute
        vm.prank(alice);
        aliceIdentity.addKey(keccak256(abi.encode(bob)), KeyPurposes.PROPOSER, KeyTypes.ECDSA);

        uint256 executionId = aliceIdentity.getCurrentNonce();
        vm.prank(bob);
        aliceIdentity.execute{ value: 10 }(carol, 10, hex"123456");

        Structs.Execution memory exec = aliceIdentity.getExecutionData(executionId);

        assertEq(exec.to, carol);
        assertEq(exec.value, 10);
        assertEq(exec.data, hex"123456");
        assertFalse(exec.approved);
        assertFalse(exec.executed);
    }

    function test_getExecutionData_nonExistentId() public view {
        Structs.Execution memory exec = aliceIdentity.getExecutionData(999);

        assertEq(exec.to, address(0));
        assertEq(exec.value, 0);
        assertEq(exec.data.length, 0);
        assertFalse(exec.approved);
        assertFalse(exec.executed);
    }

    function test_nestedExecute_claimIssuerAsManagementKey_immediateExecution() public {
        // Add claimIssuer as MANAGEMENT key on alice's identity
        bytes32 claimIssuerKeyHash = keccak256(abi.encode(address(claimIssuer)));
        vm.prank(alice);
        aliceIdentity.addKey(claimIssuerKeyHash, KeyPurposes.MANAGEMENT, KeyTypes.ECDSA);

        // Build claim
        ClaimSignerHelper.Claim memory claim = ClaimSignerHelper.buildClaim(
            claimIssuerOwnerPk, address(aliceIdentity), address(claimIssuer), 42, hex"0042", "https://example.com"
        );

        // Encode inner action: addClaim on aliceIdentity
        bytes memory innerData = abi.encodeCall(
            Identity.addClaim, (claim.topic, claim.scheme, claim.issuer, claim.signature, claim.data, claim.uri)
        );

        // Encode outer action: execute inner on aliceIdentity from claimIssuer
        bytes memory outerData = abi.encodeCall(KeyManager.execute, (address(aliceIdentity), 0, innerData));

        // ClaimIssuer owner executes outer on claimIssuer
        vm.prank(claimIssuerOwner);
        claimIssuer.execute(address(aliceIdentity), 0, outerData);

        // Verify claim was added
        bytes32 claimId = keccak256(abi.encode(claim.issuer, claim.topic));
        bytes32[] memory claimIds = aliceIdentity.getClaimIdsByTopic(42);
        assertEq(claimIds.length, 1);
        assertEq(claimIds[0], claimId);
    }

    function test_nestedExecute_claimIssuerNotManagementKey_pendingExecution() public {
        // Add claimIssuer as PROPOSER key (not MANAGEMENT) so it can call execute
        vm.prank(alice);
        aliceIdentity.addKey(keccak256(abi.encode(address(claimIssuer))), KeyPurposes.PROPOSER, KeyTypes.ECDSA);

        // Build claim
        ClaimSignerHelper.Claim memory claim = ClaimSignerHelper.buildClaim(
            claimIssuerOwnerPk, address(aliceIdentity), address(claimIssuer), 42, hex"0042", "https://example.com"
        );

        // Encode inner action: addClaim on aliceIdentity
        bytes memory innerData = abi.encodeCall(
            Identity.addClaim, (claim.topic, claim.scheme, claim.issuer, claim.signature, claim.data, claim.uri)
        );

        // Encode outer action: execute inner on aliceIdentity from claimIssuer
        bytes memory outerData = abi.encodeCall(KeyManager.execute, (address(aliceIdentity), 0, innerData));

        // ClaimIssuer owner executes outer on claimIssuer
        vm.prank(claimIssuerOwner);
        claimIssuer.execute(address(aliceIdentity), 0, outerData);

        // Inner execution creates pending request on aliceIdentity (executionId = 0)
        Structs.Execution memory exec = aliceIdentity.getExecutionData(0);
        assertFalse(exec.approved);
        assertFalse(exec.executed);

        // Alice approves the pending execution
        vm.prank(alice);
        aliceIdentity.approve(0, true);

        // Verify claim was added
        bytes32[] memory claimIds = aliceIdentity.getClaimIdsByTopic(42);
        assertEq(claimIds.length, 1);
    }

    function test_executeAsManagement_transferValue() public {
        vm.deal(alice, 1 ether);
        uint256 carolBalanceBefore = carol.balance;

        vm.prank(alice);
        aliceIdentity.execute{ value: 10 }(carol, 10, hex"");

        assertEq(carol.balance, carolBalanceBefore + 10);
    }

    function test_executeAsManagement_successfulCall() public {
        bytes32 aliceKeyHash = keccak256(abi.encode(alice));

        bytes memory addKeyData =
            abi.encodeCall(KeyManager.addKey, (aliceKeyHash, KeyPurposes.CLAIM_SIGNER, KeyTypes.ECDSA));

        vm.prank(alice);
        aliceIdentity.execute(address(aliceIdentity), 0, addKeyData);

        // Verify alice's key now has both MANAGEMENT and CLAIM_SIGNER purposes
        uint256[] memory purposes = aliceIdentity.getKeyPurposes(aliceKeyHash);
        assertEq(purposes.length, 2);
        assertTrue(
            (purposes[0] == KeyPurposes.MANAGEMENT && purposes[1] == KeyPurposes.CLAIM_SIGNER)
                || (purposes[0] == KeyPurposes.CLAIM_SIGNER && purposes[1] == KeyPurposes.MANAGEMENT)
        );
    }

    function test_executeAsManagement_failingCall() public {
        bytes32 aliceKeyHash = keccak256(abi.encode(alice));

        // Try to add MANAGEMENT purpose again (duplicate — will fail)
        bytes memory addKeyData =
            abi.encodeCall(KeyManager.addKey, (aliceKeyHash, KeyPurposes.MANAGEMENT, KeyTypes.ECDSA));

        uint256 executionId = aliceIdentity.getCurrentNonce();

        vm.expectEmit(true, true, true, true, address(aliceIdentity));
        emit IERC734.ExecutionFailed(executionId, address(aliceIdentity), 0, addKeyData);

        vm.prank(alice);
        aliceIdentity.execute(address(aliceIdentity), 0, addKeyData);
    }

    function test_executeAsAction_targetIsIdentity_createsRequest() public {
        // Use a fresh address that has ONLY ACTION key (not CLAIM_SIGNER)
        address actionOnly = makeAddr("actionOnly");
        bytes32 actionOnlyKeyHash = keccak256(abi.encode(actionOnly));
        vm.prank(alice);
        aliceIdentity.addKey(actionOnlyKeyHash, KeyPurposes.ACTION, KeyTypes.ECDSA);

        // actionOnly executes addKey on aliceIdentity (ACTION key targeting self → pending request)
        bytes32 aliceKeyHash = keccak256(abi.encode(alice));
        bytes memory addKeyData = abi.encodeCall(KeyManager.addKey, (aliceKeyHash, KeyPurposes.ACTION, KeyTypes.ECDSA));

        vm.prank(actionOnly);
        aliceIdentity.execute(address(aliceIdentity), 0, addKeyData);

        // Verify execution is pending (ACTION key targeting identity = not auto-approved)
        Structs.Execution memory exec = aliceIdentity.getExecutionData(0);
        assertFalse(exec.approved);
        assertFalse(exec.executed);
    }

    function test_executeAsAction_targetIsAnotherAddress_executionFailed() public {
        // Add carol as ACTION key
        bytes32 carolKeyHash = keccak256(abi.encode(carol));
        vm.prank(alice);
        aliceIdentity.addKey(carolKeyHash, KeyPurposes.ACTION, KeyTypes.ECDSA);

        bytes32 aliceKeyHash = keccak256(abi.encode(alice));
        bytes memory addKeyData =
            abi.encodeCall(KeyManager.addKey, (aliceKeyHash, KeyPurposes.CLAIM_SIGNER, KeyTypes.ECDSA));

        vm.deal(carol, 1 ether);

        uint256 executionId = aliceIdentity.getCurrentNonce();

        vm.expectEmit(true, true, true, true, address(aliceIdentity));
        emit IERC734.ExecutionFailed(executionId, address(bobIdentity), 10, addKeyData);

        vm.prank(carol);
        aliceIdentity.execute{ value: 10 }(address(bobIdentity), 10, addKeyData);
    }

    function test_executeAsAction_targetIsAnotherAddress_success() public {
        // Add carol as ACTION key
        bytes32 carolKeyHash = keccak256(abi.encode(carol));
        vm.prank(alice);
        aliceIdentity.addKey(carolKeyHash, KeyPurposes.ACTION, KeyTypes.ECDSA);

        vm.deal(carol, 1 ether);
        uint256 davidBalanceBefore = david.balance;

        vm.prank(carol);
        aliceIdentity.execute{ value: 10 }(david, 10, hex"");

        assertEq(david.balance, davidBalanceBefore + 10);
    }

    function test_executeAsUnauthorizedKey_reverts() public {
        vm.deal(bob, 1 ether);

        // bob has no keys on aliceIdentity — should revert
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(Errors.SenderCannotPropose.selector));
        aliceIdentity.execute{ value: 10 }(carol, 10, hex"");
    }

    function test_approveNonExistingExecution() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidRequestId.selector, 2));
        aliceIdentity.approve(2, true);
    }

    function test_approveAlreadyExecuted() public {
        vm.deal(alice, 1 ether);

        vm.prank(alice);
        aliceIdentity.execute{ value: 10 }(bob, 10, hex"");

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.RequestAlreadyExecuted.selector, 0));
        aliceIdentity.approve(0, true);
    }

    function test_approveAsNonActionKey_forExternalTarget() public {
        vm.deal(bob, 1 ether);

        // Give bob a PROPOSER key so he can call execute
        vm.prank(alice);
        aliceIdentity.addKey(keccak256(abi.encode(bob)), KeyPurposes.PROPOSER, KeyTypes.ECDSA);

        // bob creates pending execution
        vm.prank(bob);
        aliceIdentity.execute{ value: 10 }(carol, 10, hex"");

        // bob tries to approve (bob has PROPOSER but not ACTION key)
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(Errors.SenderDoesNotHaveActionKey.selector, bob));
        aliceIdentity.approve(0, true);
    }

    function test_approveAsNonManagementKey_forIdentityTarget() public {
        // Give bob a PROPOSER key so he can call execute
        vm.prank(alice);
        aliceIdentity.addKey(keccak256(abi.encode(bob)), KeyPurposes.PROPOSER, KeyTypes.ECDSA);

        // bob creates pending execution targeting the identity itself
        bytes memory addKeyData = abi.encodeCall(
            KeyManager.addKey, (keccak256(abi.encode(makeAddr("newKey"))), KeyPurposes.ACTION, KeyTypes.ECDSA)
        );

        vm.deal(bob, 1 ether);
        vm.prank(bob);
        aliceIdentity.execute{ value: 10 }(address(aliceIdentity), 10, addKeyData);

        // david tries to approve (david has ACTION key but not MANAGEMENT)
        vm.prank(david);
        vm.expectRevert(abi.encodeWithSelector(Errors.SenderDoesNotHaveManagementKey.selector, david));
        aliceIdentity.approve(0, true);
    }

    function test_approveAsManagement_executesPending() public {
        vm.deal(bob, 1 ether);
        uint256 carolBalanceBefore = carol.balance;

        // Give bob a PROPOSER key so he can call execute
        vm.prank(alice);
        aliceIdentity.addKey(keccak256(abi.encode(bob)), KeyPurposes.PROPOSER, KeyTypes.ECDSA);

        // bob creates pending execution
        vm.prank(bob);
        aliceIdentity.execute{ value: 10 }(carol, 10, hex"");

        // alice approves
        vm.prank(alice);
        aliceIdentity.approve(0, true);

        assertEq(carol.balance, carolBalanceBefore + 10);
    }

    function test_approveWithFalse_doesNotExecute() public {
        vm.deal(bob, 1 ether);
        uint256 carolBalanceBefore = carol.balance;

        // Give bob a PROPOSER key so he can call execute
        vm.prank(alice);
        aliceIdentity.addKey(keccak256(abi.encode(bob)), KeyPurposes.PROPOSER, KeyTypes.ECDSA);

        // bob creates pending execution
        vm.prank(bob);
        aliceIdentity.execute{ value: 10 }(carol, 10, hex"");

        // alice approves with false
        vm.prank(alice);
        aliceIdentity.approve(0, false);

        assertEq(carol.balance, carolBalanceBefore);

        // Verify execution is finalized (not approved, but marked executed to prevent replay)
        Structs.Execution memory exec = aliceIdentity.getExecutionData(0);
        assertFalse(exec.approved);
        assertTrue(exec.executed);
    }

    function test_autoApprovalForAddClaimWithClaimSignerKey() public {
        // Add bob as CLAIM_SIGNER and PROPOSER (PROPOSER needed to call execute, CLAIM_SIGNER for auto-approval)
        bytes32 bobKeyHash = keccak256(abi.encode(bob));
        vm.startPrank(alice);
        aliceIdentity.addKey(bobKeyHash, KeyPurposes.CLAIM_SIGNER, KeyTypes.ECDSA);
        aliceIdentity.addKey(bobKeyHash, KeyPurposes.PROPOSER, KeyTypes.ECDSA);
        vm.stopPrank();

        // Build claim with claimIssuer as issuer
        ClaimSignerHelper.Claim memory claim = ClaimSignerHelper.buildClaim(
            claimIssuerOwnerPk, address(aliceIdentity), address(claimIssuer), 42, hex"0042", "https://example.com"
        );

        // Encode addClaim data
        bytes memory addClaimData = abi.encodeCall(
            Identity.addClaim, (claim.topic, claim.scheme, claim.issuer, claim.signature, claim.data, claim.uri)
        );

        // Bob (CLAIM_SIGNER) executes addClaim through execute — should auto-approve
        vm.prank(bob);
        aliceIdentity.execute(address(aliceIdentity), 0, addClaimData);

        // Verify claim was added (auto-approved and executed)
        bytes32 claimId = keccak256(abi.encode(claim.issuer, claim.topic));
        bytes32[] memory claimIds = aliceIdentity.getClaimIdsByTopic(42);
        assertEq(claimIds.length, 1);
        assertEq(claimIds[0], claimId);
    }

    // ========= Proposer Key Tests =========

    function test_executeAsProposer_createsPendingExternalRequest() public {
        address proposer = makeAddr("proposer");
        bytes32 proposerKeyHash = keccak256(abi.encode(proposer));
        vm.prank(alice);
        aliceIdentity.addKey(proposerKeyHash, KeyPurposes.PROPOSER, KeyTypes.ECDSA);

        vm.deal(proposer, 1 ether);
        uint256 carolBalanceBefore = carol.balance;

        vm.prank(proposer);
        aliceIdentity.execute{ value: 10 }(carol, 10, hex"");

        // Proposer key should NOT auto-approve — execution is pending
        Structs.Execution memory exec = aliceIdentity.getExecutionData(0);
        assertFalse(exec.approved);
        assertFalse(exec.executed);
        assertEq(carol.balance, carolBalanceBefore);
    }

    function test_executeAsProposer_createsPendingInternalRequest() public {
        address proposer = makeAddr("proposer");
        bytes32 proposerKeyHash = keccak256(abi.encode(proposer));
        vm.prank(alice);
        aliceIdentity.addKey(proposerKeyHash, KeyPurposes.PROPOSER, KeyTypes.ECDSA);

        bytes memory addKeyData = abi.encodeCall(
            KeyManager.addKey, (keccak256(abi.encode(makeAddr("newKey"))), KeyPurposes.ACTION, KeyTypes.ECDSA)
        );

        vm.prank(proposer);
        aliceIdentity.execute(address(aliceIdentity), 0, addKeyData);

        // Proposer key should NOT auto-approve internal calls either
        Structs.Execution memory exec = aliceIdentity.getExecutionData(0);
        assertFalse(exec.approved);
        assertFalse(exec.executed);
    }

    function test_approveAsProposerOnly_revertsForInternal() public {
        address proposer = makeAddr("proposer");
        bytes32 proposerKeyHash = keccak256(abi.encode(proposer));
        vm.prank(alice);
        aliceIdentity.addKey(proposerKeyHash, KeyPurposes.PROPOSER, KeyTypes.ECDSA);

        // Proposer creates a pending internal execution
        bytes memory addKeyData = abi.encodeCall(
            KeyManager.addKey, (keccak256(abi.encode(makeAddr("newKey"))), KeyPurposes.ACTION, KeyTypes.ECDSA)
        );
        vm.prank(proposer);
        aliceIdentity.execute(address(aliceIdentity), 0, addKeyData);

        // Proposer tries to approve — should revert (no MANAGEMENT key)
        vm.prank(proposer);
        vm.expectRevert(abi.encodeWithSelector(Errors.SenderDoesNotHaveManagementKey.selector, proposer));
        aliceIdentity.approve(0, true);
    }

    function test_approveAsProposerOnly_revertsForExternal() public {
        address proposer = makeAddr("proposer");
        bytes32 proposerKeyHash = keccak256(abi.encode(proposer));
        vm.prank(alice);
        aliceIdentity.addKey(proposerKeyHash, KeyPurposes.PROPOSER, KeyTypes.ECDSA);

        vm.deal(proposer, 1 ether);
        vm.prank(proposer);
        aliceIdentity.execute{ value: 10 }(carol, 10, hex"");

        // Proposer tries to approve — should revert (no ACTION key)
        vm.prank(proposer);
        vm.expectRevert(abi.encodeWithSelector(Errors.SenderDoesNotHaveActionKey.selector, proposer));
        aliceIdentity.approve(0, true);
    }

    function test_proposerWithManagement_canAutoApprove() public {
        address proposerManager = makeAddr("proposerManager");
        bytes32 keyHash = keccak256(abi.encode(proposerManager));
        vm.startPrank(alice);
        aliceIdentity.addKey(keyHash, KeyPurposes.MANAGEMENT, KeyTypes.ECDSA);
        aliceIdentity.addKey(keyHash, KeyPurposes.PROPOSER, KeyTypes.ECDSA);
        vm.stopPrank();

        vm.deal(proposerManager, 1 ether);
        uint256 carolBalanceBefore = carol.balance;

        vm.prank(proposerManager);
        aliceIdentity.execute{ value: 10 }(carol, 10, hex"");

        // MANAGEMENT takes precedence — should auto-approve
        Structs.Execution memory exec = aliceIdentity.getExecutionData(0);
        assertTrue(exec.approved);
        assertTrue(exec.executed);
        assertEq(carol.balance, carolBalanceBefore + 10);
    }

    function test_proposerWithAction_canAutoApproveExternal() public {
        address proposerAction = makeAddr("proposerAction");
        bytes32 keyHash = keccak256(abi.encode(proposerAction));
        vm.startPrank(alice);
        aliceIdentity.addKey(keyHash, KeyPurposes.ACTION, KeyTypes.ECDSA);
        aliceIdentity.addKey(keyHash, KeyPurposes.PROPOSER, KeyTypes.ECDSA);
        vm.stopPrank();

        vm.deal(proposerAction, 1 ether);
        uint256 carolBalanceBefore = carol.balance;

        vm.prank(proposerAction);
        aliceIdentity.execute{ value: 10 }(carol, 10, hex"");

        // ACTION key auto-approves external calls
        Structs.Execution memory exec = aliceIdentity.getExecutionData(0);
        assertTrue(exec.approved);
        assertTrue(exec.executed);
        assertEq(carol.balance, carolBalanceBefore + 10);
    }

    function test_addAndRemoveProposerKey() public {
        address proposer = makeAddr("proposer");
        bytes32 proposerKeyHash = keccak256(abi.encode(proposer));

        // Add PROPOSER key
        vm.prank(alice);
        aliceIdentity.addKey(proposerKeyHash, KeyPurposes.PROPOSER, KeyTypes.ECDSA);

        // Verify key exists and has PROPOSER purpose
        assertTrue(aliceIdentity.keyHasPurpose(proposerKeyHash, KeyPurposes.PROPOSER));
        bytes32[] memory proposerKeys = aliceIdentity.getKeysByPurpose(KeyPurposes.PROPOSER);
        assertEq(proposerKeys.length, 1);
        assertEq(proposerKeys[0], proposerKeyHash);

        // Verify getKey returns correct data
        (uint256[] memory purposes, uint256 keyType, bytes32 key) = aliceIdentity.getKey(proposerKeyHash);
        assertEq(key, proposerKeyHash);
        assertEq(keyType, KeyTypes.ECDSA);
        assertEq(purposes.length, 1);
        assertEq(purposes[0], KeyPurposes.PROPOSER);

        // Remove PROPOSER key
        vm.prank(alice);
        aliceIdentity.removeKey(proposerKeyHash, KeyPurposes.PROPOSER);

        // Verify key is removed
        assertFalse(aliceIdentity.keyHasPurpose(proposerKeyHash, KeyPurposes.PROPOSER));
        proposerKeys = aliceIdentity.getKeysByPurpose(KeyPurposes.PROPOSER);
        assertEq(proposerKeys.length, 0);
    }

    function test_executeAsClaimSignerOnly_reverts() public {
        // carol already has CLAIM_SIGNER on aliceIdentity from setup
        // CLAIM_SIGNER alone cannot call execute — needs PROPOSER, MANAGEMENT, or ACTION
        vm.prank(carol);
        vm.expectRevert(abi.encodeWithSelector(Errors.SenderCannotPropose.selector));
        aliceIdentity.execute(address(aliceIdentity), 0, hex"");
    }

    function test_executeAsEncryptionOnly_reverts() public {
        address encKey = makeAddr("encKey");
        vm.prank(alice);
        aliceIdentity.addKey(keccak256(abi.encode(encKey)), KeyPurposes.ENCRYPTION, KeyTypes.ECDSA);

        vm.prank(encKey);
        vm.expectRevert(abi.encodeWithSelector(Errors.SenderCannotPropose.selector));
        aliceIdentity.execute(carol, 0, hex"");
    }

    function test_multicallWithMixedApproveReject() public {
        // Add bob as ACTION key
        bytes32 bobKeyHash = keccak256(abi.encode(bob));
        vm.prank(alice);
        aliceIdentity.addKey(bobKeyHash, KeyPurposes.ACTION, KeyTypes.ECDSA);

        // Get current nonce to derive execution IDs
        uint256 startNonce = aliceIdentity.getCurrentNonce();

        // Create 3 execute calls (each adding a different key)
        bytes32 key1 = keccak256(abi.encode(makeAddr("key1")));
        bytes32 key2 = keccak256(abi.encode(makeAddr("key2")));
        bytes32 key3 = keccak256(abi.encode(makeAddr("key3")));

        bytes memory addKey1Data = abi.encodeCall(KeyManager.addKey, (key1, KeyPurposes.ACTION, KeyTypes.ECDSA));
        bytes memory addKey2Data = abi.encodeCall(KeyManager.addKey, (key2, KeyPurposes.ACTION, KeyTypes.ECDSA));
        bytes memory addKey3Data = abi.encodeCall(KeyManager.addKey, (key3, KeyPurposes.ACTION, KeyTypes.ECDSA));

        bytes[] memory executeCalls = new bytes[](3);
        executeCalls[0] = abi.encodeCall(KeyManager.execute, (address(aliceIdentity), 0, addKey1Data));
        executeCalls[1] = abi.encodeCall(KeyManager.execute, (address(aliceIdentity), 0, addKey2Data));
        executeCalls[2] = abi.encodeCall(KeyManager.execute, (address(aliceIdentity), 0, addKey3Data));

        // bob multicalls to create 3 pending executions
        vm.prank(bob);
        aliceIdentity.multicall(executeCalls);

        // Execution IDs will be startNonce, startNonce+1, startNonce+2
        uint256 exec1 = startNonce;
        uint256 exec2 = startNonce + 1;
        uint256 exec3 = startNonce + 2;

        // Encode 3 approve calls (true, false, true)
        bytes[] memory approveCalls = new bytes[](3);
        approveCalls[0] = abi.encodeCall(KeyManager.approve, (exec1, true));
        approveCalls[1] = abi.encodeCall(KeyManager.approve, (exec2, false));
        approveCalls[2] = abi.encodeCall(KeyManager.approve, (exec3, true));

        // alice multicalls to approve
        vm.prank(alice);
        aliceIdentity.multicall(approveCalls);

        // Verify exec1: approved and executed
        Structs.Execution memory execData1 = aliceIdentity.getExecutionData(exec1);
        assertTrue(execData1.approved);
        assertTrue(execData1.executed);
        assertTrue(aliceIdentity.keyHasPurpose(key1, KeyPurposes.ACTION));

        // Verify exec2: not approved, but finalized (executed=true to prevent replay)
        Structs.Execution memory execData2 = aliceIdentity.getExecutionData(exec2);
        assertFalse(execData2.approved);
        assertTrue(execData2.executed);
        assertFalse(aliceIdentity.keyHasPurpose(key2, KeyPurposes.ACTION));

        // Verify exec3: approved and executed
        Structs.Execution memory execData3 = aliceIdentity.getExecutionData(exec3);
        assertTrue(execData3.approved);
        assertTrue(execData3.executed);
        assertTrue(aliceIdentity.keyHasPurpose(key3, KeyPurposes.ACTION));
    }

}
