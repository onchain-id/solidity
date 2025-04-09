// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.27;

import { IImplementationAuthority } from "../interface/IImplementationAuthority.sol";
import { Errors } from "../libraries/Errors.sol";

contract IdentityProxy {

    /**
     *  @dev constructor of the proxy Identity contract
     *  @param _implementationAuthority the implementation Authority contract address
     *  @param initialManagementKey the management key at deployment
     *  the proxy is going to use the logic deployed on the implementation contract
     *  deployed at an address listed in the ImplementationAuthority contract
     */
    constructor(address _implementationAuthority, address initialManagementKey) {
        require(_implementationAuthority != address(0), Errors.ZeroAddress());
        require(initialManagementKey != address(0), Errors.ZeroAddress());

        // solhint-disable-next-line no-inline-assembly
        assembly {
            sstore(0x821f3e4d3d679f19eacc940c87acf846ea6eae24a63058ea750304437a62aafc, _implementationAuthority)
        }

        address logic = IImplementationAuthority(_implementationAuthority).getImplementation();

        // solhint-disable-next-line avoid-low-level-calls
        (bool success,) = logic.delegatecall(abi.encodeWithSignature("initialize(address)", initialManagementKey));
        require(success, Errors.InitializationFailed());
    }

    /**
     *  @dev fallback proxy function used for any transaction call that is made using
     *  the Identity contract ABI and called on the proxy contract
     *  The proxy will update its local storage depending on the behaviour requested
     *  by the implementation contract given by the Implementation Authority
     */
    // solhint-disable-next-line no-complex-fallback
    fallback() external payable {
        address logic = IImplementationAuthority(implementationAuthority()).getImplementation();

        // solhint-disable-next-line no-inline-assembly
        assembly {
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

    function implementationAuthority() public view returns(address) {
        address implemAuth;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            implemAuth := sload(0x821f3e4d3d679f19eacc940c87acf846ea6eae24a63058ea750304437a62aafc)
        }
        return implemAuth;
    }
}
