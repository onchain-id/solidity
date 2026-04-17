// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import { OnchainIDSetup } from "../helpers/OnchainIDSetup.sol";
import { Identity } from "contracts/Identity.sol";
import { Errors } from "contracts/libraries/Errors.sol";
import { IdentityTypes } from "contracts/libraries/IdentityTypes.sol";

contract InitTest is OnchainIDSetup {

    function test_revert_whenReinitializingDeployedIdentity() public {
        vm.prank(alice);
        vm.expectRevert("Initializable: contract is already initialized");
        aliceIdentity.initialize(alice, IdentityTypes.INDIVIDUAL);
    }

    function test_revert_whenInitializingWithZeroAddress() public {
        Identity libraryImpl = new Identity(deployer, true);
        vm.expectRevert(Errors.ZeroAddress.selector);
        libraryImpl.initialize(address(0), IdentityTypes.INDIVIDUAL);
    }

    function test_revert_whenCreatingIdentityWithInvalidInitialKey() public {
        vm.expectRevert(Errors.ZeroAddress.selector);
        new Identity(address(0), false);
    }

    function test_versionInitializedWhenDeployedAsRegularContract() public {
        Identity identityImplementation = getIdentityImplementation();
        assertEq(identityImplementation.version(), "3.0.0");
    }

    function test_revert_whenInitializingLibraryWithValidAddress() public {
        Identity libraryImpl = new Identity(deployer, true);
        vm.expectRevert(Errors.InitialKeyAlreadySetup.selector);
        libraryImpl.initialize(deployer, IdentityTypes.INDIVIDUAL);
    }

    function test_revert_whenCallingLibraryImplementationDirectly() public {
        Identity libraryImpl = new Identity(deployer, true);

        vm.prank(deployer);
        vm.expectRevert(Errors.InteractingWithLibraryContractForbidden.selector);
        libraryImpl.addKey(keccak256(abi.encodePacked(alice)), 1, 1);
    }

    function test_supportsERC165InterfaceDetection() public {
        // ERC165 interface ID
        assertTrue(aliceIdentity.supportsInterface(0x01ffc9a7));

        // Invalid interface IDs
        assertFalse(aliceIdentity.supportsInterface(0x12345678));
        assertFalse(aliceIdentity.supportsInterface(0x00000000));
        assertFalse(aliceIdentity.supportsInterface(0xffffffff));
    }

}
