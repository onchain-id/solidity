// SPDX-License-Identifier: MIT
// Vendored from OpenZeppelin openzeppelin-accounts (audited)
// Source: packages/contracts/src/modules/validators/ERC7579Validator.sol

pragma solidity ^0.8.27;

import { ERC4337Utils } from "@openzeppelin/contracts/account/utils/draft-ERC4337Utils.sol";
import { IERC1271 } from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import { PackedUserOperation } from "@openzeppelin/contracts/interfaces/draft-IERC4337.sol";
import {
    IERC7579Module,
    IERC7579Validator,
    MODULE_TYPE_VALIDATOR
} from "@openzeppelin/contracts/interfaces/draft-IERC7579.sol";

/**
 * @dev Abstract validator module for ERC-7579 accounts.
 *
 * Provides base implementation for signature validation in ERC-7579 accounts.
 * Derived contracts must implement {onInstall}, {onUninstall}, and {_rawERC7579Validation}.
 */
abstract contract ERC7579Validator is IERC7579Module, IERC7579Validator {

    /// @inheritdoc IERC7579Module
    function isModuleType(uint256 moduleTypeId) public pure virtual returns (bool) {
        return moduleTypeId == MODULE_TYPE_VALIDATOR;
    }

    /// @inheritdoc IERC7579Validator
    function validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash) public virtual returns (uint256) {
        return _validateUserOp(userOp, userOpHash);
    }

    /// @dev Internal version of {validateUserOp}.
    function _validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash)
        internal
        virtual
        returns (uint256)
    {
        return _rawERC7579Validation(userOp.sender, userOpHash, userOp.signature)
            ? ERC4337Utils.SIG_VALIDATION_SUCCESS
            : ERC4337Utils.SIG_VALIDATION_FAILED;
    }

    /**
     * @dev See {IERC7579Validator-isValidSignatureWithSender}.
     *
     * Ignores the `sender` parameter and validates using {_rawERC7579Validation}.
     */
    function isValidSignatureWithSender(
        address,
        /* sender */
        bytes32 hash,
        bytes calldata signature
    )
        public
        view
        virtual
        returns (bytes4)
    {
        return
            _rawERC7579Validation(msg.sender, hash, signature) ? IERC1271.isValidSignature.selector : bytes4(0xffffffff);
    }

    /**
     * @dev Validation algorithm. Implementations must handle cryptographic verification.
     */
    function _rawERC7579Validation(address account, bytes32 hash, bytes calldata signature)
        internal
        view
        virtual
        returns (bool);

}
