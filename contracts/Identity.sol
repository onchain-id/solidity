// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import { MulticallUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/MulticallUpgradeable.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { IdentitySmartAccount } from "./IdentitySmartAccount.sol";
import {
    SIG_VALIDATION_FAILED,
    SIG_VALIDATION_SUCCESS
} from "@account-abstraction/contracts/core/Helpers.sol";
import { PackedUserOperation } from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import { IEntryPoint } from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { Exec } from "@account-abstraction/contracts/utils/Exec.sol";
import { IIdentity } from "./interface/IIdentity.sol";
import { IClaimIssuer } from "./interface/IClaimIssuer.sol";
import { IERC734 } from "./interface/IERC734.sol";
import { IERC735 } from "./interface/IERC735.sol";
import { Version } from "./version/Version.sol";
import { Errors } from "./libraries/Errors.sol";
import { KeyPurposes } from "./libraries/KeyPurposes.sol";
import { Structs } from "./storage/Structs.sol";
import { KeyManager } from "./KeyManager.sol";

/**
 * @title Identity
 * @dev Implementation of the `IERC734` "KeyHolder" and the `IERC735` "ClaimHolder" interfaces
 * into a common Identity Contract.
 *
 * This implementation uses ERC-7201 storage slots for upgradeability, providing:
 * - O(1) key and claim management operations
 * - Efficient index mappings for fast lookups
 * - Swap-and-pop techniques for gas-optimized array operations
 * - Separation of key and claim storage for better organization
 * - Upgradeable version management through ERC-7201 storage slots
 *
 * The contract supports four key purposes:
 * - MANAGEMENT: Keys that can manage the identity
 * - ACTION: Keys that can perform actions on behalf of the identity
 * - CLAIM_SIGNER: Keys that can sign claims for other identities
 * - ENCRYPTION: Keys used for data encryption
 *
 * @custom:security This contract uses ERC-7201 storage slots to prevent storage collision attacks
 * in upgradeable contracts.
 */
