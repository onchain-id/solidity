// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import { BeaconProxy } from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";

import { Identity } from "../Identity.sol";

contract IdentityProxy is BeaconProxy {

    constructor(address _implementationAuthority, address _initialManagementKey, uint256 _identityType)
        BeaconProxy(
            _implementationAuthority, abi.encodeCall(Identity.initialize, (_initialManagementKey, _identityType))
        )
    { }

}
