import {task} from "hardhat/config";
import {TaskArguments} from "hardhat/types";

task("revoke", "Revoke a claim issued by a claim issuer")
  .addParam("from", "A MANAGEMENT key on the claim issuer")
  .addParam("issuer", "The address of the claim issuer")
  .addParam("signature", "The signature of the claim to revoke")
  .setAction(async (args: TaskArguments, hre) => {
    const signer = await hre.ethers.getSigner(args.from);

    const claimIssuer = await hre.ethers.getContractAt('ClaimIssuer', args.issuer, signer);

    const tx = await claimIssuer.revokeClaimBySignature(args.signature);

    console.log(`Revoke claim with signature ${args.signature} tx: ${tx.hash}`);

    await tx.wait();

    console.log(`Revoke claim with signature ${args.signature} tx mined: ${tx.hash}`);
  });
