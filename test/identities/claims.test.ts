import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { expect } from "chai";
import { ethers } from "hardhat";

import { deployIdentityFixture } from '../fixtures';

describe('Identity', () => {
  describe('Claims', () => {
    describe('addClaim', () => {
      describe('when the claim is self-attested (issuer is identity address)', () => {
        describe('when the claim is not valid', () => {
          it('should add the claim anyway', async () => {
            const { aliceIdentity, aliceWallet } = await loadFixture(deployIdentityFixture);

            const claim = {
              identity: aliceIdentity.target,
              issuer: aliceIdentity.target,
              topic: 42,
              scheme: 1,
              data: '0x0042',
              signature: '',
              uri: 'https://example.com',
            };
            claim.signature = await aliceWallet.signMessage(ethers.getBytes(ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(['address', 'uint256', 'bytes'], [claim.identity, claim.topic, '0x101010']))));

            const tx = await aliceIdentity.connect(aliceWallet).addClaim(claim.topic, claim.scheme, claim.issuer, claim.signature, claim.data, claim.uri);
            await expect(tx).to.emit(aliceIdentity, 'ClaimAdded').withArgs(ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(['address', 'uint256'], [claim.issuer, claim.topic])), claim.topic, claim.scheme, claim.issuer, claim.signature, claim.data, claim.uri);
            await expect(aliceIdentity.isClaimValid(claim.identity, claim.topic, claim.signature, claim.data)).to.eventually.equal(false);
          });
        });

        describe('when the claim is valid', () => {
          let claim = { identity: '', issuer: '', topic: 0, scheme: 1, data: '', uri: '', signature: '' };
          before(async () => {
            const { aliceIdentity, aliceWallet } = await loadFixture(deployIdentityFixture);

            claim = {
              identity: aliceIdentity.target,
              issuer: aliceIdentity.target,
              topic: 42,
              scheme: 1,
              data: '0x0042',
              signature: '',
              uri: 'https://example.com',
            };
            claim.signature = await aliceWallet.signMessage(ethers.getBytes(ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(['address', 'uint256', 'bytes'], [claim.identity, claim.topic, claim.data]))));
          });

          describe('when caller is the identity itself (execute)', () => {
            it('should add the claim', async () => {
              const { aliceIdentity, aliceWallet, bobWallet } = await loadFixture(deployIdentityFixture);

              const action = {
                to: aliceIdentity.target,
                value: 0,
                data: aliceIdentity.interface.encodeFunctionData('addClaim', [
                  claim.topic, claim.scheme, claim.issuer, claim.signature, claim.data, claim.uri
                ]),
              };

              await aliceIdentity.connect(bobWallet).execute(action.to, action.value, action.data);
              const tx = await aliceIdentity.connect(aliceWallet).approve(0, true);
              await expect(tx).to.emit(aliceIdentity, 'ClaimAdded').withArgs(ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(['address', 'uint256'], [claim.issuer, claim.topic])), claim.topic, claim.scheme, claim.issuer, claim.signature, claim.data, claim.uri);
              await expect(tx).to.emit(aliceIdentity, 'Approved');
              await expect(tx).to.emit(aliceIdentity, 'Executed');
              await expect(aliceIdentity.isClaimValid(claim.identity, claim.topic, claim.signature, claim.data)).to.eventually.equal(true);
            });
          });

          describe('when caller is a CLAIM or MANAGEMENT key', () => {
            it('should add the claim', async () => {
              it('should add the claim anyway', async () => {
                const { aliceIdentity, aliceWallet } = await loadFixture(deployIdentityFixture);

                const tx = await aliceIdentity.connect(aliceWallet).addClaim(claim.topic, claim.scheme, claim.issuer, claim.signature, claim.data, claim.uri);
                await expect(tx).to.emit(aliceIdentity, 'ClaimAdded').withArgs(ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(['address', 'uint256'], [claim.issuer, claim.topic])), claim.topic, claim.scheme, claim.issuer, claim.signature, claim.data, claim.uri);
              });
            });
          });

          describe('when caller is not a CLAIM key', () => {
            it('should revert for missing permission', async () => {
              const { aliceIdentity, bobWallet } = await loadFixture(deployIdentityFixture);

              await expect(aliceIdentity.connect(bobWallet).addClaim(claim.topic, claim.scheme, claim.issuer, claim.signature, claim.data, claim.uri)).to.be.revertedWithCustomError(aliceIdentity, 'SenderDoesNotHaveClaimSignerKey');
            });
          });
        });
      });

      describe('when the claim is from a claim issuer', () => {
        describe('when the claim is not valid', () => {
          it('should revert for invalid claim', async () => {
            const { aliceIdentity, aliceWallet, claimIssuerWallet, claimIssuer } = await loadFixture(deployIdentityFixture);

            const claim = {
              identity: aliceIdentity.target,
              issuer: claimIssuer.target,
              topic: 42,
              scheme: 1,
              data: '0x0042',
              signature: '',
              uri: 'https://example.com',
            };
            claim.signature = await claimIssuerWallet.signMessage(ethers.getBytes(ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(['address', 'uint256', 'bytes'], [claim.identity, claim.topic, '0x10101010']))));

            await expect(aliceIdentity.connect(aliceWallet).addClaim(claim.topic, claim.scheme, claim.issuer, claim.signature, claim.data, claim.uri)).to.be.revertedWithCustomError(aliceIdentity, 'InvalidClaim');
          });
        });

        describe('when the claim is valid', () => {
          let claim = { identity: '', issuer: '', topic: 0, scheme: 1, data: '', uri: '', signature: '' };
          before(async () => {
            const { aliceIdentity, claimIssuer, claimIssuerWallet } = await loadFixture(deployIdentityFixture);

            claim = {
              identity: aliceIdentity.target,
              issuer: claimIssuer.target,
              topic: 42,
              scheme: 1,
              data: '0x0042',
              signature: '',
              uri: 'https://example.com',
            };
            claim.signature = await claimIssuerWallet.signMessage(ethers.getBytes(ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(['address', 'uint256', 'bytes'], [claim.identity, claim.topic, claim.data]))));
          });

          describe('when caller is the identity itself (execute)', () => {
            it('should add the claim', async () => {
              const { aliceIdentity, aliceWallet, bobWallet } = await loadFixture(deployIdentityFixture);

              const action = {
                to: aliceIdentity.target,
                value: 0,
                data: aliceIdentity.interface.encodeFunctionData('addClaim', [
                  claim.topic, claim.scheme, claim.issuer, claim.signature, claim.data, claim.uri
                ]),
              };

              await aliceIdentity.connect(bobWallet).execute(action.to, action.value, action.data);
              const tx = await aliceIdentity.connect(aliceWallet).approve(0, true);
              await expect(tx).to.emit(aliceIdentity, 'ClaimAdded').withArgs(ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(['address', 'uint256'], [claim.issuer, claim.topic])), claim.topic, claim.scheme, claim.issuer, claim.signature, claim.data, claim.uri);
              await expect(tx).to.emit(aliceIdentity, 'Approved');
              await expect(tx).to.emit(aliceIdentity, 'Executed');
            });
          });

          describe('when caller is a CLAIM or MANAGEMENT key', () => {
            it('should add the claim', async () => {
              it('should add the claim anyway', async () => {
                const { aliceIdentity, aliceWallet } = await loadFixture(deployIdentityFixture);

                const tx = await aliceIdentity.connect(aliceWallet).addClaim(claim.topic, claim.scheme, claim.issuer, claim.signature, claim.data, claim.uri);
                await expect(tx).to.emit(aliceIdentity, 'ClaimAdded').withArgs(ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(['address', 'uint256'], [claim.issuer, claim.topic])), claim.topic, claim.scheme, claim.issuer, claim.signature, claim.data, claim.uri);
              });
            });
          });

          describe('when caller is not a CLAIM key', () => {
            it('should revert for missing permission', async () => {
              const { aliceIdentity, bobWallet } = await loadFixture(deployIdentityFixture);

              await expect(aliceIdentity.connect(bobWallet).addClaim(claim.topic, claim.scheme, claim.issuer, claim.signature, claim.data, claim.uri)).to.be.revertedWithCustomError(aliceIdentity, 'SenderDoesNotHaveClaimSignerKey');
            });
          });
        });
      });
    });

    describe('updateClaim (addClaim)', () => {
      describe('when there is already a claim from this issuer and this topic', () => {
        let aliceIdentity: ethers.Contract;
        let aliceWallet: ethers.Wallet;
        let claimIssuer: ethers.Contract;
        let claimIssuerWallet: ethers.Wallet;
        before(async () => {
          const params = await loadFixture(deployIdentityFixture);
          aliceIdentity = params.aliceIdentity;
          aliceWallet = params.aliceWallet;
          claimIssuer = params.claimIssuer;
          claimIssuerWallet = params.claimIssuerWallet;

          const claim = {
            identity: aliceIdentity.target,
            issuer: claimIssuer.target,
            topic: 42,
            scheme: 1,
            data: '0x0042',
            signature: '',
            uri: 'https://example.com',
          };
          claim.signature = await claimIssuerWallet.signMessage(ethers.getBytes(ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(['address', 'uint256', 'bytes'], [claim.identity, claim.topic, claim.data]))));

          await aliceIdentity.connect(aliceWallet).addClaim(
            claim.topic,
            claim.scheme,
            claim.issuer,
            claim.signature,
            claim.data,
            claim.uri,
          );
        });

        it('should replace the existing claim', async () => {
          const claim = {
            identity: aliceIdentity.target,
            issuer: claimIssuer.target,
            topic: 42,
            scheme: 1,
            data: '0x004200101010',
            signature: '',
            uri: 'https://example.com',
          };
          claim.signature = await claimIssuerWallet.signMessage(ethers.getBytes(ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(['address', 'uint256', 'bytes'], [claim.identity, claim.topic, claim.data]))));

          const tx = await aliceIdentity.connect(aliceWallet).addClaim(
            claim.topic,
            claim.scheme,
            claim.issuer,
            claim.signature,
            claim.data,
            claim.uri,
          );
          await expect(tx).to.emit(aliceIdentity, 'ClaimChanged').withArgs(ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(['address', 'uint256'], [claim.issuer, claim.topic])), claim.topic, claim.scheme, claim.issuer, claim.signature, claim.data, claim.uri);
        });
      });
    });

    describe('removeClaim', () => {
      describe('When caller is the identity itself (execute)', () => {
        it('should remove an existing claim', async () => {
          const { aliceIdentity, aliceWallet, bobWallet, claimIssuer, claimIssuerWallet } = await loadFixture(deployIdentityFixture);
          const claim = {
            identity: aliceIdentity.target,
            issuer: claimIssuer.target,
            topic: 42,
            scheme: 1,
            data: '0x0042',
            signature: '',
            uri: 'https://example.com',
          };
          const claimId = ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(['address', 'uint256'], [claim.issuer, claim.topic]));
          claim.signature = await claimIssuerWallet.signMessage(ethers.getBytes(ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(['address', 'uint256', 'bytes'], [claim.identity, claim.topic, claim.data]))));

          await aliceIdentity.connect(aliceWallet).addClaim(claim.topic, claim.scheme, claim.issuer, claim.signature, claim.data, claim.uri);

          const action = {
            to: aliceIdentity.target,
            value: 0,
            data: aliceIdentity.interface.encodeFunctionData('removeClaim', [
              claimId,
            ]),
          };

          await aliceIdentity.connect(bobWallet).execute(action.to, action.value, action.data);
          const tx = await aliceIdentity.connect(aliceWallet).approve(0, true);
          await expect(tx).to.emit(aliceIdentity, 'ClaimRemoved').withArgs(claimId, claim.topic, claim.scheme, claim.issuer, claim.signature, claim.data, claim.uri);
        });
      });

      describe('When caller is not a CLAIM key', () => {
        it('should revert for missing permission', async () => {
          const { aliceIdentity, bobWallet, claimIssuer } = await loadFixture(deployIdentityFixture);

          const claimId = ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(['address', 'uint256'], [claimIssuer.target, 42]));

          await expect(aliceIdentity.connect(bobWallet).removeClaim(claimId)).to.be.revertedWithCustomError(aliceIdentity, 'SenderDoesNotHaveClaimSignerKey');
        });
      });

      describe('When claim does not exist', () => {
        it('should revert for non existing claim', async () => {
          const { aliceIdentity, carolWallet, claimIssuer } = await loadFixture(deployIdentityFixture);

          const claimId = ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(['address', 'uint256'], [claimIssuer.target, 42]));

          await expect(aliceIdentity.connect(carolWallet).removeClaim(claimId)).to.be.revertedWithCustomError(aliceIdentity, 'ClaimNotRegistered');
        });
      });

      describe('When claim does exist', () => {
        it('should remove the claim', async () => {
          const { aliceIdentity, aliceWallet, claimIssuer, claimIssuerWallet } = await loadFixture(deployIdentityFixture);
          const claim = {
            identity: aliceIdentity.target,
            issuer: claimIssuer.target,
            topic: 42,
            scheme: 1,
            data: '0x0042',
            signature: '',
            uri: 'https://example.com',
          };
          const claimId = ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(['address', 'uint256'], [claim.issuer, claim.topic]));
          claim.signature = await claimIssuerWallet.signMessage(ethers.getBytes(ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(['address', 'uint256', 'bytes'], [claim.identity, claim.topic, claim.data]))));

          await aliceIdentity.connect(aliceWallet).addClaim(claim.topic, claim.scheme, claim.issuer, claim.signature, claim.data, claim.uri);

          const tx = await aliceIdentity.connect(aliceWallet).removeClaim(claimId);
          await expect(tx).to.emit(aliceIdentity, 'ClaimRemoved').withArgs(claimId, claim.topic, claim.scheme, claim.issuer, claim.signature, claim.data, claim.uri);
        });
      });
    });

    describe('getClaim', () => {
      describe('when claim does not exist', () => {
        it('should return an empty struct', async () => {
          const { aliceIdentity, claimIssuer } = await loadFixture(deployIdentityFixture);
          const claimId = ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(['address', 'uint256'], [claimIssuer.target, 42]));
          const found = await aliceIdentity.getClaim(claimId);
          expect(found.issuer).to.equal(ethers.ZeroAddress);
          expect(found.topic).to.equal(0);
          expect(found.scheme).to.equal(0);
          expect(found.data).to.equal('0x');
          expect(found.signature).to.equal('0x');
          expect(found.uri).to.equal('');
        });
      });

      describe('when claim does exist', () => {
        it('should return the claim', async () => {
          const { aliceIdentity, aliceClaim666 } = await loadFixture(deployIdentityFixture);

          const found = await aliceIdentity.getClaim(aliceClaim666.id);
          expect(found.issuer).to.equal(aliceClaim666.issuer);
          expect(found.topic).to.equal(aliceClaim666.topic);
          expect(found.scheme).to.equal(aliceClaim666.scheme);
          expect(found.data).to.equal(aliceClaim666.data);
          expect(found.signature).to.equal(aliceClaim666.signature);
          expect(found.uri).to.equal(aliceClaim666.uri);
        });
      });
    });

    describe('getClaimIdsByTopic', () => {
      it('should return an empty array when there are no claims for the topic', async () => {
        const { aliceIdentity } = await loadFixture(deployIdentityFixture);

        await expect(aliceIdentity.getClaimIdsByTopic(101010)).to.eventually.deep.equal([]);
      });

      it('should return an array of claim Id existing fo the topic', async () => {
        const { aliceIdentity, aliceClaim666 } = await loadFixture(deployIdentityFixture);

        await expect(aliceIdentity.getClaimIdsByTopic(aliceClaim666.topic)).to.eventually.deep.equal([aliceClaim666.id]);
      });
    });
  });
});
