// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import { SmartAccount } from "./SmartAccount.sol";
import { IClaimIssuer } from "./interface/IClaimIssuer.sol";
import { IERC734 } from "./interface/IERC734.sol";
import { IERC735 } from "./interface/IERC735.sol";
import { IIdentity } from "./interface/IIdentity.sol";
import { Errors } from "./libraries/Errors.sol";
import { KeyPurposes } from "./libraries/KeyPurposes.sol";
import { Structs } from "./storage/Structs.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { MulticallUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/MulticallUpgradeable.sol";
import { EIP712 } from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import { SignatureChecker } from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title Identity
 * @dev Implementation of the `IERC734` "KeyHolder" and the `IERC735` "ClaimHolder" interfaces
 * into a common Identity Contract.
 *
 * This implementation uses ERC-7201 storage slots for upgradeability, providing:
 * - O(1) key and claim management operations via EnumerableSet
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
contract Identity is Initializable, IIdentity, SmartAccount, MulticallUpgradeable {

    using EnumerableSet for EnumerableSet.Bytes32Set;

    /**
     * @dev Storage struct for claim management data
     * @custom:storage-location erc7201:onchainid.identity.claim.storage
     */
    struct ClaimStorage {
        /// @dev Mapping of claim ID to Claim struct as defined by IERC735
        mapping(bytes32 => Structs.Claim) claims;
        /// @dev Identity type as defined in IdentityTypes library
        uint256 identityType;
        /// @dev Mapping of topic to set of claim IDs (EnumerableSet for O(1) add/remove/contains)
        mapping(uint256 => EnumerableSet.Bytes32Set) claimsByTopic;
    }

    /**
     * @dev ERC-7201 Storage Slot for claim management data
     * This slot ensures no storage collision between different versions of the contract
     *
     * Formula: keccak256(abi.encode(uint256(keccak256(bytes(id))) - 1)) & ~bytes32(uint256(0xff))
     * where id is the namespace identifier
     */
    bytes32 internal constant _CLAIM_STORAGE_SLOT = keccak256(
        abi.encode(uint256(keccak256(bytes("onchainid.identity.claim.storage"))) - 1)
    ) & ~bytes32(uint256(0xff));

    /// @dev EIP-712 typehash for claim signing: Claim(address identity,uint256 topic,bytes data)
    bytes32 internal constant _CLAIM_TYPEHASH = keccak256("Claim(address identity,uint256 topic,bytes data)");

    // Key management functionality is inherited from KeyManager contract

    // ========= Modifiers =========

    /// @notice requires claim key (CLAIM_SIGNER or CLAIM_ADDER) to call this function, or internal call
    modifier onlyClaimKey() {
        require(
            msg.sender == address(this)
                || keyHasPurpose(keccak256(abi.encodePacked(msg.sender)), KeyPurposes.CLAIM_SIGNER)
                || keyHasPurpose(keccak256(abi.encodePacked(msg.sender)), KeyPurposes.CLAIM_ADDER),
            Errors.SenderDoesNotHaveClaimSignerKey()
        );
        _;
    }

    /// @notice requires CLAIM_SIGNER key to call this function, or internal call
    /// @dev CLAIM_ADDER keys are excluded — they can add but not remove claims
    modifier onlyClaimSignerKey() {
        require(
            msg.sender == address(this)
                || keyHasPurpose(keccak256(abi.encodePacked(msg.sender)), KeyPurposes.CLAIM_SIGNER),
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
    constructor(address initialManagementKey, bool _isLibrary) EIP712("OnchainID", "1") {
        if (!_isLibrary) {
            __Identity_init(initialManagementKey);
        } else {
            _getKeyStorage().initialized = true;
        }
    }

    /**
     * @notice When using this contract as an implementation for a proxy, call this initializer with a delegatecall.
     * @dev This function initializes the contract and sets up the initial management key and identity type.
     * @param initialManagementKey The ethereum address to be set as the management key of the ONCHAINID.
     * @param _identityType The type of the identity.
     */
    function initialize(address initialManagementKey, uint256 _identityType) external virtual initializer {
        _getClaimStorage().identityType = _identityType;
        __AccountERC7579_init();
        __Identity_init(initialManagementKey);
    }

    /// @dev See {IERC7579AccountConfig-accountId}.
    function accountId() public view virtual override returns (string memory) {
        return "trex.onchainid.identity.v3.0.0";
    }

    /**
     * @dev See {IERC735-getClaimIdsByTopic}.
     *   * @notice Implementation of the getClaimIdsByTopic function from the ERC-735 standard.
     * used to get all the claims from the specified topic
     * @param _topic The identity of the claim i.e. keccak256(abi.encode(_issuer, _topic))
     * @return claimIds Returns an array of claim IDs by topic.
     */
    function getClaimIdsByTopic(uint256 _topic) external view override(IERC735) returns (bytes32[] memory claimIds) {
        return _getClaimStorage().claimsByTopic[_topic].values();
    }

    /**
     * @dev Returns the identity type set at initialization.
     * @return The identity type as defined in IdentityTypes library
     */
    function getIdentityType() external view returns (uint256) {
        return _getClaimStorage().identityType;
    }

    /**
     * @dev Returns the current version of the contract.
     * @return The version string
     */
    function version() external pure virtual returns (string memory) {
        return "3.0.0";
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     *  * @notice Returns true if this contract implements the interface defined by interfaceId
     * @param interfaceId The interface identifier, as specified in ERC-165
     * @return true if the interface is supported, false otherwise
     */
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return (interfaceId == type(IERC165).interfaceId || interfaceId == type(IERC734).interfaceId
                || interfaceId == type(IERC735).interfaceId || interfaceId == type(IIdentity).interfaceId);
    }

    /**
     * @dev See {IERC735-addClaim}.
     * @notice Adds or updates a claim for this identity.
     *
     * Uses EnumerableSet for O(1) claim existence checks and management.
     *
     * Claim validation:
     * - If the issuer is not the identity itself, the claim must be validated by the issuer
     * - Self-issued claims are automatically valid
     * - The signature must be over the EIP-712 typed data hash produced by `getClaimHash(identity, topic, data)`
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
        require(
            IClaimIssuer(_issuer).isClaimValid(IIdentity(address(this)), _topic, _signature, _data),
            Errors.InvalidClaim()
        );

        ClaimStorage storage cs = _getClaimStorage();
        bytes32 claimId = keccak256(abi.encode(_issuer, _topic));
        cs.claims[claimId] = Structs.Claim({
            topic: _topic, scheme: _scheme, issuer: _issuer, signature: _signature, data: _data, uri: _uri
        });

        // 2. New claim or update existing
        if (cs.claimsByTopic[_topic].add(claimId)) {
            emit ClaimAdded(claimId, _topic, _scheme, _issuer, _signature, _data, _uri);
        } else {
            emit ClaimChanged(claimId, _topic, _scheme, _issuer, _signature, _data, _uri);
        }

        return claimId;
    }

    /**
     * @dev See {IERC735-removeClaim}.
     * @notice Removes a claim from this identity.
     *
     * Uses EnumerableSet for O(1) add/remove/contains operations.
     *
     * Access control: Only CLAIM_SIGNER keys can remove claims.
     *
     * @param _claimId The unique identifier of the claim (keccak256(abi.encode(issuer, topic)))
     * @return success True if the claim was successfully removed
     *
     */
    function removeClaim(bytes32 _claimId)
        public
        override(IERC735)
        delegatedOnly
        onlyClaimSignerKey
        returns (bool success)
    {
        ClaimStorage storage cs = _getClaimStorage();

        // 1. Validate claim exists and get topic
        Structs.Claim storage c = cs.claims[_claimId];
        uint256 topic = c.topic;
        require(topic != 0, Errors.ClaimNotRegistered(_claimId));

        // 2. Remove claim from topic set
        cs.claimsByTopic[topic].remove(_claimId);

        // 3. Emit event with claim details before deletion
        emit ClaimRemoved(_claimId, topic, c.scheme, c.issuer, c.signature, c.data, c.uri);

        // 4. Clean up the claim data
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
    function getClaim(bytes32 _claimId)
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
        Structs.Claim storage claim = _getClaimStorage().claims[_claimId];
        return (claim.topic, claim.scheme, claim.issuer, claim.signature, claim.data, claim.uri);
    }

    /**
     * @dev Checks if a claim is valid via unified ERC-7913 signature verification.
     *
     * All signature schemes (ECDSA, WebAuthn, RSA, etc.) use the same format:
     * `sig = abi.encode(signer, actualSignature)`
     *
     * The claim digest is an EIP-712 typed data hash, allowing EOA wallets to use
     * `signTypedData` (readable prompts) and WebAuthn/passkey signers to use the
     * digest as an opaque challenge — both verify against the same hash.
     *
     * @param _identity the identity contract related to the claim
     * @param claimTopic the claim topic of the claim
     * @param sig the signature: abi.encode(signer, actualSignature)
     * @param data the data field of the claim
     * @return claimValid true if the claim is valid, false otherwise
     */
    function isClaimValid(IIdentity _identity, uint256 claimTopic, bytes memory sig, bytes memory data)
        public
        view
        virtual
        override
        returns (bool claimValid)
    {
        // 1. Build the EIP-712 struct hash. `data` is dynamic, so it must be hashed
        //    per EIP-712 encodeData rules.
        bytes32 structHash = keccak256(abi.encode(_CLAIM_TYPEHASH, address(_identity), claimTopic, keccak256(data)));

        // 2. Wrap with this contract's domain separator to produce the digest the
        //    issuer actually signed (matches eth_signTypedData_v4 output).
        bytes32 digest = _hashTypedDataV4(structHash);

        // 3. Decode the unified ERC-7913 signature format.
        (bytes memory signer, bytes memory actualSig) = abi.decode(sig, (bytes, bytes));

        // 4. Verify the signer is registered as a CLAIM_SIGNER on this identity.
        if (!keyHasPurpose(keccak256(signer), KeyPurposes.CLAIM_SIGNER)) {
            return false;
        }

        // 5. Dispatch through SignatureChecker:
        //    - 20-byte signer -> ECDSA recover (EIP-712 prompt in MetaMask) or ERC-1271
        //    - >20-byte signer -> ERC-7913 verifier (WebAuthn / RSA / etc.)
        return SignatureChecker.isValidSignatureNow(signer, digest, actualSig);
    }

    /**
     * @dev Computes the EIP-712 claim digest for off-chain signing.
     *
     * Frontend computes the same hash using `signTypedData` (EOA) or passes it as the
     * WebAuthn challenge (passkey). Mirrors the pattern of `getOperationHash` in SmartAccount.
     *
     * @param _identity The identity address the claim is for
     * @param _topic The claim topic
     * @param _data The claim data
     * @return The EIP-712 typed data hash
     */
    function getClaimHash(address _identity, uint256 _topic, bytes memory _data) public view returns (bytes32) {
        // EIP-712 struct hash: dynamic `_data` is hashed per encodeData rules.
        bytes32 structHash = keccak256(abi.encode(_CLAIM_TYPEHASH, _identity, _topic, keccak256(_data)));
        return _hashTypedDataV4(structHash);
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
        require(initialManagementKey != address(0), Errors.ZeroAddress());
        KeyStorage storage ks = _getKeyStorage();
        require(!ks.initialized, Errors.InitialKeyAlreadySetup());
        ks.initialized = true;
        ks.canInteract = true;

        _setupInitialManagementKey(initialManagementKey);
    }

    // ========= Internal (non-view/pure) =========

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

}
