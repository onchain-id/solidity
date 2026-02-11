// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.27;

/// @title IIdentityUtilities
/// @notice Interface for a schema registry that maps topic IDs to structured metadata schemas
/// @dev Each topic is uniquely identified and contains ABI-encoded arrays of field names and types
interface IIdentityUtilities {
    /**
     * @notice Struct that defines a registered topic schema
     * @param name Human-readable name of the topic
     * @param encodedFieldNames ABI-encoded string array representing field names
     * @param encodedFieldTypes ABI-encoded string array representing field types (e.g. "uint256", "string[]")
     */
    struct TopicInfo {
        string name;
        bytes encodedFieldNames;
        bytes encodedFieldTypes;
    }

    struct ClaimInfo {
        TopicInfo topic;
        bool isValid;
        bytes32 claimId;
        uint256 scheme;
        address issuer;
        bytes signature;
        bytes data;
        string uri;
    }
    /**
     * @notice Emitted when a new topic is added to the registry
     * @param topicId The unique identifier for the topic
     * @param name Human-readable name of the topic
     * @param encodedFieldNames ABI-encoded string[] representing the names of the fields
     * @param encodedFieldTypes ABI-encoded string[] representing the types of the fields
     */
    event TopicAdded(
        uint256 indexed topicId,
        string name,
        bytes encodedFieldNames,
        bytes encodedFieldTypes
    );

    /**
     * @notice Emitted when an existing topic is updated
     * @param topicId The ID of the topic that was updated
     * @param name New human-readable name of the topic
     * @param encodedFieldNames Updated ABI-encoded string[] of field names
     * @param encodedFieldTypes Updated ABI-encoded string[] of field types
     */
    event TopicUpdated(
        uint256 indexed topicId,
        string name,
        bytes encodedFieldNames,
        bytes encodedFieldTypes
    );

    /**
     * @notice Emitted when a topic is removed from the registry
     * @param topicId The ID of the removed topic
     */
    event TopicRemoved(uint256 indexed topicId);

    /**
     * @notice Registers a new topic with its name and schema definition
     * @param topicId The unique identifier of the topic to add
     * @param name Human-readable name of the topic
     * @param encodedFieldNames ABI-encoded string[] of field names
     * @param encodedFieldTypes ABI-encoded string[] of field types
     */
    function addTopic(
        uint256 topicId,
        string calldata name,
        bytes calldata encodedFieldNames,
        bytes calldata encodedFieldTypes
    ) external;

    /**
     * @notice Updates an existing topic's name and schema
     * @param topicId The ID of the topic to update
     * @param name New name of the topic
     * @param encodedFieldNames New ABI-encoded string[] of field names
     * @param encodedFieldTypes New ABI-encoded string[] of field types
     */
    function updateTopic(
        uint256 topicId,
        string calldata name,
        bytes calldata encodedFieldNames,
        bytes calldata encodedFieldTypes
    ) external;

    /**
     * @notice Removes a topic from the registry
     * @param topicId The ID of the topic to remove
     */
    function removeTopic(uint256 topicId) external;

    /**
     * @notice Retrieves the raw TopicInfo struct associated with a given topic ID
     * @param topicId The ID of the topic to retrieve
     * @return topic The full TopicInfo struct containing the name, encoded field names, and types
     */
    function getTopic(
        uint256 topicId
    ) external view returns (TopicInfo memory topic);

    /**
     * @notice Returns the decoded schema of a topic
     * @param topicId The ID of the topic
     * @return fieldNames Decoded string array of field names
     * @return fieldTypes Decoded string array of field types
     */
    function getSchema(
        uint256 topicId
    )
        external
        view
        returns (string[] memory fieldNames, string[] memory fieldTypes);

    /**
     * @notice Returns an array of TopicInfo structs for the given topic IDs
     * @param topicIds Array of topic IDs to get TopicInfo structs for
     * @return TopicInfo[] Array of TopicInfo structs corresponding to the input topic IDs
     */
    function getTopicInfos(
        uint256[] calldata topicIds
    ) external view returns (TopicInfo[] memory);
}
