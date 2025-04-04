import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { expect } from "chai";
import { ethers } from "hardhat";

import { deployIdentityFixture } from '../fixtures';
import { KeyPurposes, KeyTypes } from '../constants';

describe('Identity', () => {
  describe('Key Management', () => {
    describe('Read key methods', () => {
      it('should retrieve an existing key', async () => {
        const { aliceIdentity, aliceWallet } = await loadFixture(deployIdentityFixture);

        const aliceKeyHash = ethers.keccak256(
          ethers.AbiCoder.defaultAbiCoder().encode(['address'], [aliceWallet.address])
        );
        const aliceKey = await aliceIdentity.getKey(aliceKeyHash);
        expect(aliceKey.key).to.equal(aliceKeyHash);
        expect(aliceKey.purposes).to.deep.equal([KeyPurposes.MANAGEMENT]);
        expect(aliceKey.keyType).to.equal(KeyTypes.ECDSA);
      });

      it('should retrieve existing key purposes', async () => {
        const { aliceIdentity, aliceWallet } = await loadFixture(deployIdentityFixture);

        const aliceKeyHash = ethers.keccak256(
          ethers.AbiCoder.defaultAbiCoder().encode(['address'], [aliceWallet.address])
        );
        const purposes = await aliceIdentity.getKeyPurposes(aliceKeyHash);
        expect(purposes).to.deep.equal([KeyPurposes.MANAGEMENT]);
      });

      it('should retrieve existing keys with given purpose', async () => {
        const { aliceIdentity, aliceWallet } = await loadFixture(deployIdentityFixture);

        const aliceKeyHash = ethers.keccak256(
          ethers.AbiCoder.defaultAbiCoder().encode(['address'], [aliceWallet.address])
        );
        const keys = await aliceIdentity.getKeysByPurpose(KeyPurposes.MANAGEMENT);
        expect(keys).to.deep.equal([aliceKeyHash]);
      });

      it('should return true if a key has a given purpose', async () => {
        const { aliceIdentity, aliceWallet } = await loadFixture(deployIdentityFixture);

        const aliceKeyHash = ethers.keccak256(
          ethers.AbiCoder.defaultAbiCoder().encode(['address'], [aliceWallet.address])
        );
        const hasPurpose = await aliceIdentity.keyHasPurpose(aliceKeyHash, KeyPurposes.MANAGEMENT);
        expect(hasPurpose).to.equal(true);
      });

      it('should return false if a key has not a given purpose but is a MANAGEMENT key', async () => {
        const { aliceIdentity, aliceWallet } = await loadFixture(deployIdentityFixture);

        const aliceKeyHash = ethers.keccak256(
          ethers.AbiCoder.defaultAbiCoder().encode(['address'], [aliceWallet.address])
        );
        const hasPurpose = await aliceIdentity.keyHasPurpose(aliceKeyHash, KeyPurposes.ACTION);
        expect(hasPurpose).to.equal(true);
      });

      it('should return false if a key has not a given purpose', async () => {
        const { aliceIdentity, bobWallet } = await loadFixture(deployIdentityFixture);

        const bobKeyHash = ethers.keccak256(
          ethers.AbiCoder.defaultAbiCoder().encode(['address'], [bobWallet.address])
        );
        const hasPurpose = await aliceIdentity.keyHasPurpose(bobKeyHash, KeyPurposes.ACTION);
        expect(hasPurpose).to.equal(false);
      });
    });

    describe('Add key methods', () => {
      describe('when calling as a non-MANAGEMENT key', () => {
        it('should revert because the signer is not a MANAGEMENT key', async () => {
          const { aliceIdentity, bobWallet } = await loadFixture(deployIdentityFixture);

          const bobKeyHash = ethers.keccak256(
            ethers.AbiCoder.defaultAbiCoder().encode(['address'], [bobWallet.address])
          );
          await expect(
            aliceIdentity.connect(bobWallet).addKey(bobKeyHash, KeyPurposes.MANAGEMENT, KeyTypes.ECDSA)
          ).to.be.revertedWithCustomError(aliceIdentity, 'SenderDoesNotHaveManagementKey');
        });
      });

      describe('when calling as a MANAGEMENT key', () => {
        it('should add the purpose to the existing key', async () => {
          const { aliceIdentity, aliceWallet } = await loadFixture(deployIdentityFixture);

          const aliceKeyHash = ethers.keccak256(
            ethers.AbiCoder.defaultAbiCoder().encode(['address'], [aliceWallet.address])
          );
          await aliceIdentity.connect(aliceWallet).addKey(aliceKeyHash, KeyPurposes.ACTION, KeyTypes.ECDSA);
          const aliceKey = await aliceIdentity.getKey(aliceKeyHash);
          expect(aliceKey.key).to.equal(aliceKeyHash);
          expect(aliceKey.purposes).to.deep.equal([KeyPurposes.MANAGEMENT, KeyPurposes.ACTION]);
          expect(aliceKey.keyType).to.equal(KeyTypes.ECDSA);
        });

        it('should add a new key with a purpose', async () => {
          const { aliceIdentity, bobWallet, aliceWallet } = await loadFixture(deployIdentityFixture);

          const bobKeyHash = ethers.keccak256(
            ethers.AbiCoder.defaultAbiCoder().encode(['address'], [bobWallet.address])
          );
          await aliceIdentity.connect(aliceWallet).addKey(bobKeyHash, KeyPurposes.MANAGEMENT, KeyTypes.ECDSA);
          const bobKey = await aliceIdentity.getKey(bobKeyHash);
          expect(bobKey.key).to.equal(bobKeyHash);
          expect(bobKey.purposes).to.deep.equal([KeyPurposes.MANAGEMENT]);
          expect(bobKey.keyType).to.equal(KeyTypes.ECDSA);
        });

        it('should revert because key already has the purpose', async () => {
          const { aliceIdentity, aliceWallet } = await loadFixture(deployIdentityFixture);

          const aliceKeyHash = ethers.keccak256(
            ethers.AbiCoder.defaultAbiCoder().encode(['address'], [aliceWallet.address])
          );
          await expect(
            aliceIdentity.connect(aliceWallet).addKey(aliceKeyHash, KeyPurposes.MANAGEMENT, KeyTypes.ECDSA)
          ).to.be.revertedWithCustomError(aliceIdentity, 'KeyAlreadyHasPurpose');
        });
      });
    });

    describe('Remove key methods', () => {
      describe('when calling as a non-MANAGEMENT key', () => {
        it('should revert because the signer is not a MANAGEMENT key', async () => {
          const { aliceIdentity, aliceWallet, bobWallet } = await loadFixture(deployIdentityFixture);

          const aliceKeyHash = ethers.keccak256(
            ethers.AbiCoder.defaultAbiCoder().encode(['address'], [aliceWallet.address])
          );
          await expect(
            aliceIdentity.connect(bobWallet).removeKey(aliceKeyHash, KeyPurposes.MANAGEMENT)
          ).to.be.revertedWithCustomError(aliceIdentity, 'SenderDoesNotHaveManagementKey');
        });
      });

      describe('when calling as a MANAGEMENT key', () => {
        it('should remove the purpose from the existing key', async () => {
          const { aliceIdentity, aliceWallet } = await loadFixture(deployIdentityFixture);

          const aliceKeyHash = ethers.keccak256(
            ethers.AbiCoder.defaultAbiCoder().encode(['address'], [aliceWallet.address])
          );
          await aliceIdentity.connect(aliceWallet).removeKey(aliceKeyHash, 1);
          const aliceKey = await aliceIdentity.getKey(aliceKeyHash);
          expect(aliceKey.key).to.equal('0x0000000000000000000000000000000000000000000000000000000000000000');
          expect(aliceKey.purposes).to.deep.equal([]);
          expect(aliceKey.keyType).to.equal(0);
        });

        it('should revert because key does not exists', async () => {
          const { aliceIdentity, aliceWallet, bobWallet } = await loadFixture(deployIdentityFixture);

          const bobKeyHash = ethers.keccak256(
            ethers.AbiCoder.defaultAbiCoder().encode(['address'], [bobWallet.address])
          );
          await expect(
            aliceIdentity.connect(aliceWallet).removeKey(bobKeyHash, KeyPurposes.ACTION)
          ).to.be.revertedWithCustomError(aliceIdentity, 'KeyNotRegistered');
        });

        it('should revert because key does not have the purpose', async () => {
          const { aliceIdentity, aliceWallet } = await loadFixture(deployIdentityFixture);

          const aliceKeyHash = ethers.keccak256(
            ethers.AbiCoder.defaultAbiCoder().encode(['address'], [aliceWallet.address])
          );
          await expect(
            aliceIdentity.connect(aliceWallet).removeKey(aliceKeyHash, KeyPurposes.ACTION)
          ).to.be.revertedWithCustomError(aliceIdentity, 'KeyDoesNotHavePurpose');
        });
      });
    });
  });
});
