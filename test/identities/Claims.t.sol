// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import {ClaimSignerHelper} from "../helpers/ClaimSignerHelper.sol";
import {OnchainIDSetup} from "../helpers/OnchainIDSetup.sol";
import {Constants} from "../utils/Constants.sol";
import {ClaimIssuer} from "contracts/ClaimIssuer.sol";
import {Identity} from "contracts/Identity.sol";
import {IERC734} from "contracts/interface/IERC734.sol";
import {IERC735} from "contracts/interface/IERC735.sol";
import {IIdentity} from "contracts/interface/IIdentity.sol";
import {Errors} from "contracts/libraries/Errors.sol";
import {KeyPurposes} from "contracts/libraries/KeyPurposes.sol";
import {KeyTypes} from "contracts/libraries/KeyTypes.sol";

/// @notice Test suite for claim management functionality (addClaim, removeClaim, getClaim, getClaimIdsByTopic)
contract ClaimsTest is OnchainIDSetup {
    // ============ addClaim - Self-Attested (issuer = identity) ============

    /// @notice When claim is self-attested but signature is invalid, should revert
    function test_addClaim_selfAttested_invalidClaim_shouldRevert() public {
        uint256 topic = Constants.CLAIM_TOPIC_42;
        bytes memory data = hex"0042";
        string memory uri = "https://example.com";

        // Sign with wrong data (0x101010 instead of 0x0042)
        bytes memory wrongSignature = ClaimSignerHelper.signClaim(
            alicePk,
            address(aliceIdentity),
            topic,
            hex"101010" // wrong signature because this data is not the hex"0042" as data variable above
        );

        // Should revert because claim validation now applies to all claims
        vm.expectRevert(Errors.InvalidClaim.selector);
        vm.prank(alice);
        aliceIdentity.addClaim(topic, Constants.CLAIM_SCHEME, address(aliceIdentity), wrongSignature, data, uri);
    }

    /// @notice Self-attested valid claim via execute/approve pattern
    function test_addClaim_selfAttested_valid_viaExecute() public {
        uint256 topic = Constants.CLAIM_TOPIC_42;
        bytes memory data = hex"0042";
        string memory uri = "https://example.com";

        // Sign claim correctly
        bytes memory signature = ClaimSignerHelper.signClaim(alicePk, address(aliceIdentity), topic, data);

        bytes32 claimId = ClaimSignerHelper.computeClaimId(address(aliceIdentity), topic);

        // Encode addClaim call
        bytes memory actionData = abi.encodeCall(
            Identity.addClaim, (topic, Constants.CLAIM_SCHEME, address(aliceIdentity), signature, data, uri)
        );

        // Bob (ACTION key) executes
        vm.prank(bob);
        uint256 executionId = aliceIdentity.execute(address(aliceIdentity), 0, actionData);

        // Expect all three events in order: Approved, ClaimAdded, Executed
        vm.expectEmit(true, false, false, true, address(aliceIdentity));
        emit IERC734.Approved(executionId, true);
        vm.expectEmit(true, true, true, true, address(aliceIdentity));
        emit IERC735.ClaimAdded(claimId, topic, Constants.CLAIM_SCHEME, address(aliceIdentity), signature, data, uri);
        vm.expectEmit(true, true, true, true, address(aliceIdentity));
        emit IERC734.Executed(executionId, address(aliceIdentity), 0, actionData);

        // Alice (MANAGEMENT) approves
        vm.prank(alice);
        aliceIdentity.approve(executionId, true);

        // Verify claim is valid
        bool isValid = aliceIdentity.isClaimValid(IIdentity(address(aliceIdentity)), topic, signature, data);
        assertTrue(isValid, "Claim should be valid");
    }

    /// @notice When caller is not a CLAIM key, should revert
    function test_addClaim_selfAttested_notClaimKey_shouldRevert() public {
        uint256 topic = Constants.CLAIM_TOPIC_42;
        bytes memory data = hex"0042";
        string memory uri = "https://example.com";

        // Sign claim
        bytes memory signature = ClaimSignerHelper.signClaim(alicePk, address(aliceIdentity), topic, data);

        // Bob (no CLAIM_SIGNER key) tries to add claim
        vm.prank(bob);
        vm.expectRevert(Errors.SenderDoesNotHaveClaimSignerKey.selector);
        aliceIdentity.addClaim(topic, Constants.CLAIM_SCHEME, address(aliceIdentity), signature, data, uri);
    }

    // ============ addClaim - From Claim Issuer ============

    /// @notice When claim is from claim issuer but signature is invalid, should revert
    function test_addClaim_claimIssuer_invalidClaim_shouldRevert() public {
        uint256 topic = Constants.CLAIM_TOPIC_42;
        bytes memory data = hex"0042";
        string memory uri = "https://example.com";

        // Sign with wrong data (0x10101010 instead of 0x0042)
        bytes memory wrongSignature = ClaimSignerHelper.signClaim(
            claimIssuerOwnerPk,
            address(aliceIdentity),
            topic,
            hex"10101010" // wrong signature because this data is not the hex"0042" as data variable above
        );

        // Try to add claim
        vm.prank(alice);
        vm.expectRevert(Errors.InvalidClaim.selector);
        aliceIdentity.addClaim(topic, Constants.CLAIM_SCHEME, address(claimIssuer), wrongSignature, data, uri);
    }

    /// @notice Claim from claim issuer via execute/approve pattern
    function test_addClaim_claimIssuer_valid_viaExecute() public {
        uint256 topic = Constants.CLAIM_TOPIC_42;
        bytes memory data = hex"0042";
        string memory uri = "https://example.com";

        // Sign claim correctly
        bytes memory signature = ClaimSignerHelper.signClaim(claimIssuerOwnerPk, address(aliceIdentity), topic, data);

        bytes32 claimId = ClaimSignerHelper.computeClaimId(address(claimIssuer), topic);

        // Encode addClaim call
        bytes memory actionData = abi.encodeCall(
            Identity.addClaim, (topic, Constants.CLAIM_SCHEME, address(claimIssuer), signature, data, uri)
        );

        // Bob (ACTION key) executes
        vm.prank(bob);
        uint256 executionId = aliceIdentity.execute(address(aliceIdentity), 0, actionData);

        // Expect all three events in order: Approved, ClaimAdded, Executed
        vm.expectEmit(true, false, false, true, address(aliceIdentity));
        emit IERC734.Approved(executionId, true);
        vm.expectEmit(true, true, true, true, address(aliceIdentity));
        emit IERC735.ClaimAdded(claimId, topic, Constants.CLAIM_SCHEME, address(claimIssuer), signature, data, uri);
        vm.expectEmit(true, true, true, true, address(aliceIdentity));
        emit IERC734.Executed(executionId, address(aliceIdentity), 0, actionData);

        // Alice (MANAGEMENT) approves
        vm.prank(alice);
        aliceIdentity.approve(executionId, true);
    }

    /// @notice When caller is not a CLAIM key (with claim issuer), should revert
    function test_addClaim_claimIssuer_notClaimKey_shouldRevert() public {
        uint256 topic = Constants.CLAIM_TOPIC_42;
        bytes memory data = hex"0042";
        string memory uri = "https://example.com";

        // Sign claim
        bytes memory signature = ClaimSignerHelper.signClaim(claimIssuerOwnerPk, address(aliceIdentity), topic, data);

        // Bob (no CLAIM_SIGNER key) tries to add claim
        vm.prank(bob);
        vm.expectRevert(Errors.SenderDoesNotHaveClaimSignerKey.selector);
        aliceIdentity.addClaim(topic, Constants.CLAIM_SCHEME, address(claimIssuer), signature, data, uri);
    }

    // ============ updateClaim (addClaim on existing claim) ============

    /// @notice When claim already exists for issuer+topic, should emit ClaimChanged
    function test_updateClaim_shouldReplaceExistingClaim() public {
        uint256 topic = Constants.CLAIM_TOPIC_42;
        bytes memory initialData = hex"0042";
        bytes memory updatedData = hex"004200101010";
        string memory uri = "https://example.com";

        // Add initial claim
        bytes memory initialSignature =
            ClaimSignerHelper.signClaim(claimIssuerOwnerPk, address(aliceIdentity), topic, initialData);

        vm.prank(alice);
        aliceIdentity.addClaim(topic, Constants.CLAIM_SCHEME, address(claimIssuer), initialSignature, initialData, uri);

        // Update claim with different data
        bytes memory updatedSignature =
            ClaimSignerHelper.signClaim(claimIssuerOwnerPk, address(aliceIdentity), topic, updatedData);

        bytes32 claimId = ClaimSignerHelper.computeClaimId(address(claimIssuer), topic);

        // Expect ClaimChanged event
        vm.expectEmit(true, true, true, true, address(aliceIdentity));
        emit IERC735.ClaimChanged(
            claimId, topic, Constants.CLAIM_SCHEME, address(claimIssuer), updatedSignature, updatedData, uri
        );

        vm.prank(alice);
        aliceIdentity.addClaim(topic, Constants.CLAIM_SCHEME, address(claimIssuer), updatedSignature, updatedData, uri);
    }

    // ============ removeClaim ============

    /// @notice Remove claim via execute/approve pattern
    function test_removeClaim_viaExecute_shouldRemoveClaim() public {
        uint256 topic = Constants.CLAIM_TOPIC_42;
        bytes memory data = hex"0042";
        string memory uri = "https://example.com";

        // Add claim first
        bytes memory signature = ClaimSignerHelper.signClaim(claimIssuerOwnerPk, address(aliceIdentity), topic, data);

        bytes32 claimId = ClaimSignerHelper.computeClaimId(address(claimIssuer), topic);

        vm.prank(alice);
        aliceIdentity.addClaim(topic, Constants.CLAIM_SCHEME, address(claimIssuer), signature, data, uri);

        // Encode removeClaim call
        bytes memory actionData = abi.encodeCall(Identity.removeClaim, (claimId));

        // Bob (ACTION key) executes
        vm.prank(bob);
        uint256 executionId = aliceIdentity.execute(address(aliceIdentity), 0, actionData);

        // Expect ClaimRemoved event
        vm.expectEmit(true, true, true, true, address(aliceIdentity));
        emit IERC735.ClaimRemoved(claimId, topic, Constants.CLAIM_SCHEME, address(claimIssuer), signature, data, uri);

        // Alice (MANAGEMENT) approves
        vm.prank(alice);
        aliceIdentity.approve(executionId, true);
    }

    /// @notice When caller is not a CLAIM key, removeClaim should revert
    function test_removeClaim_notClaimKey_shouldRevert() public {
        bytes32 claimId = ClaimSignerHelper.computeClaimId(address(claimIssuer), Constants.CLAIM_TOPIC_42);

        // Bob (no CLAIM_SIGNER key) tries to remove claim
        vm.prank(bob);
        vm.expectRevert(Errors.SenderDoesNotHaveClaimSignerKey.selector);
        aliceIdentity.removeClaim(claimId);
    }

    /// @notice When claim does not exist, should revert
    function test_removeClaim_nonExistentClaim_shouldRevert() public {
        bytes32 claimId = ClaimSignerHelper.computeClaimId(address(claimIssuer), Constants.CLAIM_TOPIC_42);

        // Carol (CLAIM_SIGNER) tries to remove non-existent claim
        vm.prank(carol);
        vm.expectRevert(abi.encodeWithSelector(Errors.ClaimNotRegistered.selector, claimId));
        aliceIdentity.removeClaim(claimId);
    }

    /// @notice When claim exists, should remove successfully
    function test_removeClaim_existingClaim_shouldRemove() public {
        uint256 topic = Constants.CLAIM_TOPIC_42;
        bytes memory data = hex"0042";
        string memory uri = "https://example.com";

        // Add claim first
        bytes memory signature = ClaimSignerHelper.signClaim(claimIssuerOwnerPk, address(aliceIdentity), topic, data);

        bytes32 claimId = ClaimSignerHelper.computeClaimId(address(claimIssuer), topic);

        vm.prank(alice);
        aliceIdentity.addClaim(topic, Constants.CLAIM_SCHEME, address(claimIssuer), signature, data, uri);

        // Expect ClaimRemoved event
        vm.expectEmit(true, true, true, true, address(aliceIdentity));
        emit IERC735.ClaimRemoved(claimId, topic, Constants.CLAIM_SCHEME, address(claimIssuer), signature, data, uri);

        // Alice removes claim
        vm.prank(alice);
        aliceIdentity.removeClaim(claimId);
    }

    // ============ removeClaim Edge Cases ============

    /// @notice Edge case: claimIndex >= arrayLength when removing claims with same topic
    function test_removeClaim_edgeCase_claimIndexOutOfBounds() public {
        uint256 topic = Constants.CLAIM_TOPIC_42;

        // Add first claim from claim issuer
        bytes memory data1 = hex"0042";
        bytes memory signature1 = ClaimSignerHelper.signClaim(claimIssuerOwnerPk, address(aliceIdentity), topic, data1);
        bytes32 claimId1 = ClaimSignerHelper.computeClaimId(address(claimIssuer), topic);

        vm.prank(alice);
        aliceIdentity.addClaim(
            topic, Constants.CLAIM_SCHEME, address(claimIssuer), signature1, data1, "https://example.com"
        );

        // Add second claim (self-attested, same topic)
        bytes memory data2 = hex"0043";
        bytes memory signature2 = ClaimSignerHelper.signClaim(alicePk, address(aliceIdentity), topic, data2);
        bytes32 claimId2 = ClaimSignerHelper.computeClaimId(address(aliceIdentity), topic);

        vm.prank(alice);
        aliceIdentity.addClaim(
            topic, Constants.CLAIM_SCHEME, address(aliceIdentity), signature2, data2, "https://example2.com"
        );

        // Remove second claim first
        vm.prank(alice);
        aliceIdentity.removeClaim(claimId2);

        // Now remove first claim - tests edge case where claimIndex might be >= array length
        vm.expectEmit(true, true, true, true, address(aliceIdentity));
        emit IERC735.ClaimRemoved(
            claimId1, topic, Constants.CLAIM_SCHEME, address(claimIssuer), signature1, data1, "https://example.com"
        );

        vm.prank(alice);
        aliceIdentity.removeClaim(claimId1);

        // Verify claim was removed
        (uint256 retTopic,, address retIssuer,,,) = aliceIdentity.getClaim(claimId1);
        assertEq(retTopic, 0, "Topic should be 0");
        assertEq(retIssuer, address(0), "Issuer should be zero address");
    }

    /// @notice Edge case: swap-and-pop logic when removing middle claim from array
    function test_removeClaim_edgeCase_swapAndPopMiddle() public {
        uint256 topic = Constants.CLAIM_TOPIC_42;

        // Create second claim issuer
        ClaimIssuer claimIssuer2 = new ClaimIssuer(alice);
        vm.prank(alice);
        claimIssuer2.addKey(ClaimSignerHelper.addressToKey(alice), KeyPurposes.CLAIM_SIGNER, KeyTypes.ECDSA);

        // Add three claims with different issuers, same topic
        address[3] memory issuers = [
            address(claimIssuer),
            address(claimIssuer2),
            address(aliceIdentity) // Self-attested
        ];
        bytes32[3] memory claimIds;

        for (uint256 i = 0; i < 3; i++) {
            bytes memory data = abi.encodePacked(hex"0040", uint8(i));
            string memory uri = string(abi.encodePacked("https://example", vm.toString(i), ".com"));

            bytes memory signature;
            if (i == 0) {
                signature = ClaimSignerHelper.signClaim(claimIssuerOwnerPk, address(aliceIdentity), topic, data);
            } else {
                signature = ClaimSignerHelper.signClaim(alicePk, address(aliceIdentity), topic, data);
            }

            claimIds[i] = ClaimSignerHelper.computeClaimId(issuers[i], topic);

            vm.prank(alice);
            aliceIdentity.addClaim(topic, Constants.CLAIM_SCHEME, issuers[i], signature, data, uri);
        }

        // Verify all claims are added
        bytes32[] memory claimIdsByTopic = aliceIdentity.getClaimIdsByTopic(topic);
        assertEq(claimIdsByTopic.length, 3, "Should have 3 claims");

        // Remove middle claim (index 1) - triggers swap-and-pop
        vm.prank(alice);
        aliceIdentity.removeClaim(claimIds[1]);

        // Verify remaining claims
        bytes32[] memory remainingClaimIds = aliceIdentity.getClaimIdsByTopic(topic);
        assertEq(remainingClaimIds.length, 2, "Should have 2 claims remaining");

        // Check that claims 0 and 2 are still present
        bool hasFirst = false;
        bool hasThird = false;
        for (uint256 i = 0; i < remainingClaimIds.length; i++) {
            if (remainingClaimIds[i] == claimIds[0]) hasFirst = true;
            if (remainingClaimIds[i] == claimIds[2]) hasThird = true;
        }
        assertTrue(hasFirst, "First claim should still exist");
        assertTrue(hasThird, "Third claim should still exist");

        // Verify removed claim no longer exists
        (uint256 retTopic,, address retIssuer,,,) = aliceIdentity.getClaim(claimIds[1]);
        assertEq(retTopic, 0, "Removed claim topic should be 0");
        assertEq(retIssuer, address(0), "Removed claim issuer should be zero address");
    }

    // ============ getClaim ============

    /// @notice When claim does not exist, should return empty struct
    function test_getClaim_nonExistent_shouldReturnEmpty() public {
        bytes32 claimId = ClaimSignerHelper.computeClaimId(address(claimIssuer), Constants.CLAIM_TOPIC_42);

        (uint256 topic, uint256 scheme, address issuer, bytes memory signature, bytes memory data, string memory uri) =
            aliceIdentity.getClaim(claimId);

        assertEq(topic, 0, "Topic should be 0");
        assertEq(scheme, 0, "Scheme should be 0");
        assertEq(issuer, address(0), "Issuer should be zero address");
        assertEq(signature, hex"", "Signature should be empty");
        assertEq(data, hex"", "Data should be empty");
        assertEq(bytes(uri).length, 0, "URI should be empty");
    }

    /// @notice When claim exists, should return correct data
    function test_getClaim_existing_shouldReturnData() public {
        // Use the pre-built aliceClaim666 from setup
        (uint256 topic, uint256 scheme, address issuer, bytes memory signature, bytes memory data, string memory uri) =
            aliceIdentity.getClaim(aliceClaim666.id);

        assertEq(topic, aliceClaim666.topic, "Topic should match");
        assertEq(scheme, aliceClaim666.scheme, "Scheme should match");
        assertEq(issuer, aliceClaim666.issuer, "Issuer should match");
        assertEq(signature, aliceClaim666.signature, "Signature should match");
        assertEq(data, aliceClaim666.data, "Data should match");
        assertEq(uri, aliceClaim666.uri, "URI should match");
    }

    // ============ isClaimValid - ECDSA recovery error ============

    /// @notice When signature causes ECDSA recovery error, isClaimValid should return false
    function test_isClaimValid_ecdsaRecoveryError_shouldReturnFalse() public view {
        // Use a zero-length signature which causes ECDSA.RecoverError
        bytes memory invalidSignature = hex"";
        bool isValid = aliceIdentity.isClaimValid(
            IIdentity(address(aliceIdentity)), Constants.CLAIM_TOPIC_666, invalidSignature, hex"0042"
        );
        assertFalse(isValid, "Claim with recovery error should be invalid");
    }

    // ============ removeClaim - single claim (no swap needed) ============

    /// @notice When removing the only claim for a topic, no swap-and-pop needed
    function test_removeClaim_onlyClaimForTopic_shouldRemoveWithoutSwap() public {
        uint256 topic = Constants.CLAIM_TOPIC_42;
        bytes memory data = hex"0042";
        string memory uri = "https://example.com";

        bytes memory signature = ClaimSignerHelper.signClaim(claimIssuerOwnerPk, address(aliceIdentity), topic, data);
        bytes32 claimId = ClaimSignerHelper.computeClaimId(address(claimIssuer), topic);

        // Add a single claim for this topic
        vm.prank(alice);
        aliceIdentity.addClaim(topic, Constants.CLAIM_SCHEME, address(claimIssuer), signature, data, uri);

        // Verify it's the only claim for this topic
        bytes32[] memory claimIdsBefore = aliceIdentity.getClaimIdsByTopic(topic);
        assertEq(claimIdsBefore.length, 1, "Should have exactly 1 claim");

        // Remove it — exercises the _claimIdx == lastClaimIdx path (no swap)
        vm.prank(alice);
        aliceIdentity.removeClaim(claimId);

        bytes32[] memory claimIdsAfter = aliceIdentity.getClaimIdsByTopic(topic);
        assertEq(claimIdsAfter.length, 0, "Should have 0 claims");
    }

    // ============ getClaimIdsByTopic ============

    /// @notice When no claims exist for topic, should return empty array
    function test_getClaimIdsByTopic_empty_shouldReturnEmpty() public {
        bytes32[] memory claimIds = aliceIdentity.getClaimIdsByTopic(101010);
        assertEq(claimIds.length, 0, "Should return empty array");
    }

    /// @notice When claims exist for topic, should return array of claim IDs
    function test_getClaimIdsByTopic_hasClaims_shouldReturnIds() public {
        // Use the pre-built aliceClaim666 from setup
        bytes32[] memory claimIds = aliceIdentity.getClaimIdsByTopic(aliceClaim666.topic);

        assertEq(claimIds.length, 1, "Should return 1 claim ID");
        assertEq(claimIds[0], aliceClaim666.id, "Claim ID should match");
    }

    // ============ removeClaim - corrupted index (defensive check) ============

    /// @notice Exercise the defensive require(claimIdxPlusOne > 0) by corrupting storage
    function test_removeClaim_revertWhenClaimIndexCorrupted() public {
        // aliceClaim666 was already added in setUp
        bytes32 claimId = aliceClaim666.id;
        uint256 topic = aliceClaim666.topic;

        // Compute the storage slot for claimIndexInTopic[topic][claimId]
        // ClaimStorage is at _CLAIM_STORAGE_SLOT
        bytes32 baseSlot = keccak256(abi.encode(uint256(keccak256(bytes("onchainid.identity.claim.storage"))) - 1))
            & ~bytes32(uint256(0xff));

        // claimIndexInTopic is the 3rd field in ClaimStorage struct (offset 2)
        bytes32 mappingSlot = bytes32(uint256(baseSlot) + 2);

        // mapping(uint256 => mapping(bytes32 => uint256))
        // First level: keccak256(abi.encode(topic, mappingSlot))
        bytes32 innerMappingSlot = keccak256(abi.encode(topic, mappingSlot));

        // Second level: keccak256(abi.encode(claimId, innerMappingSlot))
        bytes32 valueSlot = keccak256(abi.encode(claimId, innerMappingSlot));

        // Corrupt the index to 0
        vm.store(address(aliceIdentity), valueSlot, bytes32(0));

        // Now removeClaim should revert with "Claim index missing"
        vm.prank(alice);
        vm.expectRevert("Claim index missing");
        aliceIdentity.removeClaim(claimId);
    }
}
