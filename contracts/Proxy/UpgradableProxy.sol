// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.6.9;

import "../Interface/IImplementationProxy.sol";

contract Proxy {
    fallback() external payable {
    address logic = IImplementationProxy(0xa6165bbb69f7e8f3d960220B5F28e990ea5F630D).getImplementation();

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
