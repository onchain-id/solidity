// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import { IdFactory } from "../factory/IdFactory.sol";
import { Errors } from "../libraries/Errors.sol";
import { KeyPurposes } from "../libraries/KeyPurposes.sol";
import { KeyTypes } from "../libraries/KeyTypes.sol";
import { Structs } from "../storage/Structs.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract Gateway is Ownable {

    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    IdFactory public immutable idFactory;
    mapping(address => bool) public approvedSigners;
    mapping(bytes => bool) public revokedSignatures;

    event SignerApproved(address indexed signer);
    event SignerRevoked(address indexed signer);
    event SignatureRevoked(bytes indexed signature);
    event SignatureApproved(bytes indexed signature);

    /**
     *  @dev Constructor for the ONCHAINID Factory Gateway.
     *  @param idFactoryAddress the address of the factory to operate (the Gateway must be owner of the Factory).
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
     *  @dev Approve a signer to sign ONCHAINID deployments. If the Gateway is setup to require signature, only
     *  deployments requested with a valid signature from an approved signer will be accepted.
     *  If the gateway does not require a signature,
     *  @param signer the signer address to approve.
     */
    function approveSigner(address signer) external onlyOwner {
        require(signer != address(0), Errors.ZeroAddress());
        require(!approvedSigners[signer], Errors.SignerAlreadyApproved(signer));

        approvedSigners[signer] = true;

        emit SignerApproved(signer);
    }

    /**
     *  @dev Revoke a signer to sign ONCHAINID deployments.
     *  @param signer the signer address to revoke.
     */
    function revokeSigner(address signer) external onlyOwner {
        require(signer != address(0), Errors.ZeroAddress());
        require(approvedSigners[signer], Errors.SignerAlreadyNotApproved(signer));

        delete approvedSigners[signer];

        emit SignerRevoked(signer);
    }

    /**
     *  @dev Deploy an ONCHAINID using a factory. The operation must be signed by
     *  an approved public key. This method allow to deploy an ONCHAINID using a custom salt.
     *  @param identityOwner the address to set as a management key.
     *  @param salt to use for the deployment.
     *  @param identityType the type of the identity (see IdentityTypes library).
     *  @param claimAdders the list of addresses to add as CLAIM_ADDER keys on the identity.
     *  @param signatureExpiry the block timestamp where the signature will expire.
     *  @param signature the approval containing the salt and the identityOwner address.
     */
    function deployIdentityWithSalt(
        address identityOwner,
        string memory salt,
        uint256 identityType,
        address[] calldata claimAdders,
        uint256 signatureExpiry,
        bytes calldata signature
    ) external returns (address) {
        require(identityOwner != address(0), Errors.ZeroAddress());
        require(signatureExpiry == 0 || block.timestamp <= signatureExpiry, Errors.ExpiredSignature(signature));

        address signer = keccak256(
                abi.encode(
                    "Authorize ONCHAINID deployment", identityOwner, salt, identityType, claimAdders, signatureExpiry
                )
            ).toEthSignedMessageHash().recover(signature);

        require(approvedSigners[signer], Errors.UnapprovedSigner(signer));
        require(!revokedSignatures[signature], Errors.RevokedSignature(signature));

        Structs.KeyParam[] memory keys = _buildKeysForWallet(identityOwner, claimAdders);
        return idFactory.createIdentity(identityOwner, salt, keys, identityType);
    }

    /**
     *  @dev Deploy an ONCHAINID using a factory. The operation must be signed by
     *  an approved public key. This method allow to deploy an ONCHAINID using a custom salt and a custom list of
     *  management keys. Note that the identity Owner address won't be added as a management keys, if this is desired,
     *  the key hash must be listed in the managementKeys array.
     *  @param identityOwner the address to set as a management key.
     *  @param salt to use for the deployment.
     *  @param managementKeys the list of management keys to add to the ONCHAINID.
     *  @param identityType the type of the identity (see IdentityTypes library).
     *  @param claimAdders the list of addresses to add as CLAIM_ADDER keys on the identity.
     *  @param signatureExpiry the block timestamp where the signature will expire.
     *  @param signature the approval containing the salt and the identityOwner address.
     */
    function deployIdentityWithSaltAndManagementKeys(
        address identityOwner,
        string memory salt,
        address[] calldata managementKeys,
        uint256 identityType,
        address[] calldata claimAdders,
        uint256 signatureExpiry,
        bytes calldata signature
    ) external returns (address) {
        require(identityOwner != address(0), Errors.ZeroAddress());
        require(signatureExpiry == 0 || block.timestamp <= signatureExpiry, Errors.ExpiredSignature(signature));

        address signer = keccak256(
                abi.encode(
                    "Authorize ONCHAINID deployment",
                    identityOwner,
                    salt,
                    managementKeys,
                    identityType,
                    claimAdders,
                    signatureExpiry
                )
            ).toEthSignedMessageHash().recover(signature);

        require(approvedSigners[signer], Errors.UnapprovedSigner(signer));
        require(!revokedSignatures[signature], Errors.RevokedSignature(signature));

        Structs.KeyParam[] memory keys = _buildKeys(managementKeys, claimAdders);
        return idFactory.createIdentity(identityOwner, salt, keys, identityType);
    }

    /**
     *  @dev Deploy an ONCHAINID using a factory using the identityOwner address as salt.
     *  @param identityOwner the address to set as a management key.
     *  @param identityType the type of the identity (see IdentityTypes library).
     *  @param claimAdders the list of addresses to add as CLAIM_ADDER keys on the identity.
     */
    function deployIdentityForWallet(address identityOwner, uint256 identityType, address[] calldata claimAdders)
        external
        returns (address)
    {
        require(identityOwner != address(0), Errors.ZeroAddress());

        Structs.KeyParam[] memory keys = _buildKeysForWallet(identityOwner, claimAdders);
        return idFactory.createIdentity(identityOwner, Strings.toHexString(identityOwner), keys, identityType);
    }

    /**
     *  @dev Revoke a signature, if the signature is used to deploy an ONCHAINID, the deployment would be rejected.
     *  @param signature the signature to revoke.
     */
    function revokeSignature(bytes calldata signature) external onlyOwner {
        require(!revokedSignatures[signature], Errors.SignatureAlreadyRevoked(signature));

        revokedSignatures[signature] = true;

        emit SignatureRevoked(signature);
    }

    /**
     *  @dev Remove a signature from the revoke list.
     *  @param signature the signature to approve.
     */
    function approveSignature(bytes calldata signature) external onlyOwner {
        require(revokedSignatures[signature], Errors.SignatureNotRevoked(signature));

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
        require(success, Errors.CallToFactoryFailed());
    }

    /**
     *  @dev Build a KeyParam array from a single wallet address (as MANAGEMENT key) and optional claim adders.
     */
    function _buildKeysForWallet(address wallet, address[] calldata claimAdders)
        private
        pure
        returns (Structs.KeyParam[] memory)
    {
        address[] memory mgmtKeys = new address[](1);
        mgmtKeys[0] = wallet;
        return _buildKeys(mgmtKeys, claimAdders);
    }

    /**
     *  @dev Build a KeyParam array from management key addresses and claim adder addresses.
     *  @param managementKeys the addresses to add as MANAGEMENT keys.
     *  @param claimAdders the addresses to add as CLAIM_ADDER keys.
     */
    function _buildKeys(address[] memory managementKeys, address[] calldata claimAdders)
        private
        pure
        returns (Structs.KeyParam[] memory keys)
    {
        // clientData is empty for ECDSA keys — only needed for non-ECDSA keys (e.g. WebAuthn credentialId)
        uint256 totalKeys = managementKeys.length + claimAdders.length;
        keys = new Structs.KeyParam[](totalKeys);
        for (uint256 i = 0; i < managementKeys.length; i++) {
            keys[i] = Structs.KeyParam({
                keyHash: keccak256(abi.encodePacked(managementKeys[i])),
                purpose: KeyPurposes.MANAGEMENT,
                keyType: KeyTypes.ECDSA,
                signerData: abi.encodePacked(managementKeys[i]),
                clientData: ""
            });
        }
        for (uint256 i = 0; i < claimAdders.length; i++) {
            keys[managementKeys.length + i] = Structs.KeyParam({
                keyHash: keccak256(abi.encodePacked(claimAdders[i])),
                purpose: KeyPurposes.CLAIM_ADDER,
                keyType: KeyTypes.ECDSA,
                signerData: abi.encodePacked(claimAdders[i]),
                clientData: ""
            });
        }
    }

}
