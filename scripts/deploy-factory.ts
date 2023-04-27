import {ethers} from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();

  const identityImplementation = await ethers.deployContract("Identity", [deployer.address, true]);
  console.log(`Deploying identity implementation at ${identityImplementation.address} ... (tx hash: ${identityImplementation.deployTransaction.hash} )`);
  await identityImplementation.deployed();
  console.log(`Deployed identity implementation at ${identityImplementation.address} (tx hash: ${identityImplementation.deployTransaction.hash} )`);

  const implementationAuthority = await ethers.deployContract("ImplementationAuthority", [identityImplementation.address]);
  console.log(`Deploying implementation authority at ${implementationAuthority.address} ... (tx hash: ${implementationAuthority.deployTransaction.hash} )`);
  await implementationAuthority.deployed();
  console.log(`Deployed implementation authority at ${implementationAuthority.address} (tx hash: ${implementationAuthority.deployTransaction.hash} )`);

  const factory = await ethers.deployContract("IdFactory", [implementationAuthority.address]);
  console.log(`Deploying factory at ${factory.address} ... (tx hash: ${factory.deployTransaction.hash} )`);
  await factory.deployed();
  console.log(`Deployed factory at ${factory.address} (tx hash: ${factory.deployTransaction.hash} )`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
