import "@nomicfoundation/hardhat-toolbox";
import { HardhatUserConfig } from "hardhat/config";
import 'solidity-coverage';
import "@nomiclabs/hardhat-solhint";

const config: HardhatUserConfig = {
  solidity: "0.8.17",
};

export default config;
