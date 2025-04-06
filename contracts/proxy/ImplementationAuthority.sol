// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.27;

import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

contract ImplementationAuthority is UpgradeableBeacon {

    constructor(address implementation) UpgradeableBeacon(implementation, msg.sender) {
    }

}
