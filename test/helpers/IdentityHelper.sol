// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import {Identity} from "contracts/Identity.sol";
import {IdFactory} from "contracts/factory/IdFactory.sol";
import {IdentityProxy} from "contracts/proxy/IdentityProxy.sol";
import {ImplementationAuthority} from "contracts/proxy/ImplementationAuthority.sol";

/// @notice Helper library for deploying OnchainID Identity Factory infrastructure
library IdentityHelper {
    struct OnchainIDSetup {
        Identity identityImplementation;
        ImplementationAuthority implementationAuthority;
        IdFactory idFactory;
    }

    /// @notice Deploys complete Identity Factory infrastructure
    /// @param managementKey The initial management key address
    /// @return setup Struct containing all deployed contracts
    function deployFactory(address managementKey) internal returns (OnchainIDSetup memory setup) {
        setup.identityImplementation = new Identity(managementKey, false);
        setup.implementationAuthority = new ImplementationAuthority(address(setup.identityImplementation));
        setup.idFactory = new IdFactory(address(setup.implementationAuthority));
    }

    /// @notice Deploys an Identity through the custom IdentityProxy pattern
    /// @param initialManagementKey The management key for the identity
    /// @return identity The Identity contract at the proxy address
    function deployIdentityWithProxy(address initialManagementKey) internal returns (Identity) {
        Identity impl = new Identity(initialManagementKey, false);
        ImplementationAuthority ia = new ImplementationAuthority(address(impl));
        IdentityProxy proxy = new IdentityProxy(address(ia), initialManagementKey);
        return Identity(address(proxy));
    }
}
