// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import { Constants } from "../utils/Constants.sol";
import { ClaimIssuerHelper } from "./ClaimIssuerHelper.sol";
import { ClaimSignerHelper } from "./ClaimSignerHelper.sol";
import { IdentityHelper } from "./IdentityHelper.sol";
import { ClaimIssuer } from "contracts/ClaimIssuer.sol";
import { Identity } from "contracts/Identity.sol";
import { IdFactory } from "contracts/factory/IdFactory.sol";
import { IdentityTypes } from "contracts/libraries/IdentityTypes.sol";
import { KeyPurposes } from "contracts/libraries/KeyPurposes.sol";
import { KeyTypes } from "contracts/libraries/KeyTypes.sol";
import { ImplementationAuthority } from "contracts/proxy/ImplementationAuthority.sol";
import { Structs } from "contracts/storage/Structs.sol";
import { Test } from "forge-std/Test.sol";

/// @notice Base test contract providing full OnchainID infrastructure
contract OnchainIDSetup is Test {

    // Infrastructure
    IdentityHelper.OnchainIDSetup public onchainidSetup;

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
        onchainidSetup = IdentityHelper.deployFactory(deployer);
        vm.stopPrank();

        // Deploy ClaimIssuer with proxy
        claimIssuer = ClaimIssuerHelper.deployWithProxy(claimIssuerOwner);

        // Add CLAIM_SIGNER key to ClaimIssuer (register under unified key hash)
        vm.prank(claimIssuerOwner);
        claimIssuer.addKey(ClaimSignerHelper.addressToKey(claimIssuerOwner), KeyPurposes.CLAIM_SIGNER, KeyTypes.ECDSA);

        // Create alice identity via factory
        vm.prank(deployer);
        Structs.KeyParam[] memory aliceKeys = new Structs.KeyParam[](1);
        aliceKeys[0] = Structs.KeyParam({
            keyHash: keccak256(abi.encodePacked(alice)),
            purpose: KeyPurposes.MANAGEMENT,
            keyType: KeyTypes.ECDSA,
            signerData: abi.encodePacked(alice),
            clientData: ""
        });
        address aliceIdentityAddr = onchainidSetup.idFactory
            .createIdentity(alice, IdentityTypes.INDIVIDUAL, "alice", aliceKeys, new Structs.ModuleInstall[](0));
        aliceIdentity = Identity(payable(aliceIdentityAddr));

        // Add carol as CLAIM_SIGNER and david as ACTION key on alice's identity
        vm.startPrank(alice);
        aliceIdentity.addKeyWithData(
            ClaimSignerHelper.addressToKey(carol), KeyPurposes.CLAIM_SIGNER, KeyTypes.ECDSA, abi.encodePacked(carol), ""
        );
        aliceIdentity.addKeyWithData(
            ClaimSignerHelper.addressToKey(david), KeyPurposes.ACTION, KeyTypes.ECDSA, abi.encodePacked(david), ""
        );
        vm.stopPrank();

        // Build and add alice's claim 666
        aliceClaim666 = ClaimSignerHelper.buildClaim(
            claimIssuerOwnerPk,
            claimIssuerOwner,
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
        Structs.KeyParam[] memory bobKeys = new Structs.KeyParam[](1);
        bobKeys[0] = Structs.KeyParam({
            keyHash: keccak256(abi.encodePacked(bob)),
            purpose: KeyPurposes.MANAGEMENT,
            keyType: KeyTypes.ECDSA,
            signerData: abi.encodePacked(bob),
            clientData: ""
        });
        address bobIdentityAddr = onchainidSetup.idFactory
            .createIdentity(bob, IdentityTypes.INDIVIDUAL, "bob", bobKeys, new Structs.ModuleInstall[](0));
        bobIdentity = Identity(payable(bobIdentityAddr));

        // Create token identity
        vm.prank(deployer);
        Structs.KeyParam[] memory tokenKeys = new Structs.KeyParam[](1);
        tokenKeys[0] = Structs.KeyParam({
            keyHash: keccak256(abi.encodePacked(tokenOwner)),
            purpose: KeyPurposes.MANAGEMENT,
            keyType: KeyTypes.ECDSA,
            signerData: abi.encodePacked(tokenOwner),
            clientData: ""
        });
        onchainidSetup.idFactory
            .createTokenIdentity(Constants.TOKEN_ADDRESS, "tokenOwner", tokenKeys, new Structs.ModuleInstall[](0));
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
