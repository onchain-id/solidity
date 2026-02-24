import { ethers } from "hardhat";
import { createClaim } from "./utils/claimUtils";

export enum KeyPurposes {
  MANAGEMENT = 1,
  ACTION = 2,
  CLAIM_SIGNER = 3,
  ENCRYPTION = 4,
}

export enum KeyTypes {
  ECDSA = 1,
  RSA = 2,
}

// Helper function to deploy Identity with proxy
export async function deployIdentityWithProxy(initialManagementKey: string) {
  const Identity = await ethers.getContractFactory("Identity");
  const identityImplementation = await Identity.deploy(
    initialManagementKey,
    false, // Deploy as regular contract (implementation)
  );

  // Deploy proxy using the old IdentityProxy pattern (required for IdFactory compatibility)
  const IdentityProxy = await ethers.getContractFactory("IdentityProxy");

  // Deploy ImplementationAuthority for this Identity
  const ImplementationAuthority = await ethers.getContractFactory(
    "ImplementationAuthority",
  );
  const identityImplementationAuthority = await ImplementationAuthority.deploy(
    await identityImplementation.getAddress(),
  );

  const identityProxy = await IdentityProxy.deploy(
    await identityImplementationAuthority.getAddress(),
    initialManagementKey,
  );

  // Return the proxy contract with Identity interface
  return ethers.getContractAt("Identity", await identityProxy.getAddress());
}

// Helper function to deploy ClaimIssuer with proxy
export async function deployClaimIssuerWithProxy(initialManagementKey: string) {
  const ClaimIssuer = await ethers.getContractFactory("ClaimIssuer");

  // Deploy the implementation normally - this will set up the management keys
  const claimIssuerImplementation =
    await ClaimIssuer.deploy(initialManagementKey);

  // Deploy proxy using our modern ERC1967Proxy pattern for ClaimIssuer
  const ERC1967Proxy = await ethers.getContractFactory("ERC1967Proxy");
  const claimIssuerProxy = await ERC1967Proxy.deploy(
    await claimIssuerImplementation.getAddress(),
    claimIssuerImplementation.interface.encodeFunctionData("initialize", [
      initialManagementKey,
    ]),
  );

  // Return the proxy contract with ClaimIssuer interface
  return ethers.getContractAt(
    "ClaimIssuer",
    await claimIssuerProxy.getAddress(),
  );
}

