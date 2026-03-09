// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.30;

/// @notice Mock identity whose initialize always reverts, causing IdentityProxy CREATE2 to fail
contract RevertingIdentity {

    function initialize(address) external pure {
        revert("forced revert");
    }

}
