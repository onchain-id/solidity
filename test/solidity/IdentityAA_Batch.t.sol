// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";

// EntryPoint v0.8 imports
import { EntryPoint } from "@account-abstraction/contracts/core/EntryPoint.sol";
import { IEntryPoint } from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { PackedUserOperation } from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import { UserOperationLib } from "@account-abstraction/contracts/core/UserOperationLib.sol";

// Project contracts
import { Identity } from "../../contracts/Identity.sol";
import { ImplementationAuthority } from "../../contracts/proxy/ImplementationAuthority.sol";
import { IdentityProxy } from "../../contracts/proxy/IdentityProxy.sol";
import { IdentitySmartAccount } from "../../contracts/IdentitySmartAccount.sol";
import { KeyPurposes } from "../../contracts/libraries/KeyPurposes.sol";
import { KeyTypes } from "../../contracts/libraries/KeyTypes.sol";

// Test helpers
import { UserOpBuilder } from "../../contracts/test/lib/UserOpBuilder.sol";
import { Target } from "../../contracts/test/mocks/Target.sol";

/**
 * @title IdentityAA_Batch_Test
 * @notice Test suite for executeBatch functionality in ERC-4337 Account Abstraction
 * @dev Tests multi-call execution, error handling, and atomic batch operations
 */
