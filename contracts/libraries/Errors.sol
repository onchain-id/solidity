// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.27;

/// @title Errors
/// @notice Library containing all custom errors the protocol may revert with
library Errors {

    /* ----- Generic ----- */

    /// @notice Reverts if the address is zero
    error ZeroAddress();

    /* ----- IdFactory ----- */

    /// @notice Reverts if the factory is already registered
    error AlreadyAFactory(address factory);
    
    /// @notice Reverts if the function is called on the sender address
    error CannotBeCalledOnSenderAddress();
    
    /// @notice Reverts if the list of keys is empty
    error EmptyListOfKeys();
    
    /// @notice Reverts if the string is empty
    error EmptyString();
    
    /// @notice Reverts if the address is not a factory
    error NotAFactory(address factory);
    
    /// @notice Reverts if the maximum number of wallets per identity is exceeded
    error MaxWalletsPerIdentityExceeded();
    
    /// @notice Reverts if the only linked wallet tries to unlink
    error OnlyLinkedWalletCanUnlink();
    
    /// @notice Reverts if the account is not authorized to call the function
    error OwnableUnauthorizedAccount(address account); // TODO: OZ
    
    /// @notice Reverts if the salt is taken
    error SaltTaken(string salt);
    
    /// @notice Reverts if the token is already linked
    error TokenAlreadyLinked(address token);
    
    /// @notice Reverts if the wallet is already linked to an identity
    error WalletAlreadyLinkedToIdentity(address wallet);
    
    /// @notice Reverts if the wallet is also listed in management keys
    error WalletAlsoListedInManagementKeys(address wallet);
    
    /// @notice Reverts if the wallet is not linked to an identity
    error WalletNotLinkedToIdentity(address wallet);

    /* ----- Gateway ----- */

    /// @notice The maximum number of signers was reached at deployment.
    error TooManySigners();
    
    /// @notice The signed attempted to add was already approved.
    error SignerAlreadyApproved(address signer);
    
    /// @notice The signed attempted to remove was not approved.
    error SignerAlreadyNotApproved(address signer);
    
    /// @notice A requested ONCHAINID deployment was requested and signer by a non approved signer.
    error UnapprovedSigner(address signer);
    
    /// @notice A requested ONCHAINID deployment was requested with a signature revoked.
    error RevokedSignature(bytes signature);
    
    /// @notice A requested ONCHAINID deployment was requested with a signature that expired.
    error ExpiredSignature(bytes signature);
    
    /// @notice Attempted to revoke a signature that was already revoked.
    error SignatureAlreadyRevoked(bytes signature);
    
    /// @notice Attempted to approve a signature that was not revoked.
    error SignatureNotRevoked(bytes signature);

    /// @notice A call to the factory failed.
    error CallToFactoryFailed();


    /* ----- IdentityProxy ----- */

    /// @notice The initialization failed.
    error InitializationFailed();

    /* ----- Verifier ----- */

    /// @notice The claim topic already exists.
    error ClaimTopicAlreadyExists(uint256 claimTopic);

    /// @notice The maximum number of claim topics is exceeded.
    error MaxClaimTopicsExceeded();

    /// @notice The maximum number of trusted issuers is exceeded.
    error MaxTrustedIssuersExceeded();

    /// @notice The trusted issuer already exists.
    error TrustedIssuerAlreadyExists(address trustedIssuer);

    /// @notice The trusted claim topics cannot be empty.
    error TrustedClaimTopicsCannotBeEmpty();

    /// @notice The trusted issuer does not exist.
    error NotATrustedIssuer(address trustedIssuer);

    /* ----- ClaimIssuer ----- */

    /// @notice The claim already exists.
    error ClaimAlreadyRevoked();

    /* ----- Identity ----- */

    /// @notice Interacting with the library contract is forbidden.
    error InteractingWithLibraryContractForbidden();

    /// @notice The sender does not have the management key.
    error SenderDoesNotHaveManagementKey(); 

    /// @notice The sender does not have the claim signer key.
    error SenderDoesNotHaveClaimSignerKey();

    /// @notice The sender does not have the action key.
    error SenderDoesNotHaveActionKey();

    /// @notice The initial key was already setup.
    error InitialKeyAlreadySetup();

    /// @notice The key is not registered.
    error KeyNotRegistered(bytes32 key);

    /// @notice The key already has the purpose.
    error KeyAlreadyHasPurpose(bytes32 key, uint256 purpose);

    /// @notice The key does not have the purpose.
    error KeyDoesNotHavePurpose(bytes32 key, uint256 purpose);

    /// @notice The claim is not registered.
    error ClaimNotRegistered(bytes32 claimId);

    /// @notice The request is not valid.
    error InvalidRequestId();

    /// @notice The request is already executed.
    error RequestAlreadyExecuted();

    /// @notice The claim is invalid.
    error InvalidClaim();

}
