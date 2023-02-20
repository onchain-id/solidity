import {expect} from "chai";
import {ethers} from "hardhat";
import {loadFixture} from "@nomicfoundation/hardhat-network-helpers";

import {deployIdentityFixture} from "../fixtures";

describe('IdFactory', () => {
  it('should revert because authority is Zero address', async () => {
    const [deployerWallet] = await ethers.getSigners();

    const IdFactory = await ethers.getContractFactory('IdFactory');
    await expect(IdFactory.connect(deployerWallet).deploy(ethers.constants.AddressZero)).to.be.revertedWith('invalid argument - zero address');
  });

  it('should revert because sender is not allowed to create identities', async () => {
    const {identityFactory, aliceWallet} = await loadFixture(deployIdentityFixture);

    await expect(identityFactory.connect(aliceWallet).createIdentity(ethers.constants.AddressZero, 'salt1')).to.be.revertedWith('Ownable: caller is not the owner');
  });

  it('should revert because wallet of identity cannot be Zero address', async () => {
    const {identityFactory, deployerWallet} = await loadFixture(deployIdentityFixture);

    await expect(identityFactory.connect(deployerWallet).createIdentity(ethers.constants.AddressZero, 'salt1')).to.be.revertedWith('invalid argument - zero address');
  });

  it('should revert because salt cannot be empty', async () => {
    const {identityFactory, deployerWallet, davidWallet} = await loadFixture(deployIdentityFixture);

    await expect(identityFactory.connect(deployerWallet).createIdentity(davidWallet.address, '')).to.be.revertedWith('invalid argument - empty string');
  });

  it('should revert because salt cannot be already used', async () => {
    const {identityFactory, deployerWallet, davidWallet, carolWallet} = await loadFixture(deployIdentityFixture);

    await identityFactory.connect(deployerWallet).createIdentity(carolWallet.address, 'saltUsed');

    await expect(identityFactory.connect(deployerWallet).createIdentity(davidWallet.address, 'saltUsed')).to.be.revertedWith('salt already taken');
  });

  it('should revert because wallet is already linked to an identity', async () => {
    const {identityFactory, deployerWallet, aliceWallet} = await loadFixture(deployIdentityFixture);

    await expect(identityFactory.connect(deployerWallet).createIdentity(aliceWallet.address, 'newSalt')).to.be.revertedWith('wallet already linked to an identity');
  });

  describe('link/unlink wallet', () => {
    describe('linkWallet', () => {
      it('should revert for new wallet being zero address', async () => {
        const { identityFactory, aliceWallet } = await loadFixture(deployIdentityFixture);

        await expect(identityFactory.connect(aliceWallet).linkWallet(ethers.constants.AddressZero)).to.be.revertedWith('invalid argument - zero address');
      });

      it('should revert for sender wallet being not linked', async () => {
        const { identityFactory, davidWallet } = await loadFixture(deployIdentityFixture);

        await expect(identityFactory.connect(davidWallet).linkWallet(davidWallet.address)).to.be.revertedWith('wallet not linked to an identity contract');
      });

      it('should revert for new wallet being already linked', async () => {
        const { identityFactory, bobWallet, aliceWallet } = await loadFixture(deployIdentityFixture);

        await expect(identityFactory.connect(bobWallet).linkWallet(aliceWallet.address)).to.be.revertedWith('new wallet already linked');
      });

      it('should revert for new wallet being already to a token identity', async () => {
        const { identityFactory, bobWallet, tokenAddress } = await loadFixture(deployIdentityFixture);

        await expect(identityFactory.connect(bobWallet).linkWallet(tokenAddress)).to.be.revertedWith('invalid argument - token address');
      });

      it('should link the new wallet to the existing identity', async () => {
        const { identityFactory, aliceIdentity, aliceWallet, davidWallet } = await loadFixture(deployIdentityFixture);

        const tx = await identityFactory.connect(aliceWallet).linkWallet(davidWallet.address);
        await expect(tx).to.emit(identityFactory, 'WalletLinked').withArgs(davidWallet.address, aliceIdentity.address);

        expect(await identityFactory.getWallets(aliceIdentity.address)).to.deep.equal([aliceWallet.address, davidWallet.address]);
      });
    });

    describe('unlinkWallet', () => {
      it('should revert for wallet to unlink being zero address', async () => {
        const { identityFactory, aliceWallet } = await loadFixture(deployIdentityFixture);

        await expect(identityFactory.connect(aliceWallet).unlinkWallet(ethers.constants.AddressZero)).to.be.revertedWith('invalid argument - zero address');
      });

      it('should revert for sender wallet attemoting to unlink itself', async () => {
        const { identityFactory, aliceWallet } = await loadFixture(deployIdentityFixture);

        await expect(identityFactory.connect(aliceWallet).unlinkWallet(aliceWallet.address)).to.be.revertedWith('cannot be called on sender address');
      });

      it('should revert for sender wallet being not linked', async () => {
        const { identityFactory, aliceWallet, davidWallet } = await loadFixture(deployIdentityFixture);

        await expect(identityFactory.connect(davidWallet).unlinkWallet(aliceWallet.address)).to.be.revertedWith('only a linked wallet can unlink');
      });

      it('should unlink the wallet', async () => {
        const { identityFactory, aliceIdentity, aliceWallet, davidWallet } = await loadFixture(deployIdentityFixture);

        await identityFactory.connect(aliceWallet).linkWallet(davidWallet.address);
        const tx = await identityFactory.connect(aliceWallet).unlinkWallet(davidWallet.address);
        await expect(tx).to.emit(identityFactory, 'WalletUnlinked').withArgs(davidWallet.address, aliceIdentity.address);

        expect(await identityFactory.getWallets(aliceIdentity.address)).to.deep.equal([aliceWallet.address]);
      });
    });
  });
});
