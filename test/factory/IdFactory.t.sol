// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import { ClaimSignerHelper } from "../helpers/ClaimSignerHelper.sol";
import { OnchainIDSetup } from "../helpers/OnchainIDSetup.sol";
import { Constants } from "../utils/Constants.sol";
import { Identity } from "contracts/Identity.sol";
import { RevertingIdentity } from "test/mocks/RevertingIdentity.sol";
import { IdFactory } from "contracts/factory/IdFactory.sol";
import { Errors } from "contracts/libraries/Errors.sol";
import { KeyPurposes } from "contracts/libraries/KeyPurposes.sol";
import { ImplementationAuthority } from "contracts/proxy/ImplementationAuthority.sol";

contract IdFactoryTest is OnchainIDSetup {

    // ============ createIdentity ============

    function test_revertBecauseAuthorityIsZeroAddress() public {
        vm.expectRevert(Errors.ZeroAddress.selector);
        new IdFactory(address(0));
    }

    function test_revertBecauseSenderNotAllowedToCreateIdentities() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.OwnableUnauthorizedAccount.selector, alice));
        onchainidSetup.idFactory.createIdentity(address(0), "salt1");
    }

    function test_revertBecauseWalletCannotBeZeroAddress() public {
        vm.prank(deployer);
        vm.expectRevert(Errors.ZeroAddress.selector);
        onchainidSetup.idFactory.createIdentity(address(0), "salt1");
    }

    function test_revertBecauseSaltCannotBeEmpty() public {
        vm.prank(deployer);
        vm.expectRevert(Errors.EmptyString.selector);
        onchainidSetup.idFactory.createIdentity(david, "");
    }

    function test_revertBecauseSaltAlreadyUsed() public {
        vm.prank(deployer);
        onchainidSetup.idFactory.createIdentity(carol, "saltUsed");

        vm.prank(deployer);
        vm.expectRevert(abi.encodeWithSelector(Errors.SaltTaken.selector, "OIDsaltUsed"));
        onchainidSetup.idFactory.createIdentity(david, "saltUsed");
    }

    function test_revertBecauseWalletAlreadyLinked() public {
        vm.prank(deployer);
        vm.expectRevert(abi.encodeWithSelector(Errors.WalletAlreadyLinkedToIdentity.selector, alice));
        onchainidSetup.idFactory.createIdentity(alice, "newSalt");
    }

    // ============ linkWallet ============

    function test_linkWallet_revertForZeroAddress() public {
        vm.prank(alice);
        vm.expectRevert(Errors.ZeroAddress.selector);
        onchainidSetup.idFactory.linkWallet(address(0));
    }

    function test_linkWallet_revertForSenderNotLinked() public {
        vm.prank(david);
        vm.expectRevert(abi.encodeWithSelector(Errors.WalletNotLinkedToIdentity.selector, david));
        onchainidSetup.idFactory.linkWallet(david);
    }

    function test_linkWallet_revertForNewWalletAlreadyLinked() public {
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(Errors.WalletAlreadyLinkedToIdentity.selector, alice));
        onchainidSetup.idFactory.linkWallet(alice);
    }

    function test_linkWallet_revertForNewWalletLinkedToToken() public {
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(Errors.TokenAlreadyLinked.selector, Constants.TOKEN_ADDRESS));
        onchainidSetup.idFactory.linkWallet(Constants.TOKEN_ADDRESS);
    }

    function test_linkWallet_shouldLinkNewWallet() public {
        vm.prank(alice);
        onchainidSetup.idFactory.linkWallet(david);

        address[] memory wallets = onchainidSetup.idFactory.getWallets(address(aliceIdentity));
        assertEq(wallets.length, 2);
        assertEq(wallets[0], alice);
        assertEq(wallets[1], david);
    }

    // ============ unlinkWallet ============

    function test_unlinkWallet_revertForZeroAddress() public {
        vm.prank(alice);
        vm.expectRevert(Errors.ZeroAddress.selector);
        onchainidSetup.idFactory.unlinkWallet(address(0));
    }

    function test_unlinkWallet_revertForUnlinkingSelf() public {
        vm.prank(alice);
        vm.expectRevert(Errors.CannotBeCalledOnSenderAddress.selector);
        onchainidSetup.idFactory.unlinkWallet(alice);
    }

    function test_unlinkWallet_revertForSenderNotLinked() public {
        vm.prank(david);
        vm.expectRevert(Errors.OnlyLinkedWalletCanUnlink.selector);
        onchainidSetup.idFactory.unlinkWallet(alice);
    }

    function test_unlinkWallet_shouldUnlink() public {
        vm.prank(alice);
        onchainidSetup.idFactory.linkWallet(david);

        vm.prank(alice);
        onchainidSetup.idFactory.unlinkWallet(david);

        address[] memory wallets = onchainidSetup.idFactory.getWallets(address(aliceIdentity));
        assertEq(wallets.length, 1);
        assertEq(wallets[0], alice);
    }

    // ============ getIdentity ============

    /// @notice getIdentity should return token identity for token addresses
    function test_getIdentity_forTokenAddress_shouldReturnTokenIdentity() public view {
        address identity = onchainidSetup.idFactory.getIdentity(Constants.TOKEN_ADDRESS);
        assertTrue(identity != address(0), "Token identity should exist");
    }

    /// @notice getIdentity should return user identity for wallet addresses
    function test_getIdentity_forUserWallet_shouldReturnUserIdentity() public view {
        address identity = onchainidSetup.idFactory.getIdentity(alice);
        assertEq(identity, address(aliceIdentity), "Should return alice's identity");
    }

    /// @notice getIdentity should return zero for unknown addresses
    function test_getIdentity_forUnknownAddress_shouldReturnZero() public {
        address identity = onchainidSetup.idFactory.getIdentity(makeAddr("unknown"));
        assertEq(identity, address(0), "Should return zero address");
    }

    // ============ linkWallet - max wallets ============

    /// @notice Linking more than 100 extra wallets should revert
    function test_linkWallet_revertForMaxWalletsExceeded() public {
        // alice already has 1 wallet linked. Link 100 more to reach the limit of 101.
        for (uint256 i = 0; i < 100; i++) {
            address newWallet = vm.addr(1000 + i);
            vm.prank(alice);
            onchainidSetup.idFactory.linkWallet(newWallet);
        }

        // The 102nd wallet should revert (101 wallets already linked)
        address overflowWallet = makeAddr("overflowWallet");
        vm.prank(alice);
        vm.expectRevert(Errors.MaxWalletsPerIdentityExceeded.selector);
        onchainidSetup.idFactory.linkWallet(overflowWallet);
    }

    // ============ unlinkWallet - swap-and-pop ============

    /// @notice Unlinking a wallet that is not the last in the array exercises swap-and-pop
    function test_unlinkWallet_shouldSwapAndPop() public {
        // Link carol and david to alice's identity
        vm.prank(alice);
        onchainidSetup.idFactory.linkWallet(carol);
        vm.prank(alice);
        onchainidSetup.idFactory.linkWallet(david);

        // wallets = [alice, carol, david]
        // Unlink carol (middle element) — triggers swap with david
        vm.prank(alice);
        onchainidSetup.idFactory.unlinkWallet(carol);

        address[] memory wallets = onchainidSetup.idFactory.getWallets(address(aliceIdentity));
        assertEq(wallets.length, 2, "Should have 2 wallets");
        assertEq(wallets[0], alice, "First wallet should be alice");
        assertEq(wallets[1], david, "Second wallet should be david (swapped)");
    }

    // ============ createIdentityWithManagementKeys ============

    function test_createIdentityWithManagementKeys_revertZeroAddress() public {
        bytes32[] memory keys = new bytes32[](1);
        keys[0] = ClaimSignerHelper.addressToKey(alice);

        vm.prank(deployer);
        vm.expectRevert(Errors.ZeroAddress.selector);
        onchainidSetup.idFactory.createIdentityWithManagementKeys(address(0), "salt1", keys);
    }

    function test_createIdentityWithManagementKeys_revertEmptySalt() public {
        bytes32[] memory keys = new bytes32[](1);
        keys[0] = ClaimSignerHelper.addressToKey(alice);

        vm.prank(deployer);
        vm.expectRevert(Errors.EmptyString.selector);
        onchainidSetup.idFactory.createIdentityWithManagementKeys(david, "", keys);
    }

    function test_createIdentityWithManagementKeys_revertSaltTaken() public {
        bytes32[] memory keys = new bytes32[](1);
        keys[0] = ClaimSignerHelper.addressToKey(alice);

        vm.prank(deployer);
        onchainidSetup.idFactory.createIdentityWithManagementKeys(david, "sharedSalt", keys);

        address anotherWallet = makeAddr("anotherWallet");
        vm.prank(deployer);
        vm.expectRevert(abi.encodeWithSelector(Errors.SaltTaken.selector, "OIDsharedSalt"));
        onchainidSetup.idFactory.createIdentityWithManagementKeys(anotherWallet, "sharedSalt", keys);
    }

    function test_createIdentityWithManagementKeys_revertWalletAlreadyLinked() public {
        bytes32[] memory keys = new bytes32[](1);
        keys[0] = ClaimSignerHelper.addressToKey(carol);

        vm.prank(deployer);
        vm.expectRevert(abi.encodeWithSelector(Errors.WalletAlreadyLinkedToIdentity.selector, alice));
        onchainidSetup.idFactory.createIdentityWithManagementKeys(alice, "uniqueSalt", keys);
    }

    function test_createIdentityWithManagementKeys_revertNoKeys() public {
        bytes32[] memory keys = new bytes32[](0);

        vm.prank(deployer);
        vm.expectRevert(Errors.EmptyListOfKeys.selector);
        onchainidSetup.idFactory.createIdentityWithManagementKeys(david, "salt1", keys);
    }

    function test_createIdentityWithManagementKeys_revertWalletInKeys() public {
        bytes32[] memory keys = new bytes32[](2);
        keys[0] = ClaimSignerHelper.addressToKey(alice);
        keys[1] = ClaimSignerHelper.addressToKey(david);

        vm.prank(deployer);
        vm.expectRevert(abi.encodeWithSelector(Errors.WalletAlsoListedInManagementKeys.selector, david));
        onchainidSetup.idFactory.createIdentityWithManagementKeys(david, "salt1", keys);
    }

    function test_createIdentityWithManagementKeys_shouldDeployAndSetKeys() public {
        bytes32[] memory keys = new bytes32[](1);
        keys[0] = ClaimSignerHelper.addressToKey(alice);

        vm.prank(deployer);
        address identityAddr = onchainidSetup.idFactory.createIdentityWithManagementKeys(david, "salt1", keys);

        Identity identity = Identity(identityAddr);

        // Raw abi.encode (not hashed) should return false
        assertFalse(
            identity.keyHasPurpose(bytes32(uint256(uint160(address(onchainidSetup.idFactory)))), KeyPurposes.MANAGEMENT)
        );
        assertFalse(identity.keyHasPurpose(bytes32(uint256(uint160(david))), KeyPurposes.MANAGEMENT));
        assertFalse(identity.keyHasPurpose(bytes32(uint256(uint160(alice))), KeyPurposes.MANAGEMENT));

        // Proper keccak256 hashed key SHOULD be a management key
        assertTrue(identity.keyHasPurpose(ClaimSignerHelper.addressToKey(alice), KeyPurposes.MANAGEMENT));
    }

    // ============ _deploy CREATE2 failure ============

    /// @notice CREATE2 failure triggers assembly revert when proxy constructor reverts
    function test_createIdentity_revertWhenCreate2Fails() public {
        // Deploy a factory with a reverting implementation
        RevertingIdentity revertingImpl = new RevertingIdentity();
        ImplementationAuthority badAuthority = new ImplementationAuthority(address(revertingImpl));
        IdFactory badFactory = new IdFactory(address(badAuthority));

        // createIdentity will try CREATE2 with IdentityProxy whose constructor
        // delegatecalls initialize() on RevertingIdentity, which reverts,
        // causing CREATE2 to return address(0) and triggering assembly revert
        vm.expectRevert();
        badFactory.createIdentity(david, "salt1");
    }

}
