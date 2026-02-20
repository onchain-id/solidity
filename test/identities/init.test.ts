import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

import {
  deployIdentityFixture,
  deployIdentityWithProxy,
  IdentityTypes,
} from "../fixtures";

describe("Identity", () => {
  it("should revert when attempting to initialize an already deployed identity", async () => {
    const { aliceIdentity, aliceWallet } = await loadFixture(
      deployIdentityFixture,
    );

    await expect(
      aliceIdentity
        .connect(aliceWallet)
        .initialize(aliceWallet.address, IdentityTypes.INDIVIDUAL),
    ).to.be.revertedWith("Initializable: contract is already initialized");
  });

  it("should prevent creating an identity with an invalid initial key", async () => {
    const [identityOwnerWallet] = await ethers.getSigners();

    const Identity = await ethers.getContractFactory("Identity");
    await expect(
      Identity.connect(identityOwnerWallet).deploy(ethers.ZeroAddress, false),
    ).to.be.revertedWithCustomError(Identity, "ZeroAddress");
  });

  it("should have version initialized when deployed as regular contract", async () => {
    const { identityImplementation } = await loadFixture(deployIdentityFixture);
    // When deployed as regular contract, version should be initialized
    expect(await identityImplementation.version()).to.equal("3.0.0");
  });

  it("should support ERC165 interface detection", async function () {
    const { aliceIdentity } = await loadFixture(deployIdentityFixture);

    // Test ERC165 interface (this is standard and should work)
    expect(await aliceIdentity.supportsInterface("0x01ffc9a7")).to.be.true;

    // Test that it doesn't support random interfaces
    expect(await aliceIdentity.supportsInterface("0x12345678")).to.be.false;
    expect(await aliceIdentity.supportsInterface("0x00000000")).to.be.false;
    expect(await aliceIdentity.supportsInterface("0xffffffff")).to.be.false;
  });

  describe("getIdentityType", () => {
    it("should return the identity type set during initialization", async () => {
      const { aliceIdentity } = await loadFixture(deployIdentityFixture);

      // Alice's identity was created via factory with type Individual
      expect(await aliceIdentity.getIdentityType()).to.equal(
        IdentityTypes.INDIVIDUAL,
      );
    });

    it("should return the correct type for each identity type", async () => {
      const [deployer] = await ethers.getSigners();

      // Deploy identities with each valid type
      for (const identityType of [
        IdentityTypes.ASSET,
        IdentityTypes.INDIVIDUAL,
        IdentityTypes.CORPORATE,
        IdentityTypes.IOT,
        IdentityTypes.CLAIM_ISSUER,
      ]) {
        const identity = await deployIdentityWithProxy(
          deployer.address,
          identityType,
        );
        expect(await identity.getIdentityType()).to.equal(identityType);
      }
    });

    it("should return type Asset for token identities", async () => {
      const { identityFactory, tokenAddress } = await loadFixture(
        deployIdentityFixture,
      );

      const tokenIdentityAddress =
        await identityFactory.getIdentity(tokenAddress);
      const tokenIdentity = await ethers.getContractAt(
        "Identity",
        tokenIdentityAddress,
      );

      expect(await tokenIdentity.getIdentityType()).to.equal(
        IdentityTypes.ASSET,
      );
    });

  });
});
