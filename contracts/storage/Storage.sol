// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;
import "./Structs.sol";

contract Storage is Structs {
    // nonce used by the execute/approve function
    uint256 internal _executionNonce;

    // keys as defined by IERC734
    mapping(bytes32 => Key) internal _keys;

    // keys for a given purpose
    // purpose KeyPurposes.MANAGEMENT = MANAGEMENT
    // purpose KeyPurposes.ACTION = ACTION
    // purpose KeyPurposes.CLAIM_SIGNER = CLAIM
    mapping(uint256 => bytes32[]) internal _keysByPurpose;

    // execution data
    mapping(uint256 => Execution) internal _executions;

    // claims held by the ONCHAINID
    mapping(bytes32 => Claim) internal _claims;

    // array of claims for a given topic
    mapping(uint256 => bytes32[]) internal _claimsByTopic;

    // status on initialization
    bool internal _initialized = false;

    // status on potential interactions with the contract
    bool internal _canInteract = false;

    // Index mappings for efficient key management (O(1) lookups)
    // Maps key -> purpose -> index in key.purposes array
    // Value 0 means not found, value 1+ means found at index (value-1)
    mapping(bytes32 => mapping(uint256 => uint256)) internal _purposeIndexInKey;

    // Maps purpose -> key -> index in _keysByPurpose array
    // Value 0 means not found, value 1+ means found at index (value-1)
    mapping(uint256 => mapping(bytes32 => uint256)) internal _keyIndexInPurpose;

    // Index mappings for efficient claim management (O(1) lookups)
    // Maps topic -> claimId -> index in _claimsByTopic array
    // Value 0 means not found, value 1+ means found at index (value-1)
    mapping(uint256 => mapping(bytes32 => uint256)) internal _claimIndexInTopic;

    // Maps claimId -> true if claim exists (used for validation/fallback)
    mapping(bytes32 => bool) internal _claimExists;

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     */
    uint256[45] private __gap; // solhint-disable-line ordering
}
