// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import { Identity } from "contracts/Identity.sol";
import { IdFactory } from "contracts/factory/IdFactory.sol";
import { IdentityProxy } from "contracts/proxy/IdentityProxy.sol";
import { ImplementationAuthority } from "contracts/proxy/ImplementationAuthority.sol";

/// @notice Helper library for deploying OnchainID Identity Factory infrastructure
library IdentityHelper {

    struct OnchainIDSetup {
        Identity identityImplementation;
        ImplementationAuthority implementationAuthority;
        IdFactory idFactory;
    }

    function deployFactory(address managementKey, address createx, address owner)
        internal
        returns (OnchainIDSetup memory setup)
    {
        setup.identityImplementation = new Identity(managementKey, false);
        setup.implementationAuthority = new ImplementationAuthority(address(setup.identityImplementation), owner);
        setup.idFactory = new IdFactory(address(setup.implementationAuthority), createx, owner);
    }

    function deployIdentityWithProxy(address initialManagementKey, address owner) internal returns (Identity) {
        Identity impl = new Identity(initialManagementKey, false);
        ImplementationAuthority ia = new ImplementationAuthority(address(impl), owner);
        IdentityProxy proxy = new IdentityProxy(address(ia), initialManagementKey);
        return Identity(address(proxy));
    }

}
