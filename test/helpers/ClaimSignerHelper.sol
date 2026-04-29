// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import { Identity } from "contracts/Identity.sol";
import { Vm } from "forge-std/Vm.sol";

/// @notice Helper library for building and signing claims in tests
/// @dev Centralizes the EIP-712 claim signature logic used across many test files
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

    /// @notice Computes the key hash for an address using abi.encodePacked (unified hashing)
    function addressToKey(address addr) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(addr));
    }

    /// @notice Signs a claim using the issuer contract's EIP-712 domain and wraps in ERC-7913 format
    /// @dev The signer signs the EIP-712 typed data hash from `issuerContract.getClaimHash()`.
    ///      The returned signature is `abi.encode(signer, rawSig)` where signer = abi.encodePacked(signerAddr).
    /// @param signerPk The private key of the signer
    /// @param signerAddr The address of the signer (used as the ERC-7913 signer bytes)
    /// @param issuerContract The issuer contract address (provides the EIP-712 domain)
    /// @param identity The identity address the claim is for
    /// @param topic The claim topic
    /// @param data The claim data
    /// @return signature The wrapped signature: abi.encode(signer, rawSig)
    function signClaim(
        uint256 signerPk,
        address signerAddr,
        address issuerContract,
        address identity,
        uint256 topic,
        bytes memory data
    ) internal view returns (bytes memory) {
        bytes32 digest = Identity(payable(issuerContract)).getClaimHash(identity, topic, data);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, digest);
        bytes memory rawSig = abi.encodePacked(r, s, v);
        bytes memory signer = abi.encodePacked(signerAddr);
        return abi.encode(signer, rawSig);
    }

    /// @notice Builds a complete Claim struct with computed id and EIP-712 signature
    function buildClaim(
        uint256 signerPk,
        address signerAddr,
        address identityAddr,
        address issuerAddr,
        uint256 topic,
        bytes memory data,
        string memory uri
    ) internal view returns (Claim memory claim) {
        claim.identity = identityAddr;
        claim.issuer = issuerAddr;
        claim.topic = topic;
        claim.scheme = 1;
        claim.data = data;
        claim.uri = uri;
        claim.id = computeClaimId(issuerAddr, topic);
        claim.signature = signClaim(signerPk, signerAddr, issuerAddr, identityAddr, topic, data);
    }

}
