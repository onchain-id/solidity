import {task} from "hardhat/config";
import {TaskArguments} from "hardhat/types";

task("deploy-proxy", "Deploy an identity as a proxy using a factory")
  .addParam("from", "Will pay the gas for the transaction")
  .addParam("factory", "The address of the identity factory")
  .addParam("key", "The ethereum address that will own the identity (as a MANAGEMENT key)")
  .addOptionalParam("salt", "A salt to use when creating the identity")
  .setAction(async (args: TaskArguments, hre) => {
    const signer = await hre.ethers.getSigner(args.from);

    const factory = await hre.ethers.getContractAt('IdFactory', args.factory, signer);
    const tx = await factory.createIdentity(args.key, args.salt ?? args.key);

    console.log(`Deploy a new identity as a proxy using factory ${factory.address} . tx: ${tx.hash}`);

    await tx.wait();

    const identityAddress = await factory.getIdentity(args.key);

    console.log(`Deployed a new identity at ${identityAddress} as a proxy using factory ${factory.address} . tx: ${tx.hash}`);
  });
