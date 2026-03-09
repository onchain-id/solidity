// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import { ERC1967Utils } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { Errors as OZErrors } from "@openzeppelin/contracts/utils/Errors.sol";

import { Identity } from "contracts/Identity.sol";
import { Errors } from "contracts/libraries/Errors.sol";
import { IdentityProxy } from "contracts/proxy/IdentityProxy.sol";
import { ImplementationAuthority } from "contracts/proxy/ImplementationAuthority.sol";

import { OnchainIDSetup } from "./helpers/OnchainIDSetup.sol";
import { Test as TestContract } from "./mocks/Test.sol";

contract ProxyTest is OnchainIDSetup {

    function test_revertBecauseImplementationIsZeroAddress() public {
        vm.expectRevert(abi.encode(ERC1967Utils.ERC1967InvalidBeacon.selector, address(0)));
        new IdentityProxy(address(0), alice);
    }

    function test_revertBecauseImplementationIsNotIdentity() public {
        TestContract testContract = new TestContract();
        ImplementationAuthority authority = new ImplementationAuthority(address(testContract));

        vm.expectRevert(OZErrors.FailedCall.selector);
        new IdentityProxy(address(authority), alice);
    }

    function test_revertBecauseInitialKeyIsZeroAddress() public {
        Identity impl = new Identity(deployer, true);
        ImplementationAuthority authority = new ImplementationAuthority(address(impl));

        vm.expectRevert(Errors.ZeroAddress.selector);
        new IdentityProxy(address(authority), address(0));
    }

    function test_preventCreatingAuthorityWithZeroAddress() public {
        vm.expectRevert(abi.encode(UpgradeableBeacon.BeaconInvalidImplementation.selector, address(0)));
        new ImplementationAuthority(address(0));
    }

    function test_preventUpdatingToZeroAddress() public {
        vm.prank(deployer);
        vm.expectRevert(abi.encode(UpgradeableBeacon.BeaconInvalidImplementation.selector, address(0)));
        onchainidSetup.implementationAuthority.upgradeTo(address(0));
    }

    function test_preventUpdatingWhenNotOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.OwnableUnauthorizedAccount.selector, alice));
        onchainidSetup.implementationAuthority.upgradeTo(address(0));
    }

    function test_implementationAuthority_shouldReturnCorrectAddress() public {
        Identity impl = new Identity(deployer, false);
        ImplementationAuthority authority = new ImplementationAuthority(address(impl));
        IdentityProxy proxy = new IdentityProxy(address(authority), deployer);

        // ERC-1967 beacon slot: bytes32(uint256(keccak256('eip1967.proxy.beacon')) - 1)
        bytes32 beaconSlot = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;
        address storedBeacon = address(uint160(uint256(vm.load(address(proxy), beaconSlot))));
        assertEq(storedBeacon, address(authority), "Should store the correct authority address as beacon");
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
        emit UpgradeableBeacon.Upgraded(address(newImpl));
        authority.upgradeTo(address(newImpl));
    }

}
