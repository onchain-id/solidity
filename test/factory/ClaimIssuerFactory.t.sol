// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import { ClaimIssuer } from "contracts/ClaimIssuer.sol";
import { ClaimIssuerFactory } from "contracts/factory/ClaimIssuerFactory.sol";
import { Errors } from "contracts/libraries/Errors.sol";
import { Test } from "forge-std/Test.sol";

contract ClaimIssuerFactoryTest is Test {

    ClaimIssuerFactory internal factory;
    ClaimIssuer internal claimIssuerImpl;

    address internal deployer;
    address internal alice;

    function setUp() public {
        deployer = makeAddr("cifDeployer");
        alice = makeAddr("cifAlice");

        vm.startPrank(deployer);
        claimIssuerImpl = new ClaimIssuer(deployer);
        factory = new ClaimIssuerFactory(address(claimIssuerImpl));
        vm.stopPrank();
    }

    function test_shouldDeployClaimIssuer() public {
        vm.prank(deployer);
        factory.deployClaimIssuer();

        address deployed = factory.claimIssuer(deployer);
        assertTrue(deployed != address(0));
    }

    function test_revertAlreadyDeployed() public {
        vm.prank(deployer);
        factory.deployClaimIssuer();

        vm.prank(deployer);
        vm.expectRevert(abi.encodeWithSelector(Errors.ClaimIssuerAlreadyDeployed.selector, deployer));
        factory.deployClaimIssuer();
    }

    function test_revertDeployOnBehalfZeroAddress() public {
        vm.prank(deployer);
        vm.expectRevert(Errors.ZeroAddress.selector);
        factory.deployClaimIssuerOnBehalf(address(0));
    }

    function test_revertBlacklistNotOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.OwnableUnauthorizedAccount.selector, alice));
        factory.blacklistAddress(deployer, true);
    }

    function test_revertBlacklistZeroAddress() public {
        vm.prank(deployer);
        vm.expectRevert(Errors.ZeroAddress.selector);
        factory.blacklistAddress(address(0), true);
    }

    function test_shouldBlacklistAddress() public {
        vm.prank(deployer);
        factory.blacklistAddress(alice, true);

        assertTrue(factory.isBlacklisted(alice));
    }

    function test_shouldUnblacklistAddress() public {
        vm.startPrank(deployer);
        factory.blacklistAddress(alice, true);
        factory.blacklistAddress(alice, false);
        vm.stopPrank();

        assertFalse(factory.isBlacklisted(alice));
    }

    function test_revertDeployFromBlacklisted() public {
        vm.prank(deployer);
        factory.blacklistAddress(alice, true);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.Blacklisted.selector, alice));
        factory.deployClaimIssuer();
    }

    function test_revertDeployOnBehalfNotOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.OwnableUnauthorizedAccount.selector, alice));
        factory.deployClaimIssuerOnBehalf(alice);
    }

    function test_revertUpdateImplementationNotOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.OwnableUnauthorizedAccount.selector, alice));
        factory.updateImplementation(alice);
    }

    function test_revertUpdateImplementationZeroAddress() public {
        vm.prank(deployer);
        vm.expectRevert(Errors.ZeroAddress.selector);
        factory.updateImplementation(address(0));
    }

    function test_shouldDeployClaimIssuerOnBehalf() public {
        vm.prank(deployer);
        address deployed = factory.deployClaimIssuerOnBehalf(alice);

        assertTrue(deployed != address(0), "Should deploy ClaimIssuer");
        assertEq(factory.claimIssuer(alice), deployed, "Should map alice to deployed ClaimIssuer");
    }

    function test_shouldUpdateImplementation() public {
        vm.prank(deployer);
        factory.updateImplementation(alice);

        assertEq(factory.implementation(), alice);
    }

}
