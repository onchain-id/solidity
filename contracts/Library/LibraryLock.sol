// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.6.9;

import "./LibraryLockDataLayout.sol";

contract LibraryLock is LibraryLockDataLayout {
    // Ensures no one can manipulate the Logic Contract once it is deployed.
    // PARITY WALLET HACK PREVENTION

    modifier delegatedOnly() {
        require(initialized == true, "The library is locked. No direct call is allowed");
        _;
    }
    function initialize() internal {
        initialized = true;
    }
}
