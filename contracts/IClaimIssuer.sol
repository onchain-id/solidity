pragma solidity ^0.6.2;

import "./Identity.sol";

interface IClaimIssuer {
    function isClaimValid(Identity _identity, bytes32 _claimId, uint256 claimTopic, bytes calldata sig, bytes calldata data)
    external
    view
    returns (bool claimValid);
}
