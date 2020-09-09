import "./CloneFactory.sol";
import "./Identity.sol";

pragma solidity 0.6.2;

contract IdentityFactory is CloneFactory {
    address public libraryAddress;

    Identity[] public IdentityAddresses;

    event IdentityCreated(address newIdentityAddress);

    constructor(address _libraryAddress) public {
        libraryAddress = _libraryAddress;
    }

    function setLibraryAddress(address _libraryAddress) public {
        libraryAddress = _libraryAddress;
    }

    function createIdentity(address _owner) public  {
        address clone = createClone(libraryAddress);
        IdentityAddresses.push(Identity(clone));
        Identity(clone).set(_owner);
        IdentityCreated(clone);
    }

    function isClonedIdentity(address _identity) public view returns (bool) {
        return isClone(libraryAddress, _identity);
    }

    function getIdentities() external view returns (Identity[] memory) {
        return IdentityAddresses;
    }

}
