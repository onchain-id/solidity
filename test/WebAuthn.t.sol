// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import { ERC7913P256Verifier } from "@openzeppelin/contracts/utils/cryptography/verifiers/ERC7913P256Verifier.sol";

import { ClaimIssuer } from "contracts/ClaimIssuer.sol";
import { Identity } from "contracts/Identity.sol";
import { IIdentity } from "contracts/interface/IIdentity.sol";
import { Errors } from "contracts/libraries/Errors.sol";
import { KeyPurposes } from "contracts/libraries/KeyPurposes.sol";
import { KeyTypes } from "contracts/libraries/KeyTypes.sol";

import { ClaimSignerHelper } from "./helpers/ClaimSignerHelper.sol";
import { OnchainIDSetup } from "./helpers/OnchainIDSetup.sol";

/// @notice A simple counter used as an execution target
contract P256Counter {

    uint256 public count;

    function increment() external {
        count++;
    }

    receive() external payable { }

}

/// @notice Tests for P-256 (secp256r1) key integration via ERC-7913 P256 verifier
contract WebAuthnTest is OnchainIDSetup {

    ERC7913P256Verifier public p256Verifier;
    P256Counter public counter;

    // P-256 key material
    uint256 internal p256PrivateKey = 0xaabb1234;
    uint256 internal p256Qx;
    uint256 internal p256Qy;
    bytes internal p256Signer;
    bytes32 internal p256KeyHash;

    function setUp() public override {
        super.setUp();

        p256Verifier = new ERC7913P256Verifier();
        counter = new P256Counter();

        // Generate P-256 public key
        (p256Qx, p256Qy) = vm.publicKeyP256(p256PrivateKey);

        // Build ERC-7913 signer bytes: verifier address || qx || qy (84 bytes)
        p256Signer = abi.encodePacked(address(p256Verifier), bytes32(p256Qx), bytes32(p256Qy));
        p256KeyHash = keccak256(p256Signer);

        // Register P-256 key on alice's identity with ACTION purpose
        vm.prank(alice);
        aliceIdentity.addKeyWithData(p256KeyHash, KeyPurposes.ACTION, KeyTypes.WEBAUTHN, p256Signer, "");
    }

    // ========= execute() with P-256 signature =========

    function test_executeWithP256Signature() public {
        bytes memory callData = abi.encodeCall(P256Counter.increment, ());
        uint256 nonce = aliceIdentity.getCurrentNonce();
        bytes32 opHash = aliceIdentity.getOperationHash(address(counter), 0, callData, nonce);

        // Sign with P-256
        (bytes32 r, bytes32 s) = vm.signP256(p256PrivateKey, opHash);
        bytes memory p256Sig = abi.encodePacked(r, s);

        // Execute with signature — anyone can submit
        aliceIdentity.execute(address(counter), 0, callData, p256KeyHash, p256Sig);

        assertEq(counter.count(), 1, "Counter should be incremented via P-256 signed execution");
    }

    function test_executeWithP256Signature_managementKey() public {
        // Register a P-256 key with MANAGEMENT purpose
        uint256 mgmtP256Pk = 0xdead5678;
        (uint256 mqx, uint256 mqy) = vm.publicKeyP256(mgmtP256Pk);
        bytes memory mgmtSigner = abi.encodePacked(address(p256Verifier), bytes32(mqx), bytes32(mqy));
        bytes32 mgmtKeyHash = keccak256(mgmtSigner);

        vm.prank(alice);
        aliceIdentity.addKeyWithData(mgmtKeyHash, KeyPurposes.MANAGEMENT, KeyTypes.WEBAUTHN, mgmtSigner, "");

        // Management P-256 key can execute self-calls
        address newAddr = makeAddr("newP256Key");
        bytes32 newKeyHash = keccak256(abi.encodePacked(newAddr));
        bytes memory callData = abi.encodeCall(aliceIdentity.addKey, (newKeyHash, KeyPurposes.ACTION, KeyTypes.ECDSA));

        uint256 nonce = aliceIdentity.getCurrentNonce();
        bytes32 opHash = aliceIdentity.getOperationHash(address(aliceIdentity), 0, callData, nonce);

        (bytes32 r, bytes32 s) = vm.signP256(mgmtP256Pk, opHash);
        bytes memory sig = abi.encodePacked(r, s);

        aliceIdentity.execute(address(aliceIdentity), 0, callData, mgmtKeyHash, sig);

        assertTrue(
            aliceIdentity.keyHasPurpose(newKeyHash, KeyPurposes.ACTION), "New key should be added via P-256 mgmt key"
        );
    }

    function test_executeWithP256Signature_revertInvalidSignature() public {
        bytes memory callData = abi.encodeCall(P256Counter.increment, ());
        uint256 nonce = aliceIdentity.getCurrentNonce();
        bytes32 opHash = aliceIdentity.getOperationHash(address(counter), 0, callData, nonce);

        // Sign with a different P-256 private key
        uint256 wrongPk = 0xffff9999;
        (bytes32 r, bytes32 s) = vm.signP256(wrongPk, opHash);
        bytes memory wrongSig = abi.encodePacked(r, s);

        vm.expectRevert(Errors.InvalidSignature.selector);
        aliceIdentity.execute(address(counter), 0, callData, p256KeyHash, wrongSig);
    }

    function test_executeWithP256Signature_replayProtection() public {
        bytes memory callData = abi.encodeCall(P256Counter.increment, ());
        uint256 nonce = aliceIdentity.getCurrentNonce();
        bytes32 opHash = aliceIdentity.getOperationHash(address(counter), 0, callData, nonce);

        (bytes32 r, bytes32 s) = vm.signP256(p256PrivateKey, opHash);
        bytes memory sig = abi.encodePacked(r, s);

        // First call succeeds
        aliceIdentity.execute(address(counter), 0, callData, p256KeyHash, sig);
        assertEq(counter.count(), 1);

        // Replay fails — nonce changed, so opHash differs, signature is invalid
        vm.expectRevert(Errors.InvalidSignature.selector);
        aliceIdentity.execute(address(counter), 0, callData, p256KeyHash, sig);
    }

    function test_executeWithP256Signature_withValue() public {
        vm.deal(address(aliceIdentity), 1 ether);

        uint256 nonce = aliceIdentity.getCurrentNonce();
        bytes32 opHash = aliceIdentity.getOperationHash(address(counter), 0.5 ether, "", nonce);

        (bytes32 r, bytes32 s) = vm.signP256(p256PrivateKey, opHash);
        bytes memory sig = abi.encodePacked(r, s);

        aliceIdentity.execute(address(counter), 0.5 ether, "", p256KeyHash, sig);

        assertEq(address(counter).balance, 0.5 ether, "Counter should receive ETH via P-256 signed tx");
    }

    // ========= isClaimValid with P-256 claim signature =========

    function test_isClaimValid_p256ClaimIssuer() public {
        // Set up a ClaimIssuer that uses a P-256 CLAIM_SIGNER key
        uint256 issuerP256Pk = 0xbeef4321;
        (uint256 iqx, uint256 iqy) = vm.publicKeyP256(issuerP256Pk);
        bytes memory issuerSigner = abi.encodePacked(address(p256Verifier), bytes32(iqx), bytes32(iqy));
        bytes32 issuerKeyHash = keccak256(issuerSigner);

        // Register P-256 key as CLAIM_SIGNER on claimIssuer
        vm.prank(claimIssuerOwner);
        claimIssuer.addKeyWithData(issuerKeyHash, KeyPurposes.CLAIM_SIGNER, KeyTypes.WEBAUTHN, issuerSigner, "");

        // Build claim data
        uint256 topic = 42;
        bytes memory claimData = hex"0042";

        // Sign claim with P-256: dataHash = keccak256(abi.encode(identity, topic, data))
        bytes32 dataHash = keccak256(abi.encode(address(aliceIdentity), topic, claimData));
        (bytes32 r, bytes32 s) = vm.signP256(issuerP256Pk, dataHash);
        bytes memory rawSig = abi.encodePacked(r, s);

        // Wrap in unified format: abi.encode(signer, actualSignature)
        bytes memory claimSig = abi.encode(issuerSigner, rawSig);

        // Validate claim
        bool valid =
            claimIssuer.isClaimValid(IIdentity(address(aliceIdentity)), topic, KeyTypes.WEBAUTHN, claimSig, claimData);
        assertTrue(valid, "P-256 signed claim should be valid");
    }

    function test_isClaimValid_p256_invalidSignature() public {
        // Register P-256 CLAIM_SIGNER on claimIssuer
        uint256 issuerP256Pk = 0xbeef4321;
        (uint256 iqx, uint256 iqy) = vm.publicKeyP256(issuerP256Pk);
        bytes memory issuerSigner = abi.encodePacked(address(p256Verifier), bytes32(iqx), bytes32(iqy));
        bytes32 issuerKeyHash = keccak256(issuerSigner);

        vm.prank(claimIssuerOwner);
        claimIssuer.addKeyWithData(issuerKeyHash, KeyPurposes.CLAIM_SIGNER, KeyTypes.WEBAUTHN, issuerSigner, "");

        uint256 topic = 42;
        bytes memory claimData = hex"0042";
        bytes32 dataHash = keccak256(abi.encode(address(aliceIdentity), topic, claimData));

        // Sign with wrong key
        uint256 wrongPk = 0x11112222;
        (bytes32 r, bytes32 s) = vm.signP256(wrongPk, dataHash);
        bytes memory rawSig = abi.encodePacked(r, s);
        bytes memory claimSig = abi.encode(issuerSigner, rawSig);

        bool valid =
            claimIssuer.isClaimValid(IIdentity(address(aliceIdentity)), topic, KeyTypes.WEBAUTHN, claimSig, claimData);
        assertFalse(valid, "Claim signed with wrong P-256 key should be invalid");
    }

    function test_addClaim_withP256Signature() public {
        // Full flow: ClaimIssuer signs claim with P-256, identity adds it
        uint256 issuerP256Pk = 0xbeef4321;
        (uint256 iqx, uint256 iqy) = vm.publicKeyP256(issuerP256Pk);
        bytes memory issuerSigner = abi.encodePacked(address(p256Verifier), bytes32(iqx), bytes32(iqy));
        bytes32 issuerKeyHash = keccak256(issuerSigner);

        vm.prank(claimIssuerOwner);
        claimIssuer.addKeyWithData(issuerKeyHash, KeyPurposes.CLAIM_SIGNER, KeyTypes.WEBAUTHN, issuerSigner, "");

        uint256 topic = 999;
        bytes memory claimData = hex"deadbeef";
        string memory uri = "https://example.com/p256claim";

        // Sign claim
        bytes32 dataHash = keccak256(abi.encode(address(aliceIdentity), topic, claimData));
        (bytes32 r, bytes32 s) = vm.signP256(issuerP256Pk, dataHash);
        bytes memory rawSig = abi.encodePacked(r, s);
        bytes memory claimSig = abi.encode(issuerSigner, rawSig);

        // Add claim to identity (alice has CLAIM_SIGNER key via carol, but alice is MANAGEMENT so she can use execute)
        vm.prank(alice);
        aliceIdentity.addClaim(topic, KeyTypes.WEBAUTHN, address(claimIssuer), claimSig, claimData, uri);

        // Verify claim was added
        bytes32 claimId = keccak256(abi.encode(address(claimIssuer), topic));
        (uint256 storedTopic,, address storedIssuer,,,) = aliceIdentity.getClaim(claimId);
        assertEq(storedTopic, topic, "Claim topic should match");
        assertEq(storedIssuer, address(claimIssuer), "Claim issuer should match");
    }

    // ========= Mixed keys — identity with both ECDSA and P-256 =========

    function test_mixedKeys_ecdsaAndP256() public {
        // alice's identity already has:
        // - alice: MANAGEMENT (ECDSA, from factory)
        // - david: ACTION (ECDSA, from OnchainIDSetup)
        // - p256KeyHash: ACTION (P-256, from this test's setUp)

        // david's signerData is already set via OnchainIDSetup
        bytes32 davidKeyHash = ClaimSignerHelper.addressToKey(david);

        // Execute with ECDSA key (david)
        bytes memory callData = abi.encodeCall(P256Counter.increment, ());
        uint256 nonce = aliceIdentity.getCurrentNonce();
        bytes32 opHash = aliceIdentity.getOperationHash(address(counter), 0, callData, nonce);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(davidPk, opHash);
        bytes memory ecdsaSig = abi.encodePacked(r, s, v);

        aliceIdentity.execute(address(counter), 0, callData, davidKeyHash, ecdsaSig);
        assertEq(counter.count(), 1, "ECDSA key should work");

        // Execute with P-256 key
        nonce = aliceIdentity.getCurrentNonce();
        opHash = aliceIdentity.getOperationHash(address(counter), 0, callData, nonce);

        (bytes32 pr, bytes32 ps) = vm.signP256(p256PrivateKey, opHash);
        bytes memory p256Sig = abi.encodePacked(pr, ps);

        aliceIdentity.execute(address(counter), 0, callData, p256KeyHash, p256Sig);
        assertEq(counter.count(), 2, "P-256 key should also work");
    }

    // ========= isValidSignature (ERC-1271) with P-256 =========

    function test_isValidSignature_p256ActionKey() public view {
        bytes32 hash = keccak256("test message for P-256");

        (bytes32 r, bytes32 s) = vm.signP256(p256PrivateKey, hash);
        bytes memory rawSig = abi.encodePacked(r, s);

        // Wrap: abi.encode(keyHash, actualSignature)
        bytes memory wrappedSig = abi.encode(p256KeyHash, rawSig);

        bytes4 result = aliceIdentity.isValidSignature(hash, wrappedSig);
        assertEq(result, bytes4(0x1626ba7e), "P-256 ACTION key should return ERC-1271 magic value");
    }

    function test_isValidSignature_p256_invalidSignature() public view {
        bytes32 hash = keccak256("test message for P-256");

        // Sign different hash
        (bytes32 r, bytes32 s) = vm.signP256(p256PrivateKey, keccak256("wrong message"));
        bytes memory rawSig = abi.encodePacked(r, s);

        bytes memory wrappedSig = abi.encode(p256KeyHash, rawSig);

        bytes4 result = aliceIdentity.isValidSignature(hash, wrappedSig);
        assertEq(result, bytes4(0xffffffff), "Invalid P-256 signature should return failure");
    }

    function test_isValidSignature_p256_claimSignerPurposeFails() public {
        // Register a P-256 key with CLAIM_SIGNER purpose (not ACTION)
        uint256 claimP256Pk = 0x77778888;
        (uint256 cqx, uint256 cqy) = vm.publicKeyP256(claimP256Pk);
        bytes memory claimSigner = abi.encodePacked(address(p256Verifier), bytes32(cqx), bytes32(cqy));
        bytes32 claimKeyHash = keccak256(claimSigner);

        vm.prank(alice);
        aliceIdentity.addKeyWithData(claimKeyHash, KeyPurposes.CLAIM_SIGNER, KeyTypes.WEBAUTHN, claimSigner, "");

        bytes32 hash = keccak256("test message");
        (bytes32 r, bytes32 s) = vm.signP256(claimP256Pk, hash);
        bytes memory rawSig = abi.encodePacked(r, s);

        bytes memory wrappedSig = abi.encode(claimKeyHash, rawSig);

        bytes4 result = aliceIdentity.isValidSignature(hash, wrappedSig);
        assertEq(result, bytes4(0xffffffff), "CLAIM_SIGNER P-256 key should fail ACTION check in ERC-1271");
    }

    // ========= Key registration =========

    function test_p256KeyRegistration() public view {
        // Verify the P-256 key was registered correctly
        (uint256[] memory purposes, uint256 keyType, bytes32 key) = aliceIdentity.getKey(p256KeyHash);

        assertEq(key, p256KeyHash, "Key hash should match");
        assertEq(keyType, KeyTypes.WEBAUTHN, "Key type should be WEBAUTHN");
        assertEq(purposes.length, 1, "Should have exactly one purpose");
        assertEq(purposes[0], KeyPurposes.ACTION, "Purpose should be ACTION");

        // Verify keyData
        (bytes memory storedSigner,) = aliceIdentity.getKeyData(p256KeyHash);
        assertEq(storedSigner, p256Signer, "Signer bytes should match");
        assertEq(storedSigner.length, 84, "ERC-7913 signer should be 84 bytes (20 + 32 + 32)");
    }

    function test_p256Key_multiPurpose() public {
        // Add MANAGEMENT purpose to the same P-256 key
        vm.prank(alice);
        aliceIdentity.addKey(p256KeyHash, KeyPurposes.MANAGEMENT, KeyTypes.WEBAUTHN);

        assertTrue(aliceIdentity.keyHasPurpose(p256KeyHash, KeyPurposes.ACTION), "Should still have ACTION");
        assertTrue(aliceIdentity.keyHasPurpose(p256KeyHash, KeyPurposes.MANAGEMENT), "Should also have MANAGEMENT");
    }

}
