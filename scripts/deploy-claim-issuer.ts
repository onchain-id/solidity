import {ethers} from "hardhat";

async function main() {
  const [claimIssuerOwner] = await ethers.getSigners();

  const claimIssuer = await ethers.deployContract("ClaimIssuer", [claimIssuerOwner.address]);

  console.log(`Deploying Claim Issuer at ${claimIssuer.address} ...`);

  await claimIssuer.deployed();

  console.log(`Deployed Claim Issuer ${claimIssuer.address} !`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
