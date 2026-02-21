// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import { ClaimSignerHelper } from "../helpers/ClaimSignerHelper.sol";
import { OnchainIDSetup } from "../helpers/OnchainIDSetup.sol";
import { ClaimIssuer } from "contracts/ClaimIssuer.sol";
import { IClaimIssuer } from "contracts/interface/IClaimIssuer.sol";
import { IIdentity } from "contracts/interface/IIdentity.sol";
import { Errors } from "contracts/libraries/Errors.sol";
import { KeyPurposes } from "contracts/libraries/KeyPurposes.sol";
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
        // Create 66-byte signature (one byte too long)
        bytes memory invalidSig = abi.encodePacked(aliceClaim666.signature, hex"00");

        assertFalse(
            claimIssuer.isClaimValid(
                IIdentity(address(aliceIdentity)), aliceClaim666.topic, invalidSig, aliceClaim666.data
            )
        );
    }

    function test_signatureValidation_malformed() public view {
        bytes memory invalidSig = hex"1234567890abcdef";

        assertFalse(
            claimIssuer.isClaimValid(
                IIdentity(address(aliceIdentity)), aliceClaim666.topic, invalidSig, aliceClaim666.data
            )
        );
    }

    function test_signatureValidation_wrongSigner() public view {
        bytes memory invalidSig = new bytes(65);

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

    // ---- upgrade ----

    function test_upgrade_revertIfNotOwner() public {
        address freshDeployer = makeAddr("freshClaimDeployer");
        address nonOwner = makeAddr("nonOwner");

        ClaimIssuer impl = new ClaimIssuer(freshDeployer);
        ClaimIssuerProxy proxyContract =
            new ClaimIssuerProxy(address(impl), abi.encodeCall(ClaimIssuer.initialize, (freshDeployer)));
        ClaimIssuer proxy = ClaimIssuer(address(proxyContract));

        ClaimIssuer newImpl = new ClaimIssuer(nonOwner);

        vm.prank(nonOwner);
        vm.expectRevert(Errors.SenderDoesNotHaveManagementKey.selector);
        proxy.upgradeTo(address(newImpl));
    }

    function test_upgrade_shouldUpgrade() public {
        address freshDeployer = makeAddr("freshClaimDeployer2");

        ClaimIssuer impl = new ClaimIssuer(freshDeployer);
        ClaimIssuerProxy proxyContract =
            new ClaimIssuerProxy(address(impl), abi.encodeCall(ClaimIssuer.initialize, (freshDeployer)));
        ClaimIssuer proxy = ClaimIssuer(address(proxyContract));

        ClaimIssuer newImpl = new ClaimIssuer(freshDeployer);

        vm.prank(freshDeployer);
        proxy.upgradeTo(address(newImpl));

        assertTrue(proxy.keyHasPurpose(ClaimSignerHelper.addressToKey(freshDeployer), KeyPurposes.MANAGEMENT));
    }

}
