// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.27;

import { BeaconProxy } from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";


contract IdentityProxy is BeaconProxy {

    constructor(address _implementationAuthority, address _initialManagementKey) 
        BeaconProxy(_implementationAuthority, abi.encodeWithSignature("initialize(address)", _initialManagementKey)) {
    }

}
