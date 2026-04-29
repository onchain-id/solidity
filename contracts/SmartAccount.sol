// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import { Account } from "@openzeppelin/contracts/account/Account.sol";
import { ERC4337Utils } from "@openzeppelin/contracts/account/utils/draft-ERC4337Utils.sol";
import { IERC1271 } from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import { IAccount, PackedUserOperation } from "@openzeppelin/contracts/interfaces/draft-IERC4337.sol";
import { EIP712 } from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import { SignatureChecker } from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

import { KeyManager } from "./KeyManager.sol";
import { Errors } from "./libraries/Errors.sol";
import { KeyPurposes } from "./libraries/KeyPurposes.sol";

/**
 * @title SmartAccount
 * @dev Extends KeyManager with signature-based execution and ERC-4337 account abstraction.
 *
 * This contract provides:
 * - Signature-based execute/approve overloads (for non-EOA key types like WebAuthn)
 * - ERC-4337 `validateUserOp` for EntryPoint integration
 * - `executeFromEntryPoint` for post-validation execution by the EntryPoint
 * - Unified signature verification via OZ SignatureChecker (ERC-7913 aware)
 * - EIP-712 typed structured data for all operation hashes
 * - ERC-1271 `isValidSignature` for external protocol interop
 *
 * Signature verification supports:
 * - ECDSA (20-byte signer → ecrecover)
 * - ERC-1271 (20-byte contract signer → isValidSignature)
 * - ERC-7913 (>20-byte signer → verifier.verify(key, hash, sig))
 */
abstract contract SmartAccount is IAccount, IERC1271, KeyManager, EIP712 {

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
    receive() external payable virtual { }

    /**
     * @notice Execute a transaction authorized by a signature (any ERC-7913 key type).
     * @dev Anyone can submit this (relayer pattern). The signature proves the key holder authorized it.
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

    /// @dev Emitted when the EntryPoint executes a call on behalf of the account.
    event EntryPointExecuted(address indexed to, uint256 value, bytes data);

    /**
     * @notice Execute a transaction from the EntryPoint after validateUserOp has passed.
     * @dev Only callable by the EntryPoint. The keyHash used for purpose routing is read from
     *      transient storage (set by validateUserOp), preventing privilege escalation.
     *
     *      Purpose routing (same as EOA execute):
     *      - MANAGEMENT key → auto-approved for any target (including self-calls)
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
     * @notice Approve an execution authorized by a signature.
     * @param _id The execution request ID to approve
     * @param _shouldApprove Whether to approve or reject
     * @param _keyHash The keccak256 of the signer bytes for the signing key
     * @param _signature The signature over the EIP-712 approval hash
     * @return success Whether the execution was successful
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
     * @dev Frontend computes the same hash off-chain using eth_signTypedData_v4.
     *      For WebAuthn, this hash is used as the passkey challenge.
     * @param _to Target address
     * @param _value ETH value
     * @param _data Calldata
     * @param _nonce Execution nonce
     * @return The EIP-712 typed data hash
     */
    function getOperationHash(address _to, uint256 _value, bytes memory _data, uint256 _nonce)
        public
        view
        virtual
        returns (bytes32)
    {
        return _hashTypedDataV4(keccak256(abi.encode(_EXECUTE_TYPEHASH, _to, _value, keccak256(_data), _nonce)));
    }

    /**
     * @dev See {IAccount-validateUserOp}.
     * @notice Validates a UserOperation for ERC-4337 account abstraction.
     *
     * Per ERC-4337 spec:
     * - MUST revert if caller is not the EntryPoint
     * - SHOULD return SIG_VALIDATION_FAILED (1) on signature mismatch (not revert)
     * - MUST pay the EntryPoint at least missingAccountFunds
     *
     * @param userOp The packed user operation
     * @param userOpHash The hash of the user operation (computed by EntryPoint)
     * @param missingAccountFunds The amount of funds the account must deposit to the EntryPoint
     * @return validationData 0 for success, 1 for failure
     */
    function validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds)
        external
        virtual
        returns (uint256 validationData)
    {
        require(msg.sender == address(ERC4337Utils.ENTRYPOINT_V09), Account.AccountUnauthorized(msg.sender));

        // Prefund payment to EntryPoint. Failure is silently discarded —
        // this is the standard ERC-4337 pattern. The EntryPoint handles
        // insufficient balance by reverting the entire handleOps batch.
        if (missingAccountFunds > 0) {
            // solhint-disable-next-line avoid-low-level-calls
            (bool prefundSuccess,) = payable(msg.sender).call{ value: missingAccountFunds }("");
            (prefundSuccess);
        }

        // Decode (keyHash, signature) from userOp.signature
        (bytes32 keyHash, bytes memory sig) = abi.decode(userOp.signature, (bytes32, bytes));

        // Verify the signature is valid for a registered key (any purpose).
        // Purpose-based routing happens in executeFromEntryPoint via _execute/_canAutoApproveExecution.
        if (!_isValidSignature(keyHash, userOpHash, sig)) return ERC4337Utils.SIG_VALIDATION_FAILED;

        // Store the validated keyHash so executeFromEntryPoint uses the same key for purpose routing.
        _validatedKeyHash = keyHash;

        return 0;
    }

    /**
     * @dev See {IERC1271-isValidSignature}.
     * @notice Validates a signature on behalf of this identity for external protocols (DeFi, marketplaces, etc.).
     * @dev Signature format: `abi.encode(bytes32 keyHash, bytes actualSignature)`
     *      Requires ACTION purpose (MANAGEMENT also works via universal permissions).
     * @param _hash The hash that was signed
     * @param _signature The signature: abi.encode(keyHash, actualSignature)
     * @return magicValue 0x1626ba7e if valid, 0xffffffff otherwise
     */
    function isValidSignature(bytes32 _hash, bytes calldata _signature)
        external
        view
        virtual
        override
        returns (bytes4 magicValue)
    {
        (bytes32 keyHash, bytes memory sig) = abi.decode(_signature, (bytes32, bytes));

        if (!keyHasPurpose(keyHash, KeyPurposes.ACTION)) return bytes4(0xffffffff);

        KeyStorage storage ks = _getKeyStorage();
        if (ks.keys[keyHash].key == bytes32(0)) return bytes4(0xffffffff);

        bytes memory signer = ks.keys[keyHash].signerData;
        if (signer.length < 20) return bytes4(0xffffffff);

        if (!SignatureChecker.isValidSignatureNow(signer, _hash, sig)) return bytes4(0xffffffff);

        return bytes4(0x1626ba7e);
    }

    /**
     * @dev Verify a signature using OZ SignatureChecker (ERC-7913 aware). Reverts on failure.
     * @param _keyHash The key hash to verify against
     * @param _hash The hash that was signed
     * @param _signature The signature to verify
     */
    function _checkSignature(bytes32 _keyHash, bytes32 _hash, bytes memory _signature) internal view virtual {
        KeyStorage storage ks = _getKeyStorage();
        require(ks.keys[_keyHash].key != bytes32(0), Errors.KeyNotRegistered(_keyHash));

        bytes memory signer = ks.keys[_keyHash].signerData;
        require(signer.length >= 20, Errors.InvalidSignerData());
        require(SignatureChecker.isValidSignatureNow(signer, _hash, _signature), Errors.InvalidSignature());
    }

    /**
     * @dev Check if a signature is valid. Returns false instead of reverting on failure.
     *      Used by validateUserOp per ERC-4337 spec (SHOULD return failure, not revert).
     * @param _keyHash The key hash to verify against
     * @param _hash The hash that was signed
     * @param _signature The signature to verify
     * @return valid True if the signature is valid
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
