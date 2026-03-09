## ![OnchainID Smart Contracts](./onchainid_logo_final.png)

![GitHub](https://img.shields.io/github/license/onchain-id/solidity?color=green)
![GitHub release (latest by date)](https://img.shields.io/github/v/release/onchain-id/solidity)
![GitHub Workflow Status (branch)](https://img.shields.io/github/actions/workflow/status/onchain-id/solidity/publish-release.yml)
![GitHub repo size](https://img.shields.io/github/repo-size/onchain-id/solidity)
![GitHub Release Date](https://img.shields.io/github/release-date/onchain-id/solidity)

---

# OnchainID Smart Contracts

Smart Contracts for secure Blockchain Identities, implementation of the ERC734 and ERC735 proposal standards.

Learn more about OnchainID and Blockchain Identities on the official OnchainID website: [https://onchainid.com](https://onchainid.com).

## Usage

- Install contracts package to use in your repository `yarn add @onchain-id/solidity`
- Require desired contracts in-code (should you need to deploy them):
  ```javascript
  const {
    contracts: { ERC734, Identity },
  } = require("@onchain-id/solidity");
  ```
- Require desired interfaces in-code (should you need to interact with deployed contracts):
  ```javascript
  const {
    interfaces: { IERC734, IERC735 },
  } = require("@onchain-id/solidity");
  ```
- Access contract ABI `ERC734.abi` and ByteCode `ERC734.bytecode`.

## Development

- Install dev dependencies `npm ci`
- Update interfaces and contracts code.
- Run lint `npm run lint`
- Compile code `npm run compile`

### Testing

- Run `npm ci`
- Run `npm test`
  - Test will be executed against a local Hardhat network.

---

<div style="padding: 16px;">
   <a href="https://tokeny.com/wp-content/uploads/2023/04/Tokeny_ONCHAINID_SC-Audit_Report.pdf" target="_blank">
       <img src="https://hacken.io/wp-content/uploads/2023/02/ColorWBTypeSmartContractAuditBackFilled.png" alt="Proofed by Hacken - Smart contract audit" style="width: 258px; height: 100px;">
   </a>
</div>
