import {expect} from "chai";
import {ethers} from "hardhat";
import {loadFixture} from "@nomicfoundation/hardhat-network-helpers";
import {deployIdentityFixture} from "./fixtures";

describe('Proxy', () => {
  it('should revert because implementation is Zero address', async () => {
    const [deployerWallet, identityOwnerWallet] = await ethers.getSigners();

    const IdentityProxy = await ethers.getContractFactory('IdentityProxy');
    await expect(IdentityProxy.connect(deployerWallet).deploy(ethers.constants.AddressZero, identityOwnerWallet.address)).to.be.revertedWith('invalid argument - zero address');
  });

  it('should revert because implementation is not an identity', async () => {
    const [deployerWallet, identityOwnerWallet] = await ethers.getSigners();

    const claimIssuer = await ethers.deployContract('Test');

    const authority = await ethers.deployContract('ImplementationAuthority', [claimIssuer.address]);

    const IdentityProxy = await ethers.getContractFactory('IdentityProxy');
    await expect(IdentityProxy.connect(deployerWallet).deploy(authority.address, identityOwnerWallet.address)).to.be.revertedWith('Initialization failed.');
  });

  it('should revert because initial key is Zero address', async () => {
    const [deployerWallet] = await ethers.getSigners();

    const implementation = await ethers.deployContract('Identity', [deployerWallet.address, true]);
    const implementationAuthority = await ethers.deployContract('ImplementationAuthority', [implementation.address]);

    const IdentityProxy = await ethers.getContractFactory('IdentityProxy');
    await expect(IdentityProxy.connect(deployerWallet).deploy(implementationAuthority.address, ethers.constants.AddressZero)).to.be.revertedWith('invalid argument - zero address');
  });

  it('should prevent creating an implementation authority with a zero address implementation', async () => {
    const [deployerWallet] = await ethers.getSigners();

    const ImplementationAuthority = await ethers.getContractFactory('ImplementationAuthority');
    await expect(ImplementationAuthority.connect(deployerWallet).deploy(ethers.constants.AddressZero)).to.be.revertedWith('invalid argument - zero address');
  });

  it('should prevent updating to a Zero address implementation', async () => {
    const {implementationAuthority, deployerWallet} = await loadFixture(deployIdentityFixture);

    await expect(implementationAuthority.connect(deployerWallet).updateImplementation(ethers.constants.AddressZero)).to.be.revertedWith('invalid argument - zero address');
  });

  it('should prevent updating when not owner', async () => {
    const {implementationAuthority, aliceWallet} = await loadFixture(deployIdentityFixture);

    await expect(implementationAuthority.connect(aliceWallet).updateImplementation(ethers.constants.AddressZero)).to.be.revertedWith('Ownable: caller is not the owner');
  });

  it('should update the implementation address', async () => {
    const [deployerWallet] = await ethers.getSigners();

    const implementation = await ethers.deployContract('Identity', [deployerWallet.address, true]);
    const implementationAuthority = await ethers.deployContract('ImplementationAuthority', [implementation.address]);

    const newImplementation = await ethers.deployContract('Identity', [deployerWallet.address, true]);

    const tx = await implementationAuthority.connect(deployerWallet).updateImplementation(newImplementation.address);
    await expect(tx).to.emit(implementationAuthority, 'UpdatedImplementation').withArgs(newImplementation.address);
  });
});
