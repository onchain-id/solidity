// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.27;

import { IdentityUtilities } from "contracts/IdentityUtilities.sol";
import { IIdentity } from "contracts/interface/IIdentity.sol";

contract TestIdentityUtilities is IdentityUtilities {

    function checkIsClaimValid(
        address identity,
        uint256 topicId,
        uint256 scheme,
        address issuer,
        bytes memory signature,
        bytes memory data
    ) external view returns (bool) {
        return _isClaimValid(identity, topicId, scheme, issuer, signature, data);
    }

}
