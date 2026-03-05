// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import {ClaimSignerHelper} from "../helpers/ClaimSignerHelper.sol";
import {IdentityHelper} from "../helpers/IdentityHelper.sol";
import {Identity} from "contracts/Identity.sol";
import {KeyPurposes} from "contracts/libraries/KeyPurposes.sol";
import {KeyTypes} from "contracts/libraries/KeyTypes.sol";
import {Test} from "forge-std/Test.sol";

contract ProxyPatternTest is Test {
    address internal deployer;
    address internal alice;

    function setUp() public {
        deployer = makeAddr("proxyDeployer");
        alice = makeAddr("proxyAlice");
    }

    function test_deployIdentityThroughProxyAndWorkCorrectly() public {
        vm.prank(deployer);
        Identity identityProxy = IdentityHelper.deployIdentityWithProxy(deployer);

        assertEq(identityProxy.version(), "3.0.0");

        bytes32 deployerKey = ClaimSignerHelper.addressToKey(deployer);
        assertTrue(identityProxy.keyHasPurpose(deployerKey, KeyPurposes.MANAGEMENT));

        bytes32 aliceKey = ClaimSignerHelper.addressToKey(alice);
        vm.prank(deployer);
        identityProxy.addKey(aliceKey, KeyPurposes.ACTION, KeyTypes.ECDSA);

        assertTrue(identityProxy.keyHasPurpose(aliceKey, KeyPurposes.ACTION));
    }
}
