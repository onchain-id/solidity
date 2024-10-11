import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { expect } from "chai";
import {ethers} from "hardhat";

import { deployIdentityFixture } from '../fixtures';

describe('Identity', () => {
  describe('.execute() - EOA', () => {
    describe('using ethereum EOA account', () => {
      describe('when calling execute as a MANAGEMENT key', () => {
        describe('when execution is possible (transferring value with enough funds on the identity)', () => {
          it('should execute immediately the action', async () => {
            const { aliceIdentity, aliceWallet, carolWallet } = await loadFixture(deployIdentityFixture);

            const previousBalance = await ethers.provider.getBalance(carolWallet);
            const action = {
              to: await carolWallet.getAddress(),
              value: 10,
              data: '0x',
            };

            const tx = await aliceIdentity.connect(aliceWallet).execute(action.to, action.value, action.data, { value: action.value });
            await expect(tx).to.emit(aliceIdentity, 'Approved');
            await expect(tx).to.emit(aliceIdentity, 'Executed');
            const newBalance = await ethers.provider.getBalance(carolWallet);

            expect(newBalance).to.equal(previousBalance + BigInt(action.value));
          });
        });

        describe('when execution is possible (successfull call)', () => {
          it('should emit Executed', async () => {
            const { aliceIdentity, aliceWallet } = await loadFixture(deployIdentityFixture);

            const aliceKeyHash = ethers.keccak256(
              ethers.AbiCoder.defaultAbiCoder().encode(['address'], [await aliceWallet.getAddress()])
            );

            const action = {
              to: aliceIdentity,
              value: 0,
              data: new ethers.Interface(['function addKey(bytes32 key, uint256 purpose, uint256 keyType) returns (bool success)']).encodeFunctionData('addKey', [
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

            const previousBalance = await ethers.provider.getBalance(carolWallet);
            const action = {
              to: aliceIdentity,
              value: 0,
              data: new ethers.Interface(['function addKey(bytes32 key, uint256 purpose, uint256 keyType) returns (bool success)']).encodeFunctionData('addKey', [
                ethers.keccak256(
                  ethers.AbiCoder.defaultAbiCoder().encode(['address'], [await aliceWallet.getAddress()])
                ),
                1,
                1,
              ]),
            };

            const tx = await aliceIdentity.connect(aliceWallet).execute(action.to, action.value, action.data);
            await expect(tx).to.emit(aliceIdentity, 'Approved');
            await expect(tx).to.emit(aliceIdentity, 'ExecutionFailed');
            const newBalance = await ethers.provider.getBalance(carolWallet);

            expect(newBalance).to.equal(previousBalance + BigInt(action.value));
          });
        });
      });

      describe('when calling execute as an ACTION key', () => {
        describe('when target is the identity contract', () => {
          it('should create an execution request', async () => {
            const { aliceIdentity, aliceWallet, bobWallet, carolWallet } = await loadFixture(deployIdentityFixture);

            const aliceKeyHash = ethers.keccak256(
              ethers.AbiCoder.defaultAbiCoder().encode(['address'], [await aliceWallet.getAddress()])
            );
            const carolKeyHash = ethers.keccak256(
              ethers.AbiCoder.defaultAbiCoder().encode(['address'], [await carolWallet.getAddress()])
            );
            await aliceIdentity.connect(aliceWallet).addKey(carolKeyHash, 2, 1);

            const action = {
              to: aliceIdentity,
              value: 0,
              data: new ethers.Interface(['function addKey(bytes32 key, uint256 purpose, uint256 keyType) returns (bool success)']).encodeFunctionData('addKey', [
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
            const { aliceIdentity, aliceWallet, carolWallet, bobIdentity } = await loadFixture(deployIdentityFixture);

            const carolKeyHash = ethers.keccak256(
              ethers.AbiCoder.defaultAbiCoder().encode(['address'], [await carolWallet.getAddress()])
            );
            await aliceIdentity.connect(aliceWallet).addKey(carolKeyHash, 2, 1);

            const aliceKeyHash = ethers.keccak256(
              ethers.AbiCoder.defaultAbiCoder().encode(['address'], [await aliceWallet.getAddress()])
            );

            const action = {
              to: bobIdentity,
              value: 10,
              data: new ethers.Interface(['function addKey(bytes32 key, uint256 purpose, uint256 keyType) returns (bool success)']).encodeFunctionData('addKey', [
                aliceKeyHash,
                3,
                1,
              ]),
            };

            const previousBalance = await ethers.provider.getBalance(bobIdentity);

            const tx = await aliceIdentity.connect(carolWallet).execute(action.to, action.value, action.data, { value: action.value });
            await expect(tx).to.emit(aliceIdentity, 'Approved');
            await expect(tx).to.emit(aliceIdentity, 'ExecutionFailed');
            const newBalance = await ethers.provider.getBalance(bobIdentity);

            expect(newBalance).to.equal(previousBalance);
          });

          it('should execute immediately the action', async () => {
            const { aliceIdentity, aliceWallet, carolWallet, davidWallet } = await loadFixture(deployIdentityFixture);

            const carolKeyHash = ethers.keccak256(
              ethers.AbiCoder.defaultAbiCoder().encode(['address'], [await carolWallet.getAddress()])
            );
            await aliceIdentity.connect(aliceWallet).addKey(carolKeyHash, 2, 1);

            const previousBalance = await ethers.provider.getBalance(davidWallet);
            const action = {
              to: davidWallet,
              value: 10,
              data: '0x',
            };

            const tx = await aliceIdentity.connect(carolWallet).execute(action.to, action.value, action.data, { value: action.value });
            await expect(tx).to.emit(aliceIdentity, 'Approved');
            await expect(tx).to.emit(aliceIdentity, 'Executed');
            const newBalance = await ethers.provider.getBalance(davidWallet);

            expect(newBalance).to.equal(previousBalance + BigInt(action.value));
          });
        });
      });

      describe('when calling execute as a non-action key', () => {
        it('should create a pending execution request', async () => {
          const { aliceIdentity, bobWallet, carolWallet } = await loadFixture(deployIdentityFixture);

          const previousBalance = await ethers.provider.getBalance(carolWallet);
          const action = {
            to: carolWallet,
            value: 10,
            data: '0x',
          };

          const tx = await aliceIdentity.connect(bobWallet).execute(action.to, action.value, action.data, { value: action.value });
          await expect(tx).to.emit(aliceIdentity, 'ExecutionRequested');
          const newBalance = await ethers.provider.getBalance(carolWallet);

          expect(newBalance).to.equal(previousBalance);
        });
      });
    });
  });

  describe('.approve() - EOA', () => {
    describe('using ethereum EOA account', () => {
      describe('when calling a non-existing execution request', () => {
        it('should revert for execution request not found', async () => {
          const { aliceIdentity, aliceWallet } = await loadFixture(deployIdentityFixture);

          await expect(aliceIdentity.connect(aliceWallet).approve(2, true)).to.be.revertedWith('Cannot approve a non-existing execution');
        });
      });

      describe('when calling an already executed request', () => {
        it('should revert for execution request already executed', async () => {
          const { aliceIdentity, aliceWallet, bobWallet } = await loadFixture(deployIdentityFixture);

          await aliceIdentity.connect(aliceWallet).execute(bobWallet, 10, '0x', { value: 10 });

          await expect(aliceIdentity.connect(aliceWallet).approve(0, true)).to.be.revertedWith('Request already executed');
        });
      });

      describe('when calling approve for an execution targeting another address as a non-action key', () => {
        it('should revert for not authorized', async () => {
          const { aliceIdentity, bobWallet, carolWallet } = await loadFixture(deployIdentityFixture);

          await aliceIdentity.connect(bobWallet).execute(carolWallet, 10, '0x', { value: 10 });

          await expect(aliceIdentity.connect(bobWallet).approve(0, true)).to.be.revertedWith('Sender does not have action key');
        });
      });

      describe('when calling approve for an execution targeting another address as a non-management key', () => {
        it('should revert for not authorized', async () => {
          const { aliceIdentity, davidWallet, bobWallet } = await loadFixture(deployIdentityFixture);

          await aliceIdentity.connect(bobWallet).execute(aliceIdentity, 10, '0x', { value: 10 });

          await expect(aliceIdentity.connect(davidWallet).approve(0, true)).to.be.revertedWith('Sender does not have management key');
        });
      });

      describe('when calling approve as a MANAGEMENT key', () => {
        it('should approve the execution request', async () => {
          const { aliceIdentity, aliceWallet, bobWallet, carolWallet } = await loadFixture(deployIdentityFixture);

          const previousBalance = await ethers.provider.getBalance(carolWallet);
          await aliceIdentity.connect(bobWallet).execute(carolWallet, 10, '0x', { value: 10 });

          const tx = await aliceIdentity.connect(aliceWallet).approve(0, true);
          await expect(tx).to.emit(aliceIdentity, 'Approved');
          await expect(tx).to.emit(aliceIdentity, 'Executed');
          const newBalance = await ethers.provider.getBalance(carolWallet);

          expect(newBalance).to.equal(previousBalance + BigInt(10));
        });

        it('should leave approve to false', async () => {
          const { aliceIdentity, aliceWallet, bobWallet, carolWallet } = await loadFixture(deployIdentityFixture);

          const previousBalance = await ethers.provider.getBalance(carolWallet);
          await aliceIdentity.connect(bobWallet).execute(carolWallet, 10, '0x', { value: 10 });

          const tx = await aliceIdentity.connect(aliceWallet).approve(0, false);
          await expect(tx).to.emit(aliceIdentity, 'Approved');
          const newBalance = await ethers.provider.getBalance(carolWallet);

          expect(newBalance).to.equal(previousBalance);
        });
      });
    });
  });

  describe('.executeSigned() - with signature', () => {
    describe('Using ECDSA signature', () => {
      describe('when signed by a MANAGEMENT key', () => {
        describe('when execution is possible (transferring value with enough funds on the identity)', () => {
          it('should execute immediately the action', async () => {
            const { aliceIdentity, aliceWallet, carolWallet, bobWallet } = await loadFixture(deployIdentityFixture);

            const sendTx = await aliceWallet.sendTransaction({ to: aliceIdentity, value: 100 });
            await sendTx.wait();

            const previousBalance = await ethers.provider.getBalance(carolWallet);
            const action = {
              to: await carolWallet.getAddress(),
              value: 10,
              data: '0x',
            };

            const signature = await aliceWallet.signMessage(ethers.getBytes(ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(
              ['address', 'address', 'uint256', 'bytes'],
              [await aliceIdentity.getAddress(), action.to, action.value, action.data],
            ))));
            const signatureParsed = ethers.Signature.from(signature);

            const tx = await aliceIdentity.connect(bobWallet).executeSigned(action.to, action.value, action.data, 1, signatureParsed.v, signatureParsed.r, signatureParsed.s);
            await expect(tx).to.emit(aliceIdentity, 'Approved');
            await expect(tx).to.emit(aliceIdentity, 'Executed');
            const newBalance = await ethers.provider.getBalance(carolWallet);

            expect(newBalance).to.equal(previousBalance + BigInt(action.value));
          });
        });

        describe('when attempting to call internal function', () => {
          it('should fail to execute the action', async () => {
            const { aliceIdentity, aliceWallet, carolWallet, bobWallet } = await loadFixture(deployIdentityFixture);

            const executeTx = await aliceIdentity.connect(carolWallet).execute(aliceIdentity, 10, '0x', { value: 10 });
            await executeTx.wait();

            const action = {
              to: await aliceIdentity.getAddress(),
              value: 0,
              data: new ethers.Interface(['function _approveAndExecute(uint256 _id, bool _approve) returns (bool success)']).encodeFunctionData('_approveAndExecute', [
                0,
                true,
              ]),
            };

            const signature = await aliceWallet.signMessage(ethers.getBytes(ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(
              ['address', 'address', 'uint256', 'bytes'],
              [await aliceIdentity.getAddress(), action.to, action.value, action.data]
            ))));
            const signatureParsed = ethers.Signature.from(signature);

            const tx = await aliceIdentity.connect(bobWallet).executeSigned(action.to, action.value, action.data, 1, signatureParsed.v, signatureParsed.r, signatureParsed.s);
            await expect(tx).to.emit(aliceIdentity, 'Approved');
            await expect(tx).to.emit(aliceIdentity, 'ExecutionFailed');
          });
        });

        describe('when execution is possible (successfull call)', () => {
          it('should emit Executed', async () => {
            const { aliceIdentity, aliceWallet, bobWallet } = await loadFixture(deployIdentityFixture);

            const aliceKeyHash = ethers.keccak256(
              ethers.AbiCoder.defaultAbiCoder().encode(['address'], [await aliceWallet.getAddress()])
            );

            const action = {
              to: await aliceIdentity.getAddress(),
              value: 0,
              data: new ethers.Interface(['function addKey(bytes32 key, uint256 purpose, uint256 keyType) returns (bool success)']).encodeFunctionData('addKey', [
                aliceKeyHash,
                3,
                1,
              ]),
            };

            const signature = await aliceWallet.signMessage(ethers.getBytes(ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(
              ['address', 'address', 'uint256', 'bytes'],
              [await aliceIdentity.getAddress(), action.to, action.value, action.data]
            ))));
            const signatureParsed = ethers.Signature.from(signature);

            const tx = await aliceIdentity.connect(bobWallet).executeSigned(action.to, action.value, action.data, 1, signatureParsed.v, signatureParsed.r, signatureParsed.s);
            await expect(tx).to.emit(aliceIdentity, 'Approved');
            await expect(tx).to.emit(aliceIdentity, 'Executed');

            const purposes = await aliceIdentity.getKeyPurposes(aliceKeyHash);
            expect(purposes).to.deep.equal([1, 3]);
          });
        });

        describe('when execution is not possible (failing call)', () => {
          it('should emit an ExecutionFailed event', async () => {
            const { aliceIdentity, aliceWallet, carolWallet, bobWallet } = await loadFixture(deployIdentityFixture);

            const previousBalance = await ethers.provider.getBalance(carolWallet);
            const action = {
              to: await aliceIdentity.getAddress(),
              value: 0,
              data: new ethers.Interface(['function addKey(bytes32 key, uint256 purpose, uint256 keyType) returns (bool success)']).encodeFunctionData('addKey', [
                ethers.keccak256(
                  ethers.AbiCoder.defaultAbiCoder().encode(['address'], [await aliceWallet.getAddress()])
                ),
                1,
                1,
              ]),
            };

            const signature = await aliceWallet.signMessage(ethers.getBytes(ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(
              ['address', 'address', 'uint256', 'bytes'],
              [await aliceIdentity.getAddress(), action.to, action.value, action.data]
            ))));
            const signatureParsed = ethers.Signature.from(signature);

            const tx = await aliceIdentity.connect(bobWallet).executeSigned(action.to, action.value, action.data, 1, signatureParsed.v, signatureParsed.r, signatureParsed.s);
            await expect(tx).to.emit(aliceIdentity, 'Approved');
            await expect(tx).to.emit(aliceIdentity, 'ExecutionFailed');
            const newBalance = await ethers.provider.getBalance(carolWallet);

            expect(newBalance).to.equal(previousBalance);
          });
        });
      });

      describe('when calling execute as an ACTION key', () => {
        describe('when target is the identity contract', () => {
          it('should create an execution request', async () => {
            const {aliceIdentity, aliceWallet, bobWallet, carolWallet} = await loadFixture(deployIdentityFixture);

            const aliceKeyHash = ethers.keccak256(
              ethers.AbiCoder.defaultAbiCoder().encode(['address'], [await aliceWallet.getAddress()])
            );
            const carolKeyHash = ethers.keccak256(
              ethers.AbiCoder.defaultAbiCoder().encode(['address'], [await carolWallet.getAddress()])
            );
            await aliceIdentity.connect(aliceWallet).addKey(carolKeyHash, 2, 1);

            const action = {
              to: await aliceIdentity.getAddress(),
              value: 0,
              data: new ethers.Interface(['function addKey(bytes32 key, uint256 purpose, uint256 keyType) returns (bool success)']).encodeFunctionData('addKey', [
                aliceKeyHash,
                2,
                1,
              ]),
            };

            const signature = await carolWallet.signMessage(ethers.getBytes(ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(
              ['address', 'uint256', 'bytes'],
              [action.to, action.value, action.data]
            ))));
            const signatureParsed = ethers.Signature.from(signature);

            const tx = await aliceIdentity.connect(bobWallet).executeSigned(action.to, action.value, action.data, 1, signatureParsed.v, signatureParsed.r, signatureParsed.s);
            await expect(tx).to.emit(aliceIdentity, 'ExecutionRequested');
          });
        });

        describe('when target is another address', () => {
          it('should emit ExecutionFailed for a failed execution', async () => {
            const {aliceIdentity, aliceWallet, carolWallet, davidWallet, bobIdentity} = await loadFixture(deployIdentityFixture);

            const carolKeyHash = ethers.keccak256(
              ethers.AbiCoder.defaultAbiCoder().encode(['address'], [await carolWallet.getAddress()])
            );
            await aliceIdentity.connect(aliceWallet).addKey(carolKeyHash, 2, 1);

            const aliceKeyHash = ethers.keccak256(
              ethers.AbiCoder.defaultAbiCoder().encode(['address'], [await aliceWallet.getAddress()])
            );

            const action = {
              to: await bobIdentity.getAddress(),
              value: 10,
              data: new ethers.Interface(['function addKey(bytes32 key, uint256 purpose, uint256 keyType) returns (bool success)']).encodeFunctionData('addKey', [
                aliceKeyHash,
                3,
                1,
              ]),
            };

            const previousBalance = await ethers.provider.getBalance(bobIdentity);

            const signature = await carolWallet.signMessage(ethers.getBytes(ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(
              ['address', 'address', 'uint256', 'bytes'],
              [await aliceIdentity.getAddress(), action.to, action.value, action.data]
            ))));
            const signatureParsed = ethers.Signature.from(signature);

            const tx = await aliceIdentity.connect(davidWallet).executeSigned(action.to, action.value, action.data, 1, signatureParsed.v, signatureParsed.r, signatureParsed.s);
            await expect(tx).to.emit(aliceIdentity, 'Approved');
            await expect(tx).to.emit(aliceIdentity, 'ExecutionFailed');
            const newBalance = await ethers.provider.getBalance(bobIdentity);

            expect(newBalance).to.equal(previousBalance);
          });

          it('should execute immediately the action', async () => {
            const {aliceIdentity, aliceWallet, bobWallet, carolWallet, davidWallet} = await loadFixture(deployIdentityFixture);

            const carolKeyHash = ethers.keccak256(
              ethers.AbiCoder.defaultAbiCoder().encode(['address'], [await carolWallet.getAddress()])
            );
            await aliceIdentity.connect(aliceWallet).addKey(carolKeyHash, 2, 1);

            const sendTx = await aliceWallet.sendTransaction({ to: aliceIdentity, value: 100 });
            await sendTx.wait();

            const previousBalance = await ethers.provider.getBalance(davidWallet);
            const action = {
              to: await davidWallet.getAddress(),
              value: 10,
              data: '0x',
            };

            const signature = await carolWallet.signMessage(ethers.getBytes(ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(
              ['address', 'address', 'uint256', 'bytes'],
              [await aliceIdentity.getAddress(), action.to, action.value, action.data]
            ))));
            const signatureParsed = ethers.Signature.from(signature);

            const tx = await aliceIdentity.connect(bobWallet).executeSigned(action.to, action.value, action.data, 1, signatureParsed.v, signatureParsed.r, signatureParsed.s);
            await expect(tx).to.emit(aliceIdentity, 'Approved');
            await expect(tx).to.emit(aliceIdentity, 'Executed');
            const newBalance = await ethers.provider.getBalance(davidWallet);

            expect(newBalance).to.equal(previousBalance + BigInt(action.value));
          });
        });
      });

      describe('when calling execute as a non-action key', () => {
        it('should create a pending execution request', async () => {
          const { aliceIdentity, bobWallet, carolWallet } = await loadFixture(deployIdentityFixture);

          const previousBalance = await ethers.provider.getBalance(carolWallet);
          const action = {
            to: await carolWallet.getAddress(),
            value: 10,
            data: '0x',
          };

          const signature = await bobWallet.signMessage(ethers.getBytes(ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(
            ['address', 'uint256', 'bytes'],
            [action.to, action.value, action.data]
          ))));
          const signatureParsed = ethers.Signature.from(signature);

          const tx = await aliceIdentity.connect(bobWallet).executeSigned(action.to, action.value, action.data, 1, signatureParsed.v, signatureParsed.r, signatureParsed.s);
          await expect(tx).to.emit(aliceIdentity, 'ExecutionRequested');

          const newBalance = await ethers.provider.getBalance(carolWallet);

          expect(newBalance).to.equal(previousBalance);
        });
      });
    });
  });

  describe('.approveSigned() - with signature', () => {
    describe('Using ECDSA signature', () => {
      describe('using ethereum EOA account', () => {
        describe('when calling a non-existing execution request', () => {
          it('should revert for execution request not found', async () => {
            const { aliceIdentity, aliceWallet, carolWallet } = await loadFixture(deployIdentityFixture);

            const action = {
              to: await carolWallet.getAddress(),
              value: 10,
              data: '0x',
            };

            const signature = await aliceWallet.signMessage(ethers.getBytes(ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(
              ['address', 'uint256', 'address', 'uint256', 'bytes'],
              [await aliceIdentity.getAddress(), 0, action.to, action.value, action.data],
            ))));
            const signatureParsed = ethers.Signature.from(signature);

            await expect(aliceIdentity.connect(aliceWallet).approveSigned(0, true, 1, signatureParsed.v, signatureParsed.r, signatureParsed.s)).to.be.revertedWith('Cannot approve a non-existing execution');
          });
        });

        describe('when calling an already executed request', () => {
          it('should revert for execution request already executed', async () => {
            const { aliceIdentity, carolWallet, aliceWallet, bobWallet } = await loadFixture(deployIdentityFixture);

            const sendTx = await aliceWallet.sendTransaction({ to: aliceIdentity, value: 100 });
            await sendTx.wait();

            const previousBalance = await ethers.provider.getBalance(carolWallet);
            const action = {
              to: await carolWallet.getAddress(),
              value: 10,
              data: '0x',
            };
            const signature = await aliceWallet.signMessage(ethers.getBytes(ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(
              ['address', 'address', 'uint256', 'bytes'],
              [await aliceIdentity.getAddress(), action.to, action.value, action.data],
            ))));
            const signatureParsed = ethers.Signature.from(signature);

            const tx = await aliceIdentity.connect(bobWallet).executeSigned(action.to, action.value, action.data, 1, signatureParsed.v, signatureParsed.r, signatureParsed.s);
            await expect(tx).to.emit(aliceIdentity, 'Approved');
            await expect(tx).to.emit(aliceIdentity, 'Executed');
            const newBalance = await ethers.provider.getBalance(carolWallet);

            expect(newBalance).to.equal(previousBalance + BigInt(action.value));

            const approvalSignature = await aliceWallet.signMessage(ethers.getBytes(ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(
              ['address', 'uint256', 'address', 'uint256', 'bytes'],
              [await aliceIdentity.getAddress(), 0, action.to, action.value, action.data],
            ))));
            const approvalSignatureParsed = ethers.Signature.from(signature);

            await expect(aliceIdentity.connect(aliceWallet).approveSigned(0, true, 1, approvalSignatureParsed.v, approvalSignatureParsed.r, approvalSignatureParsed.s)).to.be.revertedWith('Request already executed');
          });
        });

        describe('when calling approve for an execution targeting another address as a non-action key', () => {
          it('should revert for not authorized', async () => {
            const { aliceIdentity, bobWallet, carolWallet } = await loadFixture(deployIdentityFixture);

            const action = {
              to: await carolWallet.getAddress(),
              value: 10,
              data: '0x',
            };

            await aliceIdentity.connect(bobWallet).execute(action.to, action.value, action.data);

            const approvalSignature = await bobWallet.signMessage(ethers.getBytes(ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(
              ['address', 'uint256', 'address', 'uint256', 'bytes'],
              [await aliceIdentity.getAddress(), 0, action.to, action.value, action.data],
            ))));
            const approvalSignatureParsed = ethers.Signature.from(approvalSignature);

            await expect(aliceIdentity.connect(bobWallet).approveSigned(0, true, 1, approvalSignatureParsed.v, approvalSignatureParsed.r, approvalSignatureParsed.s)).to.be.revertedWith('Sender does not have action key');
          });
        });

        describe('when calling approve for an execution targeting another address as a non-management key', () => {
          it('should revert for not authorized', async () => {
            const { aliceIdentity, davidWallet, bobWallet } = await loadFixture(deployIdentityFixture);

            const action = {
              to: await aliceIdentity.getAddress(),
              value: 10,
              data: '0x',
            };

            await aliceIdentity.connect(bobWallet).execute(action.to, action.value, action.data);

            const approvalSignature = await davidWallet.signMessage(ethers.getBytes(ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(
              ['address', 'uint256', 'address', 'uint256', 'bytes'],
              [await aliceIdentity.getAddress(), 0, action.to, action.value, action.data],
            ))));
            const approvalSignatureParsed = ethers.Signature.from(approvalSignature);

            await expect(aliceIdentity.connect(davidWallet).approveSigned(0, true, 1, approvalSignatureParsed.v, approvalSignatureParsed.r, approvalSignatureParsed.s)).to.be.revertedWith('Sender does not have management key');
          });
        });

        describe('when calling approve as a MANAGEMENT key', () => {
          it('should approve the execution request', async () => {
            const { aliceIdentity, aliceWallet, bobWallet, carolWallet } = await loadFixture(deployIdentityFixture);

            const sendTx = await aliceWallet.sendTransaction({ to: aliceIdentity, value: 100 });
            await sendTx.wait();

            const previousBalance = await ethers.provider.getBalance(carolWallet);
            const action = {
              to: await carolWallet.getAddress(),
              value: 10,
              data: '0x',
            };

            await aliceIdentity.connect(bobWallet).execute(action.to, action.value, action.data);

            const approvalSignature = await aliceWallet.signMessage(ethers.getBytes(ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(
              ['address', 'uint256', 'address', 'uint256', 'bytes'],
              [await aliceIdentity.getAddress(), 0, action.to, action.value, action.data],
            ))));
            const approvalSignatureParsed = ethers.Signature.from(approvalSignature);

            const tx = await aliceIdentity.connect(aliceWallet).approveSigned(0, true, 1, approvalSignatureParsed.v, approvalSignatureParsed.r, approvalSignatureParsed.s);
            await expect(tx).to.emit(aliceIdentity, 'Approved');
            await expect(tx).to.emit(aliceIdentity, 'Executed');
            const newBalance = await ethers.provider.getBalance(carolWallet);

            expect(newBalance).to.equal(previousBalance + BigInt(action.value));
          });

          it('should leave approve to false', async () => {
            const { aliceIdentity, aliceWallet, bobWallet, carolWallet } = await loadFixture(deployIdentityFixture);

            const sendTx = await aliceWallet.sendTransaction({ to: aliceIdentity, value: 100 });
            await sendTx.wait();

            const previousBalance = await ethers.provider.getBalance(carolWallet);
            const action = {
              to: await carolWallet.getAddress(),
              value: 10,
              data: '0x',
            };

            await aliceIdentity.connect(bobWallet).execute(action.to, action.value, action.data);

            const approvalSignature = await aliceWallet.signMessage(ethers.getBytes(ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(
              ['address', 'uint256', 'address', 'uint256', 'bytes'],
              [await aliceIdentity.getAddress(), 0, action.to, action.value, action.data],
            ))));
            const approvalSignatureParsed = ethers.Signature.from(approvalSignature);

            const tx = await aliceIdentity.connect(aliceWallet).approveSigned(0, false, 1, approvalSignatureParsed.v, approvalSignatureParsed.r, approvalSignatureParsed.s);
            await expect(tx).to.emit(aliceIdentity, 'Approved');
            const newBalance = await ethers.provider.getBalance(carolWallet);

            expect(newBalance).to.equal(previousBalance);
          });
        });
      });
    });
  });
});
