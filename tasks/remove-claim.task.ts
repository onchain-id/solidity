import {task} from "hardhat/config";
import {TaskArguments} from "hardhat/types";

task("remove-claim", "Remove a cliam from an identity")
  .addParam("identity", "The address of the identity")
  .addParam("from", "A CLAIM key on the claim issuer")
  .addParam("claim", "The claim ID")
  .setAction(async (args: TaskArguments, hre) => {
    const signer = await hre.ethers.getSigner(args.from);

    const identity = await hre.ethers.getContractAt('Identity', args.identity, signer);

    const tx = await identity.removeClaim(args.claim);

    console.log(`Remove claim ${args.claim} from identity ${args.identity} tx: ${tx.hash}`);

    await tx.wait();

    console.log(`Remove claim ${args.claim} from identity ${args.identity} tx mined: ${tx.hash}`);
  });