contract IdentityAA_Batch_Test is Test {
    using UserOperationLib for PackedUserOperation;

    // Core contracts
    EntryPoint internal ep;
    address internal epAddr;
    Identity internal identity;
    address internal identityAddr;
    Target internal target1;
    Target internal target2;
    address internal target1Addr;
    address internal target2Addr;

    // Test accounts
    uint256 internal constant MGMT_KEY = 0xA11CE;
    uint256 internal constant AA_SIGNER_KEY = 0xB11CE;

    address internal mgmt;
    address internal aaSigner;

    function setUp() public {
        // 1. Generate test accounts
        mgmt = vm.addr(MGMT_KEY);
        aaSigner = vm.addr(AA_SIGNER_KEY);

        // 2. Deploy EntryPoint v0.8
        ep = new EntryPoint();
        epAddr = address(ep);

        // 3. Deploy Identity via proxy
        Identity impl = new Identity(address(1), true);
        ImplementationAuthority auth = new ImplementationAuthority(
            address(impl)
        );
        IdentityProxy proxy = new IdentityProxy(address(auth), mgmt);
        identityAddr = address(proxy);
        identity = Identity(payable(identityAddr));

        // 4. Add ERC4337_SIGNER key
        vm.prank(mgmt);
        identity.addKey(
            keccak256(abi.encode(aaSigner)),
            KeyPurposes.ERC4337_SIGNER,
            KeyTypes.ECDSA
        );

        // 5. Set EntryPoint
        vm.prank(mgmt);
        identity.setEntryPoint(IEntryPoint(epAddr));

        // 6. Deploy two target contracts
        target1 = new Target();
        target2 = new Target();
        target1Addr = address(target1);
        target2Addr = address(target2);

        // 7. Fund identity
        vm.deal(identityAddr, 10 ether);
    }

    // ========================================
    // Test: Successful Batch Execution
    // ========================================

    /**
     * @notice Test that executeBatch successfully executes multiple calls atomically
     */
    function test_executeBatch_multiple_calls_success() public {
        // Arrange: Create batch with 3 calls
        IdentitySmartAccount.Call[]
            memory calls = new IdentitySmartAccount.Call[](3);

        // Call 1: ping target1 with 0.1 ETH
        calls[0] = IdentitySmartAccount.Call({
            target: target1Addr,
            value: 0.1 ether,
            data: abi.encodeWithSignature("ping(bytes)", hex"01")
        });

        // Call 2: ping target2 with 0.2 ETH
        calls[1] = IdentitySmartAccount.Call({
            target: target2Addr,
            value: 0.2 ether,
            data: abi.encodeWithSignature("ping(bytes)", hex"02")
        });

        // Call 3: ping target1 again with 0.3 ETH
        calls[2] = IdentitySmartAccount.Call({
            target: target1Addr,
            value: 0.3 ether,
            data: abi.encodeWithSignature("ping(bytes)", hex"03")
        });

        // Act: Execute batch as EntryPoint
        vm.prank(epAddr);
        identity.executeBatch(calls);

        // Assert: All calls should have succeeded
        assertEq(target1.x(), 0.4 ether, "Target1 should have 0.4 ETH");
        assertEq(target2.x(), 0.2 ether, "Target2 should have 0.2 ETH");
        assertEq(target1.callCount(), 2, "Target1 should have 2 calls");
        assertEq(target2.callCount(), 1, "Target2 should have 1 call");

        console2.log("Batch executed successfully with 3 calls");
    }

    // ========================================
    // Test: Batch Revert on Single Failure
    // ========================================

    /**
     * @notice Test that executeBatch reverts entirely if one call fails (atomicity)
     */
    function test_executeBatch_reverts_on_single_failure() public {
        // Arrange: Create batch where middle call will fail
        IdentitySmartAccount.Call[]
            memory calls = new IdentitySmartAccount.Call[](3);

        calls[0] = IdentitySmartAccount.Call({
            target: target1Addr,
            value: 0.1 ether,
            data: abi.encodeWithSignature("ping(bytes)", hex"be")
        });

        // This call will revert
        calls[1] = IdentitySmartAccount.Call({
            target: target1Addr,
            value: 0,
            data: abi.encodeWithSignature("revertingFunction()")
        });

        calls[2] = IdentitySmartAccount.Call({
            target: target2Addr,
            value: 0.2 ether,
            data: abi.encodeWithSignature("ping(bytes)", hex"af")
        });

        // Act & Assert: Should revert entirely
        vm.prank(epAddr);
        vm.expectRevert(); // Expecting any revert
        identity.executeBatch(calls);

        // Verify no state changes occurred
        assertEq(
            target1.x(),
            0,
            "Target1 should have no value (atomic revert)"
        );
        assertEq(
            target2.x(),
            0,
            "Target2 should have no value (atomic revert)"
        );
        assertEq(target1.callCount(), 0, "Target1 should have no calls");

        console2.log("Batch correctly reverted on failure");
    }

    // ========================================
    // Test: Empty Batch Execution
    // ========================================

    /**
     * @notice Test that empty batch executes without error
     */
    function test_executeBatch_empty_batch() public {
        // Arrange: Empty call array
        IdentitySmartAccount.Call[]
            memory calls = new IdentitySmartAccount.Call[](0);

        // Act: Should not revert
        vm.prank(epAddr);
        identity.executeBatch(calls);

        console2.log("Empty batch executed successfully");
    }

    // ========================================
    // Test: Batch with Value Transfers
    // ========================================

    /**
     * @notice Test batch execution with various ETH value transfers
     */
    function test_executeBatch_value_transfers() public {
        // Arrange
        IdentitySmartAccount.Call[]
            memory calls = new IdentitySmartAccount.Call[](2);

        uint256 target1BalanceBefore = target1Addr.balance;
        uint256 target2BalanceBefore = target2Addr.balance;

        calls[0] = IdentitySmartAccount.Call({
            target: target1Addr,
            value: 1 ether,
            data: abi.encodeWithSignature("ping(bytes)", "")
        });

        calls[1] = IdentitySmartAccount.Call({
            target: target2Addr,
            value: 2 ether,
            data: abi.encodeWithSignature("ping(bytes)", "")
        });

        // Act
        vm.prank(epAddr);
        identity.executeBatch(calls);

        // Assert
        assertEq(
            target1Addr.balance,
            target1BalanceBefore + 1 ether,
            "Target1 balance should increase by 1 ETH"
        );
        assertEq(
            target2Addr.balance,
            target2BalanceBefore + 2 ether,
            "Target2 balance should increase by 2 ETH"
        );

        console2.log("Value transfers in batch succeeded");
    }

    // ========================================
    // Test: Only EntryPoint Can Call Batch
    // ========================================

    /**
     * @notice Test that only EntryPoint or authorized callers can execute batch
     */
    function test_executeBatch_only_authorized_callers() public {
        // Arrange
        IdentitySmartAccount.Call[]
            memory calls = new IdentitySmartAccount.Call[](1);
        calls[0] = IdentitySmartAccount.Call({
            target: target1Addr,
            value: 0,
            data: abi.encodeWithSignature("ping(bytes)", "")
        });

        // Act & Assert: Random caller should fail
        address randomCaller = vm.addr(0xBABE);
        vm.prank(randomCaller);
        vm.expectRevert();
        identity.executeBatch(calls);

        // EntryPoint should succeed
        vm.prank(epAddr);
        identity.executeBatch(calls);
        assertEq(target1.callCount(), 1, "EntryPoint call should succeed");

        console2.log("Only authorized callers can execute batch");
    }

    // ========================================
    // Test: Management Key Can Execute Batch
    // ========================================

    /**
     * @notice Test that management key can also execute batch operations
     */
    function test_executeBatch_management_key_allowed() public {
        // Arrange
        IdentitySmartAccount.Call[]
            memory calls = new IdentitySmartAccount.Call[](1);
        calls[0] = IdentitySmartAccount.Call({
            target: target1Addr,
            value: 0.5 ether,
            data: abi.encodeWithSignature("ping(bytes)", hex"0a")
        });

        // Act: Management key should be able to call
        vm.prank(mgmt);
        identity.executeBatch(calls);

        // Assert
        assertEq(target1.x(), 0.5 ether, "Management key batch should succeed");

        console2.log("Management key can execute batch");
    }

    // ========================================
    // Test: Batch with Dependent Calls
    // ========================================

    /**
     * @notice Test batch execution with dependent calls (call 2 depends on call 1)
     */
    function test_executeBatch_dependent_calls() public {
        // Arrange: Set value in target1, then read it
        IdentitySmartAccount.Call[]
            memory calls = new IdentitySmartAccount.Call[](2);

        // Call 1: Set value
        calls[0] = IdentitySmartAccount.Call({
            target: target1Addr,
            value: 5 ether,
            data: abi.encodeWithSignature("ping(bytes)", hex"05")
        });

        // Call 2: Verify value was set (getData returns (x, callCount))
        calls[1] = IdentitySmartAccount.Call({
            target: target1Addr,
            value: 0,
            data: abi.encodeWithSignature("getData()")
        });

        // Act
        vm.prank(epAddr);
        identity.executeBatch(calls);

        // Assert: Second call should see the state from first call
        assertEq(
            target1.x(),
            5 ether,
            "Dependent call should see updated state"
        );

        console2.log("Dependent calls executed in order");
    }

    // ========================================
    // Test: Single Call Batch Revert Handling
    // ========================================

    /**
     * @notice Test that single-call batches revert with original error
     */
    function test_executeBatch_single_call_revert() public {
        // Arrange: Single call that will fail
        IdentitySmartAccount.Call[]
            memory calls = new IdentitySmartAccount.Call[](1);
        calls[0] = IdentitySmartAccount.Call({
            target: target1Addr,
            value: 0,
            data: abi.encodeWithSignature("revertingFunction()")
        });

        // Act & Assert: Should revert with original error message
        vm.prank(epAddr);
        vm.expectRevert("Target: intentional revert");
        identity.executeBatch(calls);

        console2.log("Single call batch reverts with original error");
    }

    // ========================================
    // Test: Large Batch Execution
    // ========================================

    /**
     * @notice Test batch with many calls (gas limits)
     */
    function test_executeBatch_large_batch() public {
        // Arrange: Create batch with 10 calls
        IdentitySmartAccount.Call[]
            memory calls = new IdentitySmartAccount.Call[](10);

        for (uint256 i = 0; i < 10; i++) {
            calls[i] = IdentitySmartAccount.Call({
                target: target1Addr,
                value: 0.01 ether,
                data: abi.encodeWithSignature(
                    "ping(bytes)",
                    abi.encodePacked("call", i)
                )
            });
        }

        // Act
        vm.prank(epAddr);
        identity.executeBatch(calls);

        // Assert
        assertEq(target1.x(), 0.1 ether, "Should accumulate all values");
        assertEq(target1.callCount(), 10, "Should have 10 calls");

        console2.log("Large batch (10 calls) executed successfully");
    }
}
