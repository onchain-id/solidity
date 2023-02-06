import { ethers } from 'hardhat';

export async function deployIdentityFixture() {
  const [deployerWallet, claimIssuerWallet, aliceWallet, bobWallet, carolWallet] =
    await ethers.getSigners();

  const Identity = await ethers.getContractFactory('Identity');
  const identityImplementation = await Identity.connect(deployerWallet).deploy(deployerWallet.address, true);

  const ImplementationAuthority = await ethers.getContractFactory(
    'ImplementationAuthority'
  );
  const implementationAuthority = await ImplementationAuthority.connect(deployerWallet).deploy(
    identityImplementation.address,
    );

  const IdentityFactory = await ethers.getContractFactory('IdFactory');
  const identityFactory = await IdentityFactory.connect(deployerWallet).deploy(
    implementationAuthority.address,
  );

  const ClaimIssuer = await ethers.getContractFactory('ClaimIssuer');
  const claimIssuer = await ClaimIssuer.connect(claimIssuerWallet).deploy(identityFactory.address);

  await identityFactory.connect(aliceWallet).createIdentity(aliceWallet.address, 'alice');
  const aliceIdentity = await ethers.getContractAt('Identity', await identityFactory.getIdentity(aliceWallet.address));
  await aliceIdentity.connect(aliceWallet).addKey(ethers.utils.keccak256(
    ethers.utils.defaultAbiCoder.encode(['address'], [carolWallet.address])
  ), 3, 1);

  await identityFactory.connect(bobWallet).createIdentity(bobWallet.address, 'bob');
  const bobIdentity = await ethers.getContractAt('Identity', await identityFactory.getIdentity(bobWallet.address));

  return {
    identityFactory,
    claimIssuer,
    aliceWallet,
    bobWallet,
    carolWallet,
    deployerWallet,
    claimIssuerWallet,
    aliceIdentity,
    bobIdentity,
  };
}