export async function deployFactoryFixture() {
  const [
    deployerWallet,
    claimIssuerWallet,
    aliceWallet,
    bobWallet,
    carolWallet,
    davidWallet,
  ] = await ethers.getSigners();

  // Deploy Identity implementation (needed for ImplementationAuthority)
  const Identity = await ethers.getContractFactory("Identity");
  const identityImplementation = await Identity.connect(deployerWallet).deploy(
    deployerWallet.address,
    false, // Deploy as regular contract (implementation)
  );

  const ImplementationAuthority = await ethers.getContractFactory(
    "ImplementationAuthority",
  );
  const implementationAuthority = await ImplementationAuthority.connect(
    deployerWallet,
  ).deploy(await identityImplementation.getAddress());

  const IdentityFactory = await ethers.getContractFactory("IdFactory");
  const identityFactory = await IdentityFactory.connect(deployerWallet).deploy(
    await implementationAuthority.getAddress(),
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
  const [
    deployerWallet,
    claimIssuerWallet,
    aliceWallet,
    bobWallet,
    carolWallet,
    davidWallet,
    tokenOwnerWallet,
  ] = await ethers.getSigners();

  const { identityFactory, identityImplementation, implementationAuthority } =
    await deployFactoryFixture();

  // Deploy ClaimIssuer using proxy pattern
  const claimIssuer = await deployClaimIssuerWithProxy(
    claimIssuerWallet.address,
  );

  // Set up the ClaimIssuer with proper keys
  await claimIssuer
    .connect(claimIssuerWallet)
    .addKey(
      ethers.keccak256(
        ethers.AbiCoder.defaultAbiCoder().encode(
          ["address"],
          [claimIssuerWallet.address],
        ),
      ),
      KeyPurposes.CLAIM_SIGNER,
      KeyTypes.ECDSA,
    );

  await identityFactory
    .connect(deployerWallet)
    .createIdentity(aliceWallet.address, "alice");
  const aliceIdentity = await ethers.getContractAt(
    "Identity",
    await identityFactory.getIdentity(aliceWallet.address),
  );
  await aliceIdentity
    .connect(aliceWallet)
    .addKey(
      ethers.keccak256(
        ethers.AbiCoder.defaultAbiCoder().encode(
          ["address"],
          [carolWallet.address],
        ),
      ),
      KeyPurposes.CLAIM_SIGNER,
      KeyTypes.ECDSA,
    );
  await aliceIdentity
    .connect(aliceWallet)
    .addKey(
      ethers.keccak256(
        ethers.AbiCoder.defaultAbiCoder().encode(
          ["address"],
          [davidWallet.address],
        ),
      ),
      KeyPurposes.ACTION,
      KeyTypes.ECDSA,
    );
  const aliceClaim666 = {
    id: "",
    identity: await aliceIdentity.getAddress(),
    issuer: await claimIssuer.getAddress(),
    topic: 666,
    scheme: 1,
    data: "0x0042",
    signature: "",
    uri: "https://example.com",
  };
  aliceClaim666.id = ethers.keccak256(
    ethers.AbiCoder.defaultAbiCoder().encode(
      ["address", "uint256"],
      [aliceClaim666.issuer, aliceClaim666.topic],
    ),
  );
  aliceClaim666.signature = await claimIssuerWallet.signMessage(
    ethers.getBytes(
      ethers.keccak256(
        ethers.AbiCoder.defaultAbiCoder().encode(
          ["address", "uint256", "bytes"],
          [aliceClaim666.identity, aliceClaim666.topic, aliceClaim666.data],
        ),
      ),
    ),
  );

  await aliceIdentity
    .connect(aliceWallet)
    .addClaim(
      aliceClaim666.topic,
      aliceClaim666.scheme,
      aliceClaim666.issuer,
      aliceClaim666.signature,
      aliceClaim666.data,
      aliceClaim666.uri,
    );

  await identityFactory
    .connect(deployerWallet)
    .createIdentity(bobWallet.address, "bob");
  const bobIdentity = await ethers.getContractAt(
    "Identity",
    await identityFactory.getIdentity(bobWallet.address),
  );

  const tokenAddress = "0xdEE019486810C7C620f6098EEcacA0244b0fa3fB";
  await identityFactory
    .connect(deployerWallet)
    .createTokenIdentity(tokenAddress, tokenOwnerWallet.address, "tokenOwner");

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
    tokenAddress,
  };
}

export async function deployVerifierFixture() {}

export async function deployIdentityWithProxyFixture() {
  const [
    deployerWallet,
    claimIssuerWallet,
    aliceWallet,
    bobWallet,
    carolWallet,
    davidWallet,
    tokenOwnerWallet,
  ] = await ethers.getSigners();

  const { identityFactory, identityImplementation, implementationAuthority } =
    await deployFactoryFixture();

  // Deploy ClaimIssuer using our proxy pattern
  const claimIssuer = await deployClaimIssuerWithProxy(
    claimIssuerWallet.address,
  );

  // Deploy Alice's Identity using our new proxy pattern
  const aliceIdentity = await deployIdentityWithProxy(aliceWallet.address);

  // Deploy Bob's Identity using our new proxy pattern
  const bobIdentity = await deployIdentityWithProxy(bobWallet.address);

  // Set up additional keys for aliceIdentity
  await aliceIdentity
    .connect(aliceWallet)
    .addKey(
      ethers.keccak256(
        ethers.AbiCoder.defaultAbiCoder().encode(
          ["address"],
          [carolWallet.address],
        ),
      ),
      KeyPurposes.CLAIM_SIGNER,
      KeyTypes.ECDSA,
    );
  await aliceIdentity
    .connect(aliceWallet)
    .addKey(
      ethers.keccak256(
        ethers.AbiCoder.defaultAbiCoder().encode(
          ["address"],
          [davidWallet.address],
        ),
      ),
      KeyPurposes.ACTION,
      KeyTypes.ECDSA,
    );

  const aliceClaim666 = await createClaim(
    await aliceIdentity.getAddress(),
    await claimIssuer.getAddress(),
    666,
    1,
    "0x0042",
    "https://example.com",
    claimIssuerWallet
  );

  await aliceIdentity
    .connect(aliceWallet)
    .addClaim(
      aliceClaim666.topic,
      aliceClaim666.scheme,
      aliceClaim666.issuer,
      aliceClaim666.signature,
      aliceClaim666.data,
      aliceClaim666.uri,
    );

  const tokenAddress = "0xdEE019486810C7C620f6098EEcacA0244b0fa3fB";
  await identityFactory
    .connect(deployerWallet)
    .createTokenIdentity(tokenAddress, tokenOwnerWallet.address, "tokenOwner");

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
    tokenAddress,
  };
}
