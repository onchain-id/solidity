import {ethers} from "hardhat";

async function main() {
  const [claimIssuerOwner] = await ethers.getSigners();

  const claimIssuer = await ethers.deployContract("ClaimIssuer", [claimIssuerOwner.address]);

  console.log(`Deploying Claim Issuer at ${await claimIssuer.getAddress()} ...`);

  await claimIssuer.waitForDeployment();

  console.log(`Deployed Claim Issuer ${await claimIssuer.getAddress()} !`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
