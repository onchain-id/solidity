// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import { WebAuthn } from "@openzeppelin/contracts/utils/cryptography/WebAuthn.sol";

import { ERC7579Validator } from "./ERC7579Validator.sol";

/**
 * @title WebAuthnValidator
 * @dev ERC-7579 validator module for WebAuthn/P256 signature verification.
 *
 * Stateless module — no signer storage, no callbacks. Uses the same signature format
 * as isClaimValid: `abi.encode(bytes signer, bytes actualSignature)`.
 *
 * The signer bytes contain the P256 public key: `abi.encodePacked(address verifier, bytes32 qx, bytes32 qy)`.
 * The module extracts qx/qy from signer and verifies the WebAuthn assertion against them.
 * The account separately verifies `keccak256(signer)` is a registered key.
 *
 * ERC-7562 compliant: uses RIP-7212 P256 precompile only.
 */
contract WebAuthnValidator is ERC7579Validator {

    /// @dev Extracts P256 coords from signer, verifies WebAuthn assertion.
    function _rawERC7579Validation(address, bytes32 hash, bytes calldata signature)
        internal
        view
        virtual
        override
        returns (bool)
    {
        // Same format as isClaimValid: abi.encode(bytes signer, bytes actualSignature)
        (bytes memory signer, bytes memory actualSig) = abi.decode(signature, (bytes, bytes));

        // signer = abi.encodePacked(address verifier, bytes32 qx, bytes32 qy) — 84 bytes
        if (signer.length < 84) return false;

        bytes32 qx;
        bytes32 qy;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            qx := mload(add(signer, 52))
            qy := mload(add(signer, 84))
        }

        // actualSig = abi.encode(WebAuthn.WebAuthnAuth)
        WebAuthn.WebAuthnAuth memory auth = abi.decode(actualSig, (WebAuthn.WebAuthnAuth));

        return WebAuthn.verify(abi.encodePacked(hash), auth, qx, qy);
    }

    /// @dev No-op: stateless module, nothing to initialize.
    function onInstall(bytes calldata) public virtual override { }

    /// @dev No-op: stateless module, nothing to clean up.
    function onUninstall(bytes calldata) public virtual override { }

}
