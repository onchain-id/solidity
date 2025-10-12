// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

/// @title KeyPurposes
/// @notice Constants for Key Purposes
library KeyPurposes {
    /// @dev 1: MANAGEMENT keys, which can manage the identity
    uint256 internal constant MANAGEMENT = 1;

    /// @dev 2: ACTION keys, which perform actions in this identities name (signing, logins, transactions, etc.)
    uint256 internal constant ACTION = 2;

    /// @dev 3: CLAIM signer keys, used to sign claims on other identities which need to be revokable.
    uint256 internal constant CLAIM_SIGNER = 3;

    /// @dev 4: ENCRYPTION keys, used to encrypt data e.g. hold in claims.
    uint256 internal constant ENCRYPTION = 4;

    /// @dev 5: ERC4337_SIGNER keys, used to sign UserOperations for ERC-4337 Account Abstraction
    uint256 internal constant ERC4337_SIGNER = 5;
}
