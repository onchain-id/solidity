import {expect} from "chai";
import {ethers} from "hardhat";

describe('Proxy', () => {
  it('should revert because implementation is Zero address', async () => {
    const [deployerWallet, identityOwnerWallet] = await ethers.getSigners();

    const IdentityProxy = await ethers.getContractFactory('IdentityProxy');
    await expect(IdentityProxy.connect(deployerWallet).deploy(ethers.constants.AddressZero, identityOwnerWallet.address)).to.be.revertedWith('invalid argument - zero address');
  });

  it('should revert because initial key is Zero address', async () => {
    const [deployerWallet] = await ethers.getSigners();

    const implementation = await ethers.deployContract('Identity', [deployerWallet.address, true]);
    const implementationAuthority = await ethers.deployContract('ImplementationAuthority', [implementation.address]);

    const IdentityProxy = await ethers.getContractFactory('IdentityProxy');
    await expect(IdentityProxy.connect(deployerWallet).deploy(implementationAuthority.address, ethers.constants.AddressZero)).to.be.revertedWith('invalid argument - zero address');
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
