// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import { IIdentity, Identity } from "./Identity.sol";
import { IClaimIssuer } from "./interface/IClaimIssuer.sol";
import { Errors } from "./libraries/Errors.sol";
import { IdentityTypes } from "./libraries/IdentityTypes.sol";
import { KeyPurposes } from "./libraries/KeyPurposes.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title ClaimIssuer
 * @notice Extension of Identity that can issue, validate, and revoke claims for other identities.
 * @dev Adds claim revocation tracking, claim issuance to external identities, and
 * signature-based claim validation. Uses UUPS upgradeability for proxy deployments.
 */
contract ClaimIssuer is IClaimIssuer, Identity, UUPSUpgradeable {

    /// @notice Tracks revoked claim signatures. True if the claim signature has been revoked.
    mapping(bytes => bool) public revokedClaims;

    /**
     * @notice Constructor for direct deployments (non-proxy)
     * @param initialManagementKey The initial management key for the ClaimIssuer
     */
    // solhint-disable-next-line no-empty-blocks
    constructor(address initialManagementKey) Identity(initialManagementKey, false) { }

    /**
     * @notice External initializer for proxy deployments
     * @dev This function should be called when deploying ClaimIssuer through a proxy.
     * The _identityType parameter is ignored — ClaimIssuer always sets type 5.
     * @param initialManagementKey The initial management key for the ClaimIssuer
     */
    function initialize(
        address initialManagementKey,
        uint256 /* _identityType */
    )
        external
        override
        initializer
    {
        _getClaimStorage().identityType = IdentityTypes.CLAIM_ISSUER;
        __Identity_init(initialManagementKey);
    }

    /**
     *  @dev See {IClaimIssuer-revokeClaimBySignature}.
     */
    function revokeClaimBySignature(bytes calldata signature) external override delegatedOnly onlyManager {
        require(!revokedClaims[signature], Errors.ClaimAlreadyRevoked());

        revokedClaims[signature] = true;

        emit ClaimRevoked(signature);
    }

    /**
     *  @dev See {IClaimIssuer-revokeClaim}.
     */
    function revokeClaim(bytes32 _claimId, address _identity)
        external
        override
        delegatedOnly
        onlyManager
        returns (bool)
    {
        uint256 foundClaimTopic;
        uint256 scheme;
        address issuer;
        bytes memory sig;
        bytes memory data;

        (foundClaimTopic, scheme, issuer, sig, data,) = Identity(payable(_identity)).getClaim(_claimId);

        require(!revokedClaims[sig], Errors.ClaimAlreadyRevoked());

        revokedClaims[sig] = true;
        emit ClaimRevoked(sig);
        return true;
    }

    /**
     *  @dev See {IClaimIssuer-addClaimTo}.
     */
    function addClaimTo(
        uint256 _topic,
        uint256 _scheme,
        bytes calldata _signature,
        bytes calldata _data,
        string calldata _uri,
        IIdentity _identity
    ) external delegatedOnly onlyManager {
        require(isClaimValid(_identity, _topic, _signature, _data), Errors.InvalidClaim());

        bytes memory addClaimData = abi.encodeWithSelector(
            _identity.addClaim.selector, _topic, _scheme, address(this), _signature, _data, _uri
        );

        try _identity.execute(address(_identity), 0, addClaimData) { }
        catch {
            revert Errors.CallFailed();
        }
        emit ClaimAddedTo(address(_identity), _topic, _signature, _data);
    }

    /**
     *  @dev See {IClaimIssuer-isClaimValid}.
     *  @notice Extends Identity's isClaimValid with claim revocation check.
     */
    function isClaimValid(IIdentity _identity, uint256 claimTopic, bytes memory sig, bytes memory data)
        public
        view
        override(Identity, IClaimIssuer)
        returns (bool claimValid)
    {
        // 1. Check if the claim signature has been revoked by this issuer.
        if (isClaimRevoked(sig)) return false;

        // 2. Delegate to Identity.isClaimValid for EIP-712 digest + SignatureChecker verification.
        return super.isClaimValid(_identity, claimTopic, sig, data);
    }

    /**
     *  @dev See {IClaimIssuer-isClaimRevoked}.
     */
    function isClaimRevoked(bytes memory _sig) public view override returns (bool) {
        return revokedClaims[_sig];
    }

    /**
     * @dev Internal function to authorize the upgrade of the contract.
     * This function is required by UUPSUpgradeable and restricts upgrades to management keys only.
     *
     * @param newImplementation The address of the new implementation contract
     */
    function _authorizeUpgrade(address newImplementation) internal override(UUPSUpgradeable) onlyManager {
        // Only management keys can authorize upgrades
        // This prevents unauthorized upgrades and potential security issues
    }

}
