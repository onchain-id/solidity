// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import { ClaimSignerHelper } from "../helpers/ClaimSignerHelper.sol";
import { OnchainIDSetup } from "../helpers/OnchainIDSetup.sol";
import { Constants } from "../utils/Constants.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Identity } from "contracts/Identity.sol";
import { IIdFactory } from "contracts/factory/IIdFactory.sol";
import { IdFactory } from "contracts/factory/IdFactory.sol";
import { Errors } from "contracts/libraries/Errors.sol";
import { KeyPurposes } from "contracts/libraries/KeyPurposes.sol";
import { ImplementationAuthority } from "contracts/proxy/ImplementationAuthority.sol";
import { RevertingIdentity } from "test/mocks/RevertingIdentity.sol";

contract IdFactoryTest is OnchainIDSetup {

    bytes32 private constant _LINK_WALLET_TYPEHASH =
        keccak256("LinkWallet(address wallet,address identity,uint256 nonce,uint256 expiry)");

    /// @dev Builds the EIP-712 domain separator matching IdFactory("IdentityFactory", "1")
    function _domainSeparator() internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("IdentityFactory"),
                keccak256("1"),
                block.chainid,
                address(onchainidSetup.idFactory)
            )
        );
    }

    /// @dev Builds an EIP-712 signature for linkWalletWithSignature
    function _signLinkWallet(uint256 signerPk, address wallet, address identity, uint256 nonce, uint256 expiry)
        internal
        view
        returns (bytes memory)
    {
        bytes32 structHash = keccak256(abi.encode(_LINK_WALLET_TYPEHASH, wallet, identity, nonce, expiry));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", _domainSeparator(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, digest);
        return abi.encodePacked(r, s, v);
    }

    /// @dev Helper: sign and call linkWalletWithSignature via execute()
    function _linkWalletWithSig(Identity identity, address walletOwner, address wallet, uint256 walletPk) internal {
        // Sign the EIP-712 message
        uint256 nonce = onchainidSetup.idFactory.nonces(wallet);
        uint256 expiry = block.timestamp + 1 hours;
        bytes memory signature = _signLinkWallet(walletPk, wallet, address(identity), nonce, expiry);

        // Call linkWalletWithSignature via identity.execute()
        bytes memory callData =
            abi.encodeWithSelector(IIdFactory.linkWalletWithSignature.selector, wallet, signature, nonce, expiry);
        vm.prank(walletOwner);
        identity.execute(address(onchainidSetup.idFactory), 0, callData);
    }

    // ============ createIdentity ============

    function test_revertBecauseAuthorityIsZeroAddress() public {
        vm.expectRevert(Errors.ZeroAddress.selector);
        new IdFactory(address(0));
    }

    function test_revertBecauseSenderNotAllowedToCreateIdentities() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
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

    function test_linkWallet_revertForNewWalletBoundToAnotherIdentity() public {
        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.WalletBoundToAnotherIdentity.selector, alice, address(aliceIdentity))
        );
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

    // ============ linkWalletWithSignature ============

    /// @notice Successful path: wallet signs EIP-712 message, identity links wallet via execute()
    function test_linkWalletWithSignature_shouldLink() public {
        _linkWalletWithSig(aliceIdentity, alice, david, davidPk);

        address[] memory wallets = onchainidSetup.idFactory.getWallets(address(aliceIdentity));
        assertEq(wallets.length, 2);
        assertEq(wallets[0], alice);
        assertEq(wallets[1], david);
        assertEq(onchainidSetup.idFactory.getIdentity(david), address(aliceIdentity));
    }

    /// @notice Nonce should increment after a successful link
    function test_linkWalletWithSignature_shouldIncrementNonce() public {
        assertEq(onchainidSetup.idFactory.nonces(david), 0);

        _linkWalletWithSig(aliceIdentity, alice, david, davidPk);

        assertEq(onchainidSetup.idFactory.nonces(david), 1);
    }

    /// @notice Wallet address cannot be zero
    function test_linkWalletWithSignature_revertForZeroAddress() public {
        uint256 expiry = block.timestamp + 1 hours;
        bytes memory signature = _signLinkWallet(davidPk, address(0), address(aliceIdentity), 0, expiry);

        bytes memory callData =
            abi.encodeWithSelector(IIdFactory.linkWalletWithSignature.selector, address(0), signature, 0, expiry);
        vm.prank(alice);
        // execute() will fail silently (ExecutionFailed event), but the inner call reverts with ZeroAddress
        aliceIdentity.execute(address(onchainidSetup.idFactory), 0, callData);

        // Verify the wallet was NOT linked
        assertEq(onchainidSetup.idFactory.getIdentity(address(0)), address(0));
    }

    /// @notice Expired signature should revert
    function test_linkWalletWithSignature_revertForExpiredSignature() public {
        uint256 expiry = block.timestamp - 1; // already expired
        bytes memory signature = _signLinkWallet(davidPk, david, address(aliceIdentity), 0, expiry);

        bytes memory callData =
            abi.encodeWithSelector(IIdFactory.linkWalletWithSignature.selector, david, signature, 0, expiry);
        vm.prank(alice);
        aliceIdentity.execute(address(onchainidSetup.idFactory), 0, callData);

        // Verify the wallet was NOT linked
        assertEq(onchainidSetup.idFactory.getIdentity(david), address(0));
    }

    /// @notice Invalid signature (wrong signer) should revert
    function test_linkWalletWithSignature_revertForInvalidSignature() public {
        uint256 expiry = block.timestamp + 1 hours;
        // Sign with carol's key instead of david's
        bytes memory badSignature = _signLinkWallet(carolPk, david, address(aliceIdentity), 0, expiry);

        bytes memory callData =
            abi.encodeWithSelector(IIdFactory.linkWalletWithSignature.selector, david, badSignature, 0, expiry);
        vm.prank(alice);
        aliceIdentity.execute(address(onchainidSetup.idFactory), 0, callData);

        // Verify the wallet was NOT linked
        assertEq(onchainidSetup.idFactory.getIdentity(david), address(0));
    }

    /// @notice Wrong nonce should revert
    function test_linkWalletWithSignature_revertForInvalidNonce() public {
        uint256 expiry = block.timestamp + 1 hours;
        uint256 wrongNonce = 42;
        bytes memory signature = _signLinkWallet(davidPk, david, address(aliceIdentity), wrongNonce, expiry);

        bytes memory callData =
            abi.encodeWithSelector(IIdFactory.linkWalletWithSignature.selector, david, signature, wrongNonce, expiry);
        vm.prank(alice);
        aliceIdentity.execute(address(onchainidSetup.idFactory), 0, callData);

        // Verify the wallet was NOT linked
        assertEq(onchainidSetup.idFactory.getIdentity(david), address(0));
    }

    /// @notice Replay attack: link -> unlink -> replay same signature should revert
    function test_linkWalletWithSignature_revertForReplayAttack() public {
        // Step 1: Create and use a valid signature (nonce=0)
        uint256 expiry = block.timestamp + 1 hours;
        uint256 nonce0 = 0;
        bytes memory signature0 = _signLinkWallet(davidPk, david, address(aliceIdentity), nonce0, expiry);

        bytes memory linkCallData =
            abi.encodeWithSelector(IIdFactory.linkWalletWithSignature.selector, david, signature0, nonce0, expiry);
        vm.prank(alice);
        aliceIdentity.execute(address(onchainidSetup.idFactory), 0, linkCallData);

        // Verify link succeeded
        assertEq(onchainidSetup.idFactory.getIdentity(david), address(aliceIdentity));
        assertEq(onchainidSetup.idFactory.nonces(david), 1);

        // Step 3: Unlink david via identity
        bytes memory unlinkCallData = abi.encodeWithSelector(IIdFactory.unlinkWalletByIdentity.selector, david);
        vm.prank(alice);
        aliceIdentity.execute(address(onchainidSetup.idFactory), 0, unlinkCallData);

        // Verify unlink succeeded
        assertEq(onchainidSetup.idFactory.getIdentity(david), address(0));

        // Step 4: Attempt to replay the same signature (nonce=0, but current nonce is 1)
        vm.prank(alice);
        aliceIdentity.execute(address(onchainidSetup.idFactory), 0, linkCallData);

        // Verify the replay was rejected — david is still NOT linked
        assertEq(onchainidSetup.idFactory.getIdentity(david), address(0));

        // Step 5: A fresh signature with nonce=1 should work
        uint256 nonce1 = 1;
        bytes memory signature1 = _signLinkWallet(davidPk, david, address(aliceIdentity), nonce1, expiry);
        bytes memory freshCallData =
            abi.encodeWithSelector(IIdFactory.linkWalletWithSignature.selector, david, signature1, nonce1, expiry);
        vm.prank(alice);
        aliceIdentity.execute(address(onchainidSetup.idFactory), 0, freshCallData);

        // Verify fresh signature succeeded
        assertEq(onchainidSetup.idFactory.getIdentity(david), address(aliceIdentity));
        assertEq(onchainidSetup.idFactory.nonces(david), 2);
    }

    /// @notice Wallet bound to a different identity should revert
    function test_linkWalletWithSignature_revertForWalletBoundToAnotherIdentity() public {
        // bob is already linked to bob's identity via factory setup
        uint256 expiry = block.timestamp + 1 hours;
        bytes memory signature = _signLinkWallet(bobPk, bob, address(aliceIdentity), 0, expiry);

        bytes memory callData =
            abi.encodeWithSelector(IIdFactory.linkWalletWithSignature.selector, bob, signature, 0, expiry);
        vm.prank(alice);
        aliceIdentity.execute(address(onchainidSetup.idFactory), 0, callData);

        // Verify bob is still linked to bob's identity, NOT alice's
        assertEq(onchainidSetup.idFactory.getIdentity(bob), address(bobIdentity));
    }

    /// @notice Wallet that is a token address should revert
    function test_linkWalletWithSignature_revertForTokenAddress() public {
        // Register david as a token identity so _tokenIdentity[david] != address(0)
        vm.prank(deployer);
        onchainidSetup.idFactory.createTokenIdentity(david, tokenOwner, "tokenDavid");

        // Sign and attempt to link
        uint256 expiry = block.timestamp + 1 hours;
        bytes memory signature = _signLinkWallet(davidPk, david, address(aliceIdentity), 0, expiry);

        bytes memory callData =
            abi.encodeWithSelector(IIdFactory.linkWalletWithSignature.selector, david, signature, 0, expiry);
        vm.prank(alice);
        aliceIdentity.execute(address(onchainidSetup.idFactory), 0, callData);

        // Verify david was NOT linked as a user wallet (still only a token identity)
        address[] memory wallets = onchainidSetup.idFactory.getWallets(address(aliceIdentity));
        assertEq(wallets.length, 1, "Should still have only alice");
    }

    /// @notice Max wallets exceeded should revert
    function test_linkWalletWithSignature_revertForMaxWallets() public {
        // Fill alice's identity to max wallets (101) using linkWallet
        for (uint256 i = 0; i < 100; i++) {
            address newWallet = vm.addr(1000 + i);
            vm.prank(alice);
            onchainidSetup.idFactory.linkWallet(newWallet);
        }

        // Now try to link one more via signature
        uint256 expiry = block.timestamp + 1 hours;
        bytes memory signature = _signLinkWallet(davidPk, david, address(aliceIdentity), 0, expiry);

        bytes memory callData =
            abi.encodeWithSelector(IIdFactory.linkWalletWithSignature.selector, david, signature, 0, expiry);
        vm.prank(alice);
        aliceIdentity.execute(address(onchainidSetup.idFactory), 0, callData);

        // Verify the wallet was NOT linked (max exceeded)
        assertEq(onchainidSetup.idFactory.getIdentity(david), address(0));
    }

    /// @notice Direct EOA call should fail because signature binds wallet to EOA address (not an identity)
    function test_linkWalletWithSignature_revertForWrongIdentityInSignature() public {
        uint256 expiry = block.timestamp + 1 hours;
        // Sign for david binding to aliceIdentity, but call from bob (EOA)
        // Signature was created for identity=aliceIdentity, but msg.sender=bob — signature mismatch
        bytes memory signature = _signLinkWallet(davidPk, david, address(aliceIdentity), 0, expiry);

        vm.prank(bob);
        vm.expectRevert();
        onchainidSetup.idFactory.linkWalletWithSignature(david, signature, 0, expiry);
    }

    // ============ unlinkWalletByIdentity ============

    /// @notice Happy path: identity unlinks a wallet via execute()
    function test_unlinkWalletByIdentity_shouldUnlink() public {
        // First link david via signature
        _linkWalletWithSig(aliceIdentity, alice, david, davidPk);
        assertEq(onchainidSetup.idFactory.getIdentity(david), address(aliceIdentity));

        // Unlink david via identity
        bytes memory callData = abi.encodeWithSelector(IIdFactory.unlinkWalletByIdentity.selector, david);
        vm.prank(alice);
        aliceIdentity.execute(address(onchainidSetup.idFactory), 0, callData);

        // Verify david is unlinked
        assertEq(onchainidSetup.idFactory.getIdentity(david), address(0));
        address[] memory wallets = onchainidSetup.idFactory.getWallets(address(aliceIdentity));
        assertEq(wallets.length, 1);
        assertEq(wallets[0], alice);
    }

    /// @notice Zero address should revert
    function test_unlinkWalletByIdentity_revertForZeroAddress() public {
        bytes memory callData = abi.encodeWithSelector(IIdFactory.unlinkWalletByIdentity.selector, address(0));
        vm.prank(alice);
        aliceIdentity.execute(address(onchainidSetup.idFactory), 0, callData);

        // Verify nothing changed (alice is still linked)
        assertEq(onchainidSetup.idFactory.getIdentity(alice), address(aliceIdentity));
    }

    /// @notice Wallet not linked to the calling identity should revert
    function test_unlinkWalletByIdentity_revertForWalletNotLinkedToIdentity() public {
        // Try to unlink bob from alice's identity - bob is linked to bob's identity
        bytes memory callData = abi.encodeWithSelector(IIdFactory.unlinkWalletByIdentity.selector, bob);
        vm.prank(alice);
        aliceIdentity.execute(address(onchainidSetup.idFactory), 0, callData);

        // Verify bob is still linked to bob's identity
        assertEq(onchainidSetup.idFactory.getIdentity(bob), address(bobIdentity));
    }

    /// @notice Direct EOA call should fail if wallet is linked to a different identity
    function test_unlinkWalletByIdentity_revertForNonIdentityCaller() public {
        // alice is linked to aliceIdentity. If david (EOA) calls unlinkWalletByIdentity(alice),
        // it should revert because _userIdentity[alice] != david
        vm.prank(david);
        vm.expectRevert(abi.encodeWithSelector(Errors.WalletNotLinkedToIdentity.selector, alice));
        onchainidSetup.idFactory.unlinkWalletByIdentity(alice);
    }

    // ============ Re-link restriction tests ============

    /// @notice linkWallet: unlinked wallet can be re-linked to the same identity
    function test_linkWallet_shouldAllowRelinkToSameIdentity() public {
        // Link david to alice's identity
        vm.prank(alice);
        onchainidSetup.idFactory.linkWallet(david);
        assertEq(onchainidSetup.idFactory.getIdentity(david), address(aliceIdentity));

        // Unlink david
        vm.prank(alice);
        onchainidSetup.idFactory.unlinkWallet(david);
        assertEq(onchainidSetup.idFactory.getIdentity(david), address(0));

        // Re-link david to the SAME identity — should succeed
        vm.prank(alice);
        onchainidSetup.idFactory.linkWallet(david);
        assertEq(onchainidSetup.idFactory.getIdentity(david), address(aliceIdentity));
    }

    /// @notice linkWallet: unlinked wallet cannot be linked to a different identity
    function test_linkWallet_revertForRelinkingToDifferentIdentity() public {
        // Link david to alice's identity
        vm.prank(alice);
        onchainidSetup.idFactory.linkWallet(david);

        // Unlink david
        vm.prank(alice);
        onchainidSetup.idFactory.unlinkWallet(david);

        // Bob tries to link david to bob's identity — should revert
        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.WalletBoundToAnotherIdentity.selector, david, address(aliceIdentity))
        );
        onchainidSetup.idFactory.linkWallet(david);
    }

    /// @notice createIdentity: previously linked wallet cannot create a new identity
    function test_createIdentity_revertForPreviouslyLinkedWallet() public {
        // Link david to alice's identity
        vm.prank(alice);
        onchainidSetup.idFactory.linkWallet(david);

        // Unlink david
        vm.prank(alice);
        onchainidSetup.idFactory.unlinkWallet(david);

        // Try to create a new identity for david — should revert
        // because _userIdentity[david] != address(0) (still bound to alice's identity)
        vm.prank(deployer);
        vm.expectRevert(abi.encodeWithSelector(Errors.WalletAlreadyLinkedToIdentity.selector, david));
        onchainidSetup.idFactory.createIdentity(david, "davidSalt");
    }

    /// @notice createIdentityWithManagementKeys: previously linked wallet cannot create a new identity
    function test_createIdentityWithManagementKeys_revertForPreviouslyLinkedWallet() public {
        // Link david to alice's identity
        vm.prank(alice);
        onchainidSetup.idFactory.linkWallet(david);

        // Unlink david
        vm.prank(alice);
        onchainidSetup.idFactory.unlinkWallet(david);

        // Try to create a new identity for david — should revert
        bytes32[] memory keys = new bytes32[](1);
        keys[0] = ClaimSignerHelper.addressToKey(alice);

        vm.prank(deployer);
        vm.expectRevert(abi.encodeWithSelector(Errors.WalletAlreadyLinkedToIdentity.selector, david));
        onchainidSetup.idFactory.createIdentityWithManagementKeys(david, "davidSalt", keys);
    }

    /// @notice linkWalletWithSignature: unlinked wallet can be re-linked to the same identity
    function test_linkWalletWithSignature_shouldAllowRelinkToSameIdentity() public {
        // Link david to alice's identity via signature
        _linkWalletWithSig(aliceIdentity, alice, david, davidPk);
        assertEq(onchainidSetup.idFactory.getIdentity(david), address(aliceIdentity));

        // Unlink david via identity
        bytes memory unlinkCallData = abi.encodeWithSelector(IIdFactory.unlinkWalletByIdentity.selector, david);
        vm.prank(alice);
        aliceIdentity.execute(address(onchainidSetup.idFactory), 0, unlinkCallData);
        assertEq(onchainidSetup.idFactory.getIdentity(david), address(0));

        // Re-link david to the SAME identity via signature — should succeed
        _linkWalletWithSig(aliceIdentity, alice, david, davidPk);
        assertEq(onchainidSetup.idFactory.getIdentity(david), address(aliceIdentity));
    }

    /// @notice linkWalletWithSignature: unlinked wallet cannot be linked to a different identity
    function test_linkWalletWithSignature_revertForRelinkToDifferentIdentity() public {
        // Link david to alice's identity via signature
        _linkWalletWithSig(aliceIdentity, alice, david, davidPk);

        // Unlink david via identity
        bytes memory unlinkCallData = abi.encodeWithSelector(IIdFactory.unlinkWalletByIdentity.selector, david);
        vm.prank(alice);
        aliceIdentity.execute(address(onchainidSetup.idFactory), 0, unlinkCallData);

        // Try to link david to bob's identity via signature — should fail
        uint256 nonce = onchainidSetup.idFactory.nonces(david);
        uint256 expiry = block.timestamp + 1 hours;
        bytes memory signature = _signLinkWallet(davidPk, david, address(bobIdentity), nonce, expiry);

        bytes memory callData =
            abi.encodeWithSelector(IIdFactory.linkWalletWithSignature.selector, david, signature, nonce, expiry);
        vm.prank(bob);
        bobIdentity.execute(address(onchainidSetup.idFactory), 0, callData);

        // Verify david was NOT linked to bob's identity
        assertEq(onchainidSetup.idFactory.getIdentity(david), address(0));
    }

    /// @notice getIdentity should return zero for an unlinked wallet
    function test_getIdentity_shouldReturnZeroForUnlinkedWallet() public {
        // Link david to alice's identity
        vm.prank(alice);
        onchainidSetup.idFactory.linkWallet(david);
        assertEq(onchainidSetup.idFactory.getIdentity(david), address(aliceIdentity));

        // Unlink david
        vm.prank(alice);
        onchainidSetup.idFactory.unlinkWallet(david);

        // getIdentity should return address(0) even though _userIdentity[david] still stores aliceIdentity
        assertEq(onchainidSetup.idFactory.getIdentity(david), address(0));
    }

    /// @notice linkWallet: wallet already actively linked to same identity should revert
    function test_linkWallet_revertForWalletAlreadyActivelyLinked() public {
        // Link david to alice's identity
        vm.prank(alice);
        onchainidSetup.idFactory.linkWallet(david);

        // Try to link david again — already actively linked
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.WalletAlreadyLinkedToIdentity.selector, david));
        onchainidSetup.idFactory.linkWallet(david);
    }

    /// @notice unlinkWallet: trying to unlink an unlinked wallet (bound but not active) should revert
    function test_unlinkWallet_revertForUnlinkedTarget() public {
        // Link david and carol to alice's identity
        vm.prank(alice);
        onchainidSetup.idFactory.linkWallet(david);
        vm.prank(alice);
        onchainidSetup.idFactory.linkWallet(carol);

        // Unlink david (now bound but not active)
        vm.prank(alice);
        onchainidSetup.idFactory.unlinkWallet(david);

        // carol tries to unlink david — david is bound but not actively linked
        vm.prank(carol);
        vm.expectRevert(Errors.OnlyLinkedWalletCanUnlink.selector);
        onchainidSetup.idFactory.unlinkWallet(david);
    }

    /// @notice linkWalletWithSignature: wallet already actively linked to same identity should revert
    function test_linkWalletWithSignature_revertForWalletAlreadyActivelyLinked() public {
        // Link david to alice's identity via signature
        _linkWalletWithSig(aliceIdentity, alice, david, davidPk);
        assertEq(onchainidSetup.idFactory.getIdentity(david), address(aliceIdentity));

        // Try to link david again via signature — already actively linked
        uint256 nonce = onchainidSetup.idFactory.nonces(david);
        uint256 expiry = block.timestamp + 1 hours;
        bytes memory signature = _signLinkWallet(davidPk, david, address(aliceIdentity), nonce, expiry);
        bytes memory callData =
            abi.encodeWithSelector(IIdFactory.linkWalletWithSignature.selector, david, signature, nonce, expiry);
        vm.prank(alice);
        aliceIdentity.execute(address(onchainidSetup.idFactory), 0, callData);

        // Verify david is still linked (call failed silently via execute)
        assertEq(onchainidSetup.idFactory.getIdentity(david), address(aliceIdentity));
    }

    /// @notice unlinkWalletByIdentity: trying to unlink a previously linked but now unlinked wallet should revert
    function test_unlinkWalletByIdentity_revertForUnlinkedWallet() public {
        // Link david to alice's identity via signature
        _linkWalletWithSig(aliceIdentity, alice, david, davidPk);

        // Unlink david via identity
        bytes memory unlinkCallData = abi.encodeWithSelector(IIdFactory.unlinkWalletByIdentity.selector, david);
        vm.prank(alice);
        aliceIdentity.execute(address(onchainidSetup.idFactory), 0, unlinkCallData);

        // Try to unlink david again — already unlinked but still bound
        vm.prank(alice);
        aliceIdentity.execute(address(onchainidSetup.idFactory), 0, unlinkCallData);

        // Verify david is still unlinked
        assertEq(onchainidSetup.idFactory.getIdentity(david), address(0));
    }

    /// @notice unlinkWallet: unlinked sender cannot unlink another wallet
    function test_unlinkWallet_revertForUnlinkedSender() public {
        // Link david and carol to alice's identity
        vm.prank(alice);
        onchainidSetup.idFactory.linkWallet(david);
        vm.prank(alice);
        onchainidSetup.idFactory.linkWallet(carol);

        // Unlink david
        vm.prank(alice);
        onchainidSetup.idFactory.unlinkWallet(david);

        // david (now unlinked but still bound) tries to unlink carol — should revert
        vm.prank(david);
        vm.expectRevert(Errors.OnlyLinkedWalletCanUnlink.selector);
        onchainidSetup.idFactory.unlinkWallet(carol);
    }

}
