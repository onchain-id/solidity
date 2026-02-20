// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

/// @title IdentityTypes
/// @notice Constants for Identity Types
library IdentityTypes {
    /// @dev 1: ASSET identity, used for token identities
    uint256 internal constant ASSET = 1;

    /// @dev 2: INDIVIDUAL identity
    uint256 internal constant INDIVIDUAL = 2;

    /// @dev 3: CORPORATE identity
    uint256 internal constant CORPORATE = 3;

    /// @dev 4: IOT identity
    uint256 internal constant IOT = 4;

    /// @dev 5: CLAIM_ISSUER identity
    uint256 internal constant CLAIM_ISSUER = 5;
}
