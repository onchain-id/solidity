// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import { IERC734 } from "./interface/IERC734.sol";
import { Errors } from "./libraries/Errors.sol";
import { KeyPurposes } from "./libraries/KeyPurposes.sol";
import { KeyTypes } from "./libraries/KeyTypes.sol";
import { Structs } from "./storage/Structs.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title KeyManager
 * @dev Contract responsible for managing keys and execution functionality.
 *
 * This contract handles:
 * - Key addition, removal, and validation
 * - Execution request management
 * - Key purpose verification
 * - O(1) key lookups using index mappings
 *
 * The contract uses ERC-7201 storage slots for upgradeability.
 *
 * @custom:security This contract uses ERC-7201 storage slots to prevent storage collision attacks
 * in upgradeable contracts.
 */
contract KeyManager is IERC734 {

    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    /**
     * @dev Storage struct for key management and execution data
     * @custom:storage-location erc7201:onchainid.keymanager.storage
     */
    struct KeyStorage {
        /// @dev Nonce used by the execute/approve function to track execution requests
        uint256 executionNonce;
        /// @dev Mapping of key hash to Key struct as defined by IERC734
        mapping(bytes32 => Structs.Key) keys;
        /// @dev Mapping of purpose to set of key hashes (EnumerableSet for O(1) add/remove/contains)
        mapping(uint256 => EnumerableSet.Bytes32Set) keysByPurpose;
        /// @dev Mapping of execution ID to Execution struct for tracking execution requests
        mapping(uint256 => Structs.Execution) executions;
        /// @dev Flag indicating if the contract has been initialized
        bool initialized;
        /// @dev Flag indicating if the contract can be interacted with (prevents direct calls to implementation)
        bool canInteract;
        /// @dev Mapping of key hash to set of purposes (EnumerableSet for O(1) add/remove/contains)
        mapping(bytes32 => EnumerableSet.UintSet) keyPurposes;
        /// @dev Mapping of function selector to set of pending execution IDs
        mapping(bytes4 => EnumerableSet.UintSet) pendingExecutionsBySelector;
    }

    /**
     * @dev ERC-7201 Storage Slot for upgradeable contract pattern
     * This slot ensures no storage collision between different versions of the contract
     *
     * Formula: keccak256(abi.encode(uint256(keccak256(bytes(id))) - 1)) & ~bytes32(uint256(0xff))
     * where id is the namespace identifier
     */
    bytes32 internal constant _KEY_STORAGE_SLOT = keccak256(
        abi.encode(uint256(keccak256(bytes("onchainid.keymanager.storage"))) - 1)
    ) & ~bytes32(uint256(0xff));

    /**
     * @notice Prevent any direct calls to the implementation contract (marked by _canInteract = false).
     */
    modifier delegatedOnly() {
        _checkDelegated();
        _;
    }

    /**
     * @notice requires management key to call this function, or internal call
     */
    modifier onlyManager() {
        require(
            msg.sender == address(this) || keyHasPurpose(keccak256(abi.encode(msg.sender)), KeyPurposes.MANAGEMENT),
            Errors.SenderDoesNotHaveManagementKey()
        );
        _;
    }

    /**
     * @dev See {IERC734-execute}.
     * @notice Passes an execution instruction to the keymanager.
     *
     * Execution flow:
     * 1. If the sender is an ACTION key and the destination is external, execution is auto-approved
     * 2. If the sender is a MANAGEMENT key, execution is auto-approved for any destination
     * 3. If the sender is a CLAIM_SIGNER key and the call is to addClaim, execution is auto-approved
     * 4. Otherwise, the execution request must be approved via the `approve` method
     *
     * @param _to The destination address for the execution
     * @param _value The amount of ETH to send with the execution
     * @param _data The calldata for the execution
     * @return executionId The ID to use in the approve function to approve or reject this execution
     */
    function execute(address _to, uint256 _value, bytes memory _data)
        external
        payable
        virtual
        returns (uint256 executionId)
    {
        KeyStorage storage ks = _getKeyStorage();
        uint256 _executionId = ks.executionNonce;
        ks.executions[_executionId].to = _to;
        ks.executions[_executionId].value = _value;
        ks.executions[_executionId].data = _data;
        ks.executionNonce++;

        emit ExecutionRequested(_executionId, _to, _value, _data);

        // Check if execution can be auto-approved
        if (_canAutoApproveExecution(_to)) {
            _approve(_executionId, true);
        }

        // Only index if execution is still pending (not auto-executed)
        if (!ks.executions[_executionId].executed) {
            ks.pendingExecutionsBySelector[_extractSelector(_data)].add(_executionId);
        }

        return _executionId;
    }

    /**
     * @notice Gets the current execution nonce
     * @return The current execution nonce
     */
    function getCurrentNonce() external view virtual returns (uint256) {
        return _getKeyStorage().executionNonce;
    }

    /**
     * @dev See {IERC734-getKey}.
     * @notice Implementation of the getKey function from the ERC-734 standard
     * @param _key The public key.  for non-hex and long keys, its the Keccak256 hash of the key
     * @return purposes Returns the full key data, if present in the identity.
     * @return keyType Returns the full key data, if present in the identity.
     * @return key Returns the full key data, if present in the identity.
     */
    function getKey(bytes32 _key)
        external
        view
        virtual
        returns (uint256[] memory purposes, uint256 keyType, bytes32 key)
    {
        KeyStorage storage ks = _getKeyStorage();
        return (ks.keyPurposes[_key].values(), ks.keys[_key].keyType, ks.keys[_key].key);
    }

    /**
     * @dev See {IERC734-getKeyPurposes}.
     * @notice gets the purposes of a key
     * @param _key The public key.  for non-hex and long keys, its the Keccak256 hash of the key
     * @return _purposes Returns the purposes of the specified key
     */
    function getKeyPurposes(bytes32 _key) external view virtual returns (uint256[] memory _purposes) {
        return _getKeyStorage().keyPurposes[_key].values();
    }

    /**
     * @dev See {IERC734-getKeysByPurpose}.
     * @notice gets all the keys with a specific purpose from an identity
     * @param _purpose a uint256[] Array of the key types, like 1 = MANAGEMENT, 2 = ACTION, 3 = CLAIM, 4 = ENCRYPTION
     * @return keys Returns an array of public key bytes32 hold by this identity and having the specified purpose
     */
    function getKeysByPurpose(uint256 _purpose) external view virtual returns (bytes32[] memory keys) {
        return _getKeyStorage().keysByPurpose[_purpose].values();
    }

    /**
     * @notice Gets the execution data for a specific execution ID
     * @param _executionId The execution ID to get data for
     * @return execution including (to, value, data, approved, executed)
     */
    function getExecutionData(uint256 _executionId) external view virtual returns (Structs.Execution memory execution) {
        return _getKeyStorage().executions[_executionId];
    }

    /**
     * @notice Returns all pending (non-executed) execution IDs for a given function selector.
     * @dev Use bytes4(0) to query executions with empty or sub-4-byte calldata (e.g., plain ETH transfers).
     * @param _selector The 4-byte function selector to filter by
     * @return executionIds Array of pending execution IDs matching the selector
     */
    function getPendingExecutionsBySelector(bytes4 _selector)
        external
        view
        virtual
        returns (uint256[] memory executionIds)
    {
        return _getKeyStorage().pendingExecutionsBySelector[_selector].values();
    }

    /**
     * @dev See {IERC734-addKey}.
     * @notice implementation of the addKey function of the ERC-734 standard
     * Adds a _key to the identity. The _purpose specifies the purpose of key. Initially we propose four purposes:
     * 1: MANAGEMENT keys, which can manage the identity
     * 2: ACTION keys, which perform actions in this identities name (signing, logins, transactions, etc.)
     * 3: CLAIM signer keys, used to sign claims on other identities which need to be revokable.
     * 4: ENCRYPTION keys, used to encrypt data e.g. hold in claims.
     * MUST only be done by keys of purpose 1, or the identity itself.
     * If its the identity itself, the approval process will determine its approval.
     * @param _key keccak256 representation of an ethereum address
     * @param _type type of key used, which would be a uint256 for different key types. e.g. 1 = ECDSA, 2 = RSA, etc.
     * @param _purpose a uint256 specifying the key type, like 1 = MANAGEMENT, 2 = ACTION, 3 = CLAIM, 4 = ENCRYPTION
     * @return success Returns TRUE if the addition was successful and FALSE if not
     */
    function addKey(bytes32 _key, uint256 _purpose, uint256 _type)
        public
        virtual
        delegatedOnly
        onlyManager
        returns (bool success)
    {
        KeyStorage storage ks = _getKeyStorage();

        // 1. Early validation: Reject if key already has this purpose (O(1) lookup)
        require(!ks.keyPurposes[_key].contains(_purpose), Errors.KeyAlreadyHasPurpose(_key, _purpose));

        Structs.Key storage k = ks.keys[_key];

        // 2. Initialize new key if it doesn't exist yet
        if (k.key == bytes32(0)) {
            k.key = _key;
            k.keyType = _type;
        }

        // 3. Add purpose to key's purpose set and key to purpose's key set
        ks.keyPurposes[_key].add(_purpose);
        ks.keysByPurpose[_purpose].add(_key);

        emit KeyAdded(_key, _purpose, _type);
        return true;
    }

    /**
     * @dev See {IERC734-removeKey}.
     * @notice Removes a purpose from a key.
     *
     * Uses EnumerableSet for O(1) add/remove/contains operations.
     * If the key has no remaining purposes after removal, the key struct is deleted.
     *
     * Access control: Only MANAGEMENT keys or the identity itself can remove keys.
     *
     * @param _key The key to remove the purpose from
     * @param _purpose The purpose to remove from the key
     * @return success True if the purpose was successfully removed
     *
     */
    function removeKey(bytes32 _key, uint256 _purpose) public virtual delegatedOnly onlyManager returns (bool success) {
        KeyStorage storage ks = _getKeyStorage();
        Structs.Key storage k = ks.keys[_key];

        // 1. Validate key exists
        require(k.key == _key, Errors.KeyNotRegistered(_key));

        // 2. Validate key has the specified purpose (O(1) lookup)
        require(ks.keyPurposes[_key].contains(_purpose), Errors.KeyDoesNotHavePurpose(_key, _purpose));

        // 3. Remove purpose from key's set and key from purpose's set
        ks.keyPurposes[_key].remove(_purpose);
        ks.keysByPurpose[_purpose].remove(_key);

        emit KeyRemoved(_key, _purpose, k.keyType);

        // If key has no more purposes, delete the entire key struct to save gas
        if (ks.keyPurposes[_key].length() == 0) {
            delete ks.keys[_key];
        }

        return true;
    }

    /**
     *  @dev See {IERC734-approve}.
     *  @notice Approves an execution.
     *  If the sender is an ACTION key and the destination address is not the identity contract itself, then the
     *  approval is authorized and the operation would be performed.
     *  If the destination address is the identity itself, then the execution would be authorized and performed only
     *  if the sender is a MANAGEMENT key.
     */
    function approve(uint256 _id, bool _shouldApprove) public virtual delegatedOnly returns (bool success) {
        KeyStorage storage ks = _getKeyStorage();
        require(_id < ks.executionNonce, Errors.InvalidRequestId());
        require(!ks.executions[_id].executed, Errors.RequestAlreadyExecuted());

        // Validate that the sender has the appropriate key purpose
        if (ks.executions[_id].to == address(this)) {
            require(
                keyHasPurpose(keccak256(abi.encode(msg.sender)), KeyPurposes.MANAGEMENT),
                Errors.SenderDoesNotHaveManagementKey()
            );
        } else {
            require(
                keyHasPurpose(keccak256(abi.encode(msg.sender)), KeyPurposes.ACTION),
                Errors.SenderDoesNotHaveActionKey()
            );
        }

        return _approve(_id, _shouldApprove);
    }

    /**
     * @dev See {IERC734-keyHasPurpose}.
     * @notice Checks if a key has a specific purpose or MANAGEMENT purpose.
     *
     * This function uses O(1) index mappings for efficient lookups instead of
     * linear search through the purposes array. MANAGEMENT keys have universal
     * permissions according to the ERC-734 standard, so any key with MANAGEMENT
     * purpose will return true for any purpose.
     *
     * @param _key The key to check (keccak256 hash of the address)
     * @param _purpose The purpose to check for
     * @return result True if the key has the specified purpose or MANAGEMENT purpose
     *
     */
    function keyHasPurpose(bytes32 _key, uint256 _purpose) public view virtual returns (bool result) {
        KeyStorage storage ks = _getKeyStorage();

        // Early return if key doesn't exist
        if (ks.keys[_key].key == 0) return false;

        // O(1) lookup: Check if key has the specific purpose OR MANAGEMENT purpose
        // MANAGEMENT keys have universal permissions in the ERC-734 standard
        return ks.keyPurposes[_key].contains(_purpose) || ks.keyPurposes[_key].contains(KeyPurposes.MANAGEMENT);
    }

    /**
     * @dev Internal method to handle the actual approval logic
     * @param _id The execution ID to approve
     * @param _shouldApprove Whether to approve or reject the execution
     * @return success Whether the execution was successful
     */
    function _approve(uint256 _id, bool _shouldApprove) internal virtual returns (bool success) {
        KeyStorage storage ks = _getKeyStorage();
        emit Approved(_id, _shouldApprove);

        if (_shouldApprove) {
            ks.executions[_id].approved = true;

            // solhint-disable-next-line avoid-low-level-calls
            (success,) = ks.executions[_id].to.call{ value: (ks.executions[_id].value) }(ks.executions[_id].data);

            if (success) {
                emit Executed(_id, ks.executions[_id].to, ks.executions[_id].value, ks.executions[_id].data);
            } else {
                emit ExecutionFailed(_id, ks.executions[_id].to, ks.executions[_id].value, ks.executions[_id].data);
            }
        } else {
            ks.executions[_id].approved = false;
        }

        // Once approve() is called, the execution is no longer pending.
        ks.executions[_id].executed = true;
        ks.pendingExecutionsBySelector[_extractSelector(ks.executions[_id].data)].remove(_id);

        return success;
    }

    /**
     * @dev Internal helper to setup initial management key
     * @param initialManagementKey The ethereum address to be set as the management key
     */
    function _setupInitialManagementKey(address initialManagementKey) internal {
        KeyStorage storage ks = _getKeyStorage();

        bytes32 _key = keccak256(abi.encode(initialManagementKey));
        ks.keys[_key].key = _key;
        ks.keys[_key].keyType = KeyTypes.ECDSA;
        ks.keyPurposes[_key].add(KeyPurposes.MANAGEMENT);
        ks.keysByPurpose[KeyPurposes.MANAGEMENT].add(_key);

        emit KeyAdded(_key, KeyPurposes.MANAGEMENT, KeyTypes.ECDSA);
    }

    /**
     * @dev Internal helper to initialize key storage
     * @param initialManagementKey The ethereum address to be set as the management key
     */
    function _initializeKeyStorage(address initialManagementKey) internal {
        KeyStorage storage ks = _getKeyStorage();
        require(!ks.initialized, Errors.InitialKeyAlreadySetup());

        ks.initialized = true;
        ks.canInteract = true;

        _setupInitialManagementKey(initialManagementKey);
    }

    /**
     * @dev Internal method to check if an execution can be auto-approved based on key purposes.
     *
     * This function determines whether an execution request can be automatically approved
     * without requiring manual approval through the approve function.
     *
     * Auto-approval conditions:
     * 1. MANAGEMENT keys can auto-approve any execution
     * 2. CLAIM_SIGNER keys can auto-approve addClaim calls to the identity itself
     * 3. ACTION keys can auto-approve external calls (not to the identity itself)
     *
     * @param _to The target address of the execution
     * @return canAutoApprove Whether the execution can be auto-approved
     */
    function _canAutoApproveExecution(address _to) internal view virtual returns (bool canAutoApprove) {
        // MANAGEMENT keys can auto-approve any execution
        if (keyHasPurpose(keccak256(abi.encode(msg.sender)), KeyPurposes.MANAGEMENT)) {
            return true;
        }

        // For identity contract calls, check if it's a CLAIM_SIGNER key
        if (_to == address(this) && keyHasPurpose(keccak256(abi.encode(msg.sender)), KeyPurposes.CLAIM_SIGNER)) {
            return true;
        }

        // ACTION keys can auto-approve external calls
        if (_to != address(this) && keyHasPurpose(keccak256(abi.encode(msg.sender)), KeyPurposes.ACTION)) {
            return true;
        }

        return false;
    }

    /**
     * @dev Internal helper to enforce delegatedOnly check.
     */
    function _checkDelegated() internal view {
        require(_getKeyStorage().canInteract, Errors.InteractingWithLibraryContractForbidden());
    }

    /**
     * @dev Extracts the function selector (first 4 bytes) from calldata.
     * Returns bytes4(0) if data is shorter than 4 bytes.
     * @param _data The calldata to extract the selector from
     * @return selector The 4-byte function selector
     */
    function _extractSelector(bytes memory _data) internal pure returns (bytes4 selector) {
        if (_data.length >= 4) {
            selector = bytes4(_data);
        }
    }

    /**
     * @dev Returns the key storage struct at the specified ERC-7201 slot
     * @return s The KeyStorage struct pointer for the key management slot
     */
    function _getKeyStorage() internal pure returns (KeyStorage storage s) {
        bytes32 slot = _KEY_STORAGE_SLOT;
        assembly {
            s.slot := slot
        }
    }

}
