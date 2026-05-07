// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import { ClaimSignerHelper } from "../helpers/ClaimSignerHelper.sol";
import { OnchainIDSetup } from "../helpers/OnchainIDSetup.sol";
import { ClaimIssuer } from "contracts/ClaimIssuer.sol";
import { IClaimIssuer } from "contracts/interface/IClaimIssuer.sol";
import { IIdentity } from "contracts/interface/IIdentity.sol";
import { Errors } from "contracts/libraries/Errors.sol";
import { IdentityTypes } from "contracts/libraries/IdentityTypes.sol";
import { KeyPurposes } from "contracts/libraries/KeyPurposes.sol";
import { KeyTypes } from "contracts/libraries/KeyTypes.sol";
import { ClaimIssuerProxy } from "contracts/proxy/ClaimIssuerProxy.sol";

contract ClaimIssuerTest is OnchainIDSetup {

    // ---- revokeClaim ----

    function test_revokeClaim_revertNonManagementKey() public {
        vm.prank(alice);
        vm.expectRevert(Errors.SenderDoesNotHaveManagementKey.selector);
        claimIssuer.revokeClaim(aliceClaim666.id, aliceClaim666.identity);
    }

    function test_revokeClaim_revertAlreadyRevoked() public {
        vm.prank(claimIssuerOwner);
        claimIssuer.revokeClaim(aliceClaim666.id, aliceClaim666.identity);

        vm.prank(claimIssuerOwner);
        vm.expectRevert(Errors.ClaimAlreadyRevoked.selector);
        claimIssuer.revokeClaim(aliceClaim666.id, aliceClaim666.identity);
    }

    function test_revokeClaim_shouldRevoke() public {
        assertTrue(
            claimIssuer.isClaimValid(
                IIdentity(address(aliceIdentity)), aliceClaim666.topic, aliceClaim666.signature, aliceClaim666.data
            )
        );

        vm.prank(claimIssuerOwner);
        vm.expectEmit(true, false, false, false, address(claimIssuer));
        emit IClaimIssuer.ClaimRevoked(aliceClaim666.signature);
        claimIssuer.revokeClaim(aliceClaim666.id, aliceClaim666.identity);

        assertTrue(claimIssuer.isClaimRevoked(aliceClaim666.signature));
        assertFalse(
            claimIssuer.isClaimValid(
                IIdentity(address(aliceIdentity)), aliceClaim666.topic, aliceClaim666.signature, aliceClaim666.data
            )
        );
    }

    // ---- revokeClaimBySignature ----

    function test_revokeClaimBySignature_revertNonManagementKey() public {
        vm.prank(alice);
        vm.expectRevert(Errors.SenderDoesNotHaveManagementKey.selector);
        claimIssuer.revokeClaimBySignature(aliceClaim666.signature);
    }

    function test_revokeClaimBySignature_revertAlreadyRevoked() public {
        vm.prank(claimIssuerOwner);
        claimIssuer.revokeClaimBySignature(aliceClaim666.signature);

        vm.prank(claimIssuerOwner);
        vm.expectRevert(Errors.ClaimAlreadyRevoked.selector);
        claimIssuer.revokeClaimBySignature(aliceClaim666.signature);
    }

    function test_revokeClaimBySignature_shouldRevoke() public {
        assertTrue(
            claimIssuer.isClaimValid(
                IIdentity(address(aliceIdentity)), aliceClaim666.topic, aliceClaim666.signature, aliceClaim666.data
            )
        );

        vm.prank(claimIssuerOwner);
        vm.expectEmit(true, false, false, false, address(claimIssuer));
        emit IClaimIssuer.ClaimRevoked(aliceClaim666.signature);
        claimIssuer.revokeClaimBySignature(aliceClaim666.signature);

        assertTrue(claimIssuer.isClaimRevoked(aliceClaim666.signature));
        assertFalse(
            claimIssuer.isClaimValid(
                IIdentity(address(aliceIdentity)), aliceClaim666.topic, aliceClaim666.signature, aliceClaim666.data
            )
        );
    }

    // ---- signature validation ----

    function test_signatureValidation_invalidLength() public view {
        // Wrap a 66-byte inner signature (one byte too long) in the unified format
        bytes memory badInnerSig = abi.encodePacked(new bytes(65), hex"00");
        bytes memory invalidSig = abi.encode(abi.encodePacked(claimIssuerOwner), badInnerSig);

        assertFalse(
            claimIssuer.isClaimValid(
                IIdentity(address(aliceIdentity)), aliceClaim666.topic, invalidSig, aliceClaim666.data
            )
        );
    }

    function test_signatureValidation_malformed() public view {
        // Wrap a malformed inner signature in the unified format
        bytes memory invalidSig = abi.encode(abi.encodePacked(claimIssuerOwner), hex"1234567890abcdef");

        assertFalse(
            claimIssuer.isClaimValid(
                IIdentity(address(aliceIdentity)), aliceClaim666.topic, invalidSig, aliceClaim666.data
            )
        );
    }

    function test_signatureValidation_wrongSigner() public view {
        // Wrap a zero-filled inner signature with a valid signer in the unified format
        bytes memory invalidSig = abi.encode(abi.encodePacked(claimIssuerOwner), new bytes(65));

        assertFalse(
            claimIssuer.isClaimValid(
                IIdentity(address(aliceIdentity)), aliceClaim666.topic, invalidSig, aliceClaim666.data
            )
        );
    }

    function test_signatureValidation_validSignature() public view {
        assertTrue(
            claimIssuer.isClaimValid(
                IIdentity(address(aliceIdentity)), aliceClaim666.topic, aliceClaim666.signature, aliceClaim666.data
            )
        );
    }

    /// @notice CLAIM_ADDER key should NOT validate claim signatures (only CLAIM_SIGNER can)
    function test_isClaimValid_claimAdderKey_shouldReturnFalse() public {
        // Create a signer that will be added as CLAIM_ADDER (not CLAIM_SIGNER)
        (address claimAdderAddr, uint256 claimAdderPk) = makeAddrAndKey("claimAdderSigner");

        // Add claimAdderAddr as CLAIM_ADDER on the claimIssuer (not CLAIM_SIGNER)
        vm.prank(claimIssuerOwner);
        claimIssuer.addKey(ClaimSignerHelper.addressToKey(claimAdderAddr), KeyPurposes.CLAIM_ADDER, KeyTypes.ECDSA);

        // Sign a claim with the CLAIM_ADDER key
        uint256 topic = 999;
        bytes memory data = hex"0099";
        bytes memory signature = ClaimSignerHelper.signClaim(
            claimAdderPk, claimAdderAddr, address(claimIssuer), address(aliceIdentity), topic, data
        );

        // isClaimValid should return false because CLAIM_ADDER cannot sign claims
        assertFalse(
            claimIssuer.isClaimValid(IIdentity(address(aliceIdentity)), topic, signature, data),
            "CLAIM_ADDER key should not validate claim signatures"
        );
    }

    // ---- upgrade ----

    function test_upgrade_revertIfNotOwner() public {
        address freshDeployer = makeAddr("freshClaimDeployer");
        address nonOwner = makeAddr("nonOwner");

        ClaimIssuer impl = new ClaimIssuer(freshDeployer);
        ClaimIssuerProxy proxyContract = new ClaimIssuerProxy(
            address(impl), abi.encodeCall(ClaimIssuer.initialize, (freshDeployer, IdentityTypes.CLAIM_ISSUER))
        );
        ClaimIssuer proxy = ClaimIssuer(payable(address(proxyContract)));

        ClaimIssuer newImpl = new ClaimIssuer(nonOwner);

        vm.prank(nonOwner);
        vm.expectRevert(Errors.SenderDoesNotHaveManagementKey.selector);
        proxy.upgradeToAndCall(address(newImpl), "");
    }

    function test_upgrade_shouldUpgrade() public {
        address freshDeployer = makeAddr("freshClaimDeployer2");

        ClaimIssuer impl = new ClaimIssuer(freshDeployer);
        ClaimIssuerProxy proxyContract = new ClaimIssuerProxy(
            address(impl), abi.encodeCall(ClaimIssuer.initialize, (freshDeployer, IdentityTypes.CLAIM_ISSUER))
        );
        ClaimIssuer proxy = ClaimIssuer(payable(address(proxyContract)));

        ClaimIssuer newImpl = new ClaimIssuer(freshDeployer);

        vm.prank(freshDeployer);
        proxy.upgradeToAndCall(address(newImpl), "");

        assertTrue(proxy.keyHasPurpose(ClaimSignerHelper.addressToKey(freshDeployer), KeyPurposes.MANAGEMENT));
    }

}
