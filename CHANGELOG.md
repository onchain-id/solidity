# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
