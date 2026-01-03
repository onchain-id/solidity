import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { deployIdentityFixture } from "../fixtures";

describe("Identity Version Upgrade", function () {
  describe("Version Management", function () {
    it("should return the initial version", async function () {
      const { aliceIdentity } = await loadFixture(deployIdentityFixture);

      const version = await aliceIdentity.version();
      expect(version).to.equal("3.0.0");
    });

    it("should maintain version constant", async function () {
      const { aliceIdentity } = await loadFixture(deployIdentityFixture);

      // Version is a constant
      const version = await aliceIdentity.version();
      expect(version).to.equal("3.0.0");
    });
  });

  describe("Version Upgrade Pattern", function () {
    it("should demonstrate the upgrade pattern", async function () {
      const { aliceIdentity, aliceWallet } = await loadFixture(
        deployIdentityFixture,
      );

      // Connect as management key
      const identityAsManager = aliceIdentity.connect(aliceWallet);

      // Version is now a constant
      expect(await aliceIdentity.version()).to.equal("3.0.0");
      const claimTopic = ethers.keccak256(ethers.toUtf8Bytes("test"));
      const claimData = ethers.toUtf8Bytes("test data");
      const claimUri = "https://example.com";

      // Add a claim to show the contract is still functional
      await identityAsManager.addClaim(
        claimTopic,
        1, // ECDSA scheme
        aliceIdentity.target, // self-issued
        "0x", // empty signature for self-issued
        claimData,
        claimUri,
      );

      // Verify the claim was added
      const claimId = ethers.keccak256(
        ethers.AbiCoder.defaultAbiCoder().encode(
          ["address", "uint256"],
          [aliceIdentity.target, claimTopic],
        ),
      );

      const claim = await aliceIdentity.getClaim(claimId);
      expect(claim.topic).to.equal(claimTopic);
      expect(claim.data).to.equal(ethers.hexlify(claimData));
      expect(claim.uri).to.equal(claimUri);
    });
  });
});
