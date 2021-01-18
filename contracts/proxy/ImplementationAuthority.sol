// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "../interface/IImplementationAuthority.sol";

contract ImplementationAuthority is IImplementationAuthority {

    address public owner;

    modifier onlyOwner() {
        require(
            msg.sender == owner,
            "This function is restricted to the contract's owner"
        );
        _;
    }

    event UpdatedImplementation(address newAddress);

    address implementation;

    constructor(address _implementation) public {
        implementation = _implementation;
        emit UpdatedImplementation(_implementation);
        owner = msg.sender;
    }

    /**
     * @dev get the address of the implementation contract.
     * @return implementation the address of the implementation contract
     */
    function getImplementation() external override view returns(address) {
        return implementation;
    }

    /**
     * @dev update the address of the implementation contract.
     * @param _newImplementation the implementation address
     */
    function updateImplementation(address _newImplementation) public onlyOwner {
        implementation = _newImplementation;
        emit UpdatedImplementation(_newImplementation);
    }
}


