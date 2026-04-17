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

    /// @dev 4: P256 (raw secp256r1 without WebAuthn ceremony, ERC-7913)
    uint256 internal constant P256 = 4;

    /// @dev 5: ERC1271 (smart contract wallet signature)
    uint256 internal constant ERC1271 = 5;

}
