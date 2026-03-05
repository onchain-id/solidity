// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ClaimIssuer} from "contracts/ClaimIssuer.sol";

/// @notice Helper library for deploying ClaimIssuer contracts with proxy
library ClaimIssuerHelper {
    /// @notice Deploys a ClaimIssuer behind an ERC1967Proxy
    /// @param initialManagementKey The management key for the claim issuer
    /// @return claimIssuer The ClaimIssuer contract at the proxy address
    function deployWithProxy(address initialManagementKey) internal returns (ClaimIssuer) {
        ClaimIssuer impl = new ClaimIssuer(initialManagementKey);
        ERC1967Proxy proxy =
            new ERC1967Proxy(address(impl), abi.encodeCall(ClaimIssuer.initialize, (initialManagementKey)));
        return ClaimIssuer(address(proxy));
    }
}
