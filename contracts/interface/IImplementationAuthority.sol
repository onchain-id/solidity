// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

interface IImplementationAuthority {

    // event emitted when the implementation contract is updated
    event UpdatedImplementation(address newAddress);

    /**
     * @dev updates the address used as implementation by the proxies linked
     * to this ImplementationAuthority contract
     * @param _newImplementation the address of the new implementation contract
     * only Owner can call
     */
    function updateImplementation(address _newImplementation) external;

    /**
     * @dev returns the address of the implementation
     */
    function getImplementation() external view returns(address);
}
