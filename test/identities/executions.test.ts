import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { expect } from "chai";
import { ethers } from "hardhat";

import { deployIdentityFixture } from '../fixtures';

describe('Identity', () => {
  describe('Execute', () => {
    describe('when calling execute as a MANAGEMENT key', () => {
      describe('when execution is possible (transferring value with enough funds on the identity)', () => {
        it('should execute immediately the action', async () => {
          const { aliceIdentity, aliceWallet, carolWallet } = await loadFixture(deployIdentityFixture);

          const previousBalance = await ethers.provider.getBalance(carolWallet.address);
          const action = {
            to: carolWallet.address,
            value: 10n,
            data: '0x',
          };

          const tx = await aliceIdentity.connect(aliceWallet).execute(action.to, action.value, action.data, { value: action.value });
          await expect(tx).to.emit(aliceIdentity, 'Approved');
          await expect(tx).to.emit(aliceIdentity, 'Executed');
          const newBalance = await ethers.provider.getBalance(carolWallet.address);

          expect(newBalance).to.equal(previousBalance + action.value);
        });
      });

      describe('when execution is possible (successfull call)', () => {
        it('should emit Executed', async () => {
          const { aliceIdentity, aliceWallet } = await loadFixture(deployIdentityFixture);

          const aliceKeyHash = ethers.keccak256(
            ethers.AbiCoder.defaultAbiCoder().encode(['address'], [aliceWallet.address])
          );

          const action = {
            to: aliceIdentity.target,
            value: 0,
            data: aliceIdentity.interface.encodeFunctionData('addKey', [
              aliceKeyHash,
              3,
              1,
            ]),
          };

          const tx = await aliceIdentity.connect(aliceWallet).execute(action.to, action.value, action.data);
          await expect(tx).to.emit(aliceIdentity, 'Approved');
          await expect(tx).to.emit(aliceIdentity, 'Executed');

          const purposes = await aliceIdentity.getKeyPurposes(aliceKeyHash);
          expect(purposes).to.deep.equal([1, 3]);
        });
      });

      describe('when execution is not possible (failing call)', () => {
        it('should emit an ExecutionFailed event', async () => {
          const { aliceIdentity, aliceWallet, carolWallet } = await loadFixture(deployIdentityFixture);

          const previousBalance = await ethers.provider.getBalance(carolWallet.address);
          const action = {
            to: aliceIdentity.target,
            value: 0n,
            data: aliceIdentity.interface.encodeFunctionData('addKey', [
              ethers.keccak256(
                ethers.AbiCoder.defaultAbiCoder().encode(['address'], [aliceWallet.address])
              ),
              1,
              1,
            ]),
          };

          const tx = await aliceIdentity.connect(aliceWallet).execute(action.to, action.value, action.data);
          await expect(tx).to.emit(aliceIdentity, 'Approved');
          await expect(tx).to.emit(aliceIdentity, 'ExecutionFailed');
          const newBalance = await ethers.provider.getBalance(carolWallet.address);

          expect(newBalance).to.equal(previousBalance + action.value);
        });
      });
    });

    describe('when calling execute as an ACTION key', () => {
      describe('when target is the identity contract', () => {
        it('should create an execution request', async () => {
          const { aliceIdentity, aliceWallet, bobWallet, carolWallet } = await loadFixture(deployIdentityFixture);

          const aliceKeyHash = ethers.keccak256(
            ethers.AbiCoder.defaultAbiCoder().encode(['address'], [aliceWallet.address])
          );
          const carolKeyHash = ethers.keccak256(
            ethers.AbiCoder.defaultAbiCoder().encode(['address'], [carolWallet.address])
          );
          await aliceIdentity.connect(aliceWallet).addKey(carolKeyHash, 2, 1);

          const action = {
            to: aliceIdentity.target,
            value: 0n,
            data: aliceIdentity.interface.encodeFunctionData('addKey', [
              aliceKeyHash,
              2,
              1,
            ]),
          };

          const tx = await aliceIdentity.connect(carolWallet).execute(action.to, action.value, action.data, { value: action.value });
          await expect(tx).to.emit(aliceIdentity, 'ExecutionRequested');
        });
      });

      describe('when target is another address', () => {
        it('should emit ExecutionFailed for a failed execution', async () => {
          const { aliceIdentity, aliceWallet, carolWallet, davidWallet, bobIdentity } = await loadFixture(deployIdentityFixture);

          const carolKeyHash = ethers.keccak256(
            ethers.AbiCoder.defaultAbiCoder().encode(['address'], [carolWallet.address])
          );
          await aliceIdentity.connect(aliceWallet).addKey(carolKeyHash, 2, 1);

          const aliceKeyHash = ethers.keccak256(
            ethers.AbiCoder.defaultAbiCoder().encode(['address'], [aliceWallet.address])
          );

          const action = {
            to: bobIdentity.target,
            value: 10n,
            data: aliceIdentity.interface.encodeFunctionData('addKey', [
              aliceKeyHash,
              3,
              1,
            ]),
          };

          const previousBalance = await ethers.provider.getBalance(bobIdentity.target);

          const tx = await aliceIdentity.connect(carolWallet).execute(action.to, action.value, action.data, { value: action.value });
          await expect(tx).to.emit(aliceIdentity, 'Approved');
          await expect(tx).to.emit(aliceIdentity, 'ExecutionFailed');
          const newBalance = await ethers.provider.getBalance(bobIdentity.target);

          expect(newBalance).to.equal(previousBalance);
        });

        it('should execute immediately the action', async () => {
          const { aliceIdentity, aliceWallet, carolWallet, davidWallet } = await loadFixture(deployIdentityFixture);

          const carolKeyHash = ethers.keccak256(
            ethers.AbiCoder.defaultAbiCoder().encode(['address'], [carolWallet.address])
          );
          await aliceIdentity.connect(aliceWallet).addKey(carolKeyHash, 2, 1);

          const previousBalance = await ethers.provider.getBalance(davidWallet.address);
          const action = {
            to: davidWallet.address,
            value: 10n,
            data: '0x',
          };

          const tx = await aliceIdentity.connect(carolWallet).execute(action.to, action.value, action.data, { value: action.value });
          await expect(tx).to.emit(aliceIdentity, 'Approved');
          await expect(tx).to.emit(aliceIdentity, 'Executed');
          const newBalance = await ethers.provider.getBalance(davidWallet.address);

          expect(newBalance).to.equal(previousBalance + action.value);
        });
      });
    });

    describe('when calling execute as a non-action key', () => {
      it('should create a pending execution request', async () => {
        const { aliceIdentity, bobWallet, carolWallet } = await loadFixture(deployIdentityFixture);

        const previousBalance = await ethers.provider.getBalance(carolWallet.address);
        const action = {
          to: carolWallet.address,
          value: 10n,
          data: '0x',
        };

        const tx = await aliceIdentity.connect(bobWallet).execute(action.to, action.value, action.data, { value: action.value });
        await expect(tx).to.emit(aliceIdentity, 'ExecutionRequested');
        const newBalance = await ethers.provider.getBalance(carolWallet.address);

        expect(newBalance).to.equal(previousBalance);
      });
    });
  });

  describe('Approve', () => {
    describe('when calling a non-existing execution request', () => {
      it('should revert for execution request not found', async () => {
        const { aliceIdentity, aliceWallet } = await loadFixture(deployIdentityFixture);

        await expect(aliceIdentity.connect(aliceWallet).approve(2, true)).to.be.revertedWithCustomError(aliceIdentity, 'InvalidRequestId');
      });
    });

    describe('when calling an already executed request', () => {
      it('should revert for execution request already executed', async () => {
        const { aliceIdentity, aliceWallet, bobWallet } = await loadFixture(deployIdentityFixture);

        await aliceIdentity.connect(aliceWallet).execute(bobWallet.address, 10, '0x', { value: 10 });

        await expect(aliceIdentity.connect(aliceWallet).approve(0, true)).to.be.revertedWithCustomError(aliceIdentity, 'RequestAlreadyExecuted');
      });
    });

    describe('when calling approve for an execution targeting another address as a non-action key', () => {
      it('should revert for not authorized', async () => {
        const { aliceIdentity, bobWallet, carolWallet } = await loadFixture(deployIdentityFixture);

        await aliceIdentity.connect(bobWallet).execute(carolWallet.address, 10, '0x', { value: 10 });

        await expect(aliceIdentity.connect(bobWallet).approve(0, true)).to.be.revertedWithCustomError(aliceIdentity, 'SenderDoesNotHaveActionKey');
      });
    });

    describe('when calling approve for an execution targeting another address as a non-management key', () => {
      it('should revert for not authorized', async () => {
        const { aliceIdentity, davidWallet, bobWallet } = await loadFixture(deployIdentityFixture);

        await aliceIdentity.connect(bobWallet).execute(aliceIdentity.target, 10n, '0x', { value: 10n });

        await expect(aliceIdentity.connect(davidWallet).approve(0, true)).to.be.revertedWithCustomError(aliceIdentity, 'SenderDoesNotHaveManagementKey');
      });
    });

    describe('when calling approve as a MANAGEMENT key', () => {
      it('should approve the execution request', async () => {
        const { aliceIdentity, aliceWallet, bobWallet, carolWallet } = await loadFixture(deployIdentityFixture);

        const previousBalance = await ethers.provider.getBalance(carolWallet.address);
        await aliceIdentity.connect(bobWallet).execute(carolWallet.address, 10n, '0x', { value: 10n });

        const tx = await aliceIdentity.connect(aliceWallet).approve(0, true);
        await expect(tx).to.emit(aliceIdentity, 'Approved');
        await expect(tx).to.emit(aliceIdentity, 'Executed');
        const newBalance = await ethers.provider.getBalance(carolWallet.address);

        expect(newBalance).to.equal(previousBalance + 10n);
      });

      it('should leave approve to false', async () => {
        const { aliceIdentity, aliceWallet, bobWallet, carolWallet } = await loadFixture(deployIdentityFixture);

        const previousBalance = await ethers.provider.getBalance(carolWallet.address);
        await aliceIdentity.connect(bobWallet).execute(carolWallet.address, 10, '0x', { value: 10 });

        const tx = await aliceIdentity.connect(aliceWallet).approve(0, false);
        await expect(tx).to.emit(aliceIdentity, 'Approved');
        const newBalance = await ethers.provider.getBalance(carolWallet.address);

        expect(newBalance).to.equal(previousBalance);
      });
    });
  });
});
