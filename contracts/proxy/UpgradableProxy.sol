// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.6.9;

interface IImplementationAuthority {
    function getImplementation() external view returns(address);
}

contract Proxy {
    address implementationAuthority;

    constructor(address _implementationAuthority) public {
        implementationAuthority = _implementationAuthority;
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
