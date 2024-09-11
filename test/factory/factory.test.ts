import {expect} from "chai";
import {ethers} from "hardhat";
import {loadFixture} from "@nomicfoundation/hardhat-network-helpers";

import {deployIdentityFixture} from "../fixtures";

describe('IdFactory', () => {
  it('should revert because authority is Zero address', async () => {
    const [deployerWallet] = await ethers.getSigners();

    const IdFactory = await ethers.getContractFactory('IdFactory');
    await expect(IdFactory.connect(deployerWallet).deploy(ethers.ZeroAddress)).to.be.revertedWith('invalid argument - zero address');
  });

  it('should revert because sender is not allowed to create identities', async () => {
    const {identityFactory, aliceWallet} = await loadFixture(deployIdentityFixture);

    await expect(identityFactory.connect(aliceWallet).createIdentity(ethers.ZeroAddress, 'salt1')).to.be.revertedWithCustomError(identityFactory, 'OwnableUnauthorizedAccount');
  });

  it('should revert because wallet of identity cannot be Zero address', async () => {
    const {identityFactory, deployerWallet} = await loadFixture(deployIdentityFixture);

    await expect(identityFactory.connect(deployerWallet).createIdentity(ethers.ZeroAddress, 'salt1')).to.be.revertedWith('invalid argument - zero address');
  });

  it('should revert because salt cannot be empty', async () => {
    const {identityFactory, deployerWallet, davidWallet} = await loadFixture(deployIdentityFixture);

    await expect(identityFactory.connect(deployerWallet).createIdentity(davidWallet, '')).to.be.revertedWith('invalid argument - empty string');
  });

  it('should revert because salt cannot be already used', async () => {
    const {identityFactory, deployerWallet, davidWallet, carolWallet} = await loadFixture(deployIdentityFixture);

    await identityFactory.connect(deployerWallet).createIdentity(carolWallet, 'saltUsed');

    await expect(identityFactory.connect(deployerWallet).createIdentity(davidWallet, 'saltUsed')).to.be.revertedWith('salt already taken');
  });

  it('should revert because wallet is already linked to an identity', async () => {
    const {identityFactory, deployerWallet, aliceWallet} = await loadFixture(deployIdentityFixture);

    await expect(identityFactory.connect(deployerWallet).createIdentity(aliceWallet, 'newSalt')).to.be.revertedWith('wallet already linked to an identity');
  });

  describe('link/unlink wallet', () => {
    describe('linkWallet', () => {
      it('should revert for new wallet being zero address', async () => {
        const { identityFactory, aliceWallet } = await loadFixture(deployIdentityFixture);

        await expect(identityFactory.connect(aliceWallet).linkWallet(ethers.ZeroAddress)).to.be.revertedWith('invalid argument - zero address');
      });

      it('should revert for sender wallet being not linked', async () => {
        const { identityFactory, davidWallet } = await loadFixture(deployIdentityFixture);

        await expect(identityFactory.connect(davidWallet).linkWallet(davidWallet)).to.be.revertedWith('wallet not linked to an identity contract');
      });

      it('should revert for new wallet being already linked', async () => {
        const { identityFactory, bobWallet, aliceWallet } = await loadFixture(deployIdentityFixture);

        await expect(identityFactory.connect(bobWallet).linkWallet(aliceWallet)).to.be.revertedWith('new wallet already linked');
      });

      it('should revert for new wallet being already to a token identity', async () => {
        const { identityFactory, bobWallet, tokenAddress } = await loadFixture(deployIdentityFixture);

        await expect(identityFactory.connect(bobWallet).linkWallet(tokenAddress)).to.be.revertedWith('invalid argument - token address');
      });

      it('should link the new wallet to the existing identity', async () => {
        const { identityFactory, aliceIdentity, aliceWallet, davidWallet } = await loadFixture(deployIdentityFixture);

        const tx = await identityFactory.connect(aliceWallet).linkWallet(davidWallet);
        await expect(tx).to.emit(identityFactory, 'WalletLinked').withArgs(davidWallet, aliceIdentity);

        expect(await identityFactory.getWallets(aliceIdentity)).to.deep.equal([await aliceWallet.getAddress(), await davidWallet.getAddress()]);
      });
    });

    describe('unlinkWallet', () => {
      it('should revert for wallet to unlink being zero address', async () => {
        const { identityFactory, aliceWallet } = await loadFixture(deployIdentityFixture);

        await expect(identityFactory.connect(aliceWallet).unlinkWallet(ethers.ZeroAddress)).to.be.revertedWith('invalid argument - zero address');
      });

      it('should revert for sender wallet attemoting to unlink itself', async () => {
        const { identityFactory, aliceWallet } = await loadFixture(deployIdentityFixture);

        await expect(identityFactory.connect(aliceWallet).unlinkWallet(aliceWallet)).to.be.revertedWith('cannot be called on sender address');
      });

      it('should revert for sender wallet being not linked', async () => {
        const { identityFactory, aliceWallet, davidWallet } = await loadFixture(deployIdentityFixture);

        await expect(identityFactory.connect(davidWallet).unlinkWallet(aliceWallet)).to.be.revertedWith('only a linked wallet can unlink');
      });

      it('should unlink the wallet', async () => {
        const { identityFactory, aliceIdentity, aliceWallet, davidWallet } = await loadFixture(deployIdentityFixture);

        await identityFactory.connect(aliceWallet).linkWallet(davidWallet);
        const tx = await identityFactory.connect(aliceWallet).unlinkWallet(davidWallet);
        await expect(tx).to.emit(identityFactory, 'WalletUnlinked').withArgs(davidWallet, aliceIdentity);

        expect(await identityFactory.getWallets(aliceIdentity)).to.deep.equal([await aliceWallet.getAddress()]);
      });
    });
  });

  describe('createIdentityWithManagementKeys()', () => {
    describe('when no management keys are provided', () => {
      it('should revert', async () => {
        const {identityFactory, deployerWallet, davidWallet} = await loadFixture(deployIdentityFixture);

        await expect(identityFactory.connect(deployerWallet).createIdentityWithManagementKeys(davidWallet, 'salt1', [])).to.be.revertedWith('invalid argument - empty list of keys');
      });
    });

    describe('when the wallet is included in the management keys listed', () => {
      it('should revert', async () => {
        const {identityFactory, deployerWallet, aliceWallet, davidWallet} = await loadFixture(deployIdentityFixture);

        await expect(identityFactory.connect(deployerWallet).createIdentityWithManagementKeys(davidWallet, 'salt1', [
          ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(['address'], [await aliceWallet.getAddress()])),
          ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(['address'], [await davidWallet.getAddress()])),
        ])).to.be.revertedWith('invalid argument - wallet is also listed in management keys');
      });
    });

    describe('when other management keys are specified', () => {
      it('should deploy the identity proxy, set keys and wallet as management, and link wallet to identity', async () => {
        const {identityFactory, deployerWallet, aliceWallet, davidWallet} = await loadFixture(deployIdentityFixture);

        const tx = await identityFactory.connect(deployerWallet).createIdentityWithManagementKeys(davidWallet, 'salt1', [ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(['address'], [await aliceWallet.getAddress()]))]);

        await expect(tx).to.emit(identityFactory, 'WalletLinked');
        await expect(tx).to.emit(identityFactory, 'Deployed');

        const identity = await ethers.getContractAt('Identity', await identityFactory.getIdentity(davidWallet));

        await expect(tx).to.emit(identity, 'KeyAdded').withArgs(ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(['address'], [await aliceWallet.getAddress()])), 1, 1);
        await expect(identity.keyHasPurpose(
          ethers.AbiCoder.defaultAbiCoder().encode(['address'], [await identityFactory.getAddress()]),
          1
        )).to.eventually.be.false;
        await expect(identity.keyHasPurpose(
          ethers.AbiCoder.defaultAbiCoder().encode(['address'], [await davidWallet.getAddress()]),
          1
        )).to.eventually.be.false;
        await expect(identity.keyHasPurpose(
          ethers.AbiCoder.defaultAbiCoder().encode(['address'], [await aliceWallet.getAddress()]),
          1
        )).to.eventually.be.false;
      });
    });
  });
});
