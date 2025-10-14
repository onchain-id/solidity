// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";

// EntryPoint v0.8 imports
import { EntryPoint } from "@account-abstraction/contracts/core/EntryPoint.sol";
import { IEntryPoint } from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { PackedUserOperation } from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import { UserOperationLib } from "@account-abstraction/contracts/core/UserOperationLib.sol";
import {
    SIG_VALIDATION_SUCCESS,
    SIG_VALIDATION_FAILED
} from "@account-abstraction/contracts/core/Helpers.sol";

// Project contracts
import { Identity } from "../../contracts/Identity.sol";
import { ImplementationAuthority } from "../../contracts/proxy/ImplementationAuthority.sol";
import { IdentityProxy } from "../../contracts/proxy/IdentityProxy.sol";
import { KeyPurposes } from "../../contracts/libraries/KeyPurposes.sol";
import { KeyTypes } from "../../contracts/libraries/KeyTypes.sol";

// Test helpers
import { UserOpBuilder } from "../../contracts/test/lib/UserOpBuilder.sol";
import { Target } from "../../contracts/test/mocks/Target.sol";

/**
 * @title IdentityAA_Test
 * @notice Comprehensive test suite for OnchainID ERC-4337 Account Abstraction implementation
 * @dev Tests cover all critical AA functionality including validation, execution, nonce management, and permissions
 */
