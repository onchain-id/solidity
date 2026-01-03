// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.27;

import { IIdentityUtilities } from "./interface/IIdentityUtilities.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import { IIdentity } from "./interface/IIdentity.sol";
import { IClaimIssuer } from "./interface/IClaimIssuer.sol";

/**
 * @title IdentityUtilities
 * @notice Contract for registering and retrieving structured topic schemas using encoded string arrays.
 * @dev Inherits from AccessControl and supports UUPS upgrades. Topics define field names and types
 * using ABI-encoded `string[]` arrays.
 */
contract IdentityUtilities is
    IIdentityUtilities,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    /// @notice Role identifier for accounts allowed to manage topics
    bytes32 public constant TOPIC_MANAGER_ROLE =
        keccak256("TOPIC_MANAGER_ROLE");

    /// @dev Mapping from topic ID to TopicInfo struct
    mapping(uint256 => TopicInfo) private _topics;

    /// @notice Disables initializers on the implementation contract
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the contract and sets the admin and topic manager roles.
     * @param admin Address to receive DEFAULT_ADMIN_ROLE and TOPIC_MANAGER_ROLE
     */
    function initialize(address admin) external initializer {
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(TOPIC_MANAGER_ROLE, admin);
    }

    /**
     * @inheritdoc IIdentityUtilities
     */
    function addTopic(
        uint256 topicId,
        string calldata name,
        bytes calldata encodedFieldNames,
        bytes calldata encodedFieldTypes
    ) external override onlyRole(TOPIC_MANAGER_ROLE) {
        require(bytes(name).length > 0, "Empty topic name");
        require(
            _topics[topicId].encodedFieldNames.length == 0,
            "Topic already exists"
        );
        _validateFieldArrays(encodedFieldNames, encodedFieldTypes);

        _topics[topicId] = TopicInfo({
            name: name,
            encodedFieldNames: encodedFieldNames,
            encodedFieldTypes: encodedFieldTypes
        });

        emit TopicAdded(topicId, name, encodedFieldNames, encodedFieldTypes);
    }

    /**
     * @inheritdoc IIdentityUtilities
     */
    function updateTopic(
        uint256 topicId,
        string calldata name,
        bytes calldata encodedFieldNames,
        bytes calldata encodedFieldTypes
    ) external override onlyRole(TOPIC_MANAGER_ROLE) {
        require(
            _topics[topicId].encodedFieldNames.length != 0,
            "Topic does not exist"
        );
        require(bytes(name).length > 0, "Empty topic name");
        _validateFieldArrays(encodedFieldNames, encodedFieldTypes);

        _topics[topicId] = TopicInfo({
            name: name,
            encodedFieldNames: encodedFieldNames,
            encodedFieldTypes: encodedFieldTypes
        });

        emit TopicUpdated(topicId, name, encodedFieldNames, encodedFieldTypes);
    }

    /**
     * @inheritdoc IIdentityUtilities
     */
    function removeTopic(
        uint256 topicId
    ) external override onlyRole(TOPIC_MANAGER_ROLE) {
        require(
            _topics[topicId].encodedFieldNames.length != 0,
            "Topic does not exist"
        );
        delete _topics[topicId];
        emit TopicRemoved(topicId);
    }

    /**
     * @inheritdoc IIdentityUtilities
     */
    function getTopic(
        uint256 topicId
    ) external view override returns (TopicInfo memory) {
        return _topics[topicId];
    }

    /**
     * @inheritdoc IIdentityUtilities
     */
    function getSchema(
        uint256 topicId
    )
        external
        view
        override
        returns (string[] memory fieldNames, string[] memory fieldTypes)
    {
        if (_topics[topicId].encodedFieldNames.length == 0) {
            return (new string[](0), new string[](0));
        }
        fieldNames = abi.decode(_topics[topicId].encodedFieldNames, (string[]));
        fieldTypes = abi.decode(_topics[topicId].encodedFieldTypes, (string[]));
    }

    /**
     * @notice Returns decoded field names for a given topic ID
     * @param topicId The ID of the topic
     * @return string[] Array of field names
     */
    function getFieldNames(
        uint256 topicId
    ) external view returns (string[] memory) {
        if (_topics[topicId].encodedFieldNames.length == 0) {
            return new string[](0);
        }
        return abi.decode(_topics[topicId].encodedFieldNames, (string[]));
    }

    /**
     * @notice Returns decoded field types for a given topic ID
     * @param topicId The ID of the topic
     * @return string[] Array of field types
     */
    function getFieldTypes(
        uint256 topicId
    ) external view returns (string[] memory) {
        if (_topics[topicId].encodedFieldTypes.length == 0) {
            return new string[](0);
        }
        return abi.decode(_topics[topicId].encodedFieldTypes, (string[]));
    }

    /**
     * @notice Returns an array of TopicInfo structs for the given topic IDs
     * @param topicIds Array of topic IDs to get TopicInfo structs for
     * @return TopicInfo[] Array of TopicInfo structs corresponding to the input topic IDs
     */
    function getTopicInfos(
        uint256[] calldata topicIds
    ) external view returns (TopicInfo[] memory) {
        TopicInfo[] memory topics = new TopicInfo[](topicIds.length);
        for (uint256 i = 0; i < topicIds.length; i++) {
            topics[i] = _topics[topicIds[i]];
        }
        return topics;
    }

    /**
     * @notice Gets comprehensive claim information for an identity across multiple topics
     * @param identity The identity contract address
     * @param topicIds Array of topic IDs to check
     * @return result Array of claim information structs
     */
    function getClaimsWithTopicInfo(
        address identity,
        uint256[] calldata topicIds
    ) external view returns (ClaimInfo[] memory result) {
        uint256 totalClaims = _countTotalClaims(identity, topicIds);
        result = new ClaimInfo[](totalClaims);
        uint256 resultIndex = 0;

        for (uint256 i = 0; i < topicIds.length; i++) {
            uint256 topicId = topicIds[i];
            TopicInfo memory topicInfo = _topics[topicId];
            bytes32[] memory claimIds = IIdentity(identity).getClaimIdsByTopic(
                topicId
            );
            for (uint256 j = 0; j < claimIds.length; j++) {
                result[resultIndex] = _buildClaimInfo(
                    identity,
                    topicId,
                    topicInfo,
                    claimIds[j]
                );
                resultIndex++;
            }
        }
    }

    /**
     * @dev Required override for UUPS upgradability authorization
     * @param newImplementation Address of the new implementation
     */
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    function _countTotalClaims(
        address identity,
        uint256[] calldata topicIds
    ) internal view returns (uint256 total) {
        for (uint256 i = 0; i < topicIds.length; i++) {
            bytes32[] memory claimIds = IIdentity(identity).getClaimIdsByTopic(
                topicIds[i]
            );
            total += claimIds.length;
        }
    }

    function _isClaimValid(
        address identity,
        uint256 topicId,
        address issuer,
        bytes memory signature,
        bytes memory data
    ) internal view returns (bool) {
        if (issuer == address(0)) return false;
        try
            IClaimIssuer(issuer).isClaimValid(
                IIdentity(identity),
                topicId,
                signature,
                data
            )
        returns (bool valid) {
            return valid;
        } catch {
            return false;
        }
    }

    function _buildClaimInfo(
        address identity,
        uint256 topicId,
        TopicInfo memory topicInfo,
        bytes32 claimId
    ) internal view returns (ClaimInfo memory info) {
        (
            ,
            // topic - not used
            uint256 scheme,
            address issuer,
            bytes memory signature,
            bytes memory data,
            string memory uri
        ) = IIdentity(identity).getClaim(claimId);

        bool isValid = _isClaimValid(
            identity,
            topicId,
            issuer,
            signature,
            data
        );

        info = ClaimInfo({
            topic: topicInfo,
            isValid: isValid,
            claimId: claimId,
            scheme: scheme,
            issuer: issuer,
            signature: signature,
            data: data,
            uri: uri
        });
    }

    /**
     * @dev Validates that encoded field names/types match in length and content.
     * @param encodedNames ABI-encoded string[] of field names
     * @param encodedTypes ABI-encoded string[] of field types
     */
    function _validateFieldArrays(
        bytes memory encodedNames,
        bytes memory encodedTypes
    ) internal pure {
        string[] memory names = abi.decode(encodedNames, (string[]));
        string[] memory types_ = abi.decode(encodedTypes, (string[]));
        require(
            names.length == types_.length,
            "Field name/type count mismatch"
        );

        for (uint256 i = 0; i < names.length; i++) {
            require(bytes(names[i]).length > 0, "Empty field name");
            require(bytes(types_[i]).length > 0, "Empty field type");
        }
    }

    /// @dev Reserved storage space to allow future layout changes
    uint256[50] private __gap; // solhint-disable-line ordering
}
