// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import { IdentityHelper } from "../helpers/IdentityHelper.sol";
import { IdFactory } from "contracts/factory/IdFactory.sol";
import { Errors } from "contracts/libraries/Errors.sol";
import { Test } from "forge-std/Test.sol";

contract TokenOidTest is Test {

    IdentityHelper.OnchainIDSetup internal setup;

    address internal deployer;
    address internal alice;
    address internal bob;

    function setUp() public {
        deployer = makeAddr("tokenOidDeployer");
        alice = makeAddr("tokenOidAlice");
        bob = makeAddr("tokenOidBob");

        vm.startPrank(deployer);
        setup = IdentityHelper.deployFactory(deployer);
        vm.stopPrank();
    }

    // ============ addTokenFactory ============

    function test_addTokenFactory_revertNotOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.OwnableUnauthorizedAccount.selector, alice));
        setup.idFactory.addTokenFactory(alice);
    }

    function test_addTokenFactory_revertZeroAddress() public {
        vm.prank(deployer);
        vm.expectRevert(Errors.ZeroAddress.selector);
        setup.idFactory.addTokenFactory(address(0));
    }

    function test_addTokenFactory_shouldAdd() public {
        vm.prank(deployer);
        setup.idFactory.addTokenFactory(alice);
        assertTrue(setup.idFactory.isTokenFactory(alice));
    }

    function test_addTokenFactory_revertAlreadyFactory() public {
        vm.prank(deployer);
        setup.idFactory.addTokenFactory(alice);

        vm.prank(deployer);
        vm.expectRevert(abi.encodeWithSelector(Errors.AlreadyAFactory.selector, alice));
        setup.idFactory.addTokenFactory(alice);
    }

    // ============ removeTokenFactory ============

    function test_removeTokenFactory_revertNotOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.OwnableUnauthorizedAccount.selector, alice));
        setup.idFactory.removeTokenFactory(bob);
    }

    function test_removeTokenFactory_revertZeroAddress() public {
        vm.prank(deployer);
        vm.expectRevert(Errors.ZeroAddress.selector);
        setup.idFactory.removeTokenFactory(address(0));
    }

    function test_removeTokenFactory_revertNotFactory() public {
        vm.prank(deployer);
        vm.expectRevert(abi.encodeWithSelector(Errors.NotAFactory.selector, bob));
        setup.idFactory.removeTokenFactory(bob);
    }

    function test_removeTokenFactory_shouldRemove() public {
        vm.prank(deployer);
        setup.idFactory.addTokenFactory(alice);

        vm.prank(deployer);
        setup.idFactory.removeTokenFactory(alice);
        assertFalse(setup.idFactory.isTokenFactory(alice));
    }

    // ============ createTokenIdentity ============

    function test_createTokenIdentity_revertNotAuthorized() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.OwnableUnauthorizedAccount.selector, alice));
        setup.idFactory.createTokenIdentity(alice, alice, "TST");
    }

    function test_createTokenIdentity_revertTokenZeroAddress() public {
        vm.prank(deployer);
        vm.expectRevert(Errors.ZeroAddress.selector);
        setup.idFactory.createTokenIdentity(address(0), alice, "TST");
    }

    function test_createTokenIdentity_revertOwnerZeroAddress() public {
        vm.prank(deployer);
        vm.expectRevert(Errors.ZeroAddress.selector);
        setup.idFactory.createTokenIdentity(alice, address(0), "TST");
    }

    function test_createTokenIdentity_revertEmptySalt() public {
        vm.prank(deployer);
        vm.expectRevert(Errors.EmptyString.selector);
        setup.idFactory.createTokenIdentity(alice, alice, "");
    }

    function test_createTokenIdentity_shouldCreateAndRevertDuplicate() public {
        assertFalse(setup.idFactory.isSaltTaken("Tokensalt1"));

        vm.prank(deployer);
        setup.idFactory.createTokenIdentity(alice, bob, "salt1");

        address tokenIdentityAddr = setup.idFactory.getIdentity(alice);
        assertTrue(tokenIdentityAddr != address(0));
        assertTrue(setup.idFactory.isSaltTaken("Tokensalt1"));
        assertFalse(setup.idFactory.isSaltTaken("Tokensalt2"));
        assertEq(setup.idFactory.getToken(tokenIdentityAddr), alice);

        // Same salt should revert
        vm.prank(deployer);
        vm.expectRevert(abi.encodeWithSelector(Errors.SaltTaken.selector, "Tokensalt1"));
        setup.idFactory.createTokenIdentity(alice, alice, "salt1");

        // Same token address should revert
        vm.prank(deployer);
        vm.expectRevert(abi.encodeWithSelector(Errors.TokenAlreadyLinked.selector, alice));
        setup.idFactory.createTokenIdentity(alice, alice, "salt2");
    }

}
