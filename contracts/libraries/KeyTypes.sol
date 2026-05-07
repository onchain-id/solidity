// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

/// @title KeyTypes
/// @notice Constants for Key Types
library KeyTypes {

    /// @dev 1: ECDSA
    uint256 internal constant ECDSA = 1;

    /// @dev 2: RSA
    uint256 internal constant RSA = 2;

    /// @dev 3: WEBAUTHN (P-256 / secp256r1 via WebAuthn ceremony, ERC-7913)
    uint256 internal constant WEBAUTHN = 3;

}
