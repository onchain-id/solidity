import {ethers} from "hardhat";

async function main() {
  const [identityOwner] = await ethers.getSigners();

  const Identity = await ethers.getContractFactory("Identity");
  const identity = await Identity.connect(identityOwner).deploy(identityOwner.address, false);

  console.log(`Deploying identity for ${identityOwner.address} at ${identity.address} ...`);

  await identity.deployed();

  console.log(`Deployed identity for ${identityOwner.address} at ${identity.address} !`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
