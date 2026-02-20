import { expect } from "chai";
import { ethers } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";

import {
  deployIdentityFixture,
  IdentityTypes,
  KeyPurposes,
  KeyTypes,
} from "../fixtures";

describe("IdFactory", () => {
  it("should revert because authority is Zero address", async () => {
    const [deployerWallet] = await ethers.getSigners();

    const IdFactory = await ethers.getContractFactory("IdFactory");
    await expect(
      IdFactory.connect(deployerWallet).deploy(ethers.ZeroAddress)
    ).to.be.revertedWithCustomError(IdFactory, "ZeroAddress");
  });

  it("should revert because sender is not allowed to create identities", async () => {
    const { identityFactory, aliceWallet } = await loadFixture(
      deployIdentityFixture
    );

    await expect(
      identityFactory
        .connect(aliceWallet)
        .createIdentity(ethers.ZeroAddress, "salt1", 2, [])
    ).to.be.revertedWithCustomError(
      identityFactory,
      "OwnableUnauthorizedAccount"
    );
  });

  it("should revert because wallet of identity cannot be Zero address", async () => {
    const { identityFactory, deployerWallet } = await loadFixture(
      deployIdentityFixture
    );

    await expect(
      identityFactory
        .connect(deployerWallet)
        .createIdentity(ethers.ZeroAddress, "salt1", 2, [])
    ).to.be.revertedWithCustomError(identityFactory, "ZeroAddress");
  });

  it("should revert because salt cannot be empty", async () => {
    const { identityFactory, deployerWallet, davidWallet } = await loadFixture(
      deployIdentityFixture
    );

    await expect(
      identityFactory
        .connect(deployerWallet)
        .createIdentity(davidWallet.address, "", 2, [])
    ).to.be.revertedWithCustomError(identityFactory, "EmptyString");
  });

  it("should revert because salt cannot be already used", async () => {
    const { identityFactory, deployerWallet, davidWallet, carolWallet } =
      await loadFixture(deployIdentityFixture);

    await identityFactory
      .connect(deployerWallet)
      .createIdentity(carolWallet.address, "saltUsed", 2, []);

    await expect(
      identityFactory
        .connect(deployerWallet)
        .createIdentity(davidWallet.address, "saltUsed", 2, [])
    ).to.be.revertedWithCustomError(identityFactory, "SaltTaken");
  });

  it("should revert because wallet is already linked to an identity", async () => {
    const { identityFactory, deployerWallet, aliceWallet } = await loadFixture(
      deployIdentityFixture
    );

    await expect(
      identityFactory
        .connect(deployerWallet)
        .createIdentity(aliceWallet.address, "newSalt", 2, [])
    ).to.be.revertedWithCustomError(
      identityFactory,
      "WalletAlreadyLinkedToIdentity"
    );
  });

  describe("link/unlink wallet", () => {
    describe("linkWallet", () => {
      it("should revert for new wallet being zero address", async () => {
        const { identityFactory, aliceWallet } = await loadFixture(
          deployIdentityFixture
        );

        await expect(
          identityFactory.connect(aliceWallet).linkWallet(ethers.ZeroAddress)
        ).to.be.revertedWithCustomError(identityFactory, "ZeroAddress");
      });

      it("should revert for sender wallet being not linked", async () => {
        const { identityFactory, davidWallet } = await loadFixture(
          deployIdentityFixture
        );

        await expect(
          identityFactory.connect(davidWallet).linkWallet(davidWallet.address)
        ).to.be.revertedWithCustomError(
          identityFactory,
          "WalletNotLinkedToIdentity"
        );
      });

      it("should revert for new wallet being already linked", async () => {
        const { identityFactory, bobWallet, aliceWallet } = await loadFixture(
          deployIdentityFixture
        );

        await expect(
          identityFactory.connect(bobWallet).linkWallet(aliceWallet.address)
        ).to.be.revertedWithCustomError(
          identityFactory,
          "WalletAlreadyLinkedToIdentity"
        );
      });

      it("should revert for new wallet being already to a token identity", async () => {
        const { identityFactory, bobWallet, tokenAddress } = await loadFixture(
          deployIdentityFixture
        );

        await expect(
          identityFactory.connect(bobWallet).linkWallet(tokenAddress)
        ).to.be.revertedWithCustomError(identityFactory, "TokenAlreadyLinked");
      });

      it("should link the new wallet to the existing identity", async () => {
        const { identityFactory, aliceIdentity, aliceWallet, davidWallet } =
          await loadFixture(deployIdentityFixture);

        const tx = await identityFactory
          .connect(aliceWallet)
          .linkWallet(davidWallet.address);
        await expect(tx)
          .to.emit(identityFactory, "WalletLinked")
          .withArgs(davidWallet.address, await aliceIdentity.getAddress());

        expect(
          await identityFactory.getWallets(await aliceIdentity.getAddress())
        ).to.deep.equal([aliceWallet.address, davidWallet.address]);
      });
    });

    describe("unlinkWallet", () => {
      it("should revert for wallet to unlink being zero address", async () => {
        const { identityFactory, aliceWallet } = await loadFixture(
          deployIdentityFixture
        );

        await expect(
          identityFactory.connect(aliceWallet).unlinkWallet(ethers.ZeroAddress)
        ).to.be.revertedWithCustomError(identityFactory, "ZeroAddress");
      });

      it("should revert for sender wallet attemoting to unlink itself", async () => {
        const { identityFactory, aliceWallet } = await loadFixture(
          deployIdentityFixture
        );

        await expect(
          identityFactory.connect(aliceWallet).unlinkWallet(aliceWallet.address)
        ).to.be.revertedWithCustomError(
          identityFactory,
          "CannotBeCalledOnSenderAddress"
        );
      });

      it("should revert for sender wallet being not linked", async () => {
        const { identityFactory, aliceWallet, davidWallet } = await loadFixture(
          deployIdentityFixture
        );

        await expect(
          identityFactory.connect(davidWallet).unlinkWallet(aliceWallet.address)
        ).to.be.revertedWithCustomError(
          identityFactory,
          "OnlyLinkedWalletCanUnlink"
        );
      });

      it("should unlink the wallet", async () => {
        const { identityFactory, aliceIdentity, aliceWallet, davidWallet } =
          await loadFixture(deployIdentityFixture);

        await identityFactory
          .connect(aliceWallet)
          .linkWallet(davidWallet.address);
        const tx = await identityFactory
          .connect(aliceWallet)
          .unlinkWallet(davidWallet.address);
        await expect(tx)
          .to.emit(identityFactory, "WalletUnlinked")
          .withArgs(davidWallet.address, await aliceIdentity.getAddress());

        expect(
          await identityFactory.getWallets(await aliceIdentity.getAddress())
        ).to.deep.equal([aliceWallet.address]);
      });
    });
  });

  describe("createIdentityWithManagementKeys()", () => {
    describe("when no management keys are provided", () => {
      it("should revert", async () => {
        const { identityFactory, deployerWallet, davidWallet } =
          await loadFixture(deployIdentityFixture);

        await expect(
          identityFactory
            .connect(deployerWallet)
            .createIdentityWithManagementKeys(
              davidWallet.address,
              "salt1",
              [],
              2,
              [],
            ),
        ).to.be.revertedWithCustomError(identityFactory, "EmptyListOfKeys");
      });
    });

    describe("when the wallet is included in the management keys listed", () => {
      it("should revert", async () => {
        const { identityFactory, deployerWallet, aliceWallet, davidWallet } =
          await loadFixture(deployIdentityFixture);

        await expect(
          identityFactory
            .connect(deployerWallet)
            .createIdentityWithManagementKeys(
              davidWallet.address,
              "salt1",
              [
                ethers.keccak256(
                  ethers.AbiCoder.defaultAbiCoder().encode(
                    ["address"],
                    [aliceWallet.address],
                  ),
                ),
                ethers.keccak256(
                  ethers.AbiCoder.defaultAbiCoder().encode(
                    ["address"],
                    [davidWallet.address],
                  ),
                ),
              ],
              2,
              [],
            )
        ).to.be.revertedWithCustomError(
          identityFactory,
          "WalletAlsoListedInManagementKeys"
        );
      });
    });

    describe("when other management keys are specified", () => {
      it("should deploy the identity proxy, set keys and wallet as management, and link wallet to identity", async () => {
        const { identityFactory, deployerWallet, aliceWallet, davidWallet } =
          await loadFixture(deployIdentityFixture);

        const tx = await identityFactory
          .connect(deployerWallet)
          .createIdentityWithManagementKeys(
            davidWallet.address,
            "salt1",
            [
              ethers.keccak256(
                ethers.AbiCoder.defaultAbiCoder().encode(
                  ["address"],
                  [aliceWallet.address],
                ),
              ),
            ],
            2,
            [],
          );

        await expect(tx).to.emit(identityFactory, "WalletLinked");
        await expect(tx).to.emit(identityFactory, "Deployed");

        const identity = await ethers.getContractAt(
          "Identity",
          await identityFactory.getIdentity(davidWallet.address)
        );

        await expect(tx)
          .to.emit(identity, "KeyAdded")
          .withArgs(
            ethers.keccak256(
              ethers.AbiCoder.defaultAbiCoder().encode(
                ["address"],
                [aliceWallet.address]
              )
            ),
            KeyPurposes.MANAGEMENT,
            KeyTypes.ECDSA
          );
        expect(
          await identity.keyHasPurpose(
            ethers.AbiCoder.defaultAbiCoder().encode(
              ["address"],
              [await identityFactory.getAddress()]
            ),
            KeyPurposes.MANAGEMENT
          )
        ).to.be.false;
        expect(
          await identity.keyHasPurpose(
            ethers.AbiCoder.defaultAbiCoder().encode(
              ["address"],
              [davidWallet.address]
            ),
            KeyPurposes.MANAGEMENT
          )
        ).to.be.false;
        expect(
          await identity.keyHasPurpose(
            ethers.AbiCoder.defaultAbiCoder().encode(
              ["address"],
              [aliceWallet.address]
            ),
            KeyPurposes.MANAGEMENT
          )
        ).to.be.false;
      });
    });
  });

  describe("createIdentity with claimIssuers", () => {
    it("should assign CLAIM_ADDER keys to trusted claim issuers at deployment", async () => {
      const {
        identityFactory,
        deployerWallet,
        claimIssuer,
        claimIssuerWallet,
        davidWallet,
      } = await loadFixture(deployIdentityFixture);

      const claimIssuerAddress = await claimIssuer.getAddress();

      const tx = await identityFactory
        .connect(deployerWallet)
        .createIdentity(davidWallet.address, "withIssuers", 2, [
          claimIssuerAddress,
        ]);

      const identity = await ethers.getContractAt(
        "Identity",
        await identityFactory.getIdentity(davidWallet.address),
      );

      // Claim issuer should have CLAIM_ADDER key
      expect(
        await identity.keyHasPurpose(
          ethers.keccak256(
            ethers.AbiCoder.defaultAbiCoder().encode(
              ["address"],
              [claimIssuerAddress],
            ),
          ),
          KeyPurposes.CLAIM_ADDER,
        ),
      ).to.be.true;

      // Owner wallet should have MANAGEMENT key
      expect(
        await identity.keyHasPurpose(
          ethers.keccak256(
            ethers.AbiCoder.defaultAbiCoder().encode(
              ["address"],
              [davidWallet.address],
            ),
          ),
          KeyPurposes.MANAGEMENT,
        ),
      ).to.be.true;

      // Factory should NOT have MANAGEMENT key (removed after bootstrap)
      expect(
        await identity.keyHasPurpose(
          ethers.keccak256(
            ethers.AbiCoder.defaultAbiCoder().encode(
              ["address"],
              [await identityFactory.getAddress()],
            ),
          ),
          KeyPurposes.MANAGEMENT,
        ),
      ).to.be.false;
    });

    it("should deploy normally with empty claimIssuers array", async () => {
      const { identityFactory, deployerWallet, davidWallet } =
        await loadFixture(deployIdentityFixture);

      await identityFactory
        .connect(deployerWallet)
        .createIdentity(davidWallet.address, "noIssuers", 2, []);

      const identity = await ethers.getContractAt(
        "Identity",
        await identityFactory.getIdentity(davidWallet.address),
      );

      // Owner wallet should have MANAGEMENT key
      expect(
        await identity.keyHasPurpose(
          ethers.keccak256(
            ethers.AbiCoder.defaultAbiCoder().encode(
              ["address"],
              [davidWallet.address],
            ),
          ),
          KeyPurposes.MANAGEMENT,
        ),
      ).to.be.true;
    });

    it("should allow trusted claim issuer to addClaim directly (single-tx flow)", async () => {
      const {
        identityFactory,
        deployerWallet,
        claimIssuer,
        claimIssuerWallet,
        davidWallet,
      } = await loadFixture(deployIdentityFixture);

      const claimIssuerAddress = await claimIssuer.getAddress();

      // Deploy identity with trusted claim issuer
      await identityFactory
        .connect(deployerWallet)
        .createIdentity(davidWallet.address, "singleTx", 2, [
          claimIssuerAddress,
        ]);

      const identity = await ethers.getContractAt(
        "Identity",
        await identityFactory.getIdentity(davidWallet.address),
      );

      // Prepare a valid claim
      const identityAddress = await identity.getAddress();
      const claimTopic = 42;
      const claimData = "0x0042";
      const claimSignature = await claimIssuerWallet.signMessage(
        ethers.getBytes(
          ethers.keccak256(
            ethers.AbiCoder.defaultAbiCoder().encode(
              ["address", "uint256", "bytes"],
              [identityAddress, claimTopic, claimData],
            ),
          ),
        ),
      );

      // Trusted issuer calls addClaimTo on ClaimIssuer, which calls execute on the identity
      // The claim issuer has CLAIM_ADDER key on the identity,
      // so it can call addClaim directly via auto-approved execution
      const addClaimData = identity.interface.encodeFunctionData("addClaim", [
        claimTopic,
        1, // scheme
        claimIssuerAddress,
        claimSignature,
        claimData,
        "https://example.com",
      ]);

      // The ClaimIssuer calls execute on the identity - since it has CLAIM_ADDER key,
      // and the target is the identity itself, it should be auto-approved
      const tx = await claimIssuer
        .connect(claimIssuerWallet)
        .addClaimTo(
          claimTopic,
          1,
          claimSignature,
          claimData,
          "https://example.com",
          identityAddress,
        );

      await expect(tx).to.emit(identity, "ClaimAdded");
    });
  });

  describe("createTokenIdentity with claimIssuers", () => {
    it("should assign CLAIM_ADDER keys to trusted claim issuers for token identity", async () => {
      const {
        identityFactory,
        deployerWallet,
        claimIssuer,
        davidWallet,
      } = await loadFixture(deployIdentityFixture);

      const claimIssuerAddress = await claimIssuer.getAddress();
      const tokenAddr = davidWallet.address;

      await identityFactory
        .connect(deployerWallet)
        .createTokenIdentity(tokenAddr, deployerWallet.address, "tokenSalt", [
          claimIssuerAddress,
        ]);

      const tokenIdentity = await ethers.getContractAt(
        "Identity",
        await identityFactory.getIdentity(tokenAddr),
      );

      // Claim issuer should have CLAIM_ADDER key
      expect(
        await tokenIdentity.keyHasPurpose(
          ethers.keccak256(
            ethers.AbiCoder.defaultAbiCoder().encode(
              ["address"],
              [claimIssuerAddress],
            ),
          ),
          KeyPurposes.CLAIM_ADDER,
        ),
      ).to.be.true;

      // Token identity type should be Asset
      expect(await tokenIdentity.getIdentityType()).to.equal(
        IdentityTypes.ASSET,
      );
    });
  });

  describe("createIdentityWithManagementKeys with claimIssuers", () => {
    it("should assign CLAIM_ADDER keys alongside custom management keys", async () => {
      const {
        identityFactory,
        deployerWallet,
        aliceWallet,
        claimIssuer,
        davidWallet,
      } = await loadFixture(deployIdentityFixture);

      const claimIssuerAddress = await claimIssuer.getAddress();

      const tx = await identityFactory
        .connect(deployerWallet)
        .createIdentityWithManagementKeys(
          davidWallet.address,
          "mgmtWithIssuers",
          [
            ethers.keccak256(
              ethers.AbiCoder.defaultAbiCoder().encode(
                ["address"],
                [aliceWallet.address],
              ),
            ),
          ],
          2,
          [claimIssuerAddress],
        );

      const identity = await ethers.getContractAt(
        "Identity",
        await identityFactory.getIdentity(davidWallet.address),
      );

      // Claim issuer should have CLAIM_ADDER key
      expect(
        await identity.keyHasPurpose(
          ethers.keccak256(
            ethers.AbiCoder.defaultAbiCoder().encode(
              ["address"],
              [claimIssuerAddress],
            ),
          ),
          KeyPurposes.CLAIM_ADDER,
        ),
      ).to.be.true;

      // Custom management key should be set
      expect(
        await identity.keyHasPurpose(
          ethers.keccak256(
            ethers.AbiCoder.defaultAbiCoder().encode(
              ["address"],
              [aliceWallet.address],
            ),
          ),
          KeyPurposes.MANAGEMENT,
        ),
      ).to.be.true;

      // Factory should NOT have MANAGEMENT key
      expect(
        await identity.keyHasPurpose(
          ethers.keccak256(
            ethers.AbiCoder.defaultAbiCoder().encode(
              ["address"],
              [await identityFactory.getAddress()],
            ),
          ),
          KeyPurposes.MANAGEMENT,
        ),
      ).to.be.false;
    });
  });
});