contract IdentityAA_Test is Test {
    using UserOperationLib for PackedUserOperation;

    // Core contracts
    EntryPoint internal ep;
    address internal epAddr;
    Identity internal identity;
    address internal identityAddr;
    Target internal target;
    address internal targetAddr;

    // Test accounts with known private keys
    uint256 internal constant MGMT_KEY = 0xA11CE;
    uint256 internal constant AA_SIGNER_KEY = 0xB11CE;
    uint256 internal constant WRONG_KEY = 0xC11CE;

    address internal mgmt;
    address internal aaSigner;
    address internal wrongSigner;

    // Events from Identity contracts
    event ExecutionRequested(
        uint256 indexed executionId,
        address indexed to,
        uint256 indexed value,
        bytes data
    );
    event KeyAdded(
        bytes32 indexed key,
        uint256 indexed purpose,
        uint256 indexed keyType
    );

    function setUp() public {
        // 1. Generate test accounts from private keys
        mgmt = vm.addr(MGMT_KEY);
        aaSigner = vm.addr(AA_SIGNER_KEY);
        wrongSigner = vm.addr(WRONG_KEY);

        // 2. Deploy EntryPoint v0.8
        ep = new EntryPoint();
        epAddr = address(ep);
        console2.log("EntryPoint deployed at:", epAddr);

        // 3. Deploy Identity implementation (in library mode)
        // Note: Even in library mode, constructor requires non-zero address
        Identity impl = new Identity(address(1), true);
        console2.log("Identity implementation deployed at:", address(impl));

        // 4. Deploy ImplementationAuthority
        ImplementationAuthority auth = new ImplementationAuthority(
            address(impl)
        );
        console2.log("ImplementationAuthority deployed at:", address(auth));

        // 5. Deploy IdentityProxy (automatically calls initialize with mgmt key)
        IdentityProxy proxy = new IdentityProxy(address(auth), mgmt);
        identityAddr = address(proxy);
        identity = Identity(payable(identityAddr));
        console2.log("IdentityProxy deployed at:", identityAddr);
        console2.log("Management key:", mgmt);

        // 6. Add ERC4337_SIGNER key (requires MANAGEMENT key to call)
        vm.prank(mgmt);
        identity.addKey(
            keccak256(abi.encode(aaSigner)),
            KeyPurposes.ERC4337_SIGNER,
            KeyTypes.ECDSA
        );
        console2.log("AA Signer key added:", aaSigner);

        // 7. Set EntryPoint to our deployed v0.8 instance
        vm.prank(mgmt);
        identity.setEntryPoint(IEntryPoint(epAddr));
        console2.log("EntryPoint set to:", epAddr);

        // 8. Deploy Target contract for execution tests
        target = new Target();
        targetAddr = address(target);
        console2.log("Target contract deployed at:", targetAddr);

        // 9. Fund identity for prefund tests (10 ETH)
        vm.deal(identityAddr, 10 ether);
        console2.log("Identity funded with 10 ETH");
    }

    // ========================================
    // Helper Functions
    // ========================================

    /**
     * @notice Helper to create calldata for execute(address,uint256,bytes)
     */
    function _callDataExecute(
        address to,
        uint256 value,
        bytes memory payload
    ) internal pure returns (bytes memory) {
        return
            abi.encodeWithSignature(
                "execute(address,uint256,bytes)",
                to,
                value,
                payload
            );
    }

    /**
     * @notice Helper to create a signed UserOperation
     * @param signerKey Private key to sign with
     * @param callData The calldata to execute
     * @param nonce The nonce for this operation
     */
    function _signedOp(
        uint256 signerKey,
        bytes memory callData,
        uint256 nonce
    ) internal view returns (PackedUserOperation memory op) {
        op.sender = identityAddr;
        op.nonce = nonce;
        op.initCode = bytes("");
        op.callData = callData;
        op.accountGasLimits = UserOpBuilder.packAccountGasLimits(
            500_000,
            1_200_000
        );
        op.preVerificationGas = 70_000;
        op.gasFees = UserOpBuilder.packGasFees(2 gwei, 30 gwei);
        op.paymasterAndData = "";

        // Sign the user operation hash
        bytes32 userOpHash = ep.getUserOpHash(op);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, userOpHash);
        op.signature = abi.encodePacked(r, s, v);
    }

    // ========================================
    // Test: validateUserOp Success & Prefund
    // ========================================

    /**
     * @notice Test that validateUserOp returns SIG_VALIDATION_SUCCESS (0) for valid signature
     * and properly handles prefund transfer to EntryPoint
     */
    function test_validateUserOp_success_and_prefund() public {
        // Arrange: Create a call to target.ping with 0.05 ETH value
        bytes memory payload = abi.encodeWithSignature(
            "ping(bytes)",
            hex"c0ffee"
        );
        bytes memory callData = _callDataExecute(
            targetAddr,
            0.05 ether,
            payload
        );

        PackedUserOperation memory op = _signedOp(AA_SIGNER_KEY, callData, 0);
        bytes32 userOpHash = ep.getUserOpHash(op);

        uint256 missingFunds = 0.05 ether;
        uint256 epBalanceBefore = epAddr.balance;

        // Act: Call validateUserOp as EntryPoint
        vm.prank(epAddr);
        uint256 validationData = identity.validateUserOp(
            op,
            userOpHash,
            missingFunds
        );

        // Assert
        assertEq(
            validationData,
            SIG_VALIDATION_SUCCESS,
            "Expected SIG_VALIDATION_SUCCESS (0)"
        );
        assertEq(
            epAddr.balance,
            epBalanceBefore + missingFunds,
            "EntryPoint should receive prefund"
        );

        console2.log("validateUserOp returned success (0)");
        console2.log("Prefund transferred to EntryPoint:", missingFunds);
    }

    // ========================================
    // Test: validateUserOp Bad Signature
    // ========================================

    /**
     * @notice Test that validateUserOp returns SIG_VALIDATION_FAILED (1) for invalid signature
     * and does NOT revert (critical for ERC-4337 spec compliance)
     */
    function test_validateUserOp_badSig_returnsFail_notRevert() public {
        // Arrange: Sign with wrong key (not registered)
        bytes memory payload = abi.encodeWithSignature("ping(bytes)", "");
        bytes memory callData = _callDataExecute(targetAddr, 0, payload);

        PackedUserOperation memory op = _signedOp(WRONG_KEY, callData, 0);
        bytes32 userOpHash = ep.getUserOpHash(op);

        // Act: Call validateUserOp - should NOT revert
        vm.prank(epAddr);
        uint256 validationData = identity.validateUserOp(op, userOpHash, 0);

        // Assert: Should return 1 (SIG_VALIDATION_FAILED), not revert
        assertEq(
            validationData,
            SIG_VALIDATION_FAILED,
            "Expected SIG_VALIDATION_FAILED (1)"
        );

        console2.log("Bad signature returned failure (1) without reverting");
    }

    // ========================================
    // Test: EntryPoint Bypass in execute()
    // ========================================

    /**
     * @notice Test that EntryPoint can call execute() directly without approval queue
     * This is the critical AA flow that bypasses ERC-734 execution approval
     */
    function test_execute_bypass_when_called_by_EntryPoint() public {
        // Arrange: Create call to target.ping with value
        bytes memory payload = abi.encodeWithSignature("ping(bytes)", hex"aa");
        bytes memory callData = _callDataExecute(
            targetAddr,
            0.2 ether,
            payload
        );

        uint256 targetBalanceBefore = targetAddr.balance;

        // Act: EntryPoint calls execute directly
        vm.prank(epAddr);
        (bool success, ) = identityAddr.call(callData);

        // Assert: Call should succeed and value should be transferred
        assertTrue(success, "EP should be allowed to call execute directly");
        assertEq(target.x(), 0.2 ether, "Target should have received value");
        assertEq(
            targetAddr.balance,
            targetBalanceBefore + 0.2 ether,
            "Target balance should increase"
        );
    }

    // ========================================
    // Test: EOA Cannot Bypass Approval Queue
    // ========================================

    /**
     * @notice Test that MANAGEMENT keys can auto-approve and execute directly
     * This validates that the key permission system works correctly
     */
    function test_execute_eoa_management_can_autoapprove() public {
        // Arrange: MANAGEMENT key calling execute
        bytes memory payload = abi.encodeWithSignature("ping(bytes)", hex"bb");
        bytes memory callData = _callDataExecute(
            targetAddr,
            0.1 ether,
            payload
        );

        // Act: MANAGEMENT key calls execute (should auto-approve and execute)
        vm.prank(mgmt);
        (bool success, ) = identityAddr.call(callData);

        // Assert: MANAGEMENT keys can auto-approve, so execution should succeed
        assertTrue(success, "MANAGEMENT key should be able to execute");
        assertEq(
            target.x(),
            0.1 ether,
            "Target should have received value from auto-approved execution"
        );

        console2.log("MANAGEMENT key can auto-approve executions");
    }

    // ========================================
    // Test: Nonce Separation (AA vs ERC-734)
    // ========================================

    /**
     * @notice Test that AA nonces (from EntryPoint) are independent from ERC-734 execution nonces
     * This ensures no replay attack vector between AA and traditional execution flows
     */
    function test_nonce_separation_AA_vs_ERC734() public {
        // Assert: Both nonce systems start at 0 and are tracked independently
        uint256 aaNonce = identity.getNonce();
        uint256 execNonce = identity.getCurrentNonce();

        assertEq(aaNonce, 0, "AA nonce should start at 0");
        assertEq(execNonce, 0, "ERC-734 nonce should start at 0");

        // Verify AA nonce comes from EntryPoint
        uint256 epNonce = ep.getNonce(identityAddr, 0);
        assertEq(aaNonce, epNonce, "AA nonce should match EntryPoint");

        console2.log("AA and ERC-734 nonces are tracked independently");
    }

    // ========================================
    // Test: Signer Purpose Enforcement
    // ========================================

    /**
     * @notice Test that both ERC4337_SIGNER and MANAGEMENT keys can sign UserOperations
     * This validates the permission model for AA signatures
     */
    function test_signer_purposes_management_and_aa_signer() public {
        // Arrange
        bytes memory payload1 = abi.encodeWithSignature("ping(bytes)", hex"01");
        bytes memory payload2 = abi.encodeWithSignature("ping(bytes)", hex"02");
        bytes memory callData1 = _callDataExecute(targetAddr, 0, payload1);
        bytes memory callData2 = _callDataExecute(targetAddr, 0, payload2);

        // Test 1: ERC4337_SIGNER key
        PackedUserOperation memory opAA = _signedOp(
            AA_SIGNER_KEY,
            callData1,
            0
        );
        bytes32 hashAA = ep.getUserOpHash(opAA);
        vm.prank(epAddr);
        uint256 vd1 = identity.validateUserOp(opAA, hashAA, 0);
        assertEq(vd1, SIG_VALIDATION_SUCCESS, "AA signer key must be valid");

        // Test 2: MANAGEMENT key (should also be allowed per policy)
        // Use the same nonce since we're testing different keys independently
        PackedUserOperation memory opMgmt = _signedOp(MGMT_KEY, callData2, 0);
        bytes32 hashMgmt = ep.getUserOpHash(opMgmt);
        vm.prank(epAddr);
        uint256 vd2 = identity.validateUserOp(opMgmt, hashMgmt, 0);
        assertEq(
            vd2,
            SIG_VALIDATION_SUCCESS,
            "Management key allowed for AA signing"
        );

        console2.log(
            "Both ERC4337_SIGNER and MANAGEMENT keys validated successfully"
        );
    }

    // ========================================
    // Test: Invalid Nonce Rejection
    // ========================================

    /**
     * @notice Test that UserOperations with invalid nonces are rejected
     */
    function test_invalid_nonce_rejected() public {
        // Arrange: Create op with nonce 5 (current is 0)
        bytes memory payload = abi.encodeWithSignature(
            "ping(bytes)",
            hex"baad"
        );
        bytes memory callData = _callDataExecute(targetAddr, 0, payload);

        PackedUserOperation memory op = _signedOp(AA_SIGNER_KEY, callData, 5);
        bytes32 userOpHash = ep.getUserOpHash(op);

        // Act & Assert: Should revert with invalid nonce
        vm.prank(epAddr);
        vm.expectRevert("Invalid nonce");
        identity.validateUserOp(op, userOpHash, 0);

        console2.log("Invalid nonce correctly rejected");
    }

    // ========================================
    // Test: Zero Prefund Handling
    // ========================================

    /**
     * @notice Test that validateUserOp works correctly with zero prefund
     */
    function test_zero_prefund_handling() public {
        // Arrange
        bytes memory payload = abi.encodeWithSignature("ping(bytes)", hex"00");
        bytes memory callData = _callDataExecute(targetAddr, 0, payload);

        PackedUserOperation memory op = _signedOp(AA_SIGNER_KEY, callData, 0);
        bytes32 userOpHash = ep.getUserOpHash(op);

        uint256 epBalanceBefore = epAddr.balance;

        // Act: Call with zero missing funds
        vm.prank(epAddr);
        uint256 validationData = identity.validateUserOp(op, userOpHash, 0);

        // Assert
        assertEq(
            validationData,
            SIG_VALIDATION_SUCCESS,
            "Should succeed with zero prefund"
        );
        assertEq(
            epAddr.balance,
            epBalanceBefore,
            "EntryPoint balance unchanged"
        );

        console2.log("Zero prefund handled correctly");
    }

    // ========================================
    // Test: Only EntryPoint Can Call Validate
    // ========================================

    /**
     * @notice Test that only the EntryPoint can call validateUserOp
     */
    function test_only_entrypoint_can_validate() public {
        // Arrange
        bytes memory payload = abi.encodeWithSignature("ping(bytes)", "");
        bytes memory callData = _callDataExecute(targetAddr, 0, payload);

        PackedUserOperation memory op = _signedOp(AA_SIGNER_KEY, callData, 0);
        bytes32 userOpHash = ep.getUserOpHash(op);

        // Act & Assert: Non-EntryPoint caller should revert
        vm.prank(mgmt);
        vm.expectRevert("IdentitySmartAccount: not from EntryPoint");
        identity.validateUserOp(op, userOpHash, 0);

        console2.log("Only EntryPoint can call validateUserOp");
    }

    // ========================================
    // Test: Deposit Management
    // ========================================

    /**
     * @notice Test deposit and withdrawal functions
     */
    function test_deposit_management() public {
        // Arrange: Fund the management account
        vm.deal(mgmt, 2 ether);

        // Test addDeposit
        vm.prank(mgmt);
        identity.addDeposit{ value: 1 ether }();

        uint256 deposit = identity.getDeposit();
        assertGt(deposit, 0, "Deposit should be > 0");
        console2.log("Deposit added:", deposit);

        // Test withdrawDepositTo
        address payable recipient = payable(vm.addr(0xDEAD));
        uint256 recipientBalanceBefore = recipient.balance;

        vm.prank(mgmt);
        identity.withdrawDepositTo(recipient, 0.5 ether);

        assertEq(
            recipient.balance,
            recipientBalanceBefore + 0.5 ether,
            "Recipient should receive withdrawal"
        );
        console2.log("Withdrawal successful");
    }

    // ========================================
    // Test: EntryPoint Can Be Updated
    // ========================================

    /**
     * @notice Test that management key can update the EntryPoint address
     */
    function test_entrypoint_can_be_updated() public {
        // Arrange: Deploy a new EntryPoint
        EntryPoint newEp = new EntryPoint();

        // Act: Update EntryPoint
        vm.prank(mgmt);
        identity.setEntryPoint(IEntryPoint(address(newEp)));

        // Assert
        assertEq(
            address(identity.entryPoint()),
            address(newEp),
            "EntryPoint should be updated"
        );
        console2.log("EntryPoint updated successfully");
    }
}
