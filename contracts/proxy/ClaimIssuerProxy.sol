// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title ClaimIssuerProxy
 * @dev Proxy contract for ClaimIssuer using ERC1967 standard
 * This proxy delegates all calls to the implementation contract
 */
contract ClaimIssuerProxy is ERC1967Proxy {
    /**
     * @dev Constructor for ClaimIssuerProxy
     * @param implementation The address of the implementation contract
     * @param data The encoded function call to initialize the proxy
     */
    constructor(
        address implementation,
        bytes memory data
    ) ERC1967Proxy(implementation, data) {}
}
