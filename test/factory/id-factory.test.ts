import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { describe, it } from "mocha";

import { deployIdentityFixture, KeyPurposes, KeyTypes } from "../fixtures";

async function signLinkWallet(
  signer: ethers.Signer,
  wallet: string,
  identity: string,
  expiry: number,
  factoryAddress: string,
  chainId: bigint,
): Promise<string> {
  const domain = {
    name: "IdentityFactory",
    version: "1",
    chainId: chainId,
    verifyingContract: factoryAddress,
  };
  const types = {
    LinkWallet: [
      { name: "wallet", type: "address" },
      { name: "identity", type: "address" },
      { name: "expiry", type: "uint256" },
    ],
  };
  const value = { wallet, identity, expiry };
  return signer.signTypedData(domain, types, value);
}

describe("IdFactory", () => {
  it("should revert because authority is Zero address", async () => {
    const [deployerWallet] = await ethers.getSigners();

    const IdFactory = await ethers.getContractFactory("IdFactory");
    await expect(
      IdFactory.connect(deployerWallet).deploy(ethers.ZeroAddress),
    ).to.be.revertedWithCustomError(IdFactory, "ZeroAddress");
  });

  it("should revert because sender is not allowed to create identities", async () => {
    const { identityFactory, aliceWallet } = await loadFixture(
      deployIdentityFixture,
    );

    await expect(
      identityFactory
        .connect(aliceWallet)
        .createIdentity(ethers.ZeroAddress, "salt1"),
    ).to.be.revertedWithCustomError(
      identityFactory,
      "OwnableUnauthorizedAccount",
    );
  });

  it("should revert because wallet of identity cannot be Zero address", async () => {
    const { identityFactory, deployerWallet } = await loadFixture(
      deployIdentityFixture,
    );

    await expect(
      identityFactory
        .connect(deployerWallet)
        .createIdentity(ethers.ZeroAddress, "salt1"),
    ).to.be.revertedWithCustomError(identityFactory, "ZeroAddress");
  });

  it("should revert because salt cannot be empty", async () => {
    const { identityFactory, deployerWallet, davidWallet } = await loadFixture(
      deployIdentityFixture,
    );

    await expect(
      identityFactory
        .connect(deployerWallet)
        .createIdentity(davidWallet.address, ""),
    ).to.be.revertedWithCustomError(identityFactory, "EmptyString");
  });

  it("should revert because salt cannot be already used", async () => {
    const { identityFactory, deployerWallet, davidWallet, carolWallet } =
      await loadFixture(deployIdentityFixture);

    await identityFactory
      .connect(deployerWallet)
      .createIdentity(carolWallet.address, "saltUsed");

    await expect(
      identityFactory
        .connect(deployerWallet)
        .createIdentity(davidWallet.address, "saltUsed"),
    ).to.be.revertedWithCustomError(identityFactory, "SaltTaken");
  });

  it("should revert because wallet is already linked to an identity", async () => {
    const { identityFactory, deployerWallet, aliceWallet } = await loadFixture(
      deployIdentityFixture,
    );

    await expect(
      identityFactory
        .connect(deployerWallet)
        .createIdentity(aliceWallet.address, "newSalt"),
    ).to.be.revertedWithCustomError(
      identityFactory,
      "WalletAlreadyLinkedToIdentity",
    );
  });

  describe("createTokenIdentity", () => {
    it("should allow an authorized token factory to create a token identity", async () => {
      const { identityFactory, deployerWallet, bobWallet, tokenOwnerWallet } =
        await loadFixture(deployIdentityFixture);

      const signers = await ethers.getSigners();
      const tokenWallet = signers[7];

      await identityFactory
        .connect(deployerWallet)
        .addTokenFactory(bobWallet.address);

      const tx = await identityFactory
        .connect(bobWallet)
        .createTokenIdentity(
          tokenWallet.address,
          tokenOwnerWallet.address,
          "factorySalt",
        );

      const tokenIdentity = await identityFactory.getIdentity(
        tokenWallet.address,
      );

      await expect(tx)
        .to.emit(identityFactory, "TokenLinked")
        .withArgs(tokenWallet.address, tokenIdentity);
    });
  });

  describe("link/unlink wallet", () => {
    describe("linkWallet", () => {
      it("should revert for new wallet being zero address", async () => {
        const { identityFactory, aliceWallet } = await loadFixture(
          deployIdentityFixture,
        );

        await expect(
          identityFactory.connect(aliceWallet).linkWallet(ethers.ZeroAddress),
        ).to.be.revertedWithCustomError(identityFactory, "ZeroAddress");
      });

      it("should revert for sender wallet being not linked", async () => {
        const { identityFactory, davidWallet } = await loadFixture(
          deployIdentityFixture,
        );

        await expect(
          identityFactory.connect(davidWallet).linkWallet(davidWallet.address),
        ).to.be.revertedWithCustomError(
          identityFactory,
          "WalletNotLinkedToIdentity",
        );
      });

      it("should revert for new wallet being already linked", async () => {
        const { identityFactory, bobWallet, aliceWallet } = await loadFixture(
          deployIdentityFixture,
        );

        await expect(
          identityFactory.connect(bobWallet).linkWallet(aliceWallet.address),
        ).to.be.revertedWithCustomError(
          identityFactory,
          "WalletAlreadyLinkedToIdentity",
        );
      });

      it("should revert for new wallet being already to a token identity", async () => {
        const { identityFactory, bobWallet, tokenAddress } = await loadFixture(
          deployIdentityFixture,
        );

        await expect(
          identityFactory.connect(bobWallet).linkWallet(tokenAddress),
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
          await identityFactory.getWallets(await aliceIdentity.getAddress()),
        ).to.deep.equal([aliceWallet.address, davidWallet.address]);
      });

      it("should revert when max wallets per identity is exceeded", async () => {
        const { identityFactory, aliceWallet } = await loadFixture(
          deployIdentityFixture,
        );

        for (let i = 0; i < 100; i++) {
          await identityFactory
            .connect(aliceWallet)
            .linkWallet(ethers.Wallet.createRandom().address);
        }

        await expect(
          identityFactory
            .connect(aliceWallet)
            .linkWallet(ethers.Wallet.createRandom().address),
        ).to.be.revertedWithCustomError(
          identityFactory,
          "MaxWalletsPerIdentityExceeded",
        );
      });
    });

    describe("unlinkWallet", () => {
      it("should revert for wallet to unlink being zero address", async () => {
        const { identityFactory, aliceWallet } = await loadFixture(
          deployIdentityFixture,
        );

        await expect(
          identityFactory.connect(aliceWallet).unlinkWallet(ethers.ZeroAddress),
        ).to.be.revertedWithCustomError(identityFactory, "ZeroAddress");
      });

      it("should revert for sender wallet attemoting to unlink itself", async () => {
        const { identityFactory, aliceWallet } = await loadFixture(
          deployIdentityFixture,
        );

        await expect(
          identityFactory
            .connect(aliceWallet)
            .unlinkWallet(aliceWallet.address),
        ).to.be.revertedWithCustomError(
          identityFactory,
          "CannotBeCalledOnSenderAddress",
        );
      });

      it("should revert for sender wallet being not linked", async () => {
        const { identityFactory, aliceWallet, davidWallet } = await loadFixture(
          deployIdentityFixture,
        );

        await expect(
          identityFactory
            .connect(davidWallet)
            .unlinkWallet(aliceWallet.address),
        ).to.be.revertedWithCustomError(
          identityFactory,
          "OnlyLinkedWalletCanUnlink",
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
          await identityFactory.getWallets(await aliceIdentity.getAddress()),
        ).to.deep.equal([aliceWallet.address]);
      });
    });
  });

  describe("createIdentityWithManagementKeys()", () => {
    describe("validation", () => {
      it("should revert when wallet is zero address", async () => {
        const { identityFactory, deployerWallet, aliceWallet } =
          await loadFixture(deployIdentityFixture);

        await expect(
          identityFactory
            .connect(deployerWallet)
            .createIdentityWithManagementKeys(ethers.ZeroAddress, "salt1", [
              ethers.keccak256(
                ethers.AbiCoder.defaultAbiCoder().encode(
                  ["address"],
                  [aliceWallet.address],
                ),
              ),
            ]),
        ).to.be.revertedWithCustomError(identityFactory, "ZeroAddress");
      });

      it("should revert when salt is empty", async () => {
        const { identityFactory, deployerWallet, aliceWallet } =
          await loadFixture(deployIdentityFixture);

        await expect(
          identityFactory
            .connect(deployerWallet)
            .createIdentityWithManagementKeys(aliceWallet.address, "", [
              ethers.keccak256(
                ethers.AbiCoder.defaultAbiCoder().encode(
                  ["address"],
                  [aliceWallet.address],
                ),
              ),
            ]),
        ).to.be.revertedWithCustomError(identityFactory, "EmptyString");
      });

      it("should revert when salt is already taken", async () => {
        const { identityFactory, deployerWallet, davidWallet, carolWallet } =
          await loadFixture(deployIdentityFixture);

        await identityFactory
          .connect(deployerWallet)
          .createIdentityWithManagementKeys(davidWallet.address, "salt1", [
            ethers.keccak256(
              ethers.AbiCoder.defaultAbiCoder().encode(
                ["address"],
                [carolWallet.address],
              ),
            ),
          ]);

        await expect(
          identityFactory
            .connect(deployerWallet)
            .createIdentityWithManagementKeys(
              ethers.Wallet.createRandom().address,
              "salt1",
              [
                ethers.keccak256(
                  ethers.AbiCoder.defaultAbiCoder().encode(
                    ["address"],
                    [carolWallet.address],
                  ),
                ),
              ],
            ),
        ).to.be.revertedWithCustomError(identityFactory, "SaltTaken");
      });

      it("should revert when wallet is already linked", async () => {
        const { identityFactory, deployerWallet, aliceWallet, carolWallet } =
          await loadFixture(deployIdentityFixture);

        await expect(
          identityFactory
            .connect(deployerWallet)
            .createIdentityWithManagementKeys(aliceWallet.address, "salt1", [
              ethers.keccak256(
                ethers.AbiCoder.defaultAbiCoder().encode(
                  ["address"],
                  [carolWallet.address],
                ),
              ),
            ]),
        ).to.be.revertedWithCustomError(
          identityFactory,
          "WalletAlreadyLinkedToIdentity",
        );
      });

      it("should revert when caller is not the owner", async () => {
        const { identityFactory, aliceWallet, davidWallet } = await loadFixture(
          deployIdentityFixture,
        );

        await expect(
          identityFactory
            .connect(aliceWallet)
            .createIdentityWithManagementKeys(davidWallet.address, "salt1", [
              ethers.keccak256(
                ethers.AbiCoder.defaultAbiCoder().encode(
                  ["address"],
                  [aliceWallet.address],
                ),
              ),
            ]),
        ).to.be.revertedWithCustomError(
          identityFactory,
          "OwnableUnauthorizedAccount",
        );
      });
    });

    describe("when no management keys are provided", () => {
      it("should revert", async () => {
        const { identityFactory, deployerWallet, davidWallet } =
          await loadFixture(deployIdentityFixture);

        await expect(
          identityFactory
            .connect(deployerWallet)
            .createIdentityWithManagementKeys(davidWallet.address, "salt1", []),
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
            .createIdentityWithManagementKeys(davidWallet.address, "salt1", [
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
            ]),
        ).to.be.revertedWithCustomError(
          identityFactory,
          "WalletAlsoListedInManagementKeys",
        );
      });
    });

    describe("when other management keys are specified", () => {
      it("should deploy the identity proxy, set keys and wallet as management, and link wallet to identity", async () => {
        const { identityFactory, deployerWallet, aliceWallet, davidWallet } =
          await loadFixture(deployIdentityFixture);

        const tx = await identityFactory
          .connect(deployerWallet)
          .createIdentityWithManagementKeys(davidWallet.address, "salt1", [
            ethers.keccak256(
              ethers.AbiCoder.defaultAbiCoder().encode(
                ["address"],
                [aliceWallet.address],
              ),
            ),
          ]);

        await expect(tx).to.emit(identityFactory, "WalletLinked");
        await expect(tx).to.emit(identityFactory, "Deployed");

        const identity = await ethers.getContractAt(
          "Identity",
          await identityFactory.getIdentity(davidWallet.address),
        );

        await expect(tx)
          .to.emit(identity, "KeyAdded")
          .withArgs(
            ethers.keccak256(
              ethers.AbiCoder.defaultAbiCoder().encode(
                ["address"],
                [aliceWallet.address],
              ),
            ),
            KeyPurposes.MANAGEMENT,
            KeyTypes.ECDSA,
          );
        expect(
          await identity.keyHasPurpose(
            ethers.AbiCoder.defaultAbiCoder().encode(
              ["address"],
              [await identityFactory.getAddress()],
            ),
            KeyPurposes.MANAGEMENT,
          ),
        ).to.be.false;
        expect(
          await identity.keyHasPurpose(
            ethers.AbiCoder.defaultAbiCoder().encode(
              ["address"],
              [davidWallet.address],
            ),
            KeyPurposes.MANAGEMENT,
          ),
        ).to.be.false;
        expect(
          await identity.keyHasPurpose(
            ethers.AbiCoder.defaultAbiCoder().encode(
              ["address"],
              [aliceWallet.address],
            ),
            KeyPurposes.MANAGEMENT,
          ),
        ).to.be.false;
      });
    });
  });

  describe("linkWalletWithSignature - unlinkWalletByIdentity", () => {
    describe("linkWalletWithSignature", () => {
      it("should revert when wallet is zero address", async () => {
        const { identityFactory, aliceIdentity, aliceWallet } =
          await loadFixture(deployIdentityFixture);

        const expiry = Math.floor(Date.now() / 1000) + 3600; // 1 hour from now
        const signature = "0x";

        const data = identityFactory.interface.encodeFunctionData(
          "linkWalletWithSignature",
          [ethers.ZeroAddress, signature, expiry],
        );

        const nonceBefore = await aliceIdentity.getCurrentNonce();
        await aliceIdentity
          .connect(aliceWallet)
          .execute(await identityFactory.getAddress(), 0, data);

        const executionId = Number(nonceBefore);
        await aliceIdentity.connect(aliceWallet).approve(executionId, true);

        // Check that the execution failed (Identity contract catches reverts from the IdFactory)
        const executionData = await aliceIdentity.getExecutionData(executionId);
        expect(executionData.executed).to.be.false;

        // Verify state didn't change, wallet should not be linked
        expect(await identityFactory.getIdentity(ethers.ZeroAddress)).to.equal(
          ethers.ZeroAddress,
        );
      });

      it("should revert when signature is expired", async () => {
        const { identityFactory, aliceIdentity, aliceWallet, davidWallet } =
          await loadFixture(deployIdentityFixture);

        const expiredTime = Math.floor(Date.now() / 1000) - 3600; // 1 hour ago
        const network = await ethers.provider.getNetwork();
        const chainId = network.chainId;
        const identityAddress = await aliceIdentity.getAddress();
        const factoryAddress = await identityFactory.getAddress();

        const signature = await signLinkWallet(
          davidWallet,
          davidWallet.address,
          identityAddress,
          expiredTime,
          factoryAddress,
          chainId,
        );

        const data = identityFactory.interface.encodeFunctionData(
          "linkWalletWithSignature",
          [davidWallet.address, signature, expiredTime],
        );

        const nonceBefore = await aliceIdentity.getCurrentNonce();
        await aliceIdentity
          .connect(aliceWallet)
          .execute(await identityFactory.getAddress(), 0, data);

        const executionId = Number(nonceBefore);
        await aliceIdentity.connect(aliceWallet).approve(executionId, true);

        // Check that the execution failed (Identity contract catches reverts from the IdFactory)
        const executionData = await aliceIdentity.getExecutionData(executionId);
        expect(executionData.executed).to.be.false;

        // Verify state didn't change, wallet should not be linked
        expect(await identityFactory.getIdentity(davidWallet.address)).to.equal(
          ethers.ZeroAddress,
        );
      });

      it("should revert when signature is invalid", async () => {
        const {
          identityFactory,
          aliceIdentity,
          aliceWallet,
          davidWallet,
          bobWallet,
        } = await loadFixture(deployIdentityFixture);

        const expiry = Math.floor(Date.now() / 1000) + 3600;
        const network = await ethers.provider.getNetwork();
        const chainId = network.chainId;
        const identityAddress = await aliceIdentity.getAddress();
        const factoryAddress = await identityFactory.getAddress();

        // Sign with wrong wallet (bob instead of david)
        const signature = await signLinkWallet(
          bobWallet,
          davidWallet.address,
          identityAddress,
          expiry,
          factoryAddress,
          chainId,
        );

        const data = identityFactory.interface.encodeFunctionData(
          "linkWalletWithSignature",
          [davidWallet.address, signature, expiry],
        );

        const nonceBefore = await aliceIdentity.getCurrentNonce();
        await aliceIdentity
          .connect(aliceWallet)
          .execute(await identityFactory.getAddress(), 0, data);

        const executionId = Number(nonceBefore);
        await aliceIdentity.connect(aliceWallet).approve(executionId, true);

        // Check that the execution failed (Identity contract catches reverts from the IdFactory)
        const executionData = await aliceIdentity.getExecutionData(executionId);
        expect(executionData.executed).to.be.false;

        // Verify state didn't change, wallet should not be linked
        expect(await identityFactory.getIdentity(davidWallet.address)).to.equal(
          ethers.ZeroAddress,
        );
      });

      it("should revert when signer does not match wallet", async () => {
        const { identityFactory, aliceIdentity, aliceWallet } =
          await loadFixture(deployIdentityFixture);

        const signers = await ethers.getSigners();
        const targetWallet = signers[8];
        const wrongSigner = signers[9];

        const expiry = Math.floor(Date.now() / 1000) + 3600;
        const network = await ethers.provider.getNetwork();
        const chainId = network.chainId;
        const identityAddress = await aliceIdentity.getAddress();
        const factoryAddress = await identityFactory.getAddress();

        const signature = await signLinkWallet(
          wrongSigner,
          targetWallet.address,
          identityAddress,
          expiry,
          factoryAddress,
          chainId,
        );

        const data = identityFactory.interface.encodeFunctionData(
          "linkWalletWithSignature",
          [targetWallet.address, signature, expiry],
        );

        const nonceBefore = await aliceIdentity.getCurrentNonce();
        await aliceIdentity
          .connect(aliceWallet)
          .execute(await identityFactory.getAddress(), 0, data);

        const executionId = Number(nonceBefore);
        await aliceIdentity.connect(aliceWallet).approve(executionId, true);

        const executionData = await aliceIdentity.getExecutionData(executionId);
        expect(executionData.executed).to.be.false;
      });

      it("should revert when signature cannot be recovered", async () => {
        const { identityFactory, aliceIdentity, aliceWallet, davidWallet } =
          await loadFixture(deployIdentityFixture);

        const expiry = Math.floor(Date.now() / 1000) + 3600;
        const data = identityFactory.interface.encodeFunctionData(
          "linkWalletWithSignature",
          [davidWallet.address, "0x1234", expiry],
        );

        const nonceBefore = await aliceIdentity.getCurrentNonce();
        await aliceIdentity
          .connect(aliceWallet)
          .execute(await identityFactory.getAddress(), 0, data);

        const executionId = Number(nonceBefore);
        await aliceIdentity.connect(aliceWallet).approve(executionId, true);

        const executionData = await aliceIdentity.getExecutionData(executionId);
        expect(executionData.executed).to.be.false;
      });

      it("should revert when wallet does not have MANAGEMENT key", async () => {
        const { identityFactory, aliceIdentity, aliceWallet, davidWallet } =
          await loadFixture(deployIdentityFixture);

        const expiry = Math.floor(Date.now() / 1000) + 3600;
        const network = await ethers.provider.getNetwork();
        const chainId = network.chainId;
        const identityAddress = await aliceIdentity.getAddress();
        const factoryAddress = await identityFactory.getAddress();

        const signature = await signLinkWallet(
          davidWallet,
          davidWallet.address,
          identityAddress,
          expiry,
          factoryAddress,
          chainId,
        );

        // davidWallet has ACTION key, not MANAGEMENT key
        const data = identityFactory.interface.encodeFunctionData(
          "linkWalletWithSignature",
          [davidWallet.address, signature, expiry],
        );

        const nonceBefore = await aliceIdentity.getCurrentNonce();
        await aliceIdentity
          .connect(aliceWallet)
          .execute(await identityFactory.getAddress(), 0, data);

        const executionId = Number(nonceBefore);
        await aliceIdentity.connect(aliceWallet).approve(executionId, true);

        // Check that the execution failed (Identity contract catches reverts from the IdFactory)
        const executionData = await aliceIdentity.getExecutionData(executionId);
        expect(executionData.executed).to.be.false;

        // Verify state didn't change, wallet should not be linked
        expect(await identityFactory.getIdentity(davidWallet.address)).to.equal(
          ethers.ZeroAddress,
        );
      });

      it("should revert when wallet is already linked", async () => {
        const { identityFactory, aliceIdentity, aliceWallet } =
          await loadFixture(deployIdentityFixture);

        const expiry = Math.floor(Date.now() / 1000) + 3600;
        const network = await ethers.provider.getNetwork();
        const chainId = network.chainId;
        const identityAddress = await aliceIdentity.getAddress();
        const factoryAddress = await identityFactory.getAddress();

        const signature = await signLinkWallet(
          aliceWallet,
          aliceWallet.address,
          identityAddress,
          expiry,
          factoryAddress,
          chainId,
        );

        const data = identityFactory.interface.encodeFunctionData(
          "linkWalletWithSignature",
          [aliceWallet.address, signature, expiry],
        );

        const nonceBefore = await aliceIdentity.getCurrentNonce();
        await aliceIdentity
          .connect(aliceWallet)
          .execute(await identityFactory.getAddress(), 0, data);

        const executionId = Number(nonceBefore);
        await aliceIdentity.connect(aliceWallet).approve(executionId, true);

        // Check that the execution failed (Identity contract catches reverts from the IdFactory)
        const executionData = await aliceIdentity.getExecutionData(executionId);
        expect(executionData.executed).to.be.false;

        // Verify state didn't change - wallet should still be linked to the same identity
        expect(await identityFactory.getIdentity(aliceWallet.address)).to.equal(
          await aliceIdentity.getAddress(),
        );
      });

      it("should revert when wallet address is already linked to a token", async () => {
        const {
          identityFactory,
          deployerWallet,
          aliceIdentity,
          aliceWallet,
          tokenOwnerWallet,
        } = await loadFixture(deployIdentityFixture);

        const signers = await ethers.getSigners();
        const tokenWallet = signers[10];

        await identityFactory
          .connect(deployerWallet)
          .createTokenIdentity(
            tokenWallet.address,
            tokenOwnerWallet.address,
            "tokenWallet",
          );

        await aliceIdentity
          .connect(aliceWallet)
          .addKey(
            ethers.keccak256(
              ethers.AbiCoder.defaultAbiCoder().encode(
                ["address"],
                [tokenWallet.address],
              ),
            ),
            KeyPurposes.MANAGEMENT,
            KeyTypes.ECDSA,
          );

        const expiry = Math.floor(Date.now() / 1000) + 3600;
        const network = await ethers.provider.getNetwork();
        const chainId = network.chainId;
        const identityAddress = await aliceIdentity.getAddress();
        const factoryAddress = await identityFactory.getAddress();

        const signature = await signLinkWallet(
          tokenWallet,
          tokenWallet.address,
          identityAddress,
          expiry,
          factoryAddress,
          chainId,
        );

        const data = identityFactory.interface.encodeFunctionData(
          "linkWalletWithSignature",
          [tokenWallet.address, signature, expiry],
        );

        const nonceBefore = await aliceIdentity.getCurrentNonce();
        await aliceIdentity
          .connect(aliceWallet)
          .execute(await identityFactory.getAddress(), 0, data);

        const executionId = Number(nonceBefore);
        await aliceIdentity.connect(aliceWallet).approve(executionId, true);

        const executionData = await aliceIdentity.getExecutionData(executionId);
        expect(executionData.executed).to.be.false;
      });

      it("should revert when exceeding max wallets per identity", async () => {
        const { identityFactory, aliceIdentity, aliceWallet } =
          await loadFixture(deployIdentityFixture);

        for (let i = 0; i < 100; i++) {
          await identityFactory
            .connect(aliceWallet)
            .linkWallet(ethers.Wallet.createRandom().address);
        }

        const signers = await ethers.getSigners();
        const overflowWallet = signers[11];

        await aliceIdentity
          .connect(aliceWallet)
          .addKey(
            ethers.keccak256(
              ethers.AbiCoder.defaultAbiCoder().encode(
                ["address"],
                [overflowWallet.address],
              ),
            ),
            KeyPurposes.MANAGEMENT,
            KeyTypes.ECDSA,
          );

        const expiry = Math.floor(Date.now() / 1000) + 3600;
        const network = await ethers.provider.getNetwork();
        const chainId = network.chainId;
        const identityAddress = await aliceIdentity.getAddress();
        const factoryAddress = await identityFactory.getAddress();

        const signature = await signLinkWallet(
          overflowWallet,
          overflowWallet.address,
          identityAddress,
          expiry,
          factoryAddress,
          chainId,
        );

        const data = identityFactory.interface.encodeFunctionData(
          "linkWalletWithSignature",
          [overflowWallet.address, signature, expiry],
        );

        const nonceBefore = await aliceIdentity.getCurrentNonce();
        await aliceIdentity
          .connect(aliceWallet)
          .execute(await identityFactory.getAddress(), 0, data);

        const executionId = Number(nonceBefore);
        await aliceIdentity.connect(aliceWallet).approve(executionId, true);

        const executionData = await aliceIdentity.getExecutionData(executionId);
        expect(executionData.executed).to.be.false;
      });

      it("should successfully register wallet to identity", async () => {
        const { identityFactory, aliceIdentity, aliceWallet, carolWallet } =
          await loadFixture(deployIdentityFixture);

        // Add carolWallet as MANAGEMENT key first
        await aliceIdentity
          .connect(aliceWallet)
          .addKey(
            ethers.keccak256(
              ethers.AbiCoder.defaultAbiCoder().encode(
                ["address"],
                [carolWallet.address],
              ),
            ),
            KeyPurposes.MANAGEMENT,
            KeyTypes.ECDSA,
          );

        const expiry = Math.floor(Date.now() / 1000) + 3600;
        const network = await ethers.provider.getNetwork();
        const chainId = network.chainId;
        const identityAddress = await aliceIdentity.getAddress();
        const factoryAddress = await identityFactory.getAddress();

        const signature = await signLinkWallet(
          carolWallet,
          carolWallet.address,
          identityAddress,
          expiry,
          factoryAddress,
          chainId,
        );

        const data = identityFactory.interface.encodeFunctionData(
          "linkWalletWithSignature",
          [carolWallet.address, signature, expiry],
        );

        // Since aliceWallet has MANAGEMENT key, execute() will auto-approve and execute
        const tx = await aliceIdentity
          .connect(aliceWallet)
          .execute(await identityFactory.getAddress(), 0, data);

        await expect(tx)
          .to.emit(identityFactory, "WalletLinked")
          .withArgs(carolWallet.address, await aliceIdentity.getAddress());

        expect(await identityFactory.getIdentity(carolWallet.address)).to.equal(
          await aliceIdentity.getAddress(),
        );
        expect(
          await identityFactory.getWallets(await aliceIdentity.getAddress()),
        ).to.include(carolWallet.address);
      });

      it("should revert when replaying an expired signature after unlinking", async () => {
        const { identityFactory, aliceIdentity, aliceWallet, carolWallet } =
          await loadFixture(deployIdentityFixture);

        // Add carolWallet as MANAGEMENT key
        await aliceIdentity
          .connect(aliceWallet)
          .addKey(
            ethers.keccak256(
              ethers.AbiCoder.defaultAbiCoder().encode(
                ["address"],
                [carolWallet.address],
              ),
            ),
            KeyPurposes.MANAGEMENT,
            KeyTypes.ECDSA,
          );

        const network = await ethers.provider.getNetwork();
        const chainId = network.chainId;
        const identityAddress = await aliceIdentity.getAddress();
        const factoryAddress = await identityFactory.getAddress();

        // Use a short expiry (60 seconds from now — enough for the link+unlink to complete)
        const latestBlock = await ethers.provider.getBlock("latest");
        const shortExpiry = latestBlock!.timestamp + 60;

        const signature = await signLinkWallet(
          carolWallet,
          carolWallet.address,
          identityAddress,
          shortExpiry,
          factoryAddress,
          chainId,
        );

        // First link succeeds
        const linkData = identityFactory.interface.encodeFunctionData(
          "linkWalletWithSignature",
          [carolWallet.address, signature, shortExpiry],
        );
        await aliceIdentity
          .connect(aliceWallet)
          .execute(await identityFactory.getAddress(), 0, linkData);

        expect(await identityFactory.getIdentity(carolWallet.address)).to.equal(
          await aliceIdentity.getAddress(),
        );

        // Unlink the wallet
        const unlinkData = identityFactory.interface.encodeFunctionData(
          "unlinkWalletByIdentity",
          [carolWallet.address],
        );
        await aliceIdentity
          .connect(aliceWallet)
          .execute(await identityFactory.getAddress(), 0, unlinkData);

        expect(await identityFactory.getIdentity(carolWallet.address)).to.equal(
          ethers.ZeroAddress,
        );

        // Advance time past the expiry
        await ethers.provider.send("evm_increaseTime", [120]);
        await ethers.provider.send("evm_mine", []);

        // Attempt to replay the same signature — should fail because it's expired
        const replayData = identityFactory.interface.encodeFunctionData(
          "linkWalletWithSignature",
          [carolWallet.address, signature, shortExpiry],
        );
        const identityNonceBefore = await aliceIdentity.getCurrentNonce();
        await aliceIdentity
          .connect(aliceWallet)
          .execute(await identityFactory.getAddress(), 0, replayData);

        const executionId = Number(identityNonceBefore);
        await aliceIdentity.connect(aliceWallet).approve(executionId, true);

        // Execution should fail due to expired signature
        const executionData = await aliceIdentity.getExecutionData(executionId);
        expect(executionData.executed).to.be.false;

        // Wallet should remain unlinked
        expect(await identityFactory.getIdentity(carolWallet.address)).to.equal(
          ethers.ZeroAddress,
        );
      });
    });

    describe("unlinkWalletByIdentity", () => {
      it("should revert when wallet is zero address", async () => {
        const { identityFactory, aliceIdentity, aliceWallet } =
          await loadFixture(deployIdentityFixture);

        const data = identityFactory.interface.encodeFunctionData(
          "unlinkWalletByIdentity",
          [ethers.ZeroAddress],
        );

        const nonceBefore = await aliceIdentity.getCurrentNonce();
        await aliceIdentity
          .connect(aliceWallet)
          .execute(await identityFactory.getAddress(), 0, data);

        const executionId = Number(nonceBefore);
        await aliceIdentity.connect(aliceWallet).approve(executionId, true);

        // Check that the execution failed (Identity contract catches reverts from the IdFactory)
        const executionData = await aliceIdentity.getExecutionData(executionId);
        expect(executionData.executed).to.be.false;
      });

      it("should revert when wallet is not linked to the identity", async () => {
        const { identityFactory, aliceIdentity, aliceWallet, davidWallet } =
          await loadFixture(deployIdentityFixture);

        const data = identityFactory.interface.encodeFunctionData(
          "unlinkWalletByIdentity",
          [davidWallet.address],
        );

        const nonceBefore = await aliceIdentity.getCurrentNonce();
        await aliceIdentity
          .connect(aliceWallet)
          .execute(await identityFactory.getAddress(), 0, data);

        const executionId = Number(nonceBefore);
        await aliceIdentity.connect(aliceWallet).approve(executionId, true);

        // Check that the execution failed (Identity contract catches reverts from the IdFactory)
        const executionData = await aliceIdentity.getExecutionData(executionId);
        expect(executionData.executed).to.be.false;

        // Verify state didn't change - wallet should still not be linked
        expect(await identityFactory.getIdentity(davidWallet.address)).to.equal(
          ethers.ZeroAddress,
        );
      });

      it("should successfully unregister wallet from identity", async () => {
        const { identityFactory, aliceIdentity, aliceWallet, carolWallet } =
          await loadFixture(deployIdentityFixture);

        // Add carolWallet as MANAGEMENT key and register it
        await aliceIdentity
          .connect(aliceWallet)
          .addKey(
            ethers.keccak256(
              ethers.AbiCoder.defaultAbiCoder().encode(
                ["address"],
                [carolWallet.address],
              ),
            ),
            KeyPurposes.MANAGEMENT,
            KeyTypes.ECDSA,
          );

        const expiry = Math.floor(Date.now() / 1000) + 3600;
        const network = await ethers.provider.getNetwork();
        const chainId = network.chainId;
        const identityAddress = await aliceIdentity.getAddress();
        const factoryAddress = await identityFactory.getAddress();

        const signature = await signLinkWallet(
          carolWallet,
          carolWallet.address,
          identityAddress,
          expiry,
          factoryAddress,
          chainId,
        );

        const registerData = identityFactory.interface.encodeFunctionData(
          "linkWalletWithSignature",
          [carolWallet.address, signature, expiry],
        );

        // Since aliceWallet has MANAGEMENT key, execute() will auto-approve and execute
        await aliceIdentity
          .connect(aliceWallet)
          .execute(await identityFactory.getAddress(), 0, registerData);

        const walletsBefore = await identityFactory.getWallets(
          await aliceIdentity.getAddress(),
        );
        expect(walletsBefore).to.include(carolWallet.address);

        const unregisterData = identityFactory.interface.encodeFunctionData(
          "unlinkWalletByIdentity",
          [carolWallet.address],
        );

        // Since aliceWallet has MANAGEMENT key, execute() will auto-approve and execute
        const tx = await aliceIdentity
          .connect(aliceWallet)
          .execute(await identityFactory.getAddress(), 0, unregisterData);

        await expect(tx)
          .to.emit(identityFactory, "WalletUnlinked")
          .withArgs(carolWallet.address, await aliceIdentity.getAddress());

        expect(await identityFactory.getIdentity(carolWallet.address)).to.equal(
          ethers.ZeroAddress,
        );
        const walletsAfter = await identityFactory.getWallets(
          await aliceIdentity.getAddress(),
        );
        expect(walletsAfter).to.not.include(carolWallet.address);
      });
    });
  });
});
