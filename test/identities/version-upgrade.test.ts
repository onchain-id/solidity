import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { deployIdentityFixture } from "../fixtures";
import { createClaim } from "../utils/claimUtils";

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

      // Create a self-issued claim using the utility function
      const claim = await createClaim(
        await aliceIdentity.getAddress(),
        await aliceIdentity.getAddress(), // self-issued
        BigInt(claimTopic), // Convert string to BigInt for topic
        1, // ECDSA scheme
        ethers.hexlify(claimData),
        claimUri,
        aliceWallet
      );

      // Add the claim to show the contract is still functional
      await identityAsManager.addClaim(
        claim.topic,
        claim.scheme,
        claim.issuer,
        claim.signature,
        claim.data,
        claim.uri,
      );

      // Verify the claim was added
      const retrievedClaim = await aliceIdentity.getClaim(claim.id);
      expect(retrievedClaim.topic).to.equal(claimTopic);
      expect(retrievedClaim.data).to.equal(ethers.hexlify(claimData));
      expect(retrievedClaim.uri).to.equal(claimUri);
    });
  });
});
