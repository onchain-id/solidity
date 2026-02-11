// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.27;

import { IdentityUtilities } from "../IdentityUtilities.sol";
import { IIdentity } from "../interface/IIdentity.sol";

contract TestIdentityUtilities is IdentityUtilities {
    function testIsClaimValid(
        address identity,
        uint256 topicId,
        address issuer,
        bytes memory signature,
        bytes memory data
    ) external view returns (bool) {
        return _isClaimValid(identity, topicId, issuer, signature, data);
    }
}
