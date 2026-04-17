// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import "./IERC734.sol";
import "./IERC735.sol";

// solhint-disable-next-line no-empty-blocks
interface IIdentity is IERC734, IERC735 {

    /**
     * @dev Checks if a claim is valid.
     * @param _identity the identity contract related to the claim
     * @param claimTopic the claim topic of the claim
     * @param _scheme the verification scheme (KeyTypes.ECDSA, KeyTypes.WEBAUTHN, etc.)
     * @param sig the signature of the claim
     * @param data the data field of the claim
     * @return claimValid true if the claim is valid, false otherwise
     */
    function isClaimValid(
        IIdentity _identity,
        uint256 claimTopic,
        uint256 _scheme,
        bytes calldata sig,
        bytes calldata data
    ) external view returns (bool);

    /**
     * @dev Returns the identity type set at initialization.
     * @return The identity type (see IdentityTypes library)
     */
    function getIdentityType() external view returns (uint256);

}
