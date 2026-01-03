// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import "./IIdentity.sol";

interface IClaimIssuer is IIdentity {
    /**
     * @dev Emitted when a claim is revoked.
     *
     * Specification: MUST be triggered when revoking a claim.
     */
    event ClaimRevoked(bytes indexed signature);

    /**
     * @dev Emitted when a claim is successfully added to an identity contract by this claim issuer.
     *
     * This event is triggered after the claim has been validated and successfully added to the target
     * identity contract through the execute mechanism. It provides a record of the claim issuance
     * from the issuer's perspective.
     *
     * @param identity The address of the identity contract that received the claim
     * @param topic The topic/type of the claim that was added
     * @param signature The cryptographic signature of the claim data
     * @param data The claim data that was signed and added
     */
    event ClaimAddedTo(
        address indexed identity,
        uint256 topic,
        bytes signature,
        bytes data
    );

    /**
     * @dev Revoke a claim previously issued, the claim is no longer considered as valid after revocation.
     * @notice will fetch the claim from the identity contract (unsafe).
     * @param _claimId the id of the claim
     * @param _identity the address of the identity contract
     * @return isRevoked true when the claim is revoked
     */
    function revokeClaim(
        bytes32 _claimId,
        address _identity
    ) external returns (bool);

    /**
     * @dev Revoke a claim previously issued, the claim is no longer considered as valid after revocation.
     * @param signature the signature of the claim
     */
    function revokeClaimBySignature(bytes calldata signature) external;

    /**
     * @dev Adds a claim to a specified identity contract.
     *
     * This function validates the provided claim data against this issuer's signing keys and
     * revocation status, then adds the claim to the target identity contract. The issuer is
     * automatically set to this contract's address.
     *
     * The claim is added to the identity contract through the execute mechanism, which may
     * require approval depending on the identity's key management configuration.
     *
     * Requirements:
     * - Caller must have management key permissions
     * - Contract must not be in library mode (delegatedOnly)
     * - Claim signature must be valid and not revoked
     * - Target identity contract must accept the claim addition
     *
     * @param _topic The topic/type of the claim
     * @param _scheme The signature scheme used (typically KeyTypes.ECDSA for ECDSA)
     * @param _signature The cryptographic signature of the claim data
     * @param _data The actual claim data being attested
     * @param _uri Optional URI pointing to additional claim information
     * @param _identity The identity contract to receive the claim
     *
     * Emits a {ClaimAddedTo} event upon successful claim addition.
     *
     * @notice This function will revert if the claim is invalid or if the identity
     * contract rejects the `execute()` call.
     */
    function addClaimTo(
        uint256 _topic,
        uint256 _scheme,
        bytes calldata _signature,
        bytes calldata _data,
        string calldata _uri,
        IIdentity _identity
    ) external;

    /**
     * @dev Returns revocation status of a claim.
     * @param _sig the signature of the claim
     * @return isRevoked true if the claim is revoked and false otherwise
     */
    function isClaimRevoked(bytes calldata _sig) external view returns (bool);

    /**
     * @dev Checks if a claim is valid.
     * @param _identity the identity contract related to the claim
     * @param claimTopic the claim topic of the claim
     * @param sig the signature of the claim
     * @param data the data field of the claim
     * @return claimValid true if the claim is valid, false otherwise
     */
    function isClaimValid(
        IIdentity _identity,
        uint256 claimTopic,
        bytes calldata sig,
        bytes calldata data
    ) external view returns (bool);
}
