import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { expect } from "chai";
import {ethers} from "hardhat";

import {deployFactoryFixture, deployIdentityFixture} from "../fixtures";

describe('IdFactory', () => {
  describe('add/remove Token factory', () => {
    it('should manipulate Token factory list', async () => {
      const { identityFactory, deployerWallet, aliceWallet, bobWallet } = await loadFixture(deployFactoryFixture);

      await expect(identityFactory.connect(aliceWallet).addTokenFactory(aliceWallet.address)).to.be.revertedWith('Ownable: caller is not the owner');

      await expect(identityFactory.connect(deployerWallet).addTokenFactory(ethers.constants.AddressZero)).to.be.revertedWith('invalid argument - zero address');

      const addTx = await identityFactory.connect(deployerWallet).addTokenFactory(aliceWallet.address);
      await expect(addTx).to.emit(identityFactory, 'TokenFactoryAdded').withArgs(aliceWallet.address);

      await expect(identityFactory.connect(deployerWallet).addTokenFactory(aliceWallet.address)).to.be.revertedWith('already a factory');

      await expect(identityFactory.connect(deployerWallet).removeTokenFactory(bobWallet.address)).to.be.revertedWith('not a factory');

      const removeTx = await identityFactory.connect(deployerWallet).removeTokenFactory(aliceWallet.address);
      await expect(removeTx).to.emit(identityFactory, 'TokenFactoryRemoved').withArgs(aliceWallet.address);
    });
  });

  describe('createTokenIdentity', () => {
    it('should revert for being not authorized to deploy token', async () => {
      const { identityFactory, aliceWallet } = await loadFixture(deployFactoryFixture);

      await expect(identityFactory.connect(aliceWallet).createTokenIdentity(aliceWallet.address, aliceWallet.address, 'TST')).to.be.revertedWith('only Factory or owner can call');
    });

    it('should revert for token address being zero address', async () => {
      const { identityFactory, deployerWallet, aliceWallet } = await loadFixture(deployFactoryFixture);

      await expect(identityFactory.connect(deployerWallet).createTokenIdentity(ethers.constants.AddressZero, aliceWallet.address, 'TST')).to.be.revertedWith('invalid argument - zero address');
    });

    it('should revert for owner being zero address', async () => {
      const { identityFactory, deployerWallet, aliceWallet } = await loadFixture(deployFactoryFixture);

      await expect(identityFactory.connect(deployerWallet).createTokenIdentity(aliceWallet.address, ethers.constants.AddressZero, 'TST')).to.be.revertedWith('invalid argument - zero address');
    });

    it('should revert for salt being empty', async () => {
      const { identityFactory, deployerWallet, aliceWallet } = await loadFixture(deployFactoryFixture);

      await expect(identityFactory.connect(deployerWallet).createTokenIdentity(aliceWallet.address, aliceWallet.address, '')).to.be.revertedWith('invalid argument - empty string');
    });

    it('should create one identity and then revert for salt/address being already used', async () => {
      const { identityFactory, deployerWallet, aliceWallet, bobWallet } = await loadFixture(deployFactoryFixture);

      expect(await identityFactory.isSaltTaken('Tokensalt1')).to.be.false;

      const tx = await identityFactory.connect(deployerWallet).createTokenIdentity(aliceWallet.address, bobWallet.address, 'salt1');
      const tokenIdentityAddress = await identityFactory.getIdentity(aliceWallet.address);
      await expect(tx).to.emit(identityFactory, 'TokenLinked').withArgs(aliceWallet.address, tokenIdentityAddress);
      await expect(tx).to.emit(identityFactory, 'Deployed').withArgs(tokenIdentityAddress);

      expect(await identityFactory.isSaltTaken('Tokensalt1')).to.be.true;
      expect(await identityFactory.isSaltTaken('Tokensalt2')).to.be.false;
      expect(await identityFactory.getToken(tokenIdentityAddress)).to.deep.equal(aliceWallet.address);

      await expect(identityFactory.connect(deployerWallet).createTokenIdentity(aliceWallet.address, aliceWallet.address, 'salt1')).to.be.revertedWith('salt already taken');
      await expect(identityFactory.connect(deployerWallet).createTokenIdentity(aliceWallet.address, aliceWallet.address, 'salt2')).to.be.revertedWith('token already linked to an identity');
    });
  });

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
