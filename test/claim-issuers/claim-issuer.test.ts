import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { deployIdentityFixture } from "../fixtures";

describe("ClaimIssuer - Reference (with revoke)", () => {
  describe("revokeClaim (deprecated)", () => {
    describe("when calling as a non MANAGEMENT key", () => {
      it("should revert for missing permissions", async () => {
        const { claimIssuer, aliceWallet, aliceClaim666 } = await loadFixture(
          deployIdentityFixture,
        );

        await expect(
          claimIssuer
            .connect(aliceWallet)
            .revokeClaim(aliceClaim666.id, aliceClaim666.identity),
        ).to.be.revertedWithCustomError(
          claimIssuer,
          "SenderDoesNotHaveManagementKey",
        );
      });
    });

    describe("when calling as a MANAGEMENT key", () => {
      describe("when claim was already revoked", () => {
        it("should revert for conflict", async () => {
          const { claimIssuer, claimIssuerWallet, aliceClaim666 } =
            await loadFixture(deployIdentityFixture);

          await claimIssuer
            .connect(claimIssuerWallet)
            .revokeClaim(aliceClaim666.id, aliceClaim666.identity);

          await expect(
            claimIssuer
              .connect(claimIssuerWallet)
              .revokeClaim(aliceClaim666.id, aliceClaim666.identity),
          ).to.be.revertedWithCustomError(claimIssuer, "ClaimAlreadyRevoked");
        });
      });

      describe("when is not revoked already", () => {
        it("should revoke the claim", async () => {
          const { claimIssuer, claimIssuerWallet, aliceClaim666 } =
            await loadFixture(deployIdentityFixture);

          expect(
            await claimIssuer.isClaimValid(
              aliceClaim666.identity,
              aliceClaim666.topic,
              aliceClaim666.signature,
              aliceClaim666.data,
            ),
          ).to.be.true;

          const tx = await claimIssuer
            .connect(claimIssuerWallet)
            .revokeClaim(aliceClaim666.id, aliceClaim666.identity);

          await expect(tx)
            .to.emit(claimIssuer, "ClaimRevoked")
            .withArgs(aliceClaim666.signature);

          expect(await claimIssuer.isClaimRevoked(aliceClaim666.signature)).to
            .be.true;
          expect(
            await claimIssuer.isClaimValid(
              aliceClaim666.identity,
              aliceClaim666.topic,
              aliceClaim666.signature,
              aliceClaim666.data,
            ),
          ).to.be.false;
        });
      });
    });
  });

  describe("revokeClaimBySignature", () => {
    describe("when calling as a non MANAGEMENT key", () => {
      it("should revert for missing permissions", async () => {
        const { claimIssuer, aliceWallet, aliceClaim666 } = await loadFixture(
          deployIdentityFixture,
        );

        await expect(
          claimIssuer
            .connect(aliceWallet)
            .revokeClaimBySignature(aliceClaim666.signature),
        ).to.be.revertedWithCustomError(
          claimIssuer,
          "SenderDoesNotHaveManagementKey",
        );
      });
    });

    describe("when calling as a MANAGEMENT key", () => {
      describe("when claim was already revoked", () => {
        it("should revert for conflict", async () => {
          const { claimIssuer, claimIssuerWallet, aliceClaim666 } =
            await loadFixture(deployIdentityFixture);

          await claimIssuer
            .connect(claimIssuerWallet)
            .revokeClaimBySignature(aliceClaim666.signature);

          await expect(
            claimIssuer
              .connect(claimIssuerWallet)
              .revokeClaimBySignature(aliceClaim666.signature),
          ).to.be.revertedWithCustomError(claimIssuer, "ClaimAlreadyRevoked");
        });
      });

      describe("when is not revoked already", () => {
        it("should revoke the claim", async () => {
          const { claimIssuer, claimIssuerWallet, aliceClaim666 } =
            await loadFixture(deployIdentityFixture);

          expect(
            await claimIssuer.isClaimValid(
              aliceClaim666.identity,
              aliceClaim666.topic,
              aliceClaim666.signature,
              aliceClaim666.data,
            ),
          ).to.be.true;

          const tx = await claimIssuer
            .connect(claimIssuerWallet)
            .revokeClaimBySignature(aliceClaim666.signature);

          await expect(tx)
            .to.emit(claimIssuer, "ClaimRevoked")
            .withArgs(aliceClaim666.signature);

          expect(await claimIssuer.isClaimRevoked(aliceClaim666.signature)).to
            .be.true;
          expect(
            await claimIssuer.isClaimValid(
              aliceClaim666.identity,
              aliceClaim666.topic,
              aliceClaim666.signature,
              aliceClaim666.data,
            ),
          ).to.be.false;
        });
      });
    });
  });

  describe("signature validation with ECDSA", () => {
    it("should return false for invalid signature length", async () => {
      const { claimIssuer, aliceIdentity, aliceClaim666 } = await loadFixture(
        deployIdentityFixture,
      );

      // Add extra byte to make signature invalid (66 bytes instead of 65)
      const invalidSignature = aliceClaim666.signature + "00";

      const isValid = await claimIssuer.isClaimValid(
        await aliceIdentity.getAddress(),
        aliceClaim666.topic,
        invalidSignature,
        aliceClaim666.data,
      );

      expect(isValid).to.be.false;
    });

    it("should return false for malformed signature", async () => {
      const { claimIssuer, aliceIdentity, aliceClaim666 } = await loadFixture(
        deployIdentityFixture,
      );

      // Use completely invalid signature data
      const invalidSignature = "0x1234567890abcdef";

      const isValid = await claimIssuer.isClaimValid(
        await aliceIdentity.getAddress(),
        aliceClaim666.topic,
        invalidSignature,
        aliceClaim666.data,
      );

      expect(isValid).to.be.false;
    });

    it("should return false for signature with wrong signer", async () => {
      const { claimIssuer, aliceIdentity, aliceClaim666 } = await loadFixture(
        deployIdentityFixture,
      );

      // Use signature with zeroed out bytes (invalid signer)
      const invalidSignature = ethers.zeroPadValue("0x00", 65);

      const isValid = await claimIssuer.isClaimValid(
        await aliceIdentity.getAddress(),
        aliceClaim666.topic,
        invalidSignature,
        aliceClaim666.data,
      );

      expect(isValid).to.be.false;
    });

    it("should return true for valid signature from authorized signer", async () => {
      const { claimIssuer, aliceIdentity, aliceClaim666 } = await loadFixture(
        deployIdentityFixture,
      );

      const isValid = await claimIssuer.isClaimValid(
        await aliceIdentity.getAddress(),
        aliceClaim666.topic,
        aliceClaim666.signature,
        aliceClaim666.data,
      );

      expect(isValid).to.be.true;
    });
  });

  describe("upgrade", () => {
    it("should revert if not owner tries to upgrade", async () => {
      const [deployerWallet, aliceWallet] = await ethers.getSigners();

      // Deploy ClaimIssuer through proxy using our working setup
      const ClaimIssuer = await ethers.getContractFactory("ClaimIssuer");
      const claimIssuerImplementation = await ClaimIssuer.deploy(
        deployerWallet.address,
      );

      const ClaimIssuerProxy =
        await ethers.getContractFactory("ClaimIssuerProxy");
      const claimIssuerProxy = await ClaimIssuerProxy.deploy(
        await claimIssuerImplementation.getAddress(),
        claimIssuerImplementation.interface.encodeFunctionData("initialize", [
          deployerWallet.address,
        ]),
      );

      const proxy = await ethers.getContractAt(
        "ClaimIssuer",
        await claimIssuerProxy.getAddress(),
      );

      // Try to upgrade with non-owner account - should revert
      const newImplementation = await ClaimIssuer.deploy(aliceWallet.address);

      await expect(
        proxy
          .connect(aliceWallet)
          .upgradeTo(await newImplementation.getAddress()),
      ).to.be.revertedWithCustomError(proxy, "SenderDoesNotHaveManagementKey");
    });

    it("should upgrade the implementation using UUPS", async () => {
      const [deployerWallet] = await ethers.getSigners();

      // Deploy ClaimIssuer through proxy using our working setup
      const ClaimIssuer = await ethers.getContractFactory("ClaimIssuer");
      const claimIssuerImplementation = await ClaimIssuer.deploy(
        deployerWallet.address,
      );

      const ClaimIssuerProxy =
        await ethers.getContractFactory("ClaimIssuerProxy");
      const claimIssuerProxy = await ClaimIssuerProxy.deploy(
        await claimIssuerImplementation.getAddress(),
        claimIssuerImplementation.interface.encodeFunctionData("initialize", [
          deployerWallet.address,
        ]),
      );

      const proxy = await ethers.getContractAt(
        "ClaimIssuer",
        await claimIssuerProxy.getAddress(),
      );

      // Deploy new ClaimIssuer implementation
      const newClaimIssuer = await ClaimIssuer.deploy(deployerWallet.address);

      // Upgrade using UUPS mechanism
      await proxy
        .connect(deployerWallet)
        .upgradeTo(await newClaimIssuer.getAddress());

      // Verify the upgrade by checking if the new implementation is active
      // We can test this by calling a function that should still work
      expect(
        await proxy.keyHasPurpose(
          ethers.keccak256(
            ethers.AbiCoder.defaultAbiCoder().encode(
              ["address"],
              [deployerWallet.address],
            ),
          ),
          1, // MANAGEMENT purpose
        ),
      ).to.be.true;
    });
  });
});
