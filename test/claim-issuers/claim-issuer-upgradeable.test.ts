import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { expect } from 'chai';
import { ethers, upgrades } from 'hardhat';
import { deployFactoryFixture } from '../fixtures';

describe('ClaimIssuerUpgradeable', () => {
  async function deployClaimIssuerFixture() {
    const [deployerWallet, claimIssuerWallet, aliceWallet, bobWallet, carolWallet, davidWallet, tokenOwnerWallet] =
      await ethers.getSigners();

    const { identityFactory, identityImplementation, implementationAuthority } = await deployFactoryFixture();
    const ClaimIssuerUpgradeable = await ethers.getContractFactory('ClaimIssuerUpgradeable');
    const claimIssuerImplementation = await ClaimIssuerUpgradeable.connect(claimIssuerWallet).deploy(claimIssuerWallet.address, false);
    const deployedProxy = await ethers.deployContract('ClaimIssuerProxy', [claimIssuerImplementation.address, claimIssuerImplementation.interface.encodeFunctionData('initialize', [claimIssuerWallet.address])]);
    const claimIssuer = await ethers.getContractAt('ClaimIssuerUpgradeable', deployedProxy.address);
    await claimIssuer.connect(claimIssuerWallet).addKey(
      ethers.utils.keccak256(
        ethers.utils.defaultAbiCoder.encode(['address'], [claimIssuerWallet.address])
      ),
      3,
      1
    );

    await identityFactory.connect(deployerWallet).createIdentity(aliceWallet.address, 'alice');
    const aliceIdentity = await ethers.getContractAt('Identity', await identityFactory.getIdentity(aliceWallet.address));
    await aliceIdentity.connect(aliceWallet).addKey(ethers.utils.keccak256(
      ethers.utils.defaultAbiCoder.encode(['address'], [carolWallet.address])
    ), 3, 1);
    await aliceIdentity.connect(aliceWallet).addKey(ethers.utils.keccak256(
      ethers.utils.defaultAbiCoder.encode(['address'], [davidWallet.address])
    ), 2, 1);
    const aliceClaim666 = {
      id: '',
      identity: aliceIdentity.address,
      issuer: claimIssuer.address,
      topic: 666,
      scheme: 1,
      data: '0x0042',
      signature: '',
      uri: 'https://example.com'
    };
    aliceClaim666.id = ethers.utils.keccak256(ethers.utils.defaultAbiCoder.encode(['address', 'uint256'], [aliceClaim666.issuer, aliceClaim666.topic]));
    aliceClaim666.signature = await claimIssuerWallet.signMessage(ethers.utils.arrayify(ethers.utils.keccak256(ethers.utils.defaultAbiCoder.encode(['address', 'uint256', 'bytes'], [aliceClaim666.identity, aliceClaim666.topic, aliceClaim666.data]))));

    await aliceIdentity.connect(aliceWallet).addClaim(aliceClaim666.topic, aliceClaim666.scheme, aliceClaim666.issuer, aliceClaim666.signature, aliceClaim666.data, aliceClaim666.uri);

    await identityFactory.connect(deployerWallet).createIdentity(bobWallet.address, 'bob');
    const bobIdentity = await ethers.getContractAt('Identity', await identityFactory.getIdentity(bobWallet.address));

    const tokenAddress = '0xdEE019486810C7C620f6098EEcacA0244b0fa3fB';
    await identityFactory.connect(deployerWallet).createTokenIdentity(tokenAddress, tokenOwnerWallet.address, 'tokenOwner');
    return {
      identityFactory,
      identityImplementation,
      implementationAuthority,
      claimIssuer,
      aliceWallet,
      bobWallet,
      carolWallet,
      davidWallet,
      deployerWallet,
      claimIssuerWallet,
      tokenOwnerWallet,
      aliceIdentity,
      bobIdentity,
      aliceClaim666,
      tokenAddress,
      claimIssuerImplementation
    };
  }

  describe('revokeClaim (deprecated)', () => {
    describe('when calling as a non MANAGEMENT key', () => {
      it('should revert for missing permissions', async () => {
        const { claimIssuer, aliceWallet, aliceClaim666 } = await loadFixture(deployClaimIssuerFixture);

        await expect(claimIssuer.connect(aliceWallet).revokeClaim(aliceClaim666.id, aliceClaim666.identity)).to.be.revertedWith('Permissions: Sender does not have management key');
      });
    });

    describe('when calling as a MANAGEMENT key', () => {
      describe('when claim was already revoked', () => {
        it('should revert for conflict', async () => {
          const { claimIssuer, claimIssuerWallet, aliceClaim666 } = await loadFixture(deployClaimIssuerFixture);

          await claimIssuer.connect(claimIssuerWallet).revokeClaim(aliceClaim666.id, aliceClaim666.identity);

          await expect(claimIssuer.connect(claimIssuerWallet).revokeClaim(aliceClaim666.id, aliceClaim666.identity)).to.be.revertedWith('Conflict: Claim already revoked');
        });
      });

      describe('when is not revoked already', () => {
        it('should revoke the claim', async () => {
          const { claimIssuer, claimIssuerWallet, aliceClaim666 } = await loadFixture(deployClaimIssuerFixture);

          expect(await claimIssuer.isClaimValid(aliceClaim666.identity, aliceClaim666.topic, aliceClaim666.signature, aliceClaim666.data)).to.be.true;

          const tx = await claimIssuer.connect(claimIssuerWallet).revokeClaim(aliceClaim666.id, aliceClaim666.identity);

          await expect(tx).to.emit(claimIssuer, 'ClaimRevoked').withArgs(aliceClaim666.signature);

          expect(await claimIssuer.isClaimRevoked(aliceClaim666.signature)).to.be.true;
          expect(await claimIssuer.isClaimValid(aliceClaim666.identity, aliceClaim666.topic, aliceClaim666.signature, aliceClaim666.data)).to.be.false;
        });
      });
    });
  });

  describe('revokeClaimBySignature', () => {
    describe('when calling as a non MANAGEMENT key', () => {
      it('should revert for missing permissions', async () => {
        const { claimIssuer, aliceWallet, aliceClaim666 } = await loadFixture(deployClaimIssuerFixture);

        await expect(claimIssuer.connect(aliceWallet).revokeClaimBySignature(aliceClaim666.signature)).to.be.revertedWith('Permissions: Sender does not have management key');
      });
    });

    describe('when calling as a MANAGEMENT key', () => {
      describe('when claim was already revoked', () => {
        it('should revert for conflict', async () => {
          const { claimIssuer, claimIssuerWallet, aliceClaim666 } = await loadFixture(deployClaimIssuerFixture);

          await claimIssuer.connect(claimIssuerWallet).revokeClaimBySignature(aliceClaim666.signature);

          await expect(claimIssuer.connect(claimIssuerWallet).revokeClaimBySignature(aliceClaim666.signature)).to.be.revertedWith('Conflict: Claim already revoked');
        });
      });

      describe('when is not revoked already', () => {
        it('should revoke the claim', async () => {
          const { claimIssuer, claimIssuerWallet, aliceClaim666 } = await loadFixture(deployClaimIssuerFixture);

          expect(await claimIssuer.isClaimValid(aliceClaim666.identity, aliceClaim666.topic, aliceClaim666.signature, aliceClaim666.data)).to.be.true;

          const tx = await claimIssuer.connect(claimIssuerWallet).revokeClaimBySignature(aliceClaim666.signature);

          await expect(tx).to.emit(claimIssuer, 'ClaimRevoked').withArgs(aliceClaim666.signature);

          expect(await claimIssuer.isClaimRevoked(aliceClaim666.signature)).to.be.true;
          expect(await claimIssuer.isClaimValid(aliceClaim666.identity, aliceClaim666.topic, aliceClaim666.signature, aliceClaim666.data)).to.be.false;
        });
      });
    });
  });

  describe('getRecoveredAddress', () => {
    it('should return with a zero address with signature is not of proper length', async () => {
      const { claimIssuer, aliceClaim666 } = await loadFixture(deployClaimIssuerFixture);

      expect(await claimIssuer.getRecoveredAddress(aliceClaim666.signature + '00', ethers.utils.arrayify(ethers.utils.keccak256(ethers.utils.defaultAbiCoder.encode(['address', 'uint256', 'bytes'], [aliceClaim666.identity, aliceClaim666.topic, aliceClaim666.data]))))).to.be.equal(ethers.constants.AddressZero);
    });
  });

  describe('upgradeTo', () => {
    describe('when UPGRADE key is missing', () => {
      it('should revert', async () => {
        const {
          claimIssuer,
          claimIssuerWallet,
          aliceWallet
        } = await loadFixture(deployClaimIssuerFixture);

        const TestUpgradedClaimIssuer = await ethers.getContractFactory('TestUpgradedClaimIssuer');
        const upgradedImplementation = await TestUpgradedClaimIssuer.connect(claimIssuerWallet).deploy(claimIssuerWallet.address, false);

        await expect(claimIssuer.connect(aliceWallet).upgradeTo(upgradedImplementation.address)).to.eventually.rejectedWith('Caller is not authorized to upgrade');
      });
    });

    describe('when UPGRADE key exists', () => {
      it('should upgrade proxy', async () => {
        // given
        const {
          claimIssuer,
          claimIssuerWallet,
          aliceWallet,
          aliceClaim666
        } = await loadFixture(deployClaimIssuerFixture);

        await claimIssuer.connect(claimIssuerWallet).revokeClaimBySignature(aliceClaim666.signature);

        const TestUpgradedClaimIssuer = await ethers.getContractFactory('TestUpgradedClaimIssuer');
        const upgradedImplementation = await TestUpgradedClaimIssuer.connect(claimIssuerWallet).deploy(claimIssuerWallet.address, false);
        await claimIssuer.connect(claimIssuerWallet).addKey(
          ethers.utils.keccak256(
            ethers.utils.defaultAbiCoder.encode(['address'], [aliceWallet.address])
          ),
          42,
          1
        );

        // when
        await claimIssuer.connect(aliceWallet).upgradeTo(upgradedImplementation.address).then(p => p.wait());

        // then
        const implementationAddress = await upgrades.erc1967.getImplementationAddress(claimIssuer.address);
        expect(implementationAddress).to.eq(upgradedImplementation.address);

        const upgradedProxy = await ethers.getContractAt('TestUpgradedClaimIssuer', claimIssuer.address);
        expect(await upgradedProxy.newField()).to.be.eq(0);
        await upgradedProxy.connect(claimIssuerWallet).setNewField(10);
        expect(await upgradedProxy.newField()).to.be.eq(10);

        expect(await upgradedProxy.isClaimRevoked(aliceClaim666.signature)).to.be.true;
      });
    });
  });
});
