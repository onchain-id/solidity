// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import { IERC1271 } from "@openzeppelin/contracts/interfaces/IERC1271.sol";

/// @notice Mock ERC-1271 contract signer that always returns the magic value
contract MockERC1271Signer is IERC1271 {

    function isValidSignature(bytes32, bytes memory) external pure returns (bytes4) {
        return 0x1626ba7e;
    }

}
