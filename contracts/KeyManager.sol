// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import { IERC734 } from "./interface/IERC734.sol";
import { Errors } from "./libraries/Errors.sol";
import { KeyPurposes } from "./libraries/KeyPurposes.sol";
import { KeyTypes } from "./libraries/KeyTypes.sol";
import { Structs } from "./storage/Structs.sol";

// Import events from IERC734
import { IERC734 } from "./interface/IERC734.sol";

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
    /**
     * @dev Storage struct for key management and execution data
     * @custom:storage-location erc7201:onchainid.keymanager.storage
     */
    struct KeyStorage {
        /// @dev Nonce used by the execute/approve function to track execution requests
        uint256 executionNonce;
        /// @dev Mapping of key hash to Key struct as defined by IERC734
        mapping(bytes32 => Structs.Key) keys;
        /// @dev Mapping of purpose to array of key hashes for efficient purpose-based lookups
        mapping(uint256 => bytes32[]) keysByPurpose;
        /// @dev Mapping of execution ID to Execution struct for tracking execution requests
        mapping(uint256 => Structs.Execution) executions;
        /// @dev Flag indicating if the contract has been initialized
        bool initialized;
        /// @dev Flag indicating if the contract can be interacted with (prevents direct calls to implementation)
        bool canInteract;
        /// @dev O(1) index mapping: key -> purpose -> index in key.purposes array
        /// @dev Value 0 means not found, value 1+ means found at index (value-1)
        mapping(bytes32 => mapping(uint256 => uint256)) purposeIndexInKey;
        /// @dev O(1) index mapping: purpose -> key -> index in keysByPurpose array
        /// @dev Value 0 means not found, value 1+ means found at index (value-1)
        mapping(uint256 => mapping(bytes32 => uint256)) keyIndexInPurpose;
    }

    /**
     * @dev ERC-7201 Storage Slot for upgradeable contract pattern
     * This slot ensures no storage collision between different versions of the contract
     *
     * Formula: keccak256(abi.encode(uint256(keccak256(bytes(id))) - 1)) & ~bytes32(uint256(0xff))
     * where id is the namespace identifier
     */
    bytes32 internal constant _KEY_STORAGE_SLOT =
        keccak256(
            abi.encode(
                uint256(keccak256(bytes("onchainid.keymanager.storage"))) - 1
            )
        ) & ~bytes32(uint256(0xff));

    /**
     * @notice Prevent any direct calls to the implementation contract (marked by _canInteract = false).
     */
    modifier delegatedOnly() {
        require(
            _getKeyStorage().canInteract,
            Errors.InteractingWithLibraryContractForbidden()
        );
        _;
    }

    /**
     * @notice requires management key to call this function, or internal call
     */
    modifier onlyManager() {
        require(
            msg.sender == address(this) ||
                keyHasPurpose(
                    keccak256(abi.encode(msg.sender)),
                    KeyPurposes.MANAGEMENT
                ),
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
    function execute(
        address _to,
        uint256 _value,
        bytes memory _data
    ) external payable virtual returns (uint256 executionId) {
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
    function getKey(
        bytes32 _key
    )
        external
        view
        virtual
        returns (uint256[] memory purposes, uint256 keyType, bytes32 key)
    {
        KeyStorage storage ks = _getKeyStorage();
        return (
            ks.keys[_key].purposes,
            ks.keys[_key].keyType,
            ks.keys[_key].key
        );
    }

    /**
     * @dev See {IERC734-getKeyPurposes}.
     * @notice gets the purposes of a key
     * @param _key The public key.  for non-hex and long keys, its the Keccak256 hash of the key
     * @return _purposes Returns the purposes of the specified key
     */
    function getKeyPurposes(
        bytes32 _key
    ) external view virtual returns (uint256[] memory _purposes) {
        return (_getKeyStorage().keys[_key].purposes);
    }

    /**
     * @dev See {IERC734-getKeysByPurpose}.
     * @notice gets all the keys with a specific purpose from an identity
     * @param _purpose a uint256[] Array of the key types, like 1 = MANAGEMENT, 2 = ACTION, 3 = CLAIM, 4 = ENCRYPTION
     * @return keys Returns an array of public key bytes32 hold by this identity and having the specified purpose
     */
    function getKeysByPurpose(
        uint256 _purpose
    ) external view virtual returns (bytes32[] memory keys) {
        return _getKeyStorage().keysByPurpose[_purpose];
    }

    /**
     * @notice Gets the execution data for a specific execution ID
     * @param _executionId The execution ID to get data for
     * @return execution including (to, value, data, approved, executed)
     */
    function getExecutionData(
        uint256 _executionId
    ) external view virtual returns (Structs.Execution memory execution) {
        return _getKeyStorage().executions[_executionId];
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
    function addKey(
        bytes32 _key,
        uint256 _purpose,
        uint256 _type
    ) public virtual delegatedOnly onlyManager returns (bool success) {
        KeyStorage storage ks = _getKeyStorage();

        // 1. Early validation: Reject if key already has this purpose (O(1) lookup)
        require(
            ks.purposeIndexInKey[_key][_purpose] == 0,
            Errors.KeyAlreadyHasPurpose(_key, _purpose)
        );

        Structs.Key storage k = ks.keys[_key];

        // 2. Initialize new key if it doesn't exist yet
        if (k.key == bytes32(0)) {
            k.key = _key;
            k.keyType = _type;
        }

        // 3. Add purpose to key.purposes array and update index mapping
        k.purposes.push(_purpose);
        ks.purposeIndexInKey[_key][_purpose] = k.purposes.length; // Store 1-based index

        // 4. Add key to _keysByPurpose array and update index mapping
        ks.keysByPurpose[_purpose].push(_key);
        ks.keyIndexInPurpose[_purpose][_key] = ks
            .keysByPurpose[_purpose]
            .length; // Store 1-based index

        emit KeyAdded(_key, _purpose, _type);
        return true;
    }

    /**
     * @dev See {IERC734-removeKey}.
     * @notice Removes a purpose from a key.
     *
     * This function uses O(1) index mappings and efficient swap-and-pop technique
     * to maintain array consistency without gaps, ensuring optimal gas usage.
     *
     * The swap-and-pop technique:
     * 1. Moves the last element to the position of the element being removed
     * 2. Updates the index mappings for the swapped element
     * 3. Removes the last element (which is now the target element)
     *
     * Access control: Only MANAGEMENT keys or the identity itself can remove keys.
     *
     * @param _key The key to remove the purpose from
     * @param _purpose The purpose to remove from the key
     * @return success True if the purpose was successfully removed
     *
     */
    function removeKey(
        bytes32 _key,
        uint256 _purpose
    ) public virtual delegatedOnly onlyManager returns (bool success) {
        KeyStorage storage ks = _getKeyStorage();

        // Fetch the key data for efficient access
        Structs.Key storage k = ks.keys[_key];

        // 1. Validate key exists
        require(k.key == _key, Errors.KeyNotRegistered(_key));

        // 2. Validate key has the specified purpose (O(1) lookup)
        uint256 purposeIdxPlusOne = ks.purposeIndexInKey[_key][_purpose];
        require(
            purposeIdxPlusOne > 0,
            Errors.KeyDoesNotHavePurpose(_key, _purpose)
        );
        uint256 purposeIdx = purposeIdxPlusOne - 1; // Convert to 0-based index

        // Remove purpose from key struct
        _removePurposeFromKey(_key, _purpose, purposeIdx);

        // Remove key from purpose index
        uint256 keyIdxPlusOne = ks.keyIndexInPurpose[_purpose][_key];
        uint256 keyIdx = keyIdxPlusOne - 1; // Convert to 0-based index
        _removeKeyFromPurposeIndex(_key, _purpose, keyIdx);

        // Emit event and cleanup
        emit KeyRemoved(_key, _purpose, k.keyType);

        // If key has no more purposes, delete the entire key struct to save gas
        if (k.purposes.length == 0) {
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
    function approve(
        uint256 _id,
        bool _shouldApprove
    ) public virtual delegatedOnly returns (bool success) {
        KeyStorage storage ks = _getKeyStorage();
        require(_id < ks.executionNonce, Errors.InvalidRequestId());
        require(!ks.executions[_id].executed, Errors.RequestAlreadyExecuted());

        // Validate that the sender has the appropriate key purpose
        if (ks.executions[_id].to == address(this)) {
            require(
                keyHasPurpose(
                    keccak256(abi.encode(msg.sender)),
                    KeyPurposes.MANAGEMENT
                ),
                Errors.SenderDoesNotHaveManagementKey()
            );
        } else {
            require(
                keyHasPurpose(
                    keccak256(abi.encode(msg.sender)),
                    KeyPurposes.ACTION
                ),
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
    function keyHasPurpose(
        bytes32 _key,
        uint256 _purpose
    ) public view virtual returns (bool result) {
        KeyStorage storage ks = _getKeyStorage();

        // Early return if key doesn't exist
        if (ks.keys[_key].key == 0) return false;

        // O(1) lookup: Check if key has the specific purpose OR MANAGEMENT purpose
        // MANAGEMENT keys have universal permissions in the ERC-734 standard
        return
            ks.purposeIndexInKey[_key][_purpose] > 0 ||
            ks.purposeIndexInKey[_key][KeyPurposes.MANAGEMENT] > 0;
    }

    /**
     * @dev Internal method to handle the actual approval logic
     * @param _id The execution ID to approve
     * @param _shouldApprove Whether to approve or reject the execution
     * @return success Whether the execution was successful
     */
    function _approve(
        uint256 _id,
        bool _shouldApprove
    ) internal virtual returns (bool success) {
        KeyStorage storage ks = _getKeyStorage();
        emit Approved(_id, _shouldApprove);

        if (_shouldApprove) {
            ks.executions[_id].approved = true;

            // solhint-disable-next-line avoid-low-level-calls
            (success, ) = ks.executions[_id].to.call{
                value: (ks.executions[_id].value)
            }(ks.executions[_id].data);

            if (success) {
                ks.executions[_id].executed = true;

                emit Executed(
                    _id,
                    ks.executions[_id].to,
                    ks.executions[_id].value,
                    ks.executions[_id].data
                );

                return true;
            } else {
                emit ExecutionFailed(
                    _id,
                    ks.executions[_id].to,
                    ks.executions[_id].value,
                    ks.executions[_id].data
                );

                return false;
            }
        } else {
            ks.executions[_id].approved = false;
        }
        return false;
    }

    /**
     * @dev Internal helper to remove a purpose from a key using swap-and-pop technique
     * @param _key The key to remove the purpose from
     * @param _purpose The purpose to remove
     * @param _purposeIdx The index of the purpose in the key.purposes array
     */
    function _removePurposeFromKey(
        bytes32 _key,
        uint256 _purpose,
        uint256 _purposeIdx
    ) internal virtual {
        KeyStorage storage ks = _getKeyStorage();
        Structs.Key storage k = ks.keys[_key];

        // Get the last purpose in the array
        uint256 lastPurpose = k.purposes[k.purposes.length - 1];

        // Move the last purpose to the position of the one being removed
        k.purposes[_purposeIdx] = lastPurpose;

        // Update the index mapping for the moved purpose
        if (lastPurpose != _purpose) {
            ks.purposeIndexInKey[_key][lastPurpose] = _purposeIdx + 1; // Store 1-based index
        }

        // Remove the last element
        k.purposes.pop();

        // Clear the index mapping for the removed purpose
        delete ks.purposeIndexInKey[_key][_purpose];
    }

    /**
     * @dev Internal helper to remove a key from a purpose index using swap-and-pop technique
     * @param _key The key to remove
     * @param _purpose The purpose to remove the key from
     * @param _keyIdx The index of the key in the keysByPurpose array
     */
    function _removeKeyFromPurposeIndex(
        bytes32 _key,
        uint256 _purpose,
        uint256 _keyIdx
    ) internal virtual {
        KeyStorage storage ks = _getKeyStorage();

        // Get the last key in the purpose array
        bytes32 lastKey = ks.keysByPurpose[_purpose][
            ks.keysByPurpose[_purpose].length - 1
        ];

        // Move the last key to the position of the one being removed
        ks.keysByPurpose[_purpose][_keyIdx] = lastKey;

        // Update the index mapping for the moved key
        if (lastKey != _key) {
            ks.keyIndexInPurpose[_purpose][lastKey] = _keyIdx + 1; // Store 1-based index
        }

        // Remove the last element
        ks.keysByPurpose[_purpose].pop();

        // Clear the index mapping for the removed key
        delete ks.keyIndexInPurpose[_purpose][_key];
    }

    /**
     * @dev Internal helper to setup initial management key
     * @param initialManagementKey The ethereum address to be set as the management key
     */
    function _setupInitialManagementKey(address initialManagementKey) internal {
        KeyStorage storage ks = _getKeyStorage();

        // Set up the initial management key
        bytes32 _key = keccak256(abi.encode(initialManagementKey));
        ks.keys[_key].key = _key;
        ks.keys[_key].purposes = [KeyPurposes.MANAGEMENT]; // MANAGEMENT purpose
        ks.keys[_key].keyType = KeyTypes.ECDSA; // ECDSA key type
        ks.keysByPurpose[KeyPurposes.MANAGEMENT].push(_key);

        // Initialize index mappings for O(1) lookups
        // Store 1-based indices (0 means not found, 1+ means found at index-1)
        ks.purposeIndexInKey[_key][KeyPurposes.MANAGEMENT] = 1; // First purpose at index 0 + 1
        ks.keyIndexInPurpose[KeyPurposes.MANAGEMENT][_key] = 1; // First key at index 0 + 1

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
     * @dev Internal helper to set canInteract flag
     * @param _canInteract The value to set
     */
    function _setCanInteract(bool _canInteract) internal {
        _getKeyStorage().canInteract = _canInteract;
    }

    /**
     * @dev Internal helper to check if key storage is initialized
     * @return True if key storage is initialized
     */
    function _isKeyStorageInitialized() internal view returns (bool) {
        return _getKeyStorage().initialized;
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
    function _canAutoApproveExecution(
        address _to
    ) internal view virtual returns (bool canAutoApprove) {
        // MANAGEMENT keys can auto-approve any execution
        if (
            keyHasPurpose(
                keccak256(abi.encode(msg.sender)),
                KeyPurposes.MANAGEMENT
            )
        ) {
            return true;
        }

        // For identity contract calls, check if it's a CLAIM_SIGNER key
        if (
            _to == address(this) &&
            keyHasPurpose(
                keccak256(abi.encode(msg.sender)),
                KeyPurposes.CLAIM_SIGNER
            )
        ) {
            return true;
        }

        // ACTION keys can auto-approve external calls
        if (
            _to != address(this) &&
            keyHasPurpose(keccak256(abi.encode(msg.sender)), KeyPurposes.ACTION)
        ) {
            return true;
        }

        return false;
    }
    /**
     * @dev Internal helper to check if contract can interact
     * @return True if contract can interact
     */
    function _canInteract() internal view returns (bool) {
        return _getKeyStorage().canInteract;
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
