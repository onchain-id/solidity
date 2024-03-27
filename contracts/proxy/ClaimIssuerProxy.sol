// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.17;
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract ClaimIssuerProxy is ERC1967Proxy {
    // solhint-disable-next-line no-empty-blocks
    constructor(address implementation, bytes memory _data) ERC1967Proxy(implementation, _data) { }
}
