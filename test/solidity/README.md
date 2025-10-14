# OnchainID ERC-4337 Solidity Test Suite

This directory contains comprehensive Solidity tests for the OnchainID ERC-4337 Account Abstraction implementation.

## Overview

The test suite validates all critical AA functionality including:

- UserOperation validation and execution
- Signature verification with ERC4337_SIGNER and MANAGEMENT keys
- Prefund handling and gas payment
- EntryPoint bypass in execute()
- Nonce separation between AA and ERC-734
- Batch execution with atomic rollback
- Access control and permissions

## Test Files

### `IdentityAA.t.sol`

Core AA functionality tests covering:

- ✅ `validateUserOp` returns 0 on success, 1 on failure (no revert)
- ✅ Prefund transfer to EntryPoint
- ✅ EntryPoint bypass in `execute()`
- ✅ EOA cannot bypass approval queue
- ✅ AA nonce independence from ERC-734 executionNonce
- ✅ Signer purpose enforcement (ERC4337_SIGNER + MANAGEMENT)
- ✅ Invalid nonce rejection
- ✅ Zero prefund handling
- ✅ EntryPoint-only access control
- ✅ Deposit management
- ✅ EntryPoint configuration

### `IdentityAA_Batch.t.sol`

Batch execution tests covering:

- ✅ Multi-call batch execution
- ✅ Atomic rollback on failure
- ✅ Empty batch handling
- ✅ Value transfers in batches
- ✅ Access control for batch operations
- ✅ Dependent call sequencing
- ✅ Error propagation
- ✅ Large batch gas limits

## Test Architecture

### Setup Pattern

Tests use the actual proxy deployment pattern:

1. Deploy EntryPoint v0.8
2. Deploy Identity implementation (library mode)
3. Deploy ImplementationAuthority
4. Deploy IdentityProxy (calls initialize)
5. Add ERC4337_SIGNER key
6. Set EntryPoint address
7. Fund identity for prefund tests

### Helper Contracts

- **UserOpBuilder**: Utility library for packing gas limits and fees
- **Target**: Mock contract for testing execute() and executeBatch()

## Running Tests

```bash
# Run all Solidity tests
npm run test:sol

# Run with gas reporting
npm run gas

# Run all tests (TypeScript + Solidity)
npm run test:all

# Generate coverage report
npm run test:coverage
```

## Test Naming Convention

Tests follow the pattern:

```
test_<functionName>_<scenario>_<expectedOutcome>
```

Examples:

- `test_validateUserOp_success_and_prefund()`
- `test_execute_bypass_when_called_by_EntryPoint()`
- `test_executeBatch_reverts_on_single_failure()`

## Key Test Insights

### EntryPoint Bypass

The `execute()` function checks `msg.sender == address(entryPoint())` to allow direct execution without the ERC-734 approval queue. This is the critical AA integration point.

### Nonce Separation

- **AA Nonces**: Managed by EntryPoint via `getNonce(address, key)`
- **ERC-734 Nonces**: Managed internally via `executionNonce`
- These are completely independent to prevent replay attacks

### Signature Validation

The `_validateSignature()` function:

1. Recovers signer from ECDSA signature
2. Validates signer has ERC4337_SIGNER OR MANAGEMENT purpose
3. Returns 0 for success, 1 for failure (never reverts)

### Batch Execution

`executeBatch()` provides atomic multi-call execution:

- All calls succeed or all revert
- Efficient for complex operations
- Supports dependent call sequences

## Coverage Goals

Target: ≥90% line coverage on:

- `IdentitySmartAccount.sol`
- `Identity.sol` (AA-related functions)

## Troubleshooting

### Import Errors

If you see "forge-std not found", ensure you've installed dependencies:

```bash
npm install
```

### Compilation Errors

Ensure Solidity version compatibility (0.8.27/0.8.28):

```bash
npm run compile
```

### Test Failures

Check that:

1. EntryPoint v0.8 is deployed correctly
2. Keys are added with correct purposes
3. Identity has sufficient ETH balance

## References

- [ERC-4337 Specification](https://eips.ethereum.org/EIPS/eip-4337)
- [EntryPoint v0.8 Contracts](https://github.com/eth-infinitism/account-abstraction)
- [ERC-734 Identity Standard](https://github.com/ethereum/EIPs/issues/734)
- [OnchainID Documentation](https://docs.onchainid.com)
