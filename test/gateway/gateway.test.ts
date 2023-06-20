import {ethers} from "hardhat";
import {expect} from "chai";
import {loadFixture} from "@nomicfoundation/hardhat-network-helpers";
import {deployFactoryFixture} from "../fixtures";

describe('Gateway', () => {
  describe('constructor', () => {
    describe('when factory address is not specified', () => {
      it('should revert', async () => {
        await expect(ethers.deployContract('Gateway', [ethers.constants.AddressZero, false, []])).to.be.reverted;
      });
    });
  });

  describe('.deployIdentity()', () => {
    describe('when Gateway requires signature', () => {
      describe('when signature is not valid', () => {
        it('should revert with UnsignedDeployment', async () => {
          const { identityFactory, aliceWallet, carolWallet } = await loadFixture(deployFactoryFixture);
          const gateway = await ethers.deployContract('Gateway', [identityFactory.address, true, [carolWallet.address]]);

          await expect(gateway.deployIdentity(aliceWallet.address, 'saltToUse', ethers.utils.randomBytes(65))).to.be.reverted;
        });
      });

      describe('when signature is signed by a non authorized signer', () => {
        it('should revert with UnsignedDeployment', async () => {
          const { identityFactory, aliceWallet, bobWallet, carolWallet } = await loadFixture(deployFactoryFixture);
          const gateway = await ethers.deployContract('Gateway', [identityFactory.address, true, [carolWallet.address]]);

          await expect(
            gateway.deployIdentity(
              aliceWallet.address,
              'saltToUse',
              bobWallet.signMessage(
                ethers.utils.keccak256(ethers.utils.defaultAbiCoder.encode(['address', 'string'], [aliceWallet.address, 'saltToUse'])),
              ),
            ),
          ).to.be.revertedWithCustomError(gateway, 'UnapprovedSigner');
        });
      });

      describe('when signature is correct and signed by an authorized signer', () => {
        it('should deploy the identity', async () => {
          const { identityFactory, aliceWallet, carolWallet } = await loadFixture(deployFactoryFixture);
          const gateway = await ethers.deployContract('Gateway', [identityFactory.address, true, [carolWallet.address]]);
          await identityFactory.transferOwnership(gateway.address);

          const digest =
            ethers.utils.keccak256(
              ethers.utils.defaultAbiCoder.encode(
                ['string', 'address', 'string'],
                ['Authorize ONCHAINID deployment', aliceWallet.address, 'saltToUse'],
              ),
          );
          const signature = await carolWallet.signMessage(
            ethers.utils.arrayify(
              digest,
            ),
          );

          const tx = await gateway.deployIdentity(
            aliceWallet.address,
            'saltToUse',
            signature,
          );
          await expect(tx).to.emit(identityFactory, "WalletLinked").withArgs(aliceWallet.address, await identityFactory.getIdentity(aliceWallet.address));
          await expect(tx).to.emit(identityFactory, "Deployed").withArgs(await identityFactory.getIdentity(aliceWallet.address));
          const identityAddress = await identityFactory.getIdentity(aliceWallet.address);
          const identity = await ethers.getContractAt('Identity', identityAddress);
          expect(await identity.keyHasPurpose(ethers.utils.keccak256(ethers.utils.defaultAbiCoder.encode(['address'], [aliceWallet.address])), 1)).to.be.true;
        });
      });

      describe('when signature is correct and signed by an authorized signer, but revoked', () => {
        it('should revert', async () => {
          const { identityFactory, aliceWallet, bobWallet, carolWallet } = await loadFixture(deployFactoryFixture);
          const gateway = await ethers.deployContract('Gateway', [identityFactory.address, true, [carolWallet.address]]);
          await identityFactory.transferOwnership(gateway.address);

          const digest =
            ethers.utils.keccak256(
              ethers.utils.defaultAbiCoder.encode(
                ['string', 'address', 'string'],
                ['Authorize ONCHAINID deployment', aliceWallet.address, 'saltToUse'],
              ),
            );
          const signature = await carolWallet.signMessage(
            ethers.utils.arrayify(
              digest,
            ),
          );

          await gateway.revokeSignature(signature);

          await expect(gateway.deployIdentity(
            aliceWallet.address,
            'saltToUse',
            signature,
          )).to.be.revertedWithCustomError(gateway, 'RevokedSignature');
        });
      });
    });
  });
});
