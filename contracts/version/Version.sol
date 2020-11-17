// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.6.9;

/**
 * @dev Version contract gives the versioning information of the implementation contract
 */
contract Version {
    /**
     * @dev Returns the address of the current version.
     */
    function version() public pure returns (bytes3) {
        // version 1.0.0
        return "100";
    }
}
