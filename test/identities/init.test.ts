import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { expect } from "chai";
import { ethers } from "hardhat";

import { deployIdentityFixture } from '../fixtures';

describe('Identity', () => {
  it('should revert when attempting to initialize an already deployed identity', async () => {
    const {aliceIdentity, aliceWallet} = await loadFixture(deployIdentityFixture);

    await expect(aliceIdentity.connect(aliceWallet).initialize(aliceWallet.address)).to.be.revertedWithCustomError(aliceIdentity, 'InitialKeyAlreadySetup');
  });

  it('should revert because interaction with library is forbidden', async () => {
    const {identityImplementation, aliceWallet, deployerWallet} = await loadFixture(deployIdentityFixture);

    await expect(identityImplementation.connect(deployerWallet).addKey(
      ethers.keccak256(
        ethers.AbiCoder.defaultAbiCoder().encode(['address'], [aliceWallet.address])
      ),
      3,
      1,
    )).to.be.revertedWithCustomError(identityImplementation, 'InteractingWithLibraryContractForbidden');

    await expect(identityImplementation.connect(aliceWallet).initialize(deployerWallet.address))
      .to.be.revertedWithCustomError(identityImplementation, 'InitialKeyAlreadySetup');
  });

  it('should prevent creating an identity with an invalid initial key', async () => {
    const [identityOwnerWallet] = await ethers.getSigners();

    const Identity = await ethers.getContractFactory('Identity');
    await expect(Identity.connect(identityOwnerWallet).deploy(ethers.ZeroAddress, false)).to.be.revertedWithCustomError(Identity, 'ZeroAddress');
  });

  it('should return the version of the implementation', async () => {
    const {identityImplementation} = await loadFixture(deployIdentityFixture);
    expect(await identityImplementation.version()).to.equal('2.2.2');
  });
});
