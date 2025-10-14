// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title Target
 * @notice Mock contract for testing execute() and executeBatch() calls
 * @dev Simple contract that tracks call data and emits events
 */
contract Target {
    uint256 public x;
    uint256 public callCount;

    event Ping(address caller, uint256 value, bytes data);

    /**
     * @notice Test function that can be called via execute()
     * @dev Increments internal state and emits event
     * @param data Arbitrary data to log in event
     */
    function ping(bytes calldata data) external payable {
        x += msg.value;
        callCount++;
        emit Ping(msg.sender, msg.value, data);
    }

    /**
     * @notice Function that returns data for testing return values
     */
    function getData() external view returns (uint256, uint256) {
        return (x, callCount);
    }

    /**
     * @notice Function that reverts for testing error handling
     */
    function revertingFunction() external pure {
        revert("Target: intentional revert");
    }
}
