# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.1.0]

### Added
- Implemented a new contract `Gateway` to interact with the `IdFactory`. The `Gateway` contract allows individual
accounts (being EOA or contracts) to deploy identities for their own address as a salt. To deploy using
a custom salt, a signature from an approved signer is required.
- Implemented a new base contract `Verifier` to be extended by contract requiring identity verification based on claims
and trusted issuers.

## [2.0.1]

### Added
- added method createIdentityWithManagementKeys() that allows the factory to issue identities with multiple
  management keys.
- tests for the createIdentityWithManagementKeys() method

## [2.0.0]

Version 2.0.0 Audited by Hacken, more details [here](https://tokeny.com/wp-content/uploads/2023/04/Tokeny_ONCHAINID_SC-Audit_Report.pdf)

### Breaking changes

## Deprecation Notice
- ClaimIssuer `revokeClaim` is now deprecated, usage of `revokeClaimBySignature(bytes signature)` is preferred.

### Added
- Add typechain-types (targeting ethers v5).
- Add tests cases for `execute` and `approve` methods.
- Add method `revokeClaimBySignature(bytes signature)` in ClaimIssuer, prefer using this method instead of the now
deprecated `revokeClaim` method.
- Add checks on ClaimIssuer to prevent revoking an already revoked claim.
- Added Factory for ONCHAINIDs

### Updated
- Switch development tooling to hardhat.
- Implemented tests for hardhat (using fixture for faster testing time).
- Prevent calling `approve` method with a non-request execute nonce (added a require on `executionNone`).
- Update NatSpec of `execute` and `approve` methods.

## [1.4.0] - 2021-01-26
### Updated
- Remove constructor's visibility

## [1.3.0] - 2021-01-21
### Added
- Ownable 0.8.0
- Context 0.8.0
### Updated
- Update version to 1.3.0
- Update contracts to SOL =0.8.0
- Update test to work with truffle
- Update truffle-config.js
- Update solhint config

## [1.2.0] - 2020-11-27
### Added
- Custom Upgradable Proxy contract that behaves similarly to the [EIP-1822](https://eips.ethereum.org/EIPS/eip-1822): Universal Upgradeable Proxy Standard (UUPS), except that it points to an Authority contract which in itself points to an implementation (which can be updated).
- New ImplementationAuthority contract that acts as an authority for proxy contracts
- Library Lock contract to ensure no one can manipulate the Logic Contract once it is deployed
- Version contract that gives the versioning information of the implementation contract
### Moved
- variables in a separate contract (Storage.sol)
- structs in a separate contract (Structs.sol)
### Updated
- Update contracts to SOL =0.6.9

## [1.1.2] - 2020-09-30
### Fixed
- Add Constructor on ClaimIssuer Contract

## [1.1.1] - 2020-09-22
### Fixed
- Fix CI

## [1.1.0] - 2020-09-16
### Added
- ONCHAINID contract uses Proxy based on [EIP-1167](https://eips.ethereum.org/EIPS/eip-1167).
- New contracts,CloneFactory and IdentityFactory
- Github workflows actions
- Build script
- Lint rules for both Solidity and JS
- Ganache-Cli
- Rules for eslint (eslintrc)
- Rules for solhint
- new Tests for Proxy behavior

### Changed
- Replaced Constructor by "Set" function on ERC734
- "Set" function is callable only once on ERC734
- Replaced Yarn by Npm
- Replaced coverage script by coverage plugin
- old Tests for compatibility with new proxy
