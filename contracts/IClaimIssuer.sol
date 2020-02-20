pragma solidity ^0.6.2;

import "./IIdentity.sol";

interface IClaimIssuer {
    function revokeClaim(bytes32 _claimId, address _identity) external returns(bool);
    function getRecoveredAddress(bytes calldata sig, bytes32 dataHash) external pure returns (address);
    function isClaimRevoked(bytes calldata _sig) external view returns (bool);
    function isClaimValid(IIdentity _identity, bytes32 _claimId, uint256 claimTopic, bytes calldata sig, bytes calldata data) external view returns (bool);
}
