// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import { OnchainIDSetup } from "./helpers/OnchainIDSetup.sol";
import { Identity } from "contracts/Identity.sol";
import { Test as TestContract } from "test/mocks/Test.sol";
import { IImplementationAuthority } from "contracts/interface/IImplementationAuthority.sol";
import { Errors } from "contracts/libraries/Errors.sol";
import { IdentityProxy } from "contracts/proxy/IdentityProxy.sol";
import { ImplementationAuthority } from "contracts/proxy/ImplementationAuthority.sol";

contract ProxyTest is OnchainIDSetup {

    function test_revertBecauseImplementationIsZeroAddress() public {
        vm.expectRevert(Errors.ZeroAddress.selector);
        new IdentityProxy(address(0), alice);
    }

    function test_revertBecauseImplementationIsNotIdentity() public {
        TestContract testContract = new TestContract();
        ImplementationAuthority authority = new ImplementationAuthority(address(testContract));

        vm.expectRevert(Errors.InitializationFailed.selector);
        new IdentityProxy(address(authority), alice);
    }

    function test_revertBecauseInitialKeyIsZeroAddress() public {
        Identity impl = new Identity(deployer, true);
        ImplementationAuthority authority = new ImplementationAuthority(address(impl));

        vm.expectRevert(Errors.ZeroAddress.selector);
        new IdentityProxy(address(authority), address(0));
    }

    function test_preventCreatingAuthorityWithZeroAddress() public {
        vm.expectRevert(Errors.ZeroAddress.selector);
        new ImplementationAuthority(address(0));
    }

    function test_preventUpdatingToZeroAddress() public {
        vm.prank(deployer);
        vm.expectRevert(Errors.ZeroAddress.selector);
        onchainidSetup.implementationAuthority.updateImplementation(address(0));
    }

    function test_preventUpdatingWhenNotOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.OwnableUnauthorizedAccount.selector, alice));
        onchainidSetup.implementationAuthority.updateImplementation(address(0));
    }

    function test_implementationAuthority_shouldReturnCorrectAddress() public {
        Identity impl = new Identity(deployer, false);
        ImplementationAuthority authority = new ImplementationAuthority(address(impl));
        IdentityProxy proxy = new IdentityProxy(address(authority), deployer);

        assertEq(proxy.implementationAuthority(), address(authority), "Should return the correct authority address");
    }

    function test_updateImplementationAddress() public {
        // Deploy identity with its own proxy and authority
        Identity impl = new Identity(deployer, false);
        ImplementationAuthority authority = new ImplementationAuthority(address(impl));
        new IdentityProxy(address(authority), deployer);

        // Deploy new implementation
        Identity newImpl = new Identity(deployer, false);

        // Update implementation and verify event
        vm.expectEmit(true, true, true, true);
        emit IImplementationAuthority.UpdatedImplementation(address(newImpl));
        authority.updateImplementation(address(newImpl));
    }

}
