![InvestorID Smart Contracts](./investorid_logo-small.png)

# InvestorID Smart Contracts

Smart Contracts for secured Blockchain Identities, implementation of the ERC734 and ERC735 proposal standards.

Learn more about InvestorID and Blockchain Identities on the official InvestorID website: [https://investorid.org](https://investorid.org). 

## Usage

- Install contracts package to use in your repository `npm i @investorid/solidity`
- Require desired contracts in-code (should you need to deploy them):
  ```javascript
  const { contracts: { ERC734, Identity } } = require('@investorid/solidity');
  ```
- Require desired interfaces in-code (should you need to interact with deployed contracts):
  ```javascript
  const { interfaces: { IERC734, IERC735 } } = require('@investorid/solidity');
  ```
- Access contract ABI `ERC734.abi` and ByteCode `ERC734.bytecode`.

## Development

- Install dev dependencies `npm i`
- Update interfaces and contracts code.
- Run lint `npm run lint`
- Compile code `npm run compile`

### Testing

- Install [Ganache](https://www.trufflesuite.com/ganache) or run another blockchain network.
  
  > The contracts WILL NOT WORK without at least version 2 of Ganache!
  
- Run `npm test`
