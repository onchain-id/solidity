// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";

/// @notice Helper to deploy CreateX from its compiled artifact.
/// CreateX (pragma 0.8.23) is compiled separately via CreateXDeployer.sol with auto_detect_solc.
/// Requires fs_permissions read access to "out" in foundry.toml.
abstract contract CreateXHelper is Test {

    function _deployCreateX() internal returns (address) {
        string memory artifact = vm.readFile("out/CreateX.sol/CreateX.json");
        bytes memory bytecode = vm.parseJsonBytes(artifact, ".bytecode.object");
        address deployed;
        assembly {
            deployed := create(0, add(bytecode, 0x20), mload(bytecode))
        }
        require(deployed != address(0), "CreateX deployment failed");
        return deployed;
    }

}
