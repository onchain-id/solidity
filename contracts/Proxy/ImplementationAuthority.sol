// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.6.9;

import "@openzeppelin/contracts/access/Ownable.sol";

contract ImplementationAuthority is Ownable {

    event UpdatedImplementation(address newAddress);

    bytes32 internal implementation;

    constructor(address _implementation) public {
        bytes32 slot = implementation;
        assembly {
            sstore(slot, _implementation)
        }
        emit UpdatedImplementation(_implementation);
    }

    function getImplementation() external view returns(address impl) {
        bytes32 slot = implementation;
        assembly {
            impl := sload(slot)
        }
    }

    function updateImplementation(address _newImplementation) public onlyOwner {
        bytes32 slot = implementation;
        assembly {
            sstore(slot, _newImplementation)
        }
        emit UpdatedImplementation(_newImplementation);
    }
}

