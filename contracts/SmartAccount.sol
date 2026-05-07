// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import {
    AccountERC7579Upgradeable
} from "@openzeppelin/contracts-upgradeable/account/extensions/draft-AccountERC7579Upgradeable.sol";
import { Account } from "@openzeppelin/contracts/account/Account.sol";
import { ERC4337Utils } from "@openzeppelin/contracts/account/utils/draft-ERC4337Utils.sol";
import { IERC1271 } from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import { PackedUserOperation } from "@openzeppelin/contracts/interfaces/draft-IERC4337.sol";
import { IERC7579Validator, MODULE_TYPE_VALIDATOR } from "@openzeppelin/contracts/interfaces/draft-IERC7579.sol";
import { Calldata } from "@openzeppelin/contracts/utils/Calldata.sol";
import { EIP712 } from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import { SignatureChecker } from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

import { KeyManager } from "./KeyManager.sol";
import { Errors } from "./libraries/Errors.sol";
import { KeyPurposes } from "./libraries/KeyPurposes.sol";

/**
 * @title SmartAccount
 * @dev Extends KeyManager with ERC-7579 modular account abstraction and signature-based execution.
 *
 * This contract bridges two systems:
 * - **ERC-7579 validator modules** for ERC-4337 validation (ERC-7562 compliant)
 * - **ERC-734 key purposes** for authorization and execution routing
 *
 * Two separate signature validation paths:
 * 1. **Application-level** (isClaimValid, execute-with-sig, approve-with-sig):
 *    Uses SignatureChecker.isValidSignatureNow — supports ECDSA, ERC-1271, and ERC-7913.
 * 2. **ERC-4337 validation** (validateUserOp) and **ERC-1271** (isValidSignature):
 *    Routes through installed ERC-7579 validator modules (ecrecover / P256 precompiles).
 *
 * Signature format for ERC-4337 and ERC-1271:
 *   `abi.encode(bytes32 keyHash, bytes rawModuleSignature)`
 *   - keyHash identifies the OnchainID key for purpose routing
 *   - rawModuleSignature is the module-specific signature (ECDSA or WebAuthn)
 */
