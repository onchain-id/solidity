// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import { Identity } from "contracts/Identity.sol";
import { IdFactory } from "contracts/factory/IdFactory.sol";
import { IdentityTypes } from "contracts/libraries/IdentityTypes.sol";
import { ECDSAValidator } from "contracts/modules/validators/ECDSAValidator.sol";
import { WebAuthnValidator } from "contracts/modules/validators/WebAuthnValidator.sol";
import { IdentityProxy } from "contracts/proxy/IdentityProxy.sol";
import { ImplementationAuthority } from "contracts/proxy/ImplementationAuthority.sol";

/// @notice Helper library for deploying OnchainID Identity Factory infrastructure
library IdentityHelper {

    struct OnchainIDSetup {
        Identity identityImplementation;
        ImplementationAuthority implementationAuthority;
        IdFactory idFactory;
        ECDSAValidator ecdsaValidator;
        WebAuthnValidator webauthnValidator;
    }

    /// @notice Deploys complete Identity Factory infrastructure
    /// @param managementKey The initial management key address
    /// @return setup Struct containing all deployed contracts
    function deployFactory(address managementKey) internal returns (OnchainIDSetup memory setup) {
        // Deploy validator module singletons
        setup.ecdsaValidator = new ECDSAValidator();
        setup.webauthnValidator = new WebAuthnValidator();

        setup.identityImplementation = new Identity(managementKey, false);
        setup.implementationAuthority = new ImplementationAuthority(address(setup.identityImplementation));
        setup.idFactory = new IdFactory(address(setup.implementationAuthority));
        // Modules are installed per-identity via createIdentity's _modules parameter
    }

    /// @notice Deploys an Identity through the custom IdentityProxy pattern
    /// @param initialManagementKey The management key for the identity
    /// @return identity The Identity contract at the proxy address
    function deployIdentityWithProxy(address initialManagementKey) internal returns (Identity) {
        return deployIdentityWithProxy(initialManagementKey, IdentityTypes.INDIVIDUAL);
    }

    function deployIdentityWithProxy(address initialManagementKey, uint256 identityType) internal returns (Identity) {
        Identity impl = new Identity(initialManagementKey, false);
        ImplementationAuthority ia = new ImplementationAuthority(address(impl));
        IdentityProxy proxy = new IdentityProxy(address(ia), initialManagementKey, identityType);
        return Identity(payable(address(proxy)));
    }

}
