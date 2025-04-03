// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.27;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @notice This contract is used to map a claim topic id to its name
/** @dev this contract stores and returns the names for different topics
*/
contract TopicIdMapping is Ownable {
    mapping(uint256 => string) public topicToName;

    /// @notice Saves the name for a given topic
    function setTopicName(
        uint256 _topic,
        string memory _name
    ) external onlyOwner {
        topicToName[_topic] = _name;
    }

    /// @notice Returns the name for a given topic
    function getTopicName(
        uint256 _topic
    ) external view returns (string memory _name) {
        return topicToName[_topic];
    }
}
