// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import { IClaimIssuer } from "./interface/IClaimIssuer.sol";
import { Identity, IIdentity } from "./Identity.sol";
import { Errors } from "./libraries/Errors.sol";
import { KeyPurposes } from "./libraries/KeyPurposes.sol";

contract ClaimIssuer is IClaimIssuer, Identity {
    mapping(bytes => bool) public revokedClaims;

    /**
     * @notice Constructor for direct deployments (non-proxy)
     * @param initialManagementKey The initial management key for the ClaimIssuer
     */
    // solhint-disable-next-line no-empty-blocks
    constructor(
        address initialManagementKey
    ) Identity(initialManagementKey, false) {}

    /**
     * @notice External initializer for proxy deployments
     * @dev This function should be called when deploying ClaimIssuer through a proxy
     * @param initialManagementKey The initial management key for the ClaimIssuer
     */
    function initialize(
        address initialManagementKey
    ) external override initializer {
        __ClaimIssuer_init(initialManagementKey);
    }

    /**
     *  @dev See {IClaimIssuer-revokeClaimBySignature}.
     */
    function revokeClaimBySignature(
        bytes calldata signature
    ) external override delegatedOnly onlyManager {
        require(!revokedClaims[signature], Errors.ClaimAlreadyRevoked());

        revokedClaims[signature] = true;

        emit ClaimRevoked(signature);
    }

    /**
     *  @dev See {IClaimIssuer-revokeClaim}.
     */
    function revokeClaim(
        bytes32 _claimId,
        address _identity
    ) external override delegatedOnly onlyManager returns (bool) {
        uint256 foundClaimTopic;
        uint256 scheme;
        address issuer;
        bytes memory sig;
        bytes memory data;

        (foundClaimTopic, scheme, issuer, sig, data, ) = Identity(_identity)
            .getClaim(_claimId);

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
        require(
            isClaimValid(_identity, _topic, _signature, _data),
            Errors.InvalidClaim()
        );

        bytes memory addClaimData = abi.encodeWithSelector(
            _identity.addClaim.selector,
            _topic,
            _scheme,
            address(this),
            _signature,
            _data,
            _uri
        );

        try _identity.execute(address(_identity), 0, addClaimData) {} catch {
            revert Errors.CallFailed();
        }
        emit ClaimAddedTo(address(_identity), _topic, _signature, _data);
    }

    /**
     *  @dev See {IClaimIssuer-isClaimValid}.
     */
    function isClaimValid(
        IIdentity _identity,
        uint256 claimTopic,
        bytes memory sig,
        bytes memory data
    ) public view override(Identity, IClaimIssuer) returns (bool claimValid) {
        bytes32 dataHash = keccak256(abi.encode(_identity, claimTopic, data));
        // Use abi.encodePacked to concatenate the message prefix and the message to sign.
        bytes32 prefixedHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", dataHash)
        );

        // Recover address of data signer
        address recovered = getRecoveredAddress(sig, prefixedHash);

        // Take hash of recovered address
        bytes32 hashedAddr = keccak256(abi.encode(recovered));

        // Does the trusted identifier have they key which signed the user's claim?
        //  && (isClaimRevoked(_claimId) == false)
        return
            keyHasPurpose(hashedAddr, KeyPurposes.CLAIM_SIGNER) &&
            !isClaimRevoked(sig);
    }

    /**
     *  @dev See {IClaimIssuer-isClaimRevoked}.
     */
    function isClaimRevoked(
        bytes memory _sig
    ) public view override returns (bool) {
        return revokedClaims[_sig];
    }

    /**
     * @notice Initializer function for proxy deployments
     * @dev This function should be called when deploying ClaimIssuer through a proxy
     * @param initialManagementKey The initial management key for the ClaimIssuer
     */
    // solhint-disable-next-line func-name-mixedcase
    function __ClaimIssuer_init(address initialManagementKey) internal {
        // Initialize UUPS upgradeability
        __UUPSUpgradeable_init();

        // Initialize IdentitySmartAccount functionality
        __IdentitySmartAccount_init();

        // Initialize Identity functionality
        __Identity_init(initialManagementKey);

        // Initialize Version functionality
        __Version_init("2.2.2");
    }

    /**
     * @dev Internal function to authorize the upgrade of the contract.
     * This function is required by UUPSUpgradeable and restricts upgrades to management keys only.
     *
     * @param newImplementation The address of the new implementation contract
     */
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyManager {
        // Only management keys can authorize upgrades
        // This prevents unauthorized upgrades and potential security issues
    }
}
