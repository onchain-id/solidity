// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import { CreateX } from "@createx/CreateX.sol";
import { Test } from "@forge-std/Test.sol";

import { ClaimIssuer } from "contracts/ClaimIssuer.sol";
import { Identity } from "contracts/Identity.sol";
import { IdFactory } from "contracts/factory/IdFactory.sol";
import { KeyPurposes } from "contracts/libraries/KeyPurposes.sol";
import { KeyTypes } from "contracts/libraries/KeyTypes.sol";
import { ImplementationAuthority } from "contracts/proxy/ImplementationAuthority.sol";

import { Constants } from "../utils/Constants.sol";
import { ClaimIssuerHelper } from "./ClaimIssuerHelper.sol";
import { ClaimSignerHelper } from "./ClaimSignerHelper.sol";
import { IdentityHelper } from "./IdentityHelper.sol";

/// @notice Base test contract providing full OnchainID infrastructure
contract OnchainIDSetup is Test {

    // Infrastructure
    IdentityHelper.OnchainIDSetup public onchainidSetup;
    CreateX public createx = new CreateX();

    // Standard test addresses with private keys
    address public deployer;
    uint256 public deployerPk;

    address public claimIssuerOwner;
    uint256 public claimIssuerOwnerPk;

    address public alice;
    uint256 public alicePk;

    address public bob;
    uint256 public bobPk;

    address public carol;
    uint256 public carolPk;

    address public david;
    uint256 public davidPk;

    address public tokenOwner;
    uint256 public tokenOwnerPk;

    // Deployed identities
    Identity public aliceIdentity;
    Identity public bobIdentity;
    ClaimIssuer public claimIssuer;

    // Pre-built claim
    ClaimSignerHelper.Claim public aliceClaim666;

    function setUp() public virtual {
        // Create labeled addresses with known private keys
        (deployer, deployerPk) = makeAddrAndKey("deployer");
        (claimIssuerOwner, claimIssuerOwnerPk) = makeAddrAndKey("claimIssuerOwner");
        (alice, alicePk) = makeAddrAndKey("alice");
        (bob, bobPk) = makeAddrAndKey("bob");
        (carol, carolPk) = makeAddrAndKey("carol");
        (david, davidPk) = makeAddrAndKey("david");
        (tokenOwner, tokenOwnerPk) = makeAddrAndKey("tokenOwner");

        // Deploy factory infrastructure (as deployer)
        vm.startPrank(deployer);
        onchainidSetup = IdentityHelper.deployFactory(deployer, address(createx), deployer);
        vm.stopPrank();

        // Deploy ClaimIssuer with proxy
        claimIssuer = ClaimIssuerHelper.deployWithProxy(claimIssuerOwner);

        // Add CLAIM_SIGNER key to ClaimIssuer
        vm.prank(claimIssuerOwner);
        claimIssuer.addKey(ClaimSignerHelper.addressToKey(claimIssuerOwner), KeyPurposes.CLAIM_SIGNER, KeyTypes.ECDSA);

        // Create alice identity via factory
        vm.prank(deployer);
        address aliceIdentityAddr = onchainidSetup.idFactory.createIdentity(alice, "alice");
        aliceIdentity = Identity(aliceIdentityAddr);

        // Add carol as CLAIM_SIGNER and david as ACTION key on alice's identity
        vm.startPrank(alice);
        aliceIdentity.addKey(ClaimSignerHelper.addressToKey(carol), KeyPurposes.CLAIM_SIGNER, KeyTypes.ECDSA);
        aliceIdentity.addKey(ClaimSignerHelper.addressToKey(david), KeyPurposes.ACTION, KeyTypes.ECDSA);
        vm.stopPrank();

        // Build and add alice's claim 666
        aliceClaim666 = ClaimSignerHelper.buildClaim(
            claimIssuerOwnerPk,
            address(aliceIdentity),
            address(claimIssuer),
            Constants.CLAIM_TOPIC_666,
            hex"0042",
            "https://example.com"
        );

        vm.prank(alice);
        aliceIdentity.addClaim(
            aliceClaim666.topic,
            aliceClaim666.scheme,
            aliceClaim666.issuer,
            aliceClaim666.signature,
            aliceClaim666.data,
            aliceClaim666.uri
        );

        // Create bob identity via factory
        vm.prank(deployer);
        address bobIdentityAddr = onchainidSetup.idFactory.createIdentity(bob, "bob");
        bobIdentity = Identity(bobIdentityAddr);

        // Create token identity
        vm.prank(deployer);
        onchainidSetup.idFactory.createTokenIdentity(Constants.TOKEN_ADDRESS, tokenOwner, "tokenOwner");
    }

    // ---- Convenience getters ----

    function getIdFactory() public view returns (IdFactory) {
        return onchainidSetup.idFactory;
    }

    function getImplementationAuthority() public view returns (ImplementationAuthority) {
        return onchainidSetup.implementationAuthority;
    }

    function getIdentityImplementation() public view returns (Identity) {
        return onchainidSetup.identityImplementation;
    }

}
