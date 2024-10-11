import "@nomicfoundation/hardhat-toolbox";
import { HardhatUserConfig } from "hardhat/config";
import 'solidity-coverage';
import "@nomiclabs/hardhat-solhint";

import "./tasks/add-claim.task";
import "./tasks/add-key.task";
import "./tasks/deploy-identity.task";
import "./tasks/deploy-proxy.task";
import "./tasks/remove-claim.task";
import "./tasks/remove-key.task";
import "./tasks/revoke.task";

const config: HardhatUserConfig = {
  solidity: "0.8.27",
  networks: {
    amoy: {
      url: 'https://rpc-amoy.polygon.technology', // chain RPC endpoint, eg. https://rpc-amoy.polygon.technology.
      accounts: [
        '0x429c8391aad3ba93b8670e1a2f4198e03af2811f5cb9a72b03bad5f96dabf2d8'
      ]
    }
  },
  etherscan: {
    apiKey: {
      amoy: "MY_KEY"
    },
    customChains: [
      {
        network: "amoy",
        chainId: 80002,
        urls: {
          apiURL: "https://api-testnet.polygonscan.com/api",
          browserURL: "https://amoy.polygonscan.com"
        }
      }
    ]
  }
};

export default config;
