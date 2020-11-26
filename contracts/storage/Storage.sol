// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.6.9;
import "./Structs.sol";

contract Storage is Structs {
    uint256 internal executionNonce;
    mapping(bytes32 => Key) internal keys;
    mapping(uint256 => bytes32[]) internal keysByPurpose;
    mapping(uint256 => Execution) internal executions;
    mapping(bytes32 => Claim) internal claims;
    mapping(uint256 => bytes32[]) internal claimsByTopic;
}
