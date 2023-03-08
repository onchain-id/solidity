![OnchainID Smart Contracts](./onchainid_logo_small.png)

# OnchainID Smart Contracts

Smart Contracts for secure Blockchain Identities, implementation of the ERC734 and ERC735 proposal standards.

Learn more about OnchainID and Blockchain Identities on the official OnchainID website: [https://onchainid.com](https://onchainid.com).

## Usage

- Install contracts package to use in your repository `yarn add @onchain-id/solidity`
- Require desired contracts in-code (should you need to deploy them):
  ```javascript
  const { contracts: { ERC734, Identity } } = require('@onchain-id/solidity');
  ```
- Require desired interfaces in-code (should you need to interact with deployed contracts):
  ```javascript
  const { interfaces: { IERC734, IERC735 } } = require('@onchain-id/solidity');
  ```
- Access contract ABI `ERC734.abi` and ByteCode `ERC734.bytecode`.

## Development

- Install dev dependencies `npm install`
- Update interfaces and contracts code.
- Run lint `npm run lint`
- Compile code `npm run compile`

### Testing

- Run `npm install`
- Run `npm test`
  - Test will be executed against a local Hardhat network.
