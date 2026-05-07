// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import { IdFactory } from "../factory/IdFactory.sol";
import { Errors } from "../libraries/Errors.sol";
import { Structs } from "../storage/Structs.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * @title Gateway
 * @notice Signature-gated entry point for the OnchainID Factory.
 * @dev Validates signed deployment requests from approved signers with optional expiry.
 * The frontend builds the full key list (any purposes, any key types, including WebAuthn)
 * and ERC-7579 modules, then submits them through the Gateway.
 */
contract Gateway is Ownable {

    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    /// @notice The IdFactory contract this Gateway operates.
    IdFactory public immutable idFactory;

    /// @notice Mapping of approved signer addresses that can authorize ONCHAINID deployments.
    mapping(address => bool) public approvedSigners;

    /// @notice Mapping of revoked signatures to prevent replay.
    mapping(bytes => bool) public revokedSignatures;

    /// @dev Emitted when a signer is approved to authorize deployments.
    event SignerApproved(address indexed signer);

    /// @dev Emitted when a signer's approval is revoked.
    event SignerRevoked(address indexed signer);

    /// @dev Emitted when a deployment signature is revoked.
    event SignatureRevoked(bytes indexed signature);

    /// @dev Emitted when a previously revoked signature is re-approved.
    event SignatureApproved(bytes indexed signature);

    /**
     * @notice Constructor for the ONCHAINID Factory Gateway.
     * @param idFactoryAddress the address of the factory to operate (the Gateway must be owner of the Factory).
     * @param signersToApprove initial list of approved signers (max 10).
     */
    constructor(address idFactoryAddress, address[] memory signersToApprove) Ownable(msg.sender) {
        require(idFactoryAddress != address(0), Errors.ZeroAddress());
        require(signersToApprove.length <= 10, Errors.TooManySigners());

        for (uint256 i = 0; i < signersToApprove.length; i++) {
            approvedSigners[signersToApprove[i]] = true;
        }

        idFactory = IdFactory(idFactoryAddress);
    }

    /**
     * @notice Approve a signer to authorize ONCHAINID deployments.
     * @param signer the signer address to approve.
     */
    function approveSigner(address signer) external onlyOwner {
        require(signer != address(0), Errors.ZeroAddress());
        require(!approvedSigners[signer], Errors.SignerAlreadyApproved(signer));
        approvedSigners[signer] = true;
        emit SignerApproved(signer);
    }

    /**
     * @notice Revoke a signer's authorization for ONCHAINID deployments.
     * @param signer the signer address to revoke.
     */
    function revokeSigner(address signer) external onlyOwner {
        require(signer != address(0), Errors.ZeroAddress());
        require(approvedSigners[signer], Errors.SignerAlreadyNotApproved(signer));
        delete approvedSigners[signer];
        emit SignerRevoked(signer);
    }

    /**
     * @notice Deploy an ONCHAINID via the factory with a signed authorization.
     * @dev The operation must be signed by an approved signer. The frontend builds
     *      the full key list (any purposes, any key types) and ERC-7579 modules.
     *      The signed message includes all parameters to prevent tampering.
     * @param identityOwner the wallet address to link to the identity.
     * @param identityType the identity type (see IdentityTypes library).
     * @param salt the salt for CREATE2 deployment.
     * @param keys the full list of keys with purposes, types, and signer data — built by the frontend.
     * @param modules the ERC-7579 modules to install during creation — built by the frontend.
     * @param signatureExpiry block timestamp when the signature expires (0 = no expiry).
     * @param signature the signed authorization from an approved signer.
     * @return the address of the deployed identity.
     */
    function deployIdentityWithSalt(
        address identityOwner,
        uint256 identityType,
        string memory salt,
        Structs.KeyParam[] calldata keys,
        Structs.ModuleInstall[] calldata modules,
        uint256 signatureExpiry,
        bytes calldata signature
    ) external returns (address) {
        require(identityOwner != address(0), Errors.ZeroAddress());
        require(signatureExpiry == 0 || block.timestamp <= signatureExpiry, Errors.ExpiredSignature(signature));

        {
            address signer = keccak256(
                    abi.encode(
                        "Authorize ONCHAINID deployment",
                        identityOwner,
                        identityType,
                        salt,
                        keys,
                        modules,
                        signatureExpiry
                    )
                ).toEthSignedMessageHash().recover(signature);

            require(approvedSigners[signer], Errors.UnapprovedSigner(signer));
            require(!revokedSignatures[signature], Errors.RevokedSignature(signature));
        }

        return idFactory.createIdentity(identityOwner, identityType, salt, keys, modules);
    }

    /**
     * @notice Deploy an ONCHAINID using the identityOwner address as salt. No signature required.
     * @dev Convenience method for self-service deployment. Anyone can call this on behalf of
     *      any identityOwner. The frontend builds the full key list and modules.
     * @param identityOwner the wallet address to link and use as salt.
     * @param identityType the identity type (see IdentityTypes library).
     * @param keys the full list of keys with purposes, types, and signer data — built by the frontend.
     * @param modules the ERC-7579 modules to install during creation — built by the frontend.
     * @return the address of the deployed identity.
     */
    function deployIdentityForWallet(
        address identityOwner,
        uint256 identityType,
        Structs.KeyParam[] calldata keys,
        Structs.ModuleInstall[] calldata modules
    ) external returns (address) {
        require(identityOwner != address(0), Errors.ZeroAddress());
        return idFactory.createIdentity(identityOwner, identityType, Strings.toHexString(identityOwner), keys, modules);
    }

    /**
     * @notice Revoke a signature to prevent it from being used for deployment.
     * @param signature the signature to revoke.
     */
    function revokeSignature(bytes calldata signature) external onlyOwner {
        require(!revokedSignatures[signature], Errors.SignatureAlreadyRevoked(signature));
        revokedSignatures[signature] = true;
        emit SignatureRevoked(signature);
    }

    /**
     * @notice Remove a signature from the revoke list, allowing it to be used again.
     * @param signature the signature to re-approve.
     */
    function approveSignature(bytes calldata signature) external onlyOwner {
        require(revokedSignatures[signature], Errors.SignatureNotRevoked(signature));
        delete revokedSignatures[signature];
        emit SignatureApproved(signature);
    }

    /**
     * @notice Transfer the ownership of the factory to a new owner.
     * @param newOwner the new owner of the factory.
     */
    function transferFactoryOwnership(address newOwner) external onlyOwner {
        idFactory.transferOwnership(newOwner);
    }

    /**
     * @notice Call a function on the factory. Only the owner of the Gateway can call this method.
     * @param data the calldata to forward to the factory.
     */
    function callFactory(bytes memory data) external onlyOwner {
        (bool success,) = address(idFactory).call(data);
        require(success, Errors.CallToFactoryFailed());
    }

}
