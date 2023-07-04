// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../factory/IdFactory.sol";

using ECDSA for bytes32;

/// A required parameter was set to the Zero address.
error ZeroAddress();
/// The maximum number of signers was reached at deployment.
error TooManySigners();
/// The signed attempted to add was already approved.
error SignerAlreadyApproved();
/// The signed attempted to remove was not approved.
error SignerAlreadyNotApproved();
/// A requested ONCHAINID deployment was requested without a valid signature while the Gateway requires one.
error UnsignedDeployment();
/// A requested ONCHAINID deployment was requested and signer by a non approved signer.
error UnapprovedSigner();
/// A requested ONCHAINID deployment was requested with a signature revoked.
error RevokedSignature();
/// A requested ONCHAINID deployment was requested with a signature that expired.
error ExpiredSignature();
/// Attempted to revoke a signature that was already revoked.
error SignatureAlreadyRevoked();
/// Attempted to approve a signature that was not revoked.
error SignatureNotRevoked();

contract Gateway is Ownable {
    IdFactory public idFactory;
    mapping(address => bool) public approvedSigners;
    mapping(bytes => bool) public revokedSignatures;

    event SignerApproved(address signer);
    event SignerRevoked(address signer);
    event SignatureRevoked(bytes signature);
    event SignatureApproved(bytes signature);

    /**
     *  @dev Constructor for the ONCHAINID Factory Gateway.
     *  @param idFactoryAddress the address of the factory to operate (the Gateway must be owner of the Factory).
     */
    constructor(address idFactoryAddress, address[] memory signersToApprove) Ownable() {
        if (idFactoryAddress == address(0)) {
            revert ZeroAddress();
        }
        if (signersToApprove.length > 10) {
            revert TooManySigners();
        }

        for (uint i = 0; i < signersToApprove.length; i++) {
            approvedSigners[signersToApprove[i]] = true;
        }

        idFactory = IdFactory(idFactoryAddress);
    }

    /**
     *  @dev Approve a signer to sign ONCHAINID deployments. If the Gateway is setup to require signature, only
     *  deployments requested with a valid signature from an approved signer will be accepted.
     *  If the gateway does not require a signature,
     *  @param signer the signer address to approve.
     */
    function approveSigner(address signer) external onlyOwner {
        if (signer == address(0)) {
            revert ZeroAddress();
        }

        if (approvedSigners[signer]) {
            revert SignerAlreadyApproved();
        }

        approvedSigners[signer] = true;

        emit SignerApproved(signer);
    }

    /**
     *  @dev Revoke a signer to sign ONCHAINID deployments.
     *  @param signer the signer address to revoke.
     */
    function revokeSigner(address signer) external onlyOwner {
        if (signer == address(0)) {
            revert ZeroAddress();
        }

        if (!approvedSigners[signer]) {
            revert SignerAlreadyNotApproved();
        }

        delete approvedSigners[signer];

        emit SignerRevoked(signer);
    }

    /**
     *  @dev Deploy an ONCHAINID using a factory. The operation must be signed by
     *  an approved public key. This method allow to deploy an ONCHAINID using a custom salt.
     *  @param identityOwner the address to set as a management key.
     *  @param salt to use for the deployment.
     *  @param signatureExpiry the block timestamp where the signature will expire.
     *  @param signature the approval containing the salt and the identityOwner address.
     */
    function deployIdentityWithSalt(
        address identityOwner,
        string memory salt,
        uint256 signatureExpiry,
        bytes calldata signature
    ) external returns (address) {
        if (identityOwner == address(0)) {
            revert ZeroAddress();
        }

        if (signatureExpiry != 0 && signatureExpiry < block.timestamp) {
            revert ExpiredSignature();
        }

        address signer = ECDSA.recover(
            keccak256(
                abi.encode(
                    "Authorize ONCHAINID deployment",
                    identityOwner,
                    salt,
                    signatureExpiry
                )
            ).toEthSignedMessageHash(),
            signature
        );

        if (!approvedSigners[signer]) {
            revert UnapprovedSigner();
        }

        if (revokedSignatures[signature]) {
            revert RevokedSignature();
        }

        return idFactory.createIdentity(identityOwner, salt);
    }

    /**
     *  @dev Deploy an ONCHAINID using a factory using the identityOwner address as salt.
     *  @param identityOwner the address to set as a management key.
     */
    function deployIdentityForWallet(address identityOwner) external returns (address) {
        if (identityOwner == address(0)) {
            revert ZeroAddress();
        }
        if (identityOwner != msg.sender) {
            revert UnapprovedSigner();
        }

        return idFactory.createIdentity(identityOwner, Strings.toHexString(identityOwner));
    }

    /**
     *  @dev Revoke a signature, if the signature is used to deploy an ONCHAINID, the deployment would be rejected.
     *  @param signature the signature to revoke.
     */
    function revokeSignature(bytes calldata signature) external onlyOwner {
        if (revokedSignatures[signature]) {
            revert SignatureAlreadyRevoked();
        }

        revokedSignatures[signature] = true;

        emit SignatureRevoked(signature);
    }

    /**
     *  @dev Remove a signature from the revoke list.
     *  @param signature the signature to approve.
     */
    function approveSignature(bytes calldata signature) external onlyOwner {
        if (!revokedSignatures[signature]) {
            revert SignatureNotRevoked();
        }

        delete revokedSignatures[signature];

        emit SignatureApproved(signature);
    }

    /**
     *  @dev Transfer the ownership of the factory to a new owner.
     *  @param newOwner the new owner of the factory.
     */
    function transferFactoryOwnership(address newOwner) external onlyOwner {
        idFactory.transferOwnership(newOwner);
    }

    /**
     *  @dev Call a function on the factory. Only the owner of the Gateway can call this method.
     *  @param data the data to call on the factory.
     */
    function callFactory(bytes memory data) external onlyOwner {
        (bool success,) = address(idFactory).call(data);
        require(success, "Gateway: call to factory failed");
    }
}
