import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { expect } from "chai";
import {ethers} from "hardhat";

import {deployFactoryFixture, deployIdentityFixture} from "../fixtures";

describe('IdFactory', () => {
  describe('add/remove Token factory', () => {
    it('should manipulate Token factory list', async () => {
      const { identityFactory, deployerWallet, aliceWallet, bobWallet } = await loadFixture(deployFactoryFixture);

      await expect(identityFactory.connect(aliceWallet).addTokenFactory(aliceWallet)).to.be.revertedWithCustomError(identityFactory, 'OwnableUnauthorizedAccount');

      await expect(identityFactory.connect(deployerWallet).addTokenFactory(ethers.ZeroAddress)).to.be.revertedWith('invalid argument - zero address');

      const addTx = await identityFactory.connect(deployerWallet).addTokenFactory(aliceWallet);
      await expect(addTx).to.emit(identityFactory, 'TokenFactoryAdded').withArgs(aliceWallet);

      await expect(identityFactory.connect(deployerWallet).addTokenFactory(aliceWallet)).to.be.revertedWith('already a factory');

      await expect(identityFactory.connect(aliceWallet).removeTokenFactory(bobWallet)).to.be.revertedWithCustomError(identityFactory, 'OwnableUnauthorizedAccount');

      await expect(identityFactory.connect(deployerWallet).removeTokenFactory(ethers.ZeroAddress)).to.be.revertedWith('invalid argument - zero address');

      await expect(identityFactory.connect(deployerWallet).removeTokenFactory(bobWallet)).to.be.revertedWith('not a factory');

      const removeTx = await identityFactory.connect(deployerWallet).removeTokenFactory(aliceWallet);
      await expect(removeTx).to.emit(identityFactory, 'TokenFactoryRemoved').withArgs(aliceWallet);
    });
  });

  describe('createTokenIdentity', () => {
    it('should revert for being not authorized to deploy token', async () => {
      const { identityFactory, aliceWallet } = await loadFixture(deployFactoryFixture);

      await expect(identityFactory.connect(aliceWallet).createTokenIdentity(aliceWallet, aliceWallet, 'TST')).to.be.revertedWith('only Factory or owner can call');
    });

    it('should revert for token address being zero address', async () => {
      const { identityFactory, deployerWallet, aliceWallet } = await loadFixture(deployFactoryFixture);

      await expect(identityFactory.connect(deployerWallet).createTokenIdentity(ethers.ZeroAddress, aliceWallet, 'TST')).to.be.revertedWith('invalid argument - zero address');
    });

    it('should revert for owner being zero address', async () => {
      const { identityFactory, deployerWallet, aliceWallet } = await loadFixture(deployFactoryFixture);

      await expect(identityFactory.connect(deployerWallet).createTokenIdentity(aliceWallet, ethers.ZeroAddress, 'TST')).to.be.revertedWith('invalid argument - zero address');
    });

    it('should revert for salt being empty', async () => {
      const { identityFactory, deployerWallet, aliceWallet } = await loadFixture(deployFactoryFixture);

      await expect(identityFactory.connect(deployerWallet).createTokenIdentity(aliceWallet, aliceWallet, '')).to.be.revertedWith('invalid argument - empty string');
    });

    it('should create one identity and then revert for salt/address being already used', async () => {
      const { identityFactory, deployerWallet, aliceWallet, bobWallet } = await loadFixture(deployFactoryFixture);

      expect(await identityFactory.isSaltTaken('Tokensalt1')).to.be.false;

      const tx = await identityFactory.connect(deployerWallet).createTokenIdentity(aliceWallet, bobWallet, 'salt1');
      const tokenIdentityAddress = await identityFactory.getIdentity(aliceWallet);
      await expect(tx).to.emit(identityFactory, 'TokenLinked').withArgs(aliceWallet, tokenIdentityAddress);
      await expect(tx).to.emit(identityFactory, 'Deployed').withArgs(tokenIdentityAddress);

      expect(await identityFactory.isSaltTaken('Tokensalt1')).to.be.true;
      expect(await identityFactory.isSaltTaken('Tokensalt2')).to.be.false;
      expect(await identityFactory.getToken(tokenIdentityAddress)).to.deep.equal(await aliceWallet.getAddress());

      await expect(identityFactory.connect(deployerWallet).createTokenIdentity(aliceWallet, aliceWallet, 'salt1')).to.be.revertedWith('salt already taken');
      await expect(identityFactory.connect(deployerWallet).createTokenIdentity(aliceWallet, aliceWallet, 'salt2')).to.be.revertedWith('token already linked to an identity');
    });
  });
});
