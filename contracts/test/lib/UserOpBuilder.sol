// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { PackedUserOperation } from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";

/**
 * @title UserOpBuilder
 * @notice Helper library for building and packing UserOperation parameters
 * @dev Provides utility functions for ERC-4337 UserOperation construction
 */
library UserOpBuilder {
    /**
     * @notice Packs verification and call gas limits into a single bytes32
     * @dev Used for the accountGasLimits field in PackedUserOperation
     * @param verificationGas Gas limit for verification (validateUserOp)
     * @param callGas Gas limit for execution (execute/executeBatch)
     * @return packed The packed gas limits as bytes32
     */
    function packAccountGasLimits(
        uint128 verificationGas,
        uint128 callGas
    ) internal pure returns (bytes32 packed) {
        return bytes32((uint256(verificationGas) << 128) | uint256(callGas));
    }

    /**
     * @notice Packs priority fee and max fee per gas into a single bytes32
     * @dev Used for the gasFees field in PackedUserOperation
     * @param maxPriorityFee Maximum priority fee per gas (tip to miner)
     * @param maxFeePerGas Maximum total fee per gas
     * @return packed The packed gas fees as bytes32
     */
    function packGasFees(
        uint128 maxPriorityFee,
        uint128 maxFeePerGas
    ) internal pure returns (bytes32 packed) {
        return
            bytes32((uint256(maxPriorityFee) << 128) | uint256(maxFeePerGas));
    }
}
