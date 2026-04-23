// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import { Account as OZAccount } from "@openzeppelin/contracts/account/Account.sol";
import { PackedUserOperation } from "@openzeppelin/contracts/interfaces/draft-IERC4337.sol";

import { Identity } from "contracts/Identity.sol";
import { Errors } from "contracts/libraries/Errors.sol";
import { KeyPurposes } from "contracts/libraries/KeyPurposes.sol";
import { KeyTypes } from "contracts/libraries/KeyTypes.sol";
import { Structs } from "contracts/storage/Structs.sol";

import { ClaimSignerHelper } from "./helpers/ClaimSignerHelper.sol";
import { OnchainIDSetup } from "./helpers/OnchainIDSetup.sol";
import { MockERC1271Signer } from "./mocks/MockERC1271Signer.sol";

/// @notice A contract that always reverts, used for testing CallFailed
contract FailingContract {

    function fail() external pure {
        revert("always fails");
    }

}

/// @notice A simple counter contract used as a target for execute() tests
contract Counter {

    uint256 public count;

    function increment() external {
        count++;
    }

    function incrementBy(uint256 amount) external {
        count += amount;
    }

    receive() external payable { }

}

contract SmartAccountTest is OnchainIDSetup {

    Counter public counter;

    // ECDSA action key (david already has ACTION purpose on aliceIdentity via OnchainIDSetup)
    // Management key: alice

    function setUp() public override {
        super.setUp();
        counter = new Counter();

        // Add ACTION key for alice so we can test management key executing external calls
        vm.startPrank(alice);
        aliceIdentity.addKeyWithData(
            ClaimSignerHelper.addressToKey(alice), KeyPurposes.ACTION, KeyTypes.ECDSA, abi.encodePacked(alice), ""
        );
        vm.stopPrank();
    }

    // ========= execute() with signature =========

    function test_executeWithSignature_actionKey() public {
        bytes memory callData = abi.encodeCall(Counter.increment, ());
        uint256 nonce = aliceIdentity.getCurrentNonce();
        bytes32 opHash = aliceIdentity.getOperationHash(address(counter), 0, callData, nonce);

        // david signs the operation hash (david has ACTION key on aliceIdentity)
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(davidPk, opHash);
        bytes memory sig = abi.encodePacked(r, s, v);

        bytes32 keyHash = ClaimSignerHelper.addressToKey(david);

        // Anyone can submit (relayer pattern)
        aliceIdentity.execute(address(counter), 0, callData, keyHash, sig);

        assertEq(counter.count(), 1, "Counter should be incremented");
    }

    function test_executeWithSignature_managementKey() public {
        bytes memory callData = abi.encodeCall(Counter.increment, ());
        uint256 nonce = aliceIdentity.getCurrentNonce();
        bytes32 opHash = aliceIdentity.getOperationHash(address(counter), 0, callData, nonce);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, opHash);
        bytes memory sig = abi.encodePacked(r, s, v);

        bytes32 keyHash = keccak256(abi.encodePacked(alice));

        aliceIdentity.execute(address(counter), 0, callData, keyHash, sig);

        assertEq(counter.count(), 1, "Management key should be able to execute external calls");
    }

    function test_executeWithSignature_managementKey_selfCall() public {
        // Management key can execute self-calls (e.g., addKey via signature)
        address newAddr = makeAddr("newKey");
        bytes32 newKeyHash = keccak256(abi.encodePacked(newAddr));
        bytes memory callData = abi.encodeCall(aliceIdentity.addKey, (newKeyHash, KeyPurposes.ACTION, KeyTypes.ECDSA));
        uint256 nonce = aliceIdentity.getCurrentNonce();
        bytes32 opHash = aliceIdentity.getOperationHash(address(aliceIdentity), 0, callData, nonce);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, opHash);
        bytes memory sig = abi.encodePacked(r, s, v);

        bytes32 keyHash = keccak256(abi.encodePacked(alice));

        aliceIdentity.execute(address(aliceIdentity), 0, callData, keyHash, sig);

        assertTrue(aliceIdentity.keyHasPurpose(newKeyHash, KeyPurposes.ACTION), "New key should have ACTION purpose");
    }

    function test_executeWithSignature_claimSignerKey_notAutoApproved() public {
        // CLAIM_SIGNER key should NOT auto-approve external calls — only self-calls
        bytes memory callData = abi.encodeCall(Counter.increment, ());
        uint256 nonce = aliceIdentity.getCurrentNonce();
        bytes32 opHash = aliceIdentity.getOperationHash(address(counter), 0, callData, nonce);

        // carol has CLAIM_SIGNER on aliceIdentity (signerData set via OnchainIDSetup)
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(carolPk, opHash);
        bytes memory sig = abi.encodePacked(r, s, v);

        bytes32 keyHash = ClaimSignerHelper.addressToKey(carol);

        // Execute succeeds (no revert) but the execution is NOT auto-approved
        uint256 execId = aliceIdentity.execute(address(counter), 0, callData, keyHash, sig);

        // Counter should NOT be incremented because CLAIM_SIGNER can't auto-approve external calls
        assertEq(counter.count(), 0, "CLAIM_SIGNER should not auto-approve external calls");

        // Verify execution exists but not executed
        (address to,,, bool approved, bool executed) = _getExecutionData(execId);
        assertEq(to, address(counter));
        assertFalse(approved, "Should not be approved");
        assertFalse(executed, "Should not be executed");
    }

    function test_executeWithSignature_revertInvalidSignature() public {
        bytes memory callData = abi.encodeCall(Counter.increment, ());
        uint256 nonce = aliceIdentity.getCurrentNonce();

        // Sign with wrong key (bob doesn't have a key on alice's identity)
        bytes32 opHash = aliceIdentity.getOperationHash(address(counter), 0, callData, nonce);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(davidPk, opHash);
        bytes memory sig = abi.encodePacked(r, s, v);

        // Use david's keyHash but tamper with signature
        bytes32 keyHash = ClaimSignerHelper.addressToKey(david);
        bytes memory badSig = abi.encodePacked(s, r, v); // swapped r and s

        vm.expectRevert(Errors.InvalidSignature.selector);
        aliceIdentity.execute(address(counter), 0, callData, keyHash, badSig);
    }

    function test_executeWithSignature_revertUnregisteredKey() public {
        bytes memory callData = abi.encodeCall(Counter.increment, ());
        uint256 nonce = aliceIdentity.getCurrentNonce();
        bytes32 opHash = aliceIdentity.getOperationHash(address(counter), 0, callData, nonce);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bobPk, opHash);
        bytes memory sig = abi.encodePacked(r, s, v);

        // bob's key is not registered on alice's identity as an addressToKey
        bytes32 keyHash = keccak256(abi.encodePacked(bob));

        vm.expectRevert(abi.encodeWithSelector(Errors.KeyNotRegistered.selector, keyHash));
        aliceIdentity.execute(address(counter), 0, callData, keyHash, sig);
    }

    function test_executeWithSignature_replayProtection() public {
        bytes memory callData = abi.encodeCall(Counter.increment, ());
        uint256 nonce = aliceIdentity.getCurrentNonce();
        bytes32 opHash = aliceIdentity.getOperationHash(address(counter), 0, callData, nonce);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(davidPk, opHash);
        bytes memory sig = abi.encodePacked(r, s, v);
        bytes32 keyHash = ClaimSignerHelper.addressToKey(david);

        // First execution succeeds
        aliceIdentity.execute(address(counter), 0, callData, keyHash, sig);
        assertEq(counter.count(), 1);

        // Same signature fails — nonce has changed so the opHash is different, signature is invalid
        vm.expectRevert(Errors.InvalidSignature.selector);
        aliceIdentity.execute(address(counter), 0, callData, keyHash, sig);

        assertEq(counter.count(), 1, "Counter should not be incremented again");
    }

    function test_executeWithSignature_withValue() public {
        // Fund the identity
        vm.deal(address(aliceIdentity), 1 ether);

        uint256 nonce = aliceIdentity.getCurrentNonce();
        bytes32 opHash = aliceIdentity.getOperationHash(address(counter), 0.5 ether, "", nonce);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(davidPk, opHash);
        bytes memory sig = abi.encodePacked(r, s, v);
        bytes32 keyHash = ClaimSignerHelper.addressToKey(david);

        aliceIdentity.execute(address(counter), 0.5 ether, "", keyHash, sig);

        assertEq(address(counter).balance, 0.5 ether, "Counter should receive ETH");
    }

    // ========= approve() with signature =========

    function test_approveWithSignature() public {
        // First create an unapproved execution request
        // Use carol (CLAIM_SIGNER) to create an external execution that won't auto-approve
        // carol's signerData is already set via OnchainIDSetup
        bytes memory callData = abi.encodeCall(Counter.increment, ());
        uint256 nonce = aliceIdentity.getCurrentNonce();
        bytes32 opHash = aliceIdentity.getOperationHash(address(counter), 0, callData, nonce);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(carolPk, opHash);
        bytes memory sig = abi.encodePacked(r, s, v);
        bytes32 carolKeyHash = ClaimSignerHelper.addressToKey(carol);

        uint256 execId = aliceIdentity.execute(address(counter), 0, callData, carolKeyHash, sig);
        assertEq(counter.count(), 0, "Should not be auto-approved");

        // Now approve with david's ACTION key using signature
        // Compute the EIP-712 approve hash manually
        bytes32 approveHash = _computeApproveHash(address(aliceIdentity), execId, true);
        (v, r, s) = vm.sign(davidPk, approveHash);
        bytes memory approveSig = abi.encodePacked(r, s, v);
        bytes32 davidKeyHash = ClaimSignerHelper.addressToKey(david);

        aliceIdentity.approve(execId, true, davidKeyHash, approveSig);
        assertEq(counter.count(), 1, "Counter should be incremented after approval");
    }

    // ========= getOperationHash =========

    function test_getOperationHash_deterministic() public view {
        bytes memory callData = abi.encodeCall(Counter.increment, ());
        uint256 nonce = aliceIdentity.getCurrentNonce();

        bytes32 hash1 = aliceIdentity.getOperationHash(address(counter), 0, callData, nonce);
        bytes32 hash2 = aliceIdentity.getOperationHash(address(counter), 0, callData, nonce);

        assertEq(hash1, hash2, "Same inputs should produce same hash");
    }

    function test_getOperationHash_changesWithNonce() public view {
        bytes memory callData = abi.encodeCall(Counter.increment, ());

        bytes32 hash1 = aliceIdentity.getOperationHash(address(counter), 0, callData, 0);
        bytes32 hash2 = aliceIdentity.getOperationHash(address(counter), 0, callData, 1);

        assertTrue(hash1 != hash2, "Different nonces should produce different hashes");
    }

    function test_getOperationHash_changesWithTarget() public view {
        bytes memory callData = abi.encodeCall(Counter.increment, ());

        bytes32 hash1 = aliceIdentity.getOperationHash(address(counter), 0, callData, 0);
        bytes32 hash2 = aliceIdentity.getOperationHash(address(aliceIdentity), 0, callData, 0);

        assertTrue(hash1 != hash2, "Different targets should produce different hashes");
    }

    // ========= isValidSignature (ERC-1271) =========

    function test_isValidSignature_validActionKey() public view {
        bytes32 hash = keccak256("test message");

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(davidPk, hash);
        bytes memory rawSig = abi.encodePacked(r, s, v);

        bytes32 keyHash = ClaimSignerHelper.addressToKey(david);
        bytes memory wrappedSig = abi.encode(keyHash, rawSig);

        bytes4 result = aliceIdentity.isValidSignature(hash, wrappedSig);
        assertEq(result, bytes4(0x1626ba7e), "Should return ERC-1271 magic value");
    }

    function test_isValidSignature_managementKeyAlsoWorks() public view {
        // Management keys have universal permissions, so ACTION check should pass
        bytes32 hash = keccak256("test message");

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, hash);
        bytes memory rawSig = abi.encodePacked(r, s, v);

        bytes32 keyHash = keccak256(abi.encodePacked(alice));
        bytes memory wrappedSig = abi.encode(keyHash, rawSig);

        bytes4 result = aliceIdentity.isValidSignature(hash, wrappedSig);
        assertEq(result, bytes4(0x1626ba7e), "Management key should pass ACTION check");
    }

    function test_isValidSignature_claimSignerKeyFails() public view {
        // CLAIM_SIGNER key should NOT pass ACTION check
        bytes32 hash = keccak256("test message");

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(carolPk, hash);
        bytes memory rawSig = abi.encodePacked(r, s, v);

        // carol has CLAIM_SIGNER purpose via addressToKey
        bytes32 keyHash = ClaimSignerHelper.addressToKey(carol);
        bytes memory wrappedSig = abi.encode(keyHash, rawSig);

        // Need to set keyData for carol first — but we can't in a view test
        // So the result will be failure because keyData is not set (signer.length < 20)
        bytes4 result = aliceIdentity.isValidSignature(hash, wrappedSig);
        assertEq(result, bytes4(0xffffffff), "CLAIM_SIGNER key should return failure");
    }

    function test_isValidSignature_claimSignerKeyFails_withKeyData() public {
        // carol's signerData is already set via OnchainIDSetup, verify CLAIM_SIGNER still fails ACTION check
        bytes32 hash = keccak256("test message");
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(carolPk, hash);
        bytes memory rawSig = abi.encodePacked(r, s, v);

        bytes32 keyHash = ClaimSignerHelper.addressToKey(carol);
        bytes memory wrappedSig = abi.encode(keyHash, rawSig);

        bytes4 result = aliceIdentity.isValidSignature(hash, wrappedSig);
        assertEq(result, bytes4(0xffffffff), "CLAIM_SIGNER key should return failure for ACTION check");
    }

    function test_isValidSignature_invalidSignature() public view {
        bytes32 hash = keccak256("test message");

        // Sign a different hash
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(davidPk, keccak256("wrong message"));
        bytes memory rawSig = abi.encodePacked(r, s, v);

        bytes32 keyHash = ClaimSignerHelper.addressToKey(david);
        bytes memory wrappedSig = abi.encode(keyHash, rawSig);

        bytes4 result = aliceIdentity.isValidSignature(hash, wrappedSig);
        assertEq(result, bytes4(0xffffffff), "Invalid signature should return failure");
    }

    function test_isValidSignature_unregisteredKey() public view {
        bytes32 hash = keccak256("test message");
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bobPk, hash);
        bytes memory rawSig = abi.encodePacked(r, s, v);

        // Use a random keyHash that doesn't exist
        bytes32 keyHash = keccak256("nonexistent");
        bytes memory wrappedSig = abi.encode(keyHash, rawSig);

        bytes4 result = aliceIdentity.isValidSignature(hash, wrappedSig);
        assertEq(result, bytes4(0xffffffff), "Unregistered key should return failure");
    }

    // ========= setKeyData =========

    function test_setKeyData_storesAndRetrieves() public {
        // Register a new key, then set its keyData
        address newAddr = makeAddr("newKey");
        bytes32 newKeyHash = keccak256(abi.encodePacked(newAddr));
        bytes memory signerData = abi.encodePacked(newAddr);

        vm.prank(alice);
        aliceIdentity.addKeyWithData(newKeyHash, KeyPurposes.ACTION, KeyTypes.ECDSA, signerData, "");

        (bytes memory storedSigner, bytes memory storedClient) = aliceIdentity.getKeyData(newKeyHash);
        assertEq(storedSigner, signerData, "SignerData should be stored correctly");
        assertEq(storedClient, "", "ClientData should be empty for ECDSA keys");
    }

    function test_addKeyWithData_revertNonManager() public {
        bytes32 keyHash = ClaimSignerHelper.addressToKey(david);

        vm.prank(david); // david has ACTION, not MANAGEMENT
        vm.expectRevert(Errors.SenderDoesNotHaveManagementKey.selector);
        aliceIdentity.addKeyWithData(keyHash, KeyPurposes.ACTION, KeyTypes.ECDSA, abi.encodePacked(david), "");
    }

    // ========= validateUserOp (ERC-4337) =========

    address internal constant ENTRY_POINT = 0x433709009B8330FDa32311DF1C2AFA402eD8D009;

    function _buildUserOp(address sender, bytes memory signature) internal pure returns (PackedUserOperation memory) {
        return PackedUserOperation({
            sender: sender,
            nonce: 0,
            initCode: "",
            callData: "",
            accountGasLimits: bytes32(0),
            preVerificationGas: 0,
            gasFees: bytes32(0),
            paymasterAndData: "",
            signature: signature
        });
    }

    function test_validateUserOp_validSignature() public {
        bytes32 keyHash = ClaimSignerHelper.addressToKey(david);
        bytes32 userOpHash = keccak256("test user op hash");

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(davidPk, userOpHash);
        bytes memory ecdsaSig = abi.encodePacked(r, s, v);

        PackedUserOperation memory userOp = _buildUserOp(address(aliceIdentity), abi.encode(keyHash, ecdsaSig));

        vm.prank(ENTRY_POINT);
        uint256 result = aliceIdentity.validateUserOp(userOp, userOpHash, 0);
        assertEq(result, 0, "Should return 0 for valid signature");
    }

    function test_validateUserOp_notEntryPoint_shouldRevert() public {
        bytes32 keyHash = ClaimSignerHelper.addressToKey(david);
        bytes32 userOpHash = keccak256("test user op hash");

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(davidPk, userOpHash);
        bytes memory ecdsaSig = abi.encodePacked(r, s, v);

        PackedUserOperation memory userOp = _buildUserOp(address(aliceIdentity), abi.encode(keyHash, ecdsaSig));

        vm.expectRevert(abi.encodeWithSelector(OZAccount.AccountUnauthorized.selector, address(this)));
        aliceIdentity.validateUserOp(userOp, userOpHash, 0);
    }

    function test_validateUserOp_invalidSignature_returnsFailure() public {
        bytes32 keyHash = ClaimSignerHelper.addressToKey(david);
        bytes32 userOpHash = keccak256("test user op hash");

        // Sign a different hash to produce an invalid signature
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(davidPk, keccak256("wrong hash"));
        bytes memory ecdsaSig = abi.encodePacked(r, s, v);

        PackedUserOperation memory userOp = _buildUserOp(address(aliceIdentity), abi.encode(keyHash, ecdsaSig));

        // Per ERC-4337 spec: returns SIG_VALIDATION_FAILED (1), not revert
        vm.prank(ENTRY_POINT);
        uint256 result = aliceIdentity.validateUserOp(userOp, userOpHash, 0);
        assertEq(result, 1, "Should return SIG_VALIDATION_FAILED");
    }

    function test_validateUserOp_anyRegisteredKey_succeeds() public {
        // Carol has CLAIM_SIGNER purpose — validateUserOp accepts any registered key
        // Purpose routing happens in executeFromEntryPoint, not validateUserOp
        // carol's signerData is already set via OnchainIDSetup
        bytes32 keyHash = ClaimSignerHelper.addressToKey(carol);
        bytes32 userOpHash = keccak256("test user op hash");

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(carolPk, userOpHash);
        bytes memory ecdsaSig = abi.encodePacked(r, s, v);

        PackedUserOperation memory userOp = _buildUserOp(address(aliceIdentity), abi.encode(keyHash, ecdsaSig));

        vm.prank(ENTRY_POINT);
        uint256 result = aliceIdentity.validateUserOp(userOp, userOpHash, 0);
        assertEq(result, 0, "Any registered key should pass validation");
    }

    function test_validateUserOp_paysPrefund() public {
        // Fund the identity with ETH
        vm.deal(address(aliceIdentity), 1 ether);

        bytes32 keyHash = ClaimSignerHelper.addressToKey(david);
        bytes32 userOpHash = keccak256("test user op hash");

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(davidPk, userOpHash);
        bytes memory ecdsaSig = abi.encodePacked(r, s, v);

        PackedUserOperation memory userOp = _buildUserOp(address(aliceIdentity), abi.encode(keyHash, ecdsaSig));

        // Put code at EntryPoint so it can receive ETH
        vm.etch(ENTRY_POINT, hex"00");
        vm.deal(ENTRY_POINT, 0);

        uint256 missingFunds = 0.1 ether;

        vm.prank(ENTRY_POINT);
        aliceIdentity.validateUserOp(userOp, userOpHash, missingFunds);

        assertEq(ENTRY_POINT.balance, missingFunds, "EntryPoint should receive prefund");
        assertEq(address(aliceIdentity).balance, 1 ether - missingFunds, "Identity balance should decrease");
    }

    // ========= executeFromEntryPoint =========

    function _validateAndExecute(uint256 signerPk, bytes32 signerKeyHash, address to, uint256 value, bytes memory data)
        internal
        returns (uint256 executionId)
    {
        // Build callData for executeFromEntryPoint
        bytes memory callData = abi.encodeCall(aliceIdentity.executeFromEntryPoint, (to, value, data));

        // Build and sign UserOp
        bytes32 userOpHash = keccak256("test-userop");
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, userOpHash);
        bytes memory sig = abi.encodePacked(r, s, v);

        PackedUserOperation memory userOp = _buildUserOp(address(aliceIdentity), abi.encode(signerKeyHash, sig));
        userOp.callData = callData;

        // Step 1: validateUserOp (sets transient _validatedKeyHash)
        vm.prank(ENTRY_POINT);
        uint256 validationResult = aliceIdentity.validateUserOp(userOp, userOpHash, 0);
        assertEq(validationResult, 0, "Validation should pass");

        // Step 2: executeFromEntryPoint (reads keyHash from transient storage)
        vm.prank(ENTRY_POINT);
        return aliceIdentity.executeFromEntryPoint(to, value, data);
    }

    function test_executeFromEntryPoint_actionKey_externalCall() public {
        vm.deal(address(aliceIdentity), 1 ether);
        address target = makeAddr("target");

        _validateAndExecute(davidPk, ClaimSignerHelper.addressToKey(david), target, 0.5 ether, "");

        assertEq(target.balance, 0.5 ether);
    }

    function test_executeFromEntryPoint_managementKey_selfCall() public {
        address newAddr = makeAddr("newKey");
        bytes32 newKeyHash = keccak256(abi.encodePacked(newAddr));
        bytes memory callData = abi.encodeCall(aliceIdentity.addKey, (newKeyHash, KeyPurposes.ACTION, KeyTypes.ECDSA));

        _validateAndExecute(alicePk, ClaimSignerHelper.addressToKey(alice), address(aliceIdentity), 0, callData);

        assertTrue(aliceIdentity.keyHasPurpose(newKeyHash, KeyPurposes.ACTION), "New key should be added");
    }

    function test_executeFromEntryPoint_actionKey_selfCall_queued() public {
        bytes memory callData = abi.encodeCall(
            aliceIdentity.addKey, (keccak256(abi.encodePacked(makeAddr("x"))), KeyPurposes.ACTION, KeyTypes.ECDSA)
        );

        uint256 execId =
            _validateAndExecute(davidPk, ClaimSignerHelper.addressToKey(david), address(aliceIdentity), 0, callData);

        Structs.Execution memory exec = aliceIdentity.getExecutionData(execId);
        assertFalse(exec.executed, "ACTION key self-call should be queued, not auto-executed");
    }

    function test_executeFromEntryPoint_notEntryPoint_shouldRevert() public {
        vm.expectRevert(abi.encodeWithSelector(OZAccount.AccountUnauthorized.selector, address(this)));
        aliceIdentity.executeFromEntryPoint(makeAddr("target"), 0, "");
    }

    function test_executeFromEntryPoint_withoutValidation_shouldRevert() public {
        // Calling executeFromEntryPoint without prior validateUserOp should fail
        // because _validatedKeyHash is bytes32(0)
        vm.prank(ENTRY_POINT);
        vm.expectRevert(Errors.InvalidSignature.selector);
        aliceIdentity.executeFromEntryPoint(makeAddr("target"), 0, "");
    }

    // ========= receive() =========

    function test_receive_acceptsETH() public {
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        (bool success,) = address(aliceIdentity).call{ value: 0.5 ether }("");
        assertTrue(success, "Identity should accept ETH");
        assertEq(address(aliceIdentity).balance, 0.5 ether);
    }

    // ========= isValidSignature with ERC-1271 contract signer =========

    function test_isValidSignature_erc1271ContractSigner() public {
        // Deploy mock ERC-1271 signer
        MockERC1271Signer mockSigner = new MockERC1271Signer();

        // Register the mock contract as an ACTION key with ERC1271 key type
        bytes32 keyHash = keccak256(abi.encodePacked(address(mockSigner)));

        vm.startPrank(alice);
        aliceIdentity.addKeyWithData(
            keyHash, KeyPurposes.ACTION, KeyTypes.ECDSA, abi.encodePacked(address(mockSigner)), ""
        );
        vm.stopPrank();

        // Call isValidSignature — should delegate to MockERC1271Signer
        bytes32 hash = keccak256("test message");
        bytes memory dummySig = hex"deadbeef";
        bytes memory wrappedSig = abi.encode(keyHash, dummySig);

        bytes4 result = aliceIdentity.isValidSignature(hash, wrappedSig);
        assertEq(result, bytes4(0x1626ba7e), "ERC-1271 contract signer should return magic value");
    }

    // ========= Helpers =========

    bytes32 internal constant _APPROVE_TYPEHASH = keccak256("Approve(uint256 id,bool shouldApprove)");

    /// @dev Computes the EIP-712 approve hash manually (mirrors SmartAccount._hashTypedDataV4)
    function _computeApproveHash(address identity, uint256 id, bool shouldApprove) internal view returns (bytes32) {
        bytes32 structHash = keccak256(abi.encode(_APPROVE_TYPEHASH, id, shouldApprove));
        bytes32 domainSeparator = _computeDomainSeparator(identity);
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }

    /// @dev Computes the EIP-712 domain separator for an identity contract
    function _computeDomainSeparator(address identity) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("OnchainID"),
                keccak256("1"),
                block.chainid,
                identity
            )
        );
    }

    function _getExecutionData(uint256 execId) internal view returns (address, uint256, bytes memory, bool, bool) {
        Structs.Execution memory exec = aliceIdentity.getExecutionData(execId);
        return (exec.to, exec.value, exec.data, exec.approved, exec.executed);
    }

}
