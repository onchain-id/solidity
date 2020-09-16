# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
