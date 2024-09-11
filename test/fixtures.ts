import { ethers } from "hardhat";

export async function deployFactoryFixture() {
  const [deployerWallet, claimIssuerWallet, aliceWallet, bobWallet, carolWallet, davidWallet] =
    await ethers.getSigners();

  const Identity = await ethers.getContractFactory('Identity');
  const identityImplementation = await Identity.connect(deployerWallet).deploy(deployerWallet, true);

  const ImplementationAuthority = await ethers.getContractFactory(
    'ImplementationAuthority'
  );
  const implementationAuthority = await ImplementationAuthority.connect(deployerWallet).deploy(
    identityImplementation,
  );

  const IdentityFactory = await ethers.getContractFactory('IdFactory');
  const identityFactory = await IdentityFactory.connect(deployerWallet).deploy(
    implementationAuthority,
  );

  return {
    identityFactory,
    identityImplementation,
    implementationAuthority,
    aliceWallet,
    bobWallet,
    carolWallet,
    davidWallet,
    deployerWallet,
    claimIssuerWallet,
  };
}

export async function deployIdentityFixture() {
  const [deployerWallet, claimIssuerWallet, aliceWallet, bobWallet, carolWallet, davidWallet, tokenOwnerWallet] =
    await ethers.getSigners();

  const { identityFactory, identityImplementation, implementationAuthority } = await deployFactoryFixture();

  const ClaimIssuer = await ethers.getContractFactory('ClaimIssuer');
  const claimIssuer = await ClaimIssuer.connect(claimIssuerWallet).deploy(claimIssuerWallet);
  await claimIssuer.connect(claimIssuerWallet).addKey(
    ethers.keccak256(
      ethers.AbiCoder.defaultAbiCoder().encode(['address'], [await claimIssuerWallet.getAddress()])
    ),
    3,
    1,
  );

  await identityFactory.connect(deployerWallet).createIdentity(aliceWallet, 'alice');
  const aliceIdentity = await ethers.getContractAt('Identity', await identityFactory.getIdentity(aliceWallet));
  await aliceIdentity.connect(aliceWallet).addKey(ethers.keccak256(
    ethers.AbiCoder.defaultAbiCoder().encode(['address'], [await carolWallet.getAddress()])
  ), 3, 1);
  await aliceIdentity.connect(aliceWallet).addKey(ethers.keccak256(
    ethers.AbiCoder.defaultAbiCoder().encode(['address'], [await davidWallet.getAddress()])
  ), 2, 1);
  const aliceClaim666 = {
    id: '',
    identity: await aliceIdentity.getAddress(),
    issuer: await claimIssuer.getAddress(),
    topic: 666,
    scheme: 1,
    data: '0x0042',
    signature: '',
    uri: 'https://example.com',
  };
  aliceClaim666.id = ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(['address', 'uint256'], [aliceClaim666.issuer, aliceClaim666.topic]));
  aliceClaim666.signature = await claimIssuerWallet.signMessage(ethers.getBytes(ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(['address', 'uint256', 'bytes'], [aliceClaim666.identity, aliceClaim666.topic, aliceClaim666.data]))));

  await aliceIdentity.connect(aliceWallet).addClaim(aliceClaim666.topic, aliceClaim666.scheme, aliceClaim666.issuer, aliceClaim666.signature, aliceClaim666.data, aliceClaim666.uri);

  await identityFactory.connect(deployerWallet).createIdentity(bobWallet, 'bob');
  const bobIdentity = await ethers.getContractAt('Identity', await identityFactory.getIdentity(bobWallet));

  const tokenAddress = '0xdEE019486810C7C620f6098EEcacA0244b0fa3fB';
  await identityFactory.connect(deployerWallet).createTokenIdentity(tokenAddress, tokenOwnerWallet, 'tokenOwner');

  return {
    identityFactory,
    identityImplementation,
    implementationAuthority,
    claimIssuer,
    aliceWallet,
    bobWallet,
    carolWallet,
    davidWallet,
    deployerWallet,
    claimIssuerWallet,
    tokenOwnerWallet,
    aliceIdentity,
    bobIdentity,
    aliceClaim666,
    tokenAddress
  };
}

export async function deployVerifierFixture() {

}
