// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.27;

import "./interface/IClaimIssuer.sol";
import "./Identity.sol";

contract ClaimIssuer is IClaimIssuer, Identity {
    mapping (bytes => bool) public revokedClaims;

    // solhint-disable-next-line no-empty-blocks
    constructor(address initialManagementKey) Identity(initialManagementKey, false) {}

    /**
     *  @dev See {IClaimIssuer-revokeClaimBySignature}.
     */
    function revokeClaimBySignature(bytes calldata signature) external override delegatedOnly onlyManager {
        require(!revokedClaims[signature], "Conflict: Claim already revoked");

        revokedClaims[signature] = true;

        emit ClaimRevoked(signature);
    }

    /**
     *  @dev See {IClaimIssuer-revokeClaim}.
     */
    function revokeClaim(bytes32 _claimId, address _identity) external override delegatedOnly onlyManager returns(bool) {
        uint256 foundClaimTopic;
        uint256 scheme;
        address issuer;
        bytes memory sig;
        bytes memory data;

        ( foundClaimTopic, scheme, issuer, sig, data, ) = Identity(_identity).getClaim(_claimId);

        require(!revokedClaims[sig], "Conflict: Claim already revoked");

        revokedClaims[sig] = true;
        emit ClaimRevoked(sig);
        return true;
    }

    /**
     *  @dev See {IClaimIssuer-isClaimValid}.
     */
    function isClaimValid(
        IIdentity _identity,
        uint256 claimTopic,
        bytes memory sig,
        bytes memory data)
    public override(Identity, IClaimIssuer) view returns (bool claimValid)
    {
        bytes32 dataHash = keccak256(abi.encode(_identity, claimTopic, data));
        // Use abi.encodePacked to concatenate the message prefix and the message to sign.
        bytes32 prefixedHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", dataHash));

        // Recover address of data signer
        address recovered = getRecoveredAddress(sig, prefixedHash);

        // Take hash of recovered address
        bytes32 hashedAddr = keccak256(abi.encode(recovered));

        // Does the trusted identifier have they key which signed the user's claim?
        //  && (isClaimRevoked(_claimId) == false)
        if (keyHasPurpose(hashedAddr, 3) && (isClaimRevoked(sig) == false)) {
            return true;
        }

        return false;
    }

    /**
     *  @dev See {IClaimIssuer-isClaimRevoked}.
     */
    function isClaimRevoked(bytes memory _sig) public override view returns (bool) {
        if (revokedClaims[_sig]) {
            return true;
        }

        return false;
    }
}
