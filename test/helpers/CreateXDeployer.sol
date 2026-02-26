// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;

// solhint-disable no-unused-import

// This file forces Foundry (with auto_detect_solc) to compile CreateX using solc 0.8.23,
// producing an artifact at out/CreateX.sol/CreateX.json.
// Tests deploy CreateX from this artifact using vm.readFile + vm.parseJsonBytes.
import { CreateX } from "@createx/CreateX.sol";
