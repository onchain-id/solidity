// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.27;

import "../interface/IImplementationAuthority.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ImplementationAuthority is IImplementationAuthority, Ownable {

    // the address of implementation of ONCHAINID
    address internal _implementation;

    constructor(address implementation) {
        require(implementation != address(0), "invalid argument - zero address");
        _implementation = implementation;
        emit UpdatedImplementation(implementation);
    }

    /**
     *  @dev See {IImplementationAuthority-updateImplementation}.
     */
    function updateImplementation(address _newImplementation) external override onlyOwner {
        require(_newImplementation != address(0), "invalid argument - zero address");
        _implementation = _newImplementation;
        emit UpdatedImplementation(_newImplementation);
    }

    /**
     *  @dev See {IImplementationAuthority-getImplementation}.
     */
    function getImplementation() external override view returns(address) {
        return _implementation;
    }
}
