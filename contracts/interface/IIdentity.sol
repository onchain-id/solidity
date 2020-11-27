// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.6.9;

import "./IERC734.sol";
import "./IERC735.sol";

interface IIdentity is IERC734, IERC735 {
    event ExecutionFailed(uint256 indexed executionId, address indexed to, uint256 indexed value, bytes data);
    event UpdatedCode(address newContractAddress);
}
