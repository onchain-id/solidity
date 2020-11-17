// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.6.9;
import "./Structs.sol";

contract Storage is Structs {
    string constant private IDENTITY_VERSION = "1.0.0";
    uint256 public constant MANAGEMENT_KEY = 1;
    uint256 public constant ACTION_KEY = 2;
    uint256 public constant CLAIM_SIGNER_KEY = 3;
    uint256 public constant ENCRYPTION_KEY = 4;
    uint256 internal executionNonce;
    mapping(bytes32 => Key) internal keys;
    mapping(uint256 => bytes32[]) internal keysByPurpose;
    mapping(uint256 => Execution) internal executions;
    mapping(bytes32 => Claim) internal claims;
    mapping(uint256 => bytes32[]) internal claimsByTopic;
}
