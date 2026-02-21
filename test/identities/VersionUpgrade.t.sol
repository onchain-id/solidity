// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import { OnchainIDSetup } from "../helpers/OnchainIDSetup.sol";

contract VersionUpgradeTest is OnchainIDSetup {

    function test_returnInitialVersion() public view {
        assertEq(aliceIdentity.version(), "3.0.0");
    }

    function test_maintainVersionConstant() public view {
        assertEq(aliceIdentity.version(), "3.0.0");
    }

    function test_demonstrateUpgradePattern() public {
        assertEq(aliceIdentity.version(), "3.0.0");

        uint256 claimTopic = uint256(keccak256(bytes("test")));
        bytes memory claimData = bytes("test data");
        string memory claimUri = "https://example.com";

        // Add self-issued claim
        vm.prank(alice);
        aliceIdentity.addClaim(claimTopic, 1, address(aliceIdentity), hex"", claimData, claimUri);

        // Verify claim
        bytes32 claimId = keccak256(abi.encode(address(aliceIdentity), claimTopic));
        (uint256 topic,, address returnedIssuer,, bytes memory data, string memory uri) =
            aliceIdentity.getClaim(claimId);

        assertEq(topic, claimTopic);
        assertEq(returnedIssuer, address(aliceIdentity));
        assertEq(data, claimData);
        assertEq(uri, claimUri);
    }

}
