// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import {Vm} from "forge-std/Vm.sol";

/// @notice Helper library for building and signing claims in tests
/// @dev Centralizes the EIP-191 signature logic used across many test files
library ClaimSignerHelper {
    struct Claim {
        address identity;
        address issuer;
        uint256 topic;
        uint256 scheme;
        bytes data;
        bytes signature;
        string uri;
        bytes32 id;
    }

    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    /// @notice Computes claim ID from issuer and topic
    function computeClaimId(address issuer, uint256 topic) internal pure returns (bytes32) {
        return keccak256(abi.encode(issuer, topic));
    }

    /// @notice Computes the key hash for an address (used in addKey / keyHasPurpose)
    function addressToKey(address addr) internal pure returns (bytes32) {
        return keccak256(abi.encode(addr));
    }

    /// @notice Signs a claim using EIP-191 format matching the Identity contract
    /// @param signerPk The private key of the signer
    /// @param identity The identity address the claim is for
    /// @param topic The claim topic
    /// @param data The claim data
    /// @return signature The EIP-191 signature (r, s, v packed)
    function signClaim(uint256 signerPk, address identity, uint256 topic, bytes memory data)
        internal
        pure
        returns (bytes memory)
    {
        bytes32 dataHash = keccak256(abi.encode(identity, topic, data));
        bytes32 ethSignedHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", dataHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, ethSignedHash);
        return abi.encodePacked(r, s, v);
    }

    /// @notice Builds a complete Claim struct with computed id and signature
    function buildClaim(
        uint256 signerPk,
        address identityAddr,
        address issuerAddr,
        uint256 topic,
        bytes memory data,
        string memory uri
    ) internal pure returns (Claim memory claim) {
        claim.identity = identityAddr;
        claim.issuer = issuerAddr;
        claim.topic = topic;
        claim.scheme = 1;
        claim.data = data;
        claim.uri = uri;
        claim.id = computeClaimId(issuerAddr, topic);
        claim.signature = signClaim(signerPk, identityAddr, topic, data);
    }
}
