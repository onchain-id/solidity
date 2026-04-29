// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import { Script, console } from "forge-std/Script.sol";

import {
    ERC7913WebAuthnVerifier
} from "@openzeppelin/contracts/utils/cryptography/verifiers/ERC7913WebAuthnVerifier.sol";
import { ClaimIssuer } from "contracts/ClaimIssuer.sol";
import { Identity } from "contracts/Identity.sol";
import { IdentityUtilities } from "contracts/IdentityUtilities.sol";
import { ClaimIssuerFactory } from "contracts/factory/ClaimIssuerFactory.sol";
import { IdFactory } from "contracts/factory/IdFactory.sol";
import { Gateway } from "contracts/gateway/Gateway.sol";
import { IdentityUtilitiesProxy } from "contracts/proxy/IdentityUtilitiesProxy.sol";
import { ImplementationAuthority } from "contracts/proxy/ImplementationAuthority.sol";

/**
 * @title DeployOnchainID
 * @notice Deploys the full OnchainID protocol stack.
 *
 * Deployment order:
 *   1. Identity implementation (library mode)
 *   2. ClaimIssuer implementation
 *   3. IdentityUtilities implementation + proxy
 *   4. ImplementationAuthority (beacon pointing to Identity impl)
 *   5. IdFactory (uses ImplementationAuthority for identity proxies)
 *   6. ClaimIssuerFactory (uses ClaimIssuer impl for CREATE3 proxies)
 *   7. Gateway (entry point for signed identity deployments)
 *
 * Usage:
 *   forge script scripts/DeployOnchainID.s.sol --rpc-url <RPC> --private-key <PK> --broadcast --verify
 */
contract DeployOnchainID is Script {

    function run() external {
        // Gateway signers — hardcode as needed
        address[] memory gatewaySigners = new address[](2);
        gatewaySigners[0] = 0x927eCbf77127C423642e6e3459CFc0B2c08BeC0c;
        gatewaySigners[1] = 0xc756c27486d07112bc11AA6d3f53DA3Ca9aAf2ca;

        vm.startBroadcast();

        address deployer = msg.sender;
        console.log("Deployer:", deployer);
        console.log("");

        // ===== Phase 1: Implementation contracts =====

        // 1. Identity implementation (library mode — prevents direct initialization)
        Identity identityImpl = new Identity(deployer, true);
        console.log("Identity implementation:", address(identityImpl));

        // 2. ClaimIssuer implementation
        ClaimIssuer claimIssuerImpl = new ClaimIssuer(deployer);
        console.log("ClaimIssuer implementation:", address(claimIssuerImpl));

        // 3. IdentityUtilities implementation + proxy
        IdentityUtilities utilitiesImpl = new IdentityUtilities();
        IdentityUtilitiesProxy utilitiesProxy = new IdentityUtilitiesProxy(
            address(utilitiesImpl), abi.encodeCall(IdentityUtilities.initialize, (deployer))
        );
        console.log("IdentityUtilities implementation:", address(utilitiesImpl));
        console.log("IdentityUtilities proxy:", address(utilitiesProxy));

        // ===== Phase 2: Infrastructure =====

        // 4. ImplementationAuthority (beacon for identity proxies)
        ImplementationAuthority authority = new ImplementationAuthority(address(identityImpl));
        console.log("ImplementationAuthority:", address(authority));

        // 5. IdFactory
        IdFactory idFactory = new IdFactory(address(authority));
        console.log("IdFactory:", address(idFactory));

        // 6. ClaimIssuerFactory
        ClaimIssuerFactory claimIssuerFactory = new ClaimIssuerFactory(address(claimIssuerImpl));
        console.log("ClaimIssuerFactory:", address(claimIssuerFactory));

        // 7. Gateway
        Gateway gateway = new Gateway(address(idFactory), gatewaySigners);
        console.log("Gateway:", address(gateway));

        // 8. ERC-7913 WebAuthn Verifier (stateless — verifies P-256 WebAuthn assertions on-chain)
        ERC7913WebAuthnVerifier webAuthnVerifier = new ERC7913WebAuthnVerifier();
        console.log("ERC7913WebAuthnVerifier:", address(webAuthnVerifier));

        // Transfer IdFactory ownership to Gateway so it can deploy identities
        idFactory.transferOwnership(address(gateway));
        console.log("IdFactory ownership transferred to Gateway");

        vm.stopBroadcast();

        // ===== Summary =====
        console.log("");
        console.log("========== Deployment Summary ==========");
        console.log("Identity impl:          ", address(identityImpl));
        console.log("ClaimIssuer impl:       ", address(claimIssuerImpl));
        console.log("IdentityUtilities impl: ", address(utilitiesImpl));
        console.log("IdentityUtilities proxy:", address(utilitiesProxy));
        console.log("ImplementationAuthority:", address(authority));
        console.log("IdFactory:              ", address(idFactory));
        console.log("ClaimIssuerFactory:     ", address(claimIssuerFactory));
        console.log("Gateway:                ", address(gateway));
        console.log("ERC7913WebAuthnVerifier:", address(webAuthnVerifier));
        console.log("=========================================");
    }

}