contract Identity is
    Initializable,
    UUPSUpgradeable,
    IIdentity,
    IdentitySmartAccount,
    Version,
    KeyManager,
    MulticallUpgradeable
{
    /**
     * @dev Storage struct for claim management data
     * @custom:storage-location erc7201:onchainid.identity.claim.storage
     */
    struct ClaimStorage {
        /// @dev Mapping of claim ID to Claim struct as defined by IERC735
        mapping(bytes32 => Structs.Claim) claims;
        /// @dev Mapping of topic to array of claim IDs for efficient topic-based lookups
        mapping(uint256 => bytes32[]) claimsByTopic;
        /// @dev O(1) index mapping: topic -> claimId -> index in claimsByTopic array
        /// @dev Value 0 means not found, value 1+ means found at index (value-1)
        mapping(uint256 => mapping(bytes32 => uint256)) claimIndexInTopic;
        /// @dev Mapping of claimId -> true if claim exists (used for validation/fallback)
        mapping(bytes32 => bool) claimExists;
    }

    /**
     * @dev ERC-7201 Storage Slot for claim management data
     * This slot ensures no storage collision between different versions of the contract
     *
     * Formula: keccak256(abi.encode(uint256(keccak256(bytes(id))) - 1)) & ~bytes32(uint256(0xff))
     * where id is the namespace identifier
     */
    bytes32 internal constant _CLAIM_STORAGE_SLOT =
        keccak256(
            abi.encode(
                uint256(keccak256(bytes("onchainid.identity.claim.storage"))) -
                    1
            )
        ) & ~bytes32(uint256(0xff));

    // Key management functionality is inherited from KeyManager contract

    // ========= Modifiers =========

    /// @notice requires claim key to call this function, or internal call
    modifier onlyClaimKey() {
        require(
            msg.sender == address(this) ||
                keyHasPurpose(
                    keccak256(abi.encode(msg.sender)),
                    KeyPurposes.CLAIM_SIGNER
                ),
            Errors.SenderDoesNotHaveClaimSignerKey()
        );
        _;
    }

    // ========= Constructor =========

    /**
     * @notice constructor of the Identity contract
     * @param initialManagementKey the address of the management key at deployment
     * @param _isLibrary boolean value stating if the contract is library or not
     * calls __Identity_init if contract is not library
     */
    constructor(address initialManagementKey, bool _isLibrary) {
        require(initialManagementKey != address(0), Errors.ZeroAddress());

        if (!_isLibrary) {
            __Identity_init(initialManagementKey);
            super.__Version_init("2.2.2"); // Initialize version storage for direct deployments
        } else {
            _getKeyStorage().initialized = true;
        }
    }

    /**
     * @dev See {IERC734-execute}.
     * @notice Executes a single call from the account (ERC-734 compatible)
     */
    function execute(
        address _to,
        uint256 _value,
        bytes calldata _data
    )
        external
        payable
        virtual
        override(IERC734, KeyManager)
        returns (uint256 executionId)
    {
        // Allow entry point calls
        if (msg.sender == address(entryPoint())) {
            // For entry point calls, use direct execution
            _executeDirect(_to, _value, _data);
            return 0; // Return 0 for entry point calls
        }

        // For regular calls, use KeyManager's execution logic
        KeyStorage storage ks = _getKeyStorage();
        executionId = ks.executionNonce;
        ks.executions[executionId].to = _to;
        ks.executions[executionId].value = _value;
        ks.executions[executionId].data = _data;
        ks.executionNonce++;

        emit ExecutionRequested(executionId, _to, _value, _data);

        // Check if execution can be auto-approved
        if (_canAutoApproveExecution(_to)) {
            _approve(executionId, true);
        }
    }

    /**
     * @notice When using this contract as an implementation for a proxy, call this initializer with a delegatecall.
     * @dev This function initializes the upgradeable contract and sets up the initial management key.
     * It calls the UUPS upgradeability initialization and the Identity-specific initialization.
     * @param initialManagementKey The ethereum address to be set as the management key of the ONCHAINID.
     */
    function initialize(
        address initialManagementKey
    ) external virtual initializer {
        require(initialManagementKey != address(0), Errors.ZeroAddress());
        __UUPSUpgradeable_init();
        __IdentitySmartAccount_init();
        __Identity_init(initialManagementKey);
        __Version_init("2.2.2");
    }

    /**
     * @dev See {IERC735-getClaimIdsByTopic}.
     *   * @notice Implementation of the getClaimIdsByTopic function from the ERC-735 standard.
     * used to get all the claims from the specified topic
     * @param _topic The identity of the claim i.e. keccak256(abi.encode(_issuer, _topic))
     * @return claimIds Returns an array of claim IDs by topic.
     */
    function getClaimIdsByTopic(
        uint256 _topic
    ) external view override(IERC735) returns (bytes32[] memory claimIds) {
        return _getClaimStorage().claimsByTopic[_topic];
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     *  * @notice Returns true if this contract implements the interface defined by interfaceId
     * @param interfaceId The interface identifier, as specified in ERC-165
     * @return true if the interface is supported, false otherwise
     */
    function supportsInterface(
        bytes4 interfaceId
    ) external pure returns (bool) {
        return (interfaceId == type(IERC165).interfaceId ||
            interfaceId == type(IERC734).interfaceId ||
            interfaceId == type(IERC735).interfaceId ||
            interfaceId == type(IIdentity).interfaceId);
    }

    /**
     * @notice Reinitializes the contract for version upgrades
     * @dev This function should be called during contract upgrades to set up new features.
     * It uses the reinitializer modifier to ensure it can only be called once per version number.
     * Only management keys can call this function to prevent unauthorized version changes.
     *
     * @param newVersion The new version string to set
     * @param versionNumber The version number for the reinitializer modifier (must be unique per upgrade)
     */
    function reinitialize(
        string memory newVersion,
        uint8 versionNumber
    ) public reinitializer(versionNumber) onlyManager {
        super._setVersion(newVersion);
    }

    /**
     * @dev See {IERC735-addClaim}.
     * @notice Adds or updates a claim for this identity.
     *
     * This function uses O(1) index mappings for efficient claim management, eliminating
     * the need for linear searches through claim arrays.
     *
     * Claim validation:
     * - If the issuer is not the identity itself, the claim must be validated by the issuer
     * - Self-issued claims are automatically valid
     * - The signature must follow the structure: keccak256(abi.encode(identityHolder_address, topic, data))
     *
     * Access control: Only CLAIM_SIGNER keys can add claims.
     *
     * @param _topic The type/category of the claim
     * @param _scheme The verification scheme for the claim (ECDSA, RSA, etc.)
     * @param _issuer The address of the claim issuer (can be the identity itself)
     * @param _signature The cryptographic proof that the issuer authorized this claim
     * @param _data The claim data or hash of the claim data
     * @param _uri The location of additional claim data (HTTP, IPFS, etc.)
     * @return claimRequestId The unique identifier for this claim
     */
    function addClaim(
        uint256 _topic,
        uint256 _scheme,
        address _issuer,
        bytes memory _signature,
        bytes memory _data,
        string memory _uri
    ) public delegatedOnly onlyClaimKey returns (bytes32 claimRequestId) {
        // 1. Validate claim if issuer is not self
        if (_issuer != address(this)) {
            _validateExternalClaim(_issuer, _topic, _signature, _data);
        }

        ClaimStorage storage cs = _getClaimStorage();
        bytes32 claimId = keccak256(abi.encode(_issuer, _topic));
        Structs.Claim storage c = cs.claims[claimId];

        // 2. New claim or update existing
        bool isNew = !cs.claimExists[claimId];
        c.topic = _topic;
        c.scheme = _scheme;
        c.signature = _signature;
        c.data = _data;
        c.uri = _uri;

        if (isNew) {
            _setupNewClaim(claimId, _topic, _issuer);
        }

        _emitClaimEvent(
            claimId,
            _topic,
            _scheme,
            _issuer,
            _signature,
            _data,
            _uri,
            isNew
        );
        return claimId;
    }

    /**
     * @dev See {IERC735-removeClaim}.
     * @notice Removes a claim from this identity.
     *
     * This function uses O(1) index mappings and efficient swap-and-pop technique
     * to maintain array consistency without gaps, ensuring optimal gas usage.
     *
     * The swap-and-pop technique:
     * 1. Moves the last claim to the position of the claim being removed
     * 2. Updates the index mappings for the swapped claim
     * 3. Removes the last claim (which is now the target claim)
     *
     * Access control: Only CLAIM_SIGNER keys can remove claims.
     *
     * @param _claimId The unique identifier of the claim (keccak256(abi.encode(issuer, topic)))
     * @return success True if the claim was successfully removed
     *
     */
    function removeClaim(
        bytes32 _claimId
    )
        public
        override(IERC735)
        delegatedOnly
        onlyClaimKey
        returns (bool success)
    {
        ClaimStorage storage cs = _getClaimStorage();

        // 1. Validate claim exists and get topic
        Structs.Claim storage c = cs.claims[_claimId];
        uint256 topic = c.topic;
        require(topic != 0, Errors.ClaimNotRegistered(_claimId));

        // 2. Get claim index using O(1) lookup
        uint256 claimIdxPlusOne = cs.claimIndexInTopic[topic][_claimId];
        require(claimIdxPlusOne > 0, "Claim index missing");
        uint256 claimIdx = claimIdxPlusOne - 1; // Convert to 0-based index

        // 3. Remove claim from topic index using efficient swap-and-pop technique
        _removeClaimFromTopicIndex(_claimId, topic, claimIdx);

        // 4. Emit event with claim details before deletion
        emit ClaimRemoved(
            _claimId,
            topic,
            c.scheme,
            c.issuer,
            c.signature,
            c.data,
            c.uri
        );

        // 5. Clean up the claim data
        delete cs.claims[_claimId];

        return true;
    }

    /**
     * @dev See {IERC735-getClaim}.
     * @notice Implementation of the getClaim function from the ERC-735 standard.
     *
     * @param _claimId The identity of the claim i.e. keccak256(abi.encode(_issuer, _topic))
     *
     * @return topic Returns all the parameters of the claim for the
     * specified _claimId (topic, scheme, signature, issuer, data, uri) .
     * @return scheme Returns all the parameters of the claim for the
     * specified _claimId (topic, scheme, signature, issuer, data, uri) .
     * @return issuer Returns all the parameters of the claim for the
     * specified _claimId (topic, scheme, signature, issuer, data, uri) .
     * @return signature Returns all the parameters of the claim for the
     * specified _claimId (topic, scheme, signature, issuer, data, uri) .
     * @return data Returns all the parameters of the claim for the
     * specified _claimId (topic, scheme, signature, issuer, data, uri) .
     * @return uri Returns all the parameters of the claim for the
     * specified _claimId (topic, scheme, signature, issuer, data, uri) .
     */
    function getClaim(
        bytes32 _claimId
    )
        public
        view
        override(IERC735)
        returns (
            uint256 topic,
            uint256 scheme,
            address issuer,
            bytes memory signature,
            bytes memory data,
            string memory uri
        )
    {
        ClaimStorage storage cs = _getClaimStorage();
        return (
            cs.claims[_claimId].topic,
            cs.claims[_claimId].scheme,
            cs.claims[_claimId].issuer,
            cs.claims[_claimId].signature,
            cs.claims[_claimId].data,
            cs.claims[_claimId].uri
        );
    }

    /**
     * @dev Checks if a claim is valid. Claims issued by the identity are self-attested claims. They do not have a
     * built-in revocation mechanism and are considered valid as long as their signature is valid and they are still
     * stored by the identity contract.
     * @param _identity the identity contract related to the claim
     * @param claimTopic the claim topic of the claim
     * @param sig the signature of the claim
     * @param data the data field of the claim
     * @return claimValid true if the claim is valid, false otherwise
     */
    function isClaimValid(
        IIdentity _identity,
        uint256 claimTopic,
        bytes memory sig,
        bytes memory data
    ) public view virtual override returns (bool claimValid) {
        // Step 1: Create the data hash that was signed
        bytes32 dataHash = keccak256(abi.encode(_identity, claimTopic, data));

        // Step 2: Add Ethereum signature prefix for EIP-191 compliance
        bytes32 prefixedHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", dataHash)
        );

        // Step 3: Recover the signer's address from the signature
        address recovered = getRecoveredAddress(sig, prefixedHash);

        // Step 4: Hash the recovered address for key lookup
        bytes32 hashedAddr = keccak256(abi.encode(recovered));

        // Step 5: Check if the recovered address has CLAIM_SIGNER purpose
        return keyHasPurpose(hashedAddr, KeyPurposes.CLAIM_SIGNER);
    }

    /**
     * @dev returns the address that signed the given data
     * @param sig the signature of the data
     * @param dataHash the data that was signed
     * returns the address that signed dataHash and created the signature sig
     */
    function getRecoveredAddress(
        bytes memory sig,
        bytes32 dataHash
    ) public pure returns (address addr) {
        // Step 1: Declare variables for signature components
        bytes32 ra; // r component of the signature
        bytes32 sa; // s component of the signature
        uint8 va; // v component (recovery byte)

        // Step 2: Validate signature length (must be exactly 65 bytes)
        if (sig.length != 65) {
            return address(0); // Invalid signature length
        }

        // Step 3:  // Divide the signature in r, s and v variables
        // solhint-disable-next-line no-inline-assembly
        assembly {
            ra := mload(add(sig, 32)) // Load r (first 32 bytes)
            sa := mload(add(sig, 64)) // Load s (next 32 bytes)
            va := byte(0, mload(add(sig, 96))) // Load v (last byte)
        }

        // Step 4: Normalize recovery byte to Ethereum standard (27 or 28)
        if (va < 27) {
            va += 27; // Convert 0-25 to 27-52 for Ethereum compatibility
        }

        // Step 5: Recover the signer's address using ecrecover
        return ecrecover(dataHash, va, ra, sa);
    }

    /**
     * @notice Initializer internal function for the Identity contract.
     *
     * @dev This function sets up the initial management key and initializes all
     * storage mappings including the new index mappings for efficient key management.
     * @param initialManagementKey The ethereum address to be set as the management key of the ONCHAINID.
     */
    // solhint-disable-next-line func-name-mixedcase
    function __Identity_init(address initialManagementKey) internal {
        KeyStorage storage ks = _getKeyStorage();
        require(
            !ks.initialized || _isConstructor(),
            Errors.InitialKeyAlreadySetup()
        );
        ks.initialized = true;
        ks.canInteract = true;

        _setupInitialManagementKey(initialManagementKey);
    }

    /**
     * @dev Internal function to authorize the upgrade of the contract.
     * This function is required by UUPSUpgradeable.
     *
     * @param newImplementation The address of the new implementation.
     */
    function _authorizeUpgrade(
        address newImplementation
    )
        internal
        virtual
        override(IdentitySmartAccount, UUPSUpgradeable)
        onlyManager
    {
        // Only management keys can authorize upgrades
        // This prevents unauthorized upgrades and potential rug pulls
    }

    // ========= Internal (non-view/pure) =========

    /**
     * @dev Internal helper to remove claim from topic index using swap-and-pop technique.
     *
     * Maintains array consistency by swapping elements before removal and updates
     * all related index mappings.
     *
     * @param _claimId The claim ID to remove from the topic index
     * @param _topic The topic identifier for the claim
     * @param _claimIdx The 0-based index of the claim in the claimsByTopic array
     */
    function _removeClaimFromTopicIndex(
        bytes32 _claimId,
        uint256 _topic,
        uint256 _claimIdx
    ) internal {
        ClaimStorage storage cs = _getClaimStorage();
        uint256 lastClaimIdx = cs.claimsByTopic[_topic].length - 1;

        // Step 1: Implement swap-and-pop strategy if claim is not the last element
        if (_claimIdx != lastClaimIdx) {
            // Swap: Move the last element to the position being vacated
            bytes32 lastClaimId = cs.claimsByTopic[_topic][lastClaimIdx];
            cs.claimsByTopic[_topic][_claimIdx] = lastClaimId;

            // Update: Fix the index mapping for the swapped claim
            // Note: We add 1 because our index mapping uses 1-based indexing
            cs.claimIndexInTopic[_topic][lastClaimId] = _claimIdx + 1;
        }

        // Step 2: Remove the last element (either the target claim or the swapped element)
        cs.claimsByTopic[_topic].pop();

        // Step 3: Clean up all related storage mappings to prevent orphaned references
        delete cs.claimIndexInTopic[_topic][_claimId]; // Remove index mapping
        delete cs.claimExists[_claimId]; // Remove existence flag
    }

    /**
     * @dev Internal helper to setup new claim tracking with index mappings.
     *
     * This function initializes the index mappings for a new claim to enable
     * O(1) lookups and efficient claim management.
     *
     * @param _claimId The unique identifier of the claim
     * @param _topic The topic of the claim
     * @param _issuer The address of the claim issuer
     */
    function _setupNewClaim(
        bytes32 _claimId,
        uint256 _topic,
        address _issuer
    ) internal {
        ClaimStorage storage cs = _getClaimStorage();
        cs.claimsByTopic[_topic].push(_claimId);
        cs.claimIndexInTopic[_topic][_claimId] = cs
            .claimsByTopic[_topic]
            .length; // index+1
        cs.claimExists[_claimId] = true;
        cs.claims[_claimId].issuer = _issuer;
    }

    /**
     * @dev Internal helper to emit appropriate claim events based on whether the claim is new or updated.
     *
     * This function emits either ClaimAdded or ClaimChanged events depending on whether
     * the claim is being added for the first time or updated.
     *
     * @param _claimId The unique identifier of the claim
     * @param _topic The topic of the claim
     * @param _scheme The verification scheme for the claim
     * @param _issuer The address of the claim issuer
     * @param _signature The cryptographic proof of the claim
     * @param _data The claim data or hash
     * @param _uri The location of additional claim data
     * @param _isNew Whether this is a new claim (true) or an update (false)
     */
    function _emitClaimEvent(
        bytes32 _claimId,
        uint256 _topic,
        uint256 _scheme,
        address _issuer,
        bytes memory _signature,
        bytes memory _data,
        string memory _uri,
        bool _isNew
    ) internal {
        if (_isNew) {
            emit ClaimAdded(
                _claimId,
                _topic,
                _scheme,
                _issuer,
                _signature,
                _data,
                _uri
            );
        } else {
            emit ClaimChanged(
                _claimId,
                _topic,
                _scheme,
                _issuer,
                _signature,
                _data,
                _uri
            );
        }
    }

    /**
     * @dev Internal function for direct execution (used by entry point)
     * @param _to The target address
     * @param _value The value to send
     * @param _data The calldata
     *
     * @notice Uses the professional Exec library pattern from BaseAccount for consistent
     * and gas-optimized execution with proper error handling.
     */
    function _executeDirect(
        address _to,
        uint256 _value,
        bytes calldata _data
    ) internal {
        bool ok = Exec.call(_to, _value, _data, gasleft());
        if (!ok) {
            Exec.revertWithReturnData();
        }
    }

    /**
     * @dev See {IdentitySmartAccount-_requireManager}.
     * @notice Requires the caller to have management permissions
     */
    function _requireManager() internal view override onlyManager {
        // The onlyManager modifier handles the access control
    }

    /**
     * @dev See {IdentitySmartAccount-_validateSignature}.
     * @notice Validates the signature of a UserOperation and the signer's permissions
     * This function performs complete validation:
     * 1. Recovers the signer address from the signature
     * 2. Validates that the signature is valid (not address(0))
     * 3. Validates that the signer has required permissions (ERC4337_SIGNER or MANAGEMENT)
     * @param userOp The UserOperation to validate
     * @param userOpHash The hash of the UserOperation
     * @return validationData Packed validation data (0 for success, 1 for signature/permission failure)
     */
    function _validateSignature(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    ) internal view override returns (uint256 validationData) {
        // 1. Recover the signer address from the signature
        address signer = ECDSA.recover(userOpHash, userOp.signature);

        // 2. Validate that the signature is valid
        if (signer == address(0)) {
            return SIG_VALIDATION_FAILED;
        }

        // 3. Validate that the signer has required permissions
        if (
            !keyHasPurpose(
                keccak256(abi.encode(signer)),
                KeyPurposes.ERC4337_SIGNER
            ) &&
            !keyHasPurpose(
                keccak256(abi.encode(signer)),
                KeyPurposes.MANAGEMENT
            )
        ) {
            return SIG_VALIDATION_FAILED;
        }

        return SIG_VALIDATION_SUCCESS;
    }

    /**
     * @dev See {IdentitySmartAccount-_requireForExecute}.
     * @notice Requires the caller to be authorized for execution
     */
    function _requireForExecute() internal view override {
        // Allow entry point calls
        if (msg.sender == address(entryPoint())) {
            return;
        }

        // For all other calls, require management permissions
        _requireManager();
    }

    /**
     * @dev Internal helper to validate claim with external issuer.
     *
     * This function validates that a claim issued by an external issuer is valid
     * by calling the issuer's isClaimValid function.
     *
     * @param _issuer The address of the claim issuer
     * @param _topic The topic of the claim
     * @param _signature The cryptographic proof of the claim
     * @param _data The claim data or hash
     */
    function _validateExternalClaim(
        address _issuer,
        uint256 _topic,
        bytes memory _signature,
        bytes memory _data
    ) internal view {
        require(
            IClaimIssuer(_issuer).isClaimValid(
                IIdentity(address(this)),
                _topic,
                _signature,
                _data
            ),
            Errors.InvalidClaim()
        );
    }

    /**
     * @dev Returns the claim storage struct at the specified ERC-7201 slot
     * @return s The ClaimStorage struct pointer for the claim management slot
     */
    function _getClaimStorage() internal pure returns (ClaimStorage storage s) {
        bytes32 slot = _CLAIM_STORAGE_SLOT;
        assembly {
            s.slot := slot
        }
    }

    /**
     * @notice Computes if the context in which the function is called is a constructor or not.
     *
     * @return true if the context is a constructor.
     */
    function _isConstructor() private view returns (bool) {
        address self = address(this);
        uint256 cs;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            cs := extcodesize(self)
        }
        return cs == 0;
    }
}
