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
     * @param sig the signature of the claim
     * @param data the data field of the claim
     * @return claimValid true if the claim is valid, false otherwise
     */
    function isClaimValid(IIdentity _identity, uint256 claimTopic, bytes calldata sig, bytes calldata data)
        external
        view
        returns (bool);

    /**
     * @dev Computes the EIP-712 claim digest for off-chain signing.
     * @param _identity The identity address the claim is for
     * @param _topic The claim topic
     * @param _data The claim data
     * @return The EIP-712 typed data hash
     */
    function getClaimHash(address _identity, uint256 _topic, bytes memory _data) external view returns (bytes32);

    /**
     * @dev Returns the identity type set at initialization.
     * @return The identity type (see IdentityTypes library)
     */
    function getIdentityType() external view returns (uint256);

}
