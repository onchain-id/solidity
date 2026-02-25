// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import { ClaimSignerHelper } from "../helpers/ClaimSignerHelper.sol";
import { OnchainIDSetup } from "../helpers/OnchainIDSetup.sol";
import { Test as TestContract } from "test/mocks/Test.sol";
import { IIdentity } from "contracts/interface/IIdentity.sol";
import { Errors } from "contracts/libraries/Errors.sol";
import { KeyPurposes } from "contracts/libraries/KeyPurposes.sol";
import { KeyTypes } from "contracts/libraries/KeyTypes.sol";

/// @notice Test suite for ClaimIssuer.addClaimTo functionality
contract ClaimToTest is OnchainIDSetup {

    /// @notice When claimIssuer has MANAGEMENT key on aliceIdentity, addClaimTo auto-approves
    function test_addClaimTo_withManagementKey() public {
        // Add claimIssuer as MANAGEMENT key on aliceIdentity
        bytes32 claimIssuerKey = ClaimSignerHelper.addressToKey(address(claimIssuer));
        vm.prank(alice);
        aliceIdentity.addKey(claimIssuerKey, KeyPurposes.MANAGEMENT, KeyTypes.ECDSA);

        // Build claim
        uint256 topic = 999;
        bytes memory data = hex"0099";
        string memory uri = "https://example.com/new-claim";
        bytes memory signature = ClaimSignerHelper.signClaim(claimIssuerOwnerPk, address(aliceIdentity), topic, data);

        // Call addClaimTo (last param is IIdentity, not address)
        vm.prank(claimIssuerOwner);
        claimIssuer.addClaimTo(topic, 1, signature, data, uri, IIdentity(address(aliceIdentity)));

        // Verify claim was added
        bytes32 claimId = ClaimSignerHelper.computeClaimId(address(claimIssuer), topic);
        (
            uint256 retTopic,
            uint256 retScheme,
            address retIssuer,
            bytes memory retSig,
            bytes memory retData,
            string memory retUri
        ) = aliceIdentity.getClaim(claimId);

        assertEq(retTopic, topic);
        assertEq(retScheme, 1);
        assertEq(retIssuer, address(claimIssuer));
        assertEq(retSig, signature);
        assertEq(retData, data);
        assertEq(retUri, uri);
    }

    /// @notice Non-management key caller should revert with SenderDoesNotHaveManagementKey
    function test_addClaimTo_revertWithoutManagementKey() public {
        vm.prank(bob);
        vm.expectRevert(Errors.SenderDoesNotHaveManagementKey.selector);
        claimIssuer.addClaimTo(
            aliceClaim666.topic,
            aliceClaim666.scheme,
            aliceClaim666.signature,
            aliceClaim666.data,
            aliceClaim666.uri,
            IIdentity(aliceClaim666.identity)
        );
    }

    /// @notice Invalid signature should revert with InvalidClaim
    function test_addClaimTo_revertInvalidSignature() public {
        bytes memory invalidSig = hex"1234567890abcdef";

        vm.prank(claimIssuerOwner);
        vm.expectRevert(Errors.InvalidClaim.selector);
        claimIssuer.addClaimTo(
            999, 1, invalidSig, hex"0099", "https://example.com/invalid-claim", IIdentity(address(aliceIdentity))
        );
    }

    /// @notice Zero address identity should revert with InvalidClaim
    function test_addClaimTo_revertZeroAddressIdentity() public {
        vm.prank(claimIssuerOwner);
        vm.expectRevert(Errors.InvalidClaim.selector);
        claimIssuer.addClaimTo(999, 1, hex"0099", hex"0099", "https://example.com/new-claim", IIdentity(address(0)));
    }

    /// @notice Without key on aliceIdentity, addClaimTo creates pending execution requiring approval
    function test_addClaimTo_requiresApproval() public {
        // ClaimIssuer does NOT have any key on aliceIdentity
        // So the execution requires manual approval from alice
        uint256 topic = 999;
        bytes memory data = hex"0099";
        string memory uri = "https://example.com/new-claim";
        bytes memory signature = ClaimSignerHelper.signClaim(claimIssuerOwnerPk, address(aliceIdentity), topic, data);

        vm.prank(claimIssuerOwner);
        claimIssuer.addClaimTo(topic, 1, signature, data, uri, IIdentity(address(aliceIdentity)));

        // Verify claim is NOT yet added (execution is pending)
        bytes32 claimId = ClaimSignerHelper.computeClaimId(address(claimIssuer), topic);
        (uint256 retTopic,,,,,) = aliceIdentity.getClaim(claimId);
        assertEq(retTopic, 0);

        // Nonce was 0 before addClaimTo, so executionId = 0
        // Alice approves the pending execution
        vm.prank(alice);
        aliceIdentity.approve(0, true);

        // Verify claim is now added
        (retTopic,,,,,) = aliceIdentity.getClaim(claimId);
        assertEq(retTopic, topic);
    }

    /// @notice Pending execution then owner approves -- full verification of claim fields
    function test_addClaimTo_pendingThenOwnerApproves() public {
        uint256 topic = 999;
        bytes memory data = hex"0099";
        string memory uri = "https://example.com/new-claim";
        bytes memory signature = ClaimSignerHelper.signClaim(claimIssuerOwnerPk, address(aliceIdentity), topic, data);

        vm.prank(claimIssuerOwner);
        claimIssuer.addClaimTo(topic, 1, signature, data, uri, IIdentity(address(aliceIdentity)));

        // Verify claim NOT added yet
        bytes32 claimId = ClaimSignerHelper.computeClaimId(address(claimIssuer), topic);
        (uint256 retTopic,,,,,) = aliceIdentity.getClaim(claimId);
        assertEq(retTopic, 0);

        // Approve execution ID 0
        vm.prank(alice);
        aliceIdentity.approve(0, true);

        // Verify all claim fields after approval
        (uint256 t, uint256 s, address iss, bytes memory sig, bytes memory d, string memory u) =
            aliceIdentity.getClaim(claimId);

        assertEq(t, topic);
        assertEq(s, 1);
        assertEq(iss, address(claimIssuer));
        assertEq(sig, signature);
        assertEq(d, data);
        assertEq(u, uri);
    }

    /// @notice With MANAGEMENT key on aliceIdentity, addClaimTo auto-approves immediately
    function test_addClaimTo_autoApproveWithManagementKey() public {
        // Add claimIssuer as MANAGEMENT key on aliceIdentity
        bytes32 claimIssuerKey = ClaimSignerHelper.addressToKey(address(claimIssuer));
        vm.prank(alice);
        aliceIdentity.addKey(claimIssuerKey, KeyPurposes.MANAGEMENT, KeyTypes.ECDSA);

        // Build and add claim
        uint256 topic = 999;
        bytes memory data = hex"0099";
        string memory uri = "https://example.com/new-claim";
        bytes memory signature = ClaimSignerHelper.signClaim(claimIssuerOwnerPk, address(aliceIdentity), topic, data);

        vm.prank(claimIssuerOwner);
        claimIssuer.addClaimTo(topic, 1, signature, data, uri, IIdentity(address(aliceIdentity)));

        // Verify claim was auto-approved and added immediately
        bytes32 claimId = ClaimSignerHelper.computeClaimId(address(claimIssuer), topic);
        (
            uint256 retTopic,
            uint256 retScheme,
            address retIssuer,
            bytes memory retSig,
            bytes memory retData,
            string memory retUri
        ) = aliceIdentity.getClaim(claimId);

        assertEq(retTopic, topic);
        assertEq(retScheme, 1);
        assertEq(retIssuer, address(claimIssuer));
        assertEq(retSig, signature);
        assertEq(retData, data);
        assertEq(retUri, uri);
    }

    /// @notice addClaimTo to an invalid contract (no execute function) should revert with CallFailed
    function test_addClaimTo_revertInvalidIdentityContract() public {
        TestContract invalidIdentity = new TestContract();

        uint256 topic = 999;
        bytes memory data = hex"0099";
        bytes memory signature = ClaimSignerHelper.signClaim(claimIssuerOwnerPk, address(invalidIdentity), topic, data);

        vm.prank(claimIssuerOwner);
        vm.expectRevert(Errors.CallFailed.selector);
        claimIssuer.addClaimTo(
            topic, 1, signature, data, "https://example.com/invalid-claim", IIdentity(address(invalidIdentity))
        );
    }

}
