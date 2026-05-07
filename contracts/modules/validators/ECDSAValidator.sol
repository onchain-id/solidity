// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import { ERC7579Validator } from "./ERC7579Validator.sol";

/**
 * @title ECDSAValidator
 * @dev ERC-7579 validator module for ECDSA signature verification.
 *
 * Stateless module — no signer storage, no callbacks. Uses the same signature format
 * as isClaimValid: `abi.encode(bytes signer, bytes actualSignature)`.
 *
 * Recovers the ECDSA signer via ecrecover and verifies the recovered address matches
 * the declared signer. The account separately verifies the signer is a registered key.
 *
 * ERC-7562 compliant: uses ecrecover precompile only.
 */
contract ECDSAValidator is ERC7579Validator {

    /// @dev Recovers the ECDSA signer and verifies it matches the declared signer.
    function _rawERC7579Validation(address, bytes32 hash, bytes calldata signature)
        internal
        view
        virtual
        override
        returns (bool)
    {
        // Same format as isClaimValid: abi.encode(bytes signer, bytes actualSignature)
        (bytes memory signer, bytes memory actualSig) = abi.decode(signature, (bytes, bytes));

        (address recovered, ECDSA.RecoverError err,) = ECDSA.tryRecover(hash, actualSig);
        if (err != ECDSA.RecoverError.NoError) return false;

        // Verify the recovered address matches the declared signer
        return keccak256(abi.encodePacked(recovered)) == keccak256(signer);
    }

    /// @dev No-op: stateless module, nothing to initialize.
    function onInstall(bytes calldata) public virtual override { }

    /// @dev No-op: stateless module, nothing to clean up.
    function onUninstall(bytes calldata) public virtual override { }

}