abstract contract SmartAccount is KeyManager, AccountERC7579Upgradeable, EIP712 {

    /// @dev EIP-712 typehash for execute operations
    bytes32 internal constant _EXECUTE_TYPEHASH =
        keccak256("Execute(address to,uint256 value,bytes data,uint256 nonce)");

    /// @dev EIP-712 typehash for approve operations
    bytes32 internal constant _APPROVE_TYPEHASH = keccak256("Approve(uint256 id,bool shouldApprove)");

    /// @dev Transient storage for the validated keyHash from validateUserOp.
    ///      Binds the key validated in validateUserOp to the execution in executeFromEntryPoint,
    ///      preventing privilege escalation (e.g., ACTION key using a MANAGEMENT keyHash in callData).
    bytes32 transient _validatedKeyHash;

    /// @notice Allow receiving ETH (required for ERC-4337 prefunding and general use)
    receive() external payable virtual override { }

    /**
     * @notice Execute a transaction authorized by a signature (any ERC-7913 key type).
     * @dev Anyone can submit this (relayer pattern). Uses SignatureChecker (application-level).
     * @param _to Target address
     * @param _value ETH value
     * @param _callData Calldata for the execution
     * @param _keyHash The keccak256 of the signer bytes for the signing key
     * @param _signature The signature over the EIP-712 operation hash
     * @return executionId The execution request ID
     */
    function execute(address _to, uint256 _value, bytes memory _callData, bytes32 _keyHash, bytes memory _signature)
        external
        payable
        virtual
        delegatedOnly
        returns (uint256 executionId)
    {
        bytes32 opHash = getOperationHash(_to, _value, _callData, _getKeyStorage().executionNonce);
        _checkSignature(_keyHash, opHash, _signature);
        return _execute(_keyHash, _to, _value, _callData);
    }

    /**
     * @notice Approve an execution authorized by a signature.
     * @dev Uses SignatureChecker (application-level).
     */
    function approve(uint256 _id, bool _shouldApprove, bytes32 _keyHash, bytes memory _signature)
        public
        virtual
        delegatedOnly
        returns (bool success)
    {
        bytes32 opHash = _hashTypedDataV4(keccak256(abi.encode(_APPROVE_TYPEHASH, _id, _shouldApprove)));
        _checkSignature(_keyHash, opHash, _signature);
        return _approveExecution(_keyHash, _id, _shouldApprove);
    }

    /**
     * @notice Compute a deterministic EIP-712 operation hash for signature-based execution.
     */
    function getOperationHash(address _to, uint256 _value, bytes memory _data, uint256 _nonce)
        public
        view
        virtual
        returns (bytes32)
    {
        return _hashTypedDataV4(keccak256(abi.encode(_EXECUTE_TYPEHASH, _to, _value, keccak256(_data), _nonce)));
    }

    /// @dev Emitted when the EntryPoint executes a call on behalf of the account.
    event EntryPointExecuted(address indexed to, uint256 value, bytes data);

    /**
     * @notice Execute a transaction from the EntryPoint after validateUserOp has passed.
     * @dev Only callable by the EntryPoint. Uses the same purpose-based auto-approval as
     *      the direct execute() path:
     *      - MANAGEMENT key → auto-approved for any target
     *      - ACTION key → auto-approved for external calls only
     *      - CLAIM_SIGNER key → auto-approved for self-calls only
     *      - Other → queued, requires separate approval
     *
     * @param _to Target address
     * @param _value ETH value
     * @param _data Calldata for the execution
     * @return executionId The execution request ID
     */
    function executeFromEntryPoint(address _to, uint256 _value, bytes memory _data)
        external
        payable
        virtual
        delegatedOnly
        returns (uint256 executionId)
    {
        require(msg.sender == address(ERC4337Utils.ENTRYPOINT_V09), Account.AccountUnauthorized(msg.sender));

        // Read and consume the validated keyHash (set by validateUserOp).
        bytes32 keyHash = _validatedKeyHash;
        _validatedKeyHash = bytes32(0);
        require(keyHash != bytes32(0), Errors.InvalidSignature());

        emit EntryPointExecuted(_to, _value, _data);

        return _execute(keyHash, _to, _value, _data);
    }

    /**
     * @dev Override ERC-7579's _validateUserOp to bridge modules with OnchainID key purposes.
     *
     * Same signature format as isClaimValid:
     * `userOp.signature = abi.encode(bytes signer, bytes actualSignature)`
     *
     * The account derives keyHash = keccak256(signer) to verify key registration and bind
     * for purpose routing. The module receives the full signature and decodes it on its own.
     *
     * Nonce: upper 160 bits = validator module address (standard ERC-7579)
     */
    function _validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash, bytes calldata signature)
        internal
        virtual
        override
        returns (uint256)
    {
        // 1. Extract validator module from nonce (standard ERC-7579 routing)
        address module = _extractUserOpValidator(userOp);
        if (!isModuleInstalled(MODULE_TYPE_VALIDATOR, module, Calldata.emptyBytes())) {
            return ERC4337Utils.SIG_VALIDATION_FAILED;
        }

        // 2. Decode signer and derive keyHash (same format as isClaimValid)
        (bytes memory signer,) = abi.decode(signature, (bytes, bytes));
        bytes32 keyHash = keccak256(signer);

        // 3. Verify key is registered in OnchainID
        if (_getKeyStorage().keys[keyHash].key == bytes32(0)) {
            return ERC4337Utils.SIG_VALIDATION_FAILED;
        }

        // 4. Delegate to module — module receives full signature, decodes it on its own
        uint256 result = IERC7579Validator(module).validateUserOp(userOp, _signableUserOpHash(userOp, userOpHash));
        if (result != 0) return result;

        // 5. Bind the validated key for purpose routing in executeFromEntryPoint
        _validatedKeyHash = keyHash;

        return 0;
    }

    /**
     * @dev See {IERC1271-isValidSignature}.
     * @notice Validates a signature for external protocols (DeFi, marketplaces, etc.).
     *
     * Signature format: `abi.encodePacked(address module) + abi.encode(bytes signer, bytes actualSig)`
     * - First 20 bytes: validator module address
     * - Remaining: abi.encode(signer, actualSignature) — same format as isClaimValid
     *
     * The module receives the full inner signature and decodes it on its own.
     * Requires ACTION purpose (MANAGEMENT also works via universal permissions).
     */
    function isValidSignature(bytes32 _hash, bytes calldata _signature)
        public
        view
        virtual
        override(AccountERC7579Upgradeable)
        returns (bytes4)
    {
        if (_signature.length < 20) return bytes4(0xffffffff);

        // Extract module (first 20 bytes) and inner signature
        (address module, bytes calldata innerSignature) = _extractSignatureValidator(_signature);
        if (!isModuleInstalled(MODULE_TYPE_VALIDATOR, module, Calldata.emptyBytes())) {
            return bytes4(0xffffffff);
        }

        // Decode signer and derive keyHash for purpose check (same format as isClaimValid)
        (bytes memory signer,) = abi.decode(innerSignature, (bytes, bytes));
        bytes32 keyHash = keccak256(signer);
        if (!keyHasPurpose(keyHash, KeyPurposes.ACTION)) return bytes4(0xffffffff);

        // Delegate full inner signature to module — module decodes it on its own
        try IERC7579Validator(module).isValidSignatureWithSender(msg.sender, _hash, innerSignature) returns (
            bytes4 magic
        ) {
            return magic;
        } catch {
            return bytes4(0xffffffff);
        }
    }

    /**
     * @dev Verify a signature using OZ SignatureChecker (ERC-7913 aware). Reverts on failure.
     * Used by application-level paths (execute-with-sig, approve-with-sig).
     */
    function _checkSignature(bytes32 _keyHash, bytes32 _hash, bytes memory _signature) internal view virtual {
        KeyStorage storage ks = _getKeyStorage();
        require(ks.keys[_keyHash].key != bytes32(0), Errors.KeyNotRegistered(_keyHash));

        bytes memory signer = ks.keys[_keyHash].signerData;
        require(signer.length >= 20, Errors.InvalidSignerData());
        require(SignatureChecker.isValidSignatureNow(signer, _hash, _signature), Errors.InvalidSignature());
    }

    /**
     * @dev Check if a signature is valid. Returns false instead of reverting.
     * Used internally where non-reverting behavior is preferred.
     */
    function _isValidSignature(bytes32 _keyHash, bytes32 _hash, bytes memory _signature)
        internal
        view
        virtual
        returns (bool valid)
    {
        KeyStorage storage ks = _getKeyStorage();
        if (ks.keys[_keyHash].key == bytes32(0)) return false;

        bytes memory signer = ks.keys[_keyHash].signerData;
        if (signer.length < 20) return false;

        return SignatureChecker.isValidSignatureNow(signer, _hash, _signature);
    }

}
