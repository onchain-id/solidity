import {task} from "hardhat/config";
import {TaskArguments} from "hardhat/types";

task("deploy-identity", "Deploy an identity as a standalone contract")
  .addParam("from", "Will pay the gas for the transaction")
  .addParam("key", "The ethereum address that will own the identity (as a MANAGEMENT key)")
  .setAction(async (args: TaskArguments, hre) => {
    const signer = await hre.ethers.getSigner(args.from);

    const identity = await hre.ethers.deployContract('Identity', [args.key, false], signer);

    console.log(`Deploy a new identity at ${identity.address} . tx: ${identity.deployTransaction.hash}`);

    await identity.deployed();

    console.log(`Deployed a new identity at ${identity.address} . tx: ${identity.deployTransaction.hash}`);
  });
