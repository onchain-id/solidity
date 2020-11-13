import "./CloneFactory.sol";
import "./Identity.sol";

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.6.9;

contract IdentityFactory is CloneFactory {
    address public libraryAddress;

    event IdentityCreated(address newIdentityAddress);

    constructor(address _libraryAddress) public {
        libraryAddress = _libraryAddress;
    }

    function setLibraryAddress(address _libraryAddress) public {
        libraryAddress = _libraryAddress;
    }

    function createIdentity(address _owner) public returns(address) {
        address clone = createClone(libraryAddress);
        Identity(clone).set(_owner);
        IdentityCreated(clone);
        return clone;
    }

    function isClonedIdentity(address _identity) public view returns (bool) {
        return isClone(libraryAddress, _identity);
    }
}
