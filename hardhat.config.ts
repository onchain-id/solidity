import "@nomicfoundation/hardhat-toolbox";
import { HardhatUserConfig } from "hardhat/config";
import 'solidity-coverage';
import "@nomiclabs/hardhat-solhint";
import "hardhat-tracer";

import "./tasks/add-claim.task";
import "./tasks/add-key.task";
import "./tasks/deploy-identity.task";
import "./tasks/deploy-proxy.task";
import "./tasks/remove-claim.task";
import "./tasks/remove-key.task";
import "./tasks/revoke.task";

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.27",
  },
  gasReporter: {
    enabled: true,    
  }
};

export default config;
