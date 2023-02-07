import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { expect } from "chai";
import {ethers} from "hardhat";

import { deployIdentityFixture } from '../fixtures';

describe('Identity', () => {
  it('should revert when attempting to initialize an already deployed identity', async () => {
    const { aliceIdentity, aliceWallet } = await loadFixture(deployIdentityFixture);

    await expect(aliceIdentity.connect(aliceWallet).initialize(aliceWallet.address)).to.be.revertedWith('Initial key was already setup.');
  });
});
