// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.6.9;

import "../Interface/IImplementationAuthority.sol";

contract Proxy {
    address implementationAuthority;

    constructor(address _implementationAuthority) public {
        // save the code address
        implementationAuthority = _implementationAuthority;
        address contractLogic = IImplementationAuthority(_implementationAuthority).getImplementation();
        assembly { // solium-disable-line
            sstore(0xc5f16f0fcc639fa48a6947836d9850f504798523bf8c9a3a87d5876cf622bcf7, contractLogic)
        }
    }

    fallback() external payable {
        address logic = IImplementationAuthority(implementationAuthority).getImplementation();

        assembly { // solium-disable-line
        calldatacopy(0x0, 0x0, calldatasize())
        let success := delegatecall(sub(gas(), 10000), logic, 0x0, calldatasize(), 0, 0)
        let retSz := returndatasize()
        returndatacopy(0, 0, retSz)
        switch success
            case 0 {
                revert(0, retSz)
            }
            default {
                return(0, retSz)
            }
        }
    }
}
