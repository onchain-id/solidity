// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import { ClaimSignerHelper } from "../helpers/ClaimSignerHelper.sol";
import { IdentityHelper } from "../helpers/IdentityHelper.sol";
import { Identity } from "contracts/Identity.sol";
import { IdFactory } from "contracts/factory/IdFactory.sol";
import { Gateway } from "contracts/gateway/Gateway.sol";
import { Errors } from "contracts/libraries/Errors.sol";
import { IdentityTypes } from "contracts/libraries/IdentityTypes.sol";
import { KeyPurposes } from "contracts/libraries/KeyPurposes.sol";
import { KeyTypes } from "contracts/libraries/KeyTypes.sol";
import { Structs } from "contracts/storage/Structs.sol";
import { Test } from "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";

contract GatewayTest is Test {

    IdentityHelper.OnchainIDSetup internal setup;

    address internal deployer;
    uint256 internal deployerPk;
    address internal alice;
    uint256 internal alicePk;
    address internal bob;
    uint256 internal bobPk;
    address internal carol;
    uint256 internal carolPk;

    Structs.ModuleInstall[] internal _emptyModules;

    function setUp() public {
        (deployer, deployerPk) = makeAddrAndKey("gwDeployer");
        (alice, alicePk) = makeAddrAndKey("gwAlice");
        (bob, bobPk) = makeAddrAndKey("gwBob");
        (carol, carolPk) = makeAddrAndKey("gwCarol");

        vm.warp(365 days);

        vm.startPrank(deployer);
        setup = IdentityHelper.deployFactory(deployer);
        vm.stopPrank();
    }

    // ---- helpers ----

    function _makeECDSAKey(address addr, uint256 purpose) internal pure returns (Structs.KeyParam memory) {
        return Structs.KeyParam({
            keyHash: keccak256(abi.encodePacked(addr)),
            purpose: purpose,
            keyType: KeyTypes.ECDSA,
            signerData: abi.encodePacked(addr),
            clientData: ""
        });
    }

    function _makeSingleMgmtKeys(address addr) internal pure returns (Structs.KeyParam[] memory keys) {
        keys = new Structs.KeyParam[](1);
        keys[0] = _makeECDSAKey(addr, KeyPurposes.MANAGEMENT);
    }

    function _signDeploy(
        uint256 signerPk,
        address owner,
        string memory salt,
        Structs.KeyParam[] memory keys,
        uint256 identityType,
        uint256 expiry
    ) internal view returns (bytes memory) {
        bytes32 digest = keccak256(
            abi.encode("Authorize ONCHAINID deployment", owner, identityType, salt, keys, _emptyModules, expiry)
        );
        bytes32 ethSignedHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", digest));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, ethSignedHash);
        return abi.encodePacked(r, s, v);
    }

    function _deployGateway(address[] memory signers) internal returns (Gateway) {
        return new Gateway(address(setup.idFactory), signers);
    }

    function _deployGatewayWithCarol() internal returns (Gateway) {
        address[] memory signers = new address[](1);
        signers[0] = carol;
        return _deployGateway(signers);
    }

    // ============ constructor ============

    function test_constructor_revertZeroFactory() public {
        address[] memory signers = new address[](0);
        vm.expectRevert(Errors.ZeroAddress.selector);
        new Gateway(address(0), signers);
    }

    function test_constructor_revertTooManySigners() public {
        address[] memory signers = new address[](11);
        vm.expectRevert(Errors.TooManySigners.selector);
        new Gateway(address(setup.idFactory), signers);
    }

    // ============ deployIdentityWithSalt ============

    function test_deployIdentityWithSalt_revertZeroAddress() public {
        Gateway gateway = _deployGatewayWithCarol();
        bytes memory sig = new bytes(65);

        vm.expectRevert(Errors.ZeroAddress.selector);
        gateway.deployIdentityWithSalt(
            address(0),
            IdentityTypes.INDIVIDUAL,
            "saltToUse",
            _makeSingleMgmtKeys(address(0)),
            _emptyModules,
            block.timestamp + 365 days,
            sig
        );
    }

    function test_deployIdentityWithSalt_revertInvalidSignature() public {
        Gateway gateway = _deployGatewayWithCarol();
        bytes memory sig = new bytes(65);

        vm.expectRevert();
        gateway.deployIdentityWithSalt(
            alice,
            IdentityTypes.INDIVIDUAL,
            "saltToUse",
            _makeSingleMgmtKeys(alice),
            _emptyModules,
            block.timestamp + 365 days,
            sig
        );
    }

    function test_deployIdentityWithSalt_revertUnapprovedSigner() public {
        Gateway gateway = _deployGatewayWithCarol();
        Structs.KeyParam[] memory keys = _makeSingleMgmtKeys(alice);
        uint256 expiry = block.timestamp + 365 days;
        bytes memory sig = _signDeploy(bobPk, alice, "saltToUse", keys, IdentityTypes.INDIVIDUAL, expiry);

        vm.expectRevert(abi.encodeWithSelector(Errors.UnapprovedSigner.selector, bob));
        gateway.deployIdentityWithSalt(alice, IdentityTypes.INDIVIDUAL, "saltToUse", keys, _emptyModules, expiry, sig);
    }

    function test_deployIdentityWithSalt_shouldDeploy() public {
        Gateway gateway = _deployGatewayWithCarol();
        vm.prank(deployer);
        setup.idFactory.transferOwnership(address(gateway));

        Structs.KeyParam[] memory keys = _makeSingleMgmtKeys(alice);
        uint256 expiry = block.timestamp + 365 days;
        bytes memory sig = _signDeploy(carolPk, alice, "saltToUse", keys, IdentityTypes.INDIVIDUAL, expiry);
        gateway.deployIdentityWithSalt(alice, IdentityTypes.INDIVIDUAL, "saltToUse", keys, _emptyModules, expiry, sig);

        address identityAddr = setup.idFactory.getIdentity(alice);
        assertTrue(identityAddr != address(0));
        assertTrue(
            Identity(payable(identityAddr)).keyHasPurpose(ClaimSignerHelper.addressToKey(alice), KeyPurposes.MANAGEMENT)
        );
    }

    function test_deployIdentityWithSalt_withMultipleKeys() public {
        Gateway gateway = _deployGatewayWithCarol();
        vm.prank(deployer);
        setup.idFactory.transferOwnership(address(gateway));

        address claimAdder = makeAddr("gwClaimAdder");
        Structs.KeyParam[] memory keys = new Structs.KeyParam[](2);
        keys[0] = _makeECDSAKey(alice, KeyPurposes.MANAGEMENT);
        keys[1] = _makeECDSAKey(claimAdder, KeyPurposes.CLAIM_ADDER);

        uint256 expiry = block.timestamp + 365 days;
        bytes memory sig = _signDeploy(carolPk, alice, "saltWithKeys", keys, IdentityTypes.INDIVIDUAL, expiry);
        gateway.deployIdentityWithSalt(
            alice, IdentityTypes.INDIVIDUAL, "saltWithKeys", keys, _emptyModules, expiry, sig
        );

        address identityAddr = setup.idFactory.getIdentity(alice);
        Identity identity = Identity(payable(identityAddr));
        assertTrue(identity.keyHasPurpose(ClaimSignerHelper.addressToKey(alice), KeyPurposes.MANAGEMENT));
        assertTrue(identity.keyHasPurpose(ClaimSignerHelper.addressToKey(claimAdder), KeyPurposes.CLAIM_ADDER));
    }

    function test_deployIdentityWithSalt_withCustomManagementKeys() public {
        Gateway gateway = _deployGatewayWithCarol();
        vm.prank(deployer);
        setup.idFactory.transferOwnership(address(gateway));

        // bob as management key, not alice
        Structs.KeyParam[] memory keys = _makeSingleMgmtKeys(bob);
        uint256 expiry = block.timestamp + 365 days;
        bytes memory sig = _signDeploy(carolPk, alice, "saltCustom", keys, IdentityTypes.INDIVIDUAL, expiry);
        gateway.deployIdentityWithSalt(alice, IdentityTypes.INDIVIDUAL, "saltCustom", keys, _emptyModules, expiry, sig);

        address identityAddr = setup.idFactory.getIdentity(alice);
        Identity identity = Identity(payable(identityAddr));
        assertFalse(identity.keyHasPurpose(ClaimSignerHelper.addressToKey(alice), KeyPurposes.MANAGEMENT));
        assertTrue(identity.keyHasPurpose(ClaimSignerHelper.addressToKey(bob), KeyPurposes.MANAGEMENT));
    }

    function test_deployIdentityWithSalt_noExpiry() public {
        Gateway gateway = _deployGatewayWithCarol();
        vm.prank(deployer);
        setup.idFactory.transferOwnership(address(gateway));

        Structs.KeyParam[] memory keys = _makeSingleMgmtKeys(alice);
        bytes memory sig = _signDeploy(carolPk, alice, "saltToUse", keys, IdentityTypes.INDIVIDUAL, 0);
        gateway.deployIdentityWithSalt(alice, IdentityTypes.INDIVIDUAL, "saltToUse", keys, _emptyModules, 0, sig);

        assertTrue(setup.idFactory.getIdentity(alice) != address(0));
    }

    function test_deployIdentityWithSalt_revertRevokedSignature() public {
        Gateway gateway = _deployGatewayWithCarol();
        vm.prank(deployer);
        setup.idFactory.transferOwnership(address(gateway));

        Structs.KeyParam[] memory keys = _makeSingleMgmtKeys(alice);
        uint256 expiry = block.timestamp + 365 days;
        bytes memory sig = _signDeploy(carolPk, alice, "saltToUse", keys, IdentityTypes.INDIVIDUAL, expiry);

        gateway.revokeSignature(sig);

        vm.expectRevert(abi.encodeWithSelector(Errors.RevokedSignature.selector, sig));
        gateway.deployIdentityWithSalt(alice, IdentityTypes.INDIVIDUAL, "saltToUse", keys, _emptyModules, expiry, sig);
    }

    function test_deployIdentityWithSalt_revertExpiredSignature() public {
        Gateway gateway = _deployGatewayWithCarol();
        vm.prank(deployer);
        setup.idFactory.transferOwnership(address(gateway));

        Structs.KeyParam[] memory keys = _makeSingleMgmtKeys(alice);
        uint256 expiry = block.timestamp - 2 days;
        bytes memory sig = _signDeploy(carolPk, alice, "saltToUse", keys, IdentityTypes.INDIVIDUAL, expiry);

        vm.expectRevert(abi.encodeWithSelector(Errors.ExpiredSignature.selector, sig));
        gateway.deployIdentityWithSalt(alice, IdentityTypes.INDIVIDUAL, "saltToUse", keys, _emptyModules, expiry, sig);
    }

    // ============ deployIdentityForWallet ============

    function test_deployForWallet_revertZeroAddress() public {
        Gateway gateway = _deployGatewayWithCarol();
        vm.prank(deployer);
        setup.idFactory.transferOwnership(address(gateway));

        vm.expectRevert(Errors.ZeroAddress.selector);
        gateway.deployIdentityForWallet(
            address(0), IdentityTypes.INDIVIDUAL, _makeSingleMgmtKeys(address(0)), _emptyModules
        );
    }

    function test_deployForWallet_anotherSender() public {
        Gateway gateway = _deployGatewayWithCarol();
        vm.prank(deployer);
        setup.idFactory.transferOwnership(address(gateway));

        vm.prank(bob);
        gateway.deployIdentityForWallet(alice, IdentityTypes.INDIVIDUAL, _makeSingleMgmtKeys(alice), _emptyModules);

        address identityAddr = setup.idFactory.getIdentity(alice);
        assertTrue(identityAddr != address(0));
        assertTrue(
            Identity(payable(identityAddr)).keyHasPurpose(ClaimSignerHelper.addressToKey(alice), KeyPurposes.MANAGEMENT)
        );
    }

    function test_deployForWallet_shouldDeploy() public {
        Gateway gateway = _deployGatewayWithCarol();
        vm.prank(deployer);
        setup.idFactory.transferOwnership(address(gateway));

        vm.prank(alice);
        gateway.deployIdentityForWallet(alice, IdentityTypes.INDIVIDUAL, _makeSingleMgmtKeys(alice), _emptyModules);

        assertTrue(setup.idFactory.getIdentity(alice) != address(0));
    }

    function test_deployForWallet_revertAlreadyDeployed() public {
        Gateway gateway = _deployGatewayWithCarol();
        vm.prank(deployer);
        setup.idFactory.transferOwnership(address(gateway));

        vm.prank(alice);
        gateway.deployIdentityForWallet(alice, IdentityTypes.INDIVIDUAL, _makeSingleMgmtKeys(alice), _emptyModules);

        vm.prank(alice);
        vm.expectRevert();
        gateway.deployIdentityForWallet(alice, IdentityTypes.INDIVIDUAL, _makeSingleMgmtKeys(alice), _emptyModules);
    }

    // ============ transferFactoryOwnership ============

    function test_transferOwnership_shouldTransfer() public {
        Gateway gateway = _deployGatewayWithCarol();
        vm.prank(deployer);
        setup.idFactory.transferOwnership(address(gateway));

        gateway.transferFactoryOwnership(bob);
        assertEq(setup.idFactory.owner(), bob);
    }

    function test_transferOwnership_revertNotOwner() public {
        Gateway gateway = _deployGatewayWithCarol();
        vm.prank(deployer);
        setup.idFactory.transferOwnership(address(gateway));

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.OwnableUnauthorizedAccount.selector, alice));
        gateway.transferFactoryOwnership(bob);
    }

    // ============ revokeSignature ============

    function test_revokeSignature_revertNotOwner() public {
        Gateway gateway = _deployGatewayWithCarol();
        Structs.KeyParam[] memory keys = _makeSingleMgmtKeys(alice);
        uint256 expiry = block.timestamp + 365 days;
        bytes memory sig = _signDeploy(carolPk, alice, "saltToUse", keys, IdentityTypes.INDIVIDUAL, expiry);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.OwnableUnauthorizedAccount.selector, alice));
        gateway.revokeSignature(sig);
    }

    function test_revokeSignature_revertAlreadyRevoked() public {
        Gateway gateway = _deployGatewayWithCarol();
        Structs.KeyParam[] memory keys = _makeSingleMgmtKeys(alice);
        uint256 expiry = block.timestamp + 365 days;
        bytes memory sig = _signDeploy(carolPk, alice, "saltToUse", keys, IdentityTypes.INDIVIDUAL, expiry);

        gateway.revokeSignature(sig);

        vm.expectRevert(abi.encodeWithSelector(Errors.SignatureAlreadyRevoked.selector, sig));
        gateway.revokeSignature(sig);
    }

    // ============ approveSignature ============

    function test_approveSignature_revertNotOwner() public {
        Gateway gateway = _deployGatewayWithCarol();
        Structs.KeyParam[] memory keys = _makeSingleMgmtKeys(alice);
        uint256 expiry = block.timestamp + 365 days;
        bytes memory sig = _signDeploy(carolPk, alice, "saltToUse", keys, IdentityTypes.INDIVIDUAL, expiry);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.OwnableUnauthorizedAccount.selector, alice));
        gateway.approveSignature(sig);
    }

    function test_approveSignature_revertNotRevoked() public {
        Gateway gateway = _deployGatewayWithCarol();
        Structs.KeyParam[] memory keys = _makeSingleMgmtKeys(alice);
        uint256 expiry = block.timestamp + 365 days;
        bytes memory sig = _signDeploy(carolPk, alice, "saltToUse", keys, IdentityTypes.INDIVIDUAL, expiry);

        vm.expectRevert(abi.encodeWithSelector(Errors.SignatureNotRevoked.selector, sig));
        gateway.approveSignature(sig);
    }

    function test_approveSignature_shouldApprove() public {
        Gateway gateway = _deployGatewayWithCarol();
        Structs.KeyParam[] memory keys = _makeSingleMgmtKeys(alice);
        uint256 expiry = block.timestamp + 365 days;
        bytes memory sig = _signDeploy(carolPk, alice, "saltToUse", keys, IdentityTypes.INDIVIDUAL, expiry);

        gateway.revokeSignature(sig);
        gateway.approveSignature(sig);
    }

    // ============ approveSigner ============

    function test_approveSigner_revertZeroAddress() public {
        Gateway gateway = _deployGatewayWithCarol();
        vm.expectRevert(Errors.ZeroAddress.selector);
        gateway.approveSigner(address(0));
    }

    function test_approveSigner_revertNotOwner() public {
        Gateway gateway = _deployGatewayWithCarol();
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.OwnableUnauthorizedAccount.selector, alice));
        gateway.approveSigner(bob);
    }

    function test_approveSigner_revertAlreadyApproved() public {
        Gateway gateway = _deployGatewayWithCarol();
        gateway.approveSigner(bob);
        vm.expectRevert(abi.encodeWithSelector(Errors.SignerAlreadyApproved.selector, bob));
        gateway.approveSigner(bob);
    }

    function test_approveSigner_shouldApprove() public {
        Gateway gateway = _deployGatewayWithCarol();
        gateway.approveSigner(bob);
        assertTrue(gateway.approvedSigners(bob));
    }

    // ============ revokeSigner ============

    function test_revokeSigner_revertZeroAddress() public {
        address[] memory signers = new address[](1);
        signers[0] = alice;
        Gateway gateway = _deployGateway(signers);
        vm.expectRevert(Errors.ZeroAddress.selector);
        gateway.revokeSigner(address(0));
    }

    function test_revokeSigner_revertNotOwner() public {
        address[] memory signers = new address[](1);
        signers[0] = bob;
        Gateway gateway = _deployGateway(signers);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.OwnableUnauthorizedAccount.selector, alice));
        gateway.revokeSigner(bob);
    }

    function test_revokeSigner_revertNotApproved() public {
        address[] memory signers = new address[](1);
        signers[0] = alice;
        Gateway gateway = _deployGateway(signers);
        vm.expectRevert(abi.encodeWithSelector(Errors.SignerAlreadyNotApproved.selector, bob));
        gateway.revokeSigner(bob);
    }

    function test_revokeSigner_shouldRevoke() public {
        address[] memory signers = new address[](1);
        signers[0] = bob;
        Gateway gateway = _deployGateway(signers);
        gateway.revokeSigner(bob);
        assertFalse(gateway.approvedSigners(bob));
    }

    // ============ callFactory ============

    function test_callFactory_revertNotOwner() public {
        address[] memory signers = new address[](1);
        signers[0] = alice;
        Gateway gateway = _deployGateway(signers);
        vm.prank(deployer);
        setup.idFactory.transferOwnership(address(gateway));

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.OwnableUnauthorizedAccount.selector, alice));
        gateway.callFactory(abi.encodeCall(IdFactory.addTokenFactory, (address(0))));
    }

    function test_callFactory_revertFactoryError() public {
        address[] memory signers = new address[](1);
        signers[0] = alice;
        Gateway gateway = _deployGateway(signers);
        vm.prank(deployer);
        setup.idFactory.transferOwnership(address(gateway));

        vm.expectRevert(Errors.CallToFactoryFailed.selector);
        gateway.callFactory(abi.encodeCall(IdFactory.addTokenFactory, (address(0))));
    }

    function test_callFactory_shouldExecute() public {
        address[] memory signers = new address[](1);
        signers[0] = alice;
        Gateway gateway = _deployGateway(signers);
        vm.prank(deployer);
        setup.idFactory.transferOwnership(address(gateway));

        gateway.callFactory(abi.encodeCall(IdFactory.addTokenFactory, (bob)));
        assertTrue(setup.idFactory.isTokenFactory(bob));
    }

}
