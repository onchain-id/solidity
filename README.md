![InvestorID Smart Contracts](./investorid_logo-small.png)

# InvestorID Smart Contracts

Smart Contracts for secured Blockchain Identities, implementation of the ERC734 and ERC735 proposal standards.

Learn more about InvestorID and Blockchain Identities on the official InvestorID website: [https://investorid.org](https://investorid.org). 

## Usage

- Install contracts package to use in your repository `npm i @investorid/solidity`
- Require desired contracts in-code:
  ```javascript
  const { contracts: { ERC734 } } = require('@investorid/solidity');
  ```
- Access contract ABI `ERC734.abi` and ByteCode `ERC734.bytecode`.

