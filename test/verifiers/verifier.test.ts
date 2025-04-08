import { ethers } from "hardhat";
import { expect } from "chai";


describe('Verifier', () => {
  describe('.verify()', () => {
    describe('when the Verifier does expect claim topics', () => {
      it('should return true', async () => {
        const [deployer, aliceWallet] = await ethers.getSigners();
        const verifier = await ethers.deployContract('Verifier');

        await expect(verifier.verify(aliceWallet.address)).to.eventually.be.true;
      });
    });

    describe('when the Verifier expect one claim topic but has no trusted issuers', () => {
      it('should return false', async () => {
        const [deployer, aliceWallet] = await ethers.getSigners();
        const verifier = await ethers.deployContract('Verifier');
        await verifier.addClaimTopic(ethers.encodeBytes32String('SOME_TOPIC'));

        await expect(verifier.verify(aliceWallet.address)).to.eventually.be.false;
      });
    });

    describe('when the Verifier expect one claim topic and a trusted issuer for another topic', () => {
      it('should return false', async () => {
        const [deployer, aliceWallet] = await ethers.getSigners();
        const verifier = await ethers.deployContract('Verifier');
        await verifier.addClaimTopic(ethers.encodeBytes32String('SOME_TOPIC'));
        await verifier.addTrustedIssuer(deployer.address, [ethers.encodeBytes32String('SOME_OTHER_TOPIC')]);

        await expect(verifier.verify(aliceWallet.address)).to.eventually.be.false;
      });
    });

    describe('when the Verifier expect one claim topic and a trusted issuer for the topic', () => {
      describe('when the identity does not have the claim', () => {
        it('should return false', async () => {
          const [deployer, aliceWallet, claimIssuerWallet] = await ethers.getSigners();
          const verifier = await ethers.deployContract('Verifier');
          const claimIssuer = await ethers.deployContract('ClaimIssuer', [claimIssuerWallet.address]);
          const aliceIdentity = await ethers.deployContract('Identity', [aliceWallet.address, false]);
          await verifier.addClaimTopic(ethers.encodeBytes32String('SOME_TOPIC'));
          await verifier.addTrustedIssuer(claimIssuer.target, [ethers.encodeBytes32String('SOME_TOPIC')]);

          await expect(verifier.verify(aliceIdentity.target)).to.eventually.be.false;
        });
      });

      describe('when the identity does not have a valid expected claim', () => {
        it('should return false', async () => {
          const [deployer, aliceWallet, claimIssuerWallet] = await ethers.getSigners();
          const verifier = await ethers.deployContract('Verifier');
          const claimIssuer = await ethers.deployContract('ClaimIssuer', [claimIssuerWallet.address]);
          const aliceIdentity = await ethers.deployContract('Identity', [aliceWallet.address, false]);

          await verifier.addClaimTopic(666);
          await verifier.addTrustedIssuer(claimIssuer.target, [666]);

          const aliceClaim666 = {
            id: '',
            identity: aliceIdentity.target,
            issuer: claimIssuer.target,
            topic: 666,
            scheme: 1,
            data: '0x0042',
            signature: '',
            uri: 'https://example.com',
          };
          aliceClaim666.signature = await claimIssuerWallet.signMessage(ethers.getBytes(ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(['address', 'uint256', 'bytes'], [aliceClaim666.identity, aliceClaim666.topic, aliceClaim666.data]))));
          await aliceIdentity.connect(aliceWallet).addClaim(
            aliceClaim666.topic,
            aliceClaim666.scheme,
            aliceClaim666.issuer,
            aliceClaim666.signature,
            aliceClaim666.data,
            aliceClaim666.uri,
          );
          await claimIssuer.connect(claimIssuerWallet).revokeClaimBySignature(
            aliceClaim666.signature,
          );

          await expect(verifier.verify(aliceIdentity.target)).to.eventually.be.false;
        });
      });

      describe('when the identity has the valid expected claim', () => {
        it('should return true', async () => {
          const [deployer, aliceWallet, claimIssuerWallet] = await ethers.getSigners();
          const verifier = await ethers.deployContract('Verifier');
          const claimIssuer = await ethers.deployContract('ClaimIssuer', [claimIssuerWallet.address]);
          const aliceIdentity = await ethers.deployContract('Identity', [aliceWallet.address, false]);

          await verifier.addClaimTopic(666);
          await verifier.addTrustedIssuer(claimIssuer.target, [666]);

          const aliceClaim666 = {
            id: '',
            identity: aliceIdentity.target,
            issuer: claimIssuer.target,
            topic: 666,
            scheme: 1,
            data: '0x0042',
            signature: '',
            uri: 'https://example.com',
          };
          aliceClaim666.signature = await claimIssuerWallet.signMessage(ethers.getBytes(ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(['address', 'uint256', 'bytes'], [aliceClaim666.identity, aliceClaim666.topic, aliceClaim666.data]))));
          await aliceIdentity.connect(aliceWallet).addClaim(
            aliceClaim666.topic,
            aliceClaim666.scheme,
            aliceClaim666.issuer,
            aliceClaim666.signature,
            aliceClaim666.data,
            aliceClaim666.uri,
          );

          await expect(verifier.verify(aliceIdentity.target)).to.eventually.be.true;
        });
      });
    });

    describe('when the Verifier expect multiple claim topics and allow multiple trusted issuers', () => {
      describe('when identity is compliant', () => {
        it('should return true', async () => {
          const [deployer, aliceWallet, claimIssuerAWallet, claimIssuerBWallet, claimIssuerCWallet] = await ethers.getSigners();
          const verifier = await ethers.deployContract('Verifier');
          const claimIssuerA = await ethers.deployContract('ClaimIssuer', [claimIssuerAWallet.address]);
          const claimIssuerB = await ethers.deployContract('ClaimIssuer', [claimIssuerBWallet.address]);
          const claimIssuerC = await ethers.deployContract('ClaimIssuer', [claimIssuerCWallet.address]);
          const aliceIdentity = await ethers.deployContract('Identity', [aliceWallet.address, false]);

          await verifier.addClaimTopic(666);
          await verifier.addTrustedIssuer(claimIssuerA.target, [666]);
          await verifier.addClaimTopic(42);
          await verifier.addTrustedIssuer(claimIssuerB.target, [42, 666]);

          const aliceClaim666C = {
            id: '',
            identity: aliceIdentity.target,
            issuer: claimIssuerC.target,
            topic: 666,
            scheme: 1,
            data: '0x0042',
            signature: '',
            uri: 'https://example.com',
          };
          aliceClaim666C.signature = await claimIssuerCWallet.signMessage(ethers.getBytes(ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(['address', 'uint256', 'bytes'], [aliceClaim666C.identity, aliceClaim666C.topic, aliceClaim666C.data]))));
          await aliceIdentity.connect(aliceWallet).addClaim(
            aliceClaim666C.topic,
            aliceClaim666C.scheme,
            aliceClaim666C.issuer,
            aliceClaim666C.signature,
            aliceClaim666C.data,
            aliceClaim666C.uri,
          );

          const aliceClaim666 = {
            id: '',
            identity: aliceIdentity.target,
            issuer: claimIssuerA.target,
            topic: 666,
            scheme: 1,
            data: '0x0042',
            signature: '',
            uri: 'https://example.com',
          };
          aliceClaim666.signature = await claimIssuerAWallet.signMessage(ethers.getBytes(ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(['address', 'uint256', 'bytes'], [aliceClaim666.identity, aliceClaim666.topic, aliceClaim666.data]))));
          await aliceIdentity.connect(aliceWallet).addClaim(
            aliceClaim666.topic,
            aliceClaim666.scheme,
            aliceClaim666.issuer,
            aliceClaim666.signature,
            aliceClaim666.data,
            aliceClaim666.uri,
          );

          const aliceClaim666B = {
            id: '',
            identity: aliceIdentity.target,
            issuer: claimIssuerB.target,
            topic: 666,
            scheme: 1,
            data: '0x0066',
            signature: '',
            uri: 'https://example.com/B/666',
          };
          aliceClaim666B.signature = await claimIssuerBWallet.signMessage(ethers.getBytes(ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(['address', 'uint256', 'bytes'], [aliceClaim666B.identity, aliceClaim666B.topic, aliceClaim666B.data]))));
          await aliceIdentity.connect(aliceWallet).addClaim(
            aliceClaim666B.topic,
            aliceClaim666B.scheme,
            aliceClaim666B.issuer,
            aliceClaim666B.signature,
            aliceClaim666B.data,
            aliceClaim666B.uri,
          );

          const aliceClaim42 = {
            id: '',
            identity: aliceIdentity.target,
            issuer: claimIssuerB.target,
            topic: 42,
            scheme: 1,
            data: '0x0010',
            signature: '',
            uri: 'https://example.com/42',
          };
          aliceClaim42.signature = await claimIssuerBWallet.signMessage(ethers.getBytes(ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(['address', 'uint256', 'bytes'], [aliceClaim42.identity, aliceClaim42.topic, aliceClaim42.data]))));
          await aliceIdentity.connect(aliceWallet).addClaim(
            aliceClaim42.topic,
            aliceClaim42.scheme,
            aliceClaim42.issuer,
            aliceClaim42.signature,
            aliceClaim42.data,
            aliceClaim42.uri,
          );

          await claimIssuerB.connect(claimIssuerBWallet).revokeClaimBySignature(aliceClaim666B.signature);

          await expect(verifier.verify(aliceIdentity.target)).to.eventually.be.true;
        });
      });

      describe('when identity is not compliant', () => {
        it('should return false', async () => {
          const [deployer, aliceWallet, claimIssuerAWallet, claimIssuerBWallet] = await ethers.getSigners();
          const verifier = await ethers.deployContract('Verifier');
          const claimIssuerA = await ethers.deployContract('ClaimIssuer', [claimIssuerAWallet.address]);
          const claimIssuerB = await ethers.deployContract('ClaimIssuer', [claimIssuerBWallet.address]);
          const aliceIdentity = await ethers.deployContract('Identity', [aliceWallet.address, false]);

          await verifier.addClaimTopic(666);
          await verifier.addTrustedIssuer(claimIssuerA.target, [666]);
          await verifier.addClaimTopic(42);
          await verifier.addTrustedIssuer(claimIssuerB.target, [42, 666]);

          const aliceClaim666 = {
            id: '',
            identity: aliceIdentity.target,
            issuer: claimIssuerA.target,
            topic: 666,
            scheme: 1,
            data: '0x0042',
            signature: '',
            uri: 'https://example.com',
          };
          aliceClaim666.signature = await claimIssuerAWallet.signMessage(ethers.getBytes(ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(['address', 'uint256', 'bytes'], [aliceClaim666.identity, aliceClaim666.topic, aliceClaim666.data]))));
          await aliceIdentity.connect(aliceWallet).addClaim(
            aliceClaim666.topic,
            aliceClaim666.scheme,
            aliceClaim666.issuer,
            aliceClaim666.signature,
            aliceClaim666.data,
            aliceClaim666.uri,
          );

          const aliceClaim666B = {
            id: '',
            identity: aliceIdentity.target,
            issuer: claimIssuerB.target,
            topic: 666,
            scheme: 1,
            data: '0x0066',
            signature: '',
            uri: 'https://example.com/B/666',
          };
          aliceClaim666B.signature = await claimIssuerBWallet.signMessage(ethers.getBytes(ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(['address', 'uint256', 'bytes'], [aliceClaim666B.identity, aliceClaim666B.topic, aliceClaim666B.data]))));
          await aliceIdentity.connect(aliceWallet).addClaim(
            aliceClaim666B.topic,
            aliceClaim666B.scheme,
            aliceClaim666B.issuer,
            aliceClaim666B.signature,
            aliceClaim666B.data,
            aliceClaim666B.uri,
          );

          const aliceClaim42 = {
            id: '',
            identity: aliceIdentity.target,
            issuer: claimIssuerB.target,
            topic: 42,
            scheme: 1,
            data: '0x0010',
            signature: '',
            uri: 'https://example.com/42',
          };
          aliceClaim42.signature = await claimIssuerBWallet.signMessage(ethers.getBytes(ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(['address', 'uint256', 'bytes'], [aliceClaim42.identity, aliceClaim42.topic, aliceClaim42.data]))));
          await aliceIdentity.connect(aliceWallet).addClaim(
            aliceClaim42.topic,
            aliceClaim42.scheme,
            aliceClaim42.issuer,
            aliceClaim42.signature,
            aliceClaim42.data,
            aliceClaim42.uri,
          );

          await claimIssuerB.connect(claimIssuerBWallet).revokeClaimBySignature(aliceClaim42.signature);

          await expect(verifier.verify(aliceIdentity.target)).to.eventually.be.false;
        });
      });
    });
  });

  describe('.removeClaimTopic', () => {
    describe('when not called by the owner', () => {
      it('should revert', async () => {
        const [deployer, aliceWallet] = await ethers.getSigners();
        const verifier = await ethers.deployContract('Verifier');

        await expect(verifier.connect(aliceWallet).removeClaimTopic(2)).to.be.revertedWith('Ownable: caller is not the owner');
      });
    });

    describe('when called by the owner', () => {
      it('should remove the claim topic', async () => {
        const [deployer] = await ethers.getSigners();
        const verifier = await ethers.deployContract('Verifier');
        await verifier.addClaimTopic(1);
        await verifier.addClaimTopic(2);
        await verifier.addClaimTopic(3);

        const tx = await verifier.removeClaimTopic(2);
        await expect(tx).to.emit(verifier, 'ClaimTopicRemoved').withArgs(2);
        expect(await verifier.isClaimTopicRequired(1)).to.be.true;
        expect(await verifier.isClaimTopicRequired(2)).to.be.false;
        expect(await verifier.isClaimTopicRequired(3)).to.be.true;
      });
    });
  });

  describe('.removeTrustedIssuer', () => {
    describe('when not called by the owner', () => {
      it('should revert', async () => {
        const [deployer, aliceWallet] = await ethers.getSigners();
        const verifier = await ethers.deployContract('Verifier');
        const claimIssuer = await ethers.deployContract('ClaimIssuer', [aliceWallet.address]);

        await expect(verifier.connect(aliceWallet).removeTrustedIssuer(claimIssuer.target)).to.be.revertedWith('Ownable: caller is not the owner');
      });
    });

    describe('when called by the owner', () => {
      it('should remove the trusted issuer', async () => {
        const [deployer, aliceWallet] = await ethers.getSigners();
        const verifier = await ethers.deployContract('Verifier');
        const claimIssuer = await ethers.deployContract('ClaimIssuer', [aliceWallet.address]);
        const claimIssuerB = await ethers.deployContract('ClaimIssuer', [aliceWallet.address]);
        await verifier.addTrustedIssuer(claimIssuer.target, [1]);
        await verifier.addTrustedIssuer(claimIssuerB.target, [2]);

        const tx = await verifier.removeTrustedIssuer(claimIssuer.target);
        await expect(tx).to.emit(verifier, 'TrustedIssuerRemoved').withArgs(claimIssuer.target);
        expect(await verifier.isTrustedIssuer(claimIssuer.target)).to.be.false;
        expect(await verifier.getTrustedIssuers()).to.be.deep.equal([claimIssuerB.target]);
      });
    });

    describe('when issuer address is zero', () => {
      it('should revert', async () => {
        const [deployer] = await ethers.getSigners();
        const verifier = await ethers.deployContract('Verifier');

        await expect(verifier.removeTrustedIssuer(ethers.ZeroAddress)).to.be.revertedWith('invalid argument - zero address');
      });
    });

    describe('when issuer is not trusted', () => {
      it('should revert', async () => {
        const [deployer, aliceWallet] = await ethers.getSigners();
        const verifier = await ethers.deployContract('Verifier');
        const claimIssuer = await ethers.deployContract('ClaimIssuer', [aliceWallet.address]);

        await expect(verifier.removeTrustedIssuer(claimIssuer.target)).to.be.revertedWith('NOT a trusted issuer');
      });
    });
  });

  describe('.addTrustedIssuer', () => {
    describe('when not called by the owner', () => {
      it('should revert', async () => {
        const [deployer, aliceWallet] = await ethers.getSigners();
        const verifier = await ethers.deployContract('Verifier');
        const claimIssuer = await ethers.deployContract('ClaimIssuer', [aliceWallet.address]);

        await expect(verifier.connect(aliceWallet).addTrustedIssuer(claimIssuer.target, [1])).to.be.revertedWith('Ownable: caller is not the owner');
      });
    });

    describe('when issuer address is the zero', () => {
      it('should revert', async () => {
        const [deployer] = await ethers.getSigners();
        const verifier = await ethers.deployContract('Verifier');

        await expect(verifier.addTrustedIssuer(ethers.ZeroAddress, [1])).to.be.revertedWith('invalid argument - zero address');
      });
    });

    describe('when issuer is already trusted', () => {
      it('should revert', async () => {
        const [deployer, aliceWallet] = await ethers.getSigners();
        const verifier = await ethers.deployContract('Verifier');
        const claimIssuer = await ethers.deployContract('ClaimIssuer', [aliceWallet.address]);
        await verifier.addTrustedIssuer(claimIssuer.target, [1]);

        await expect(verifier.addTrustedIssuer(claimIssuer.target, [2])).to.be.revertedWith('trusted Issuer already exists');
      });
    });

    describe('when claim topics array is empty', () => {
      it('should revert', async () => {
        const [deployer] = await ethers.getSigners();
        const verifier = await ethers.deployContract('Verifier');

        await expect(verifier.addTrustedIssuer(deployer.address, [])).to.be.revertedWith('trusted claim topics cannot be empty');
      });
    });

    describe('when claim topics array contains more than 15 topics', () => {
      it('should revert', async () => {
        const [deployer] = await ethers.getSigners();
        const verifier = await ethers.deployContract('Verifier');

        await expect(verifier.addTrustedIssuer(deployer.address, [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16])).to.be.revertedWith('cannot have more than 15 claim topics');
      });
    });

    describe('when adding a 51th trusted issuer', () => {
      it('should revert', async () => {
        const [deployer] = await ethers.getSigners();
        const verifier = await ethers.deployContract('Verifier');
        for (let i = 0; i < 50; i++) {
          const claimIssuer = await ethers.deployContract('ClaimIssuer', [deployer.address]);
          await verifier.addTrustedIssuer(claimIssuer.target, [1]);
        }

        const claimIssuer = await ethers.deployContract('ClaimIssuer', [deployer.address]);
        await expect(verifier.addTrustedIssuer(claimIssuer.target, [1])).to.be.revertedWith('cannot have more than 50 trusted issuers');
      });
    });
  });

  describe('.updateIssuerClaimTopics', () => {
    describe('when not called by the owner', () => {
      it('should revert', async () => {
        const [deployer, aliceWallet] = await ethers.getSigners();
        const verifier = await ethers.deployContract('Verifier');
        const claimIssuer = await ethers.deployContract('ClaimIssuer', [aliceWallet.address]);

        await expect(verifier.connect(aliceWallet).updateIssuerClaimTopics(claimIssuer.target, [1])).to.be.revertedWith('Ownable: caller is not the owner');
      });
    });

    describe('when called by the owner', () => {
      it('should update the issuer claim topics', async () => {
        const [deployer, aliceWallet] = await ethers.getSigners();
        const verifier = await ethers.deployContract('Verifier');
        const claimIssuer = await ethers.deployContract('ClaimIssuer', [aliceWallet.address]);
        await verifier.addTrustedIssuer(claimIssuer.target, [1]);

        const tx = await verifier.updateIssuerClaimTopics(claimIssuer.target, [2, 3]);
        await expect(tx).to.emit(verifier, 'ClaimTopicsUpdated').withArgs(claimIssuer.target, [2, 3]);
        expect(await verifier.isTrustedIssuer(claimIssuer.target)).to.be.true;
        expect(await verifier.getTrustedIssuersForClaimTopic(1)).to.be.empty;
        expect(await verifier.getTrustedIssuerClaimTopics(claimIssuer.target)).to.be.deep.equal([2, 3]);
        expect(await verifier.hasClaimTopic(claimIssuer.target, 2)).to.be.true;
        expect(await verifier.hasClaimTopic(claimIssuer.target, 1)).to.be.false;
      });
    });

    describe('when issuer address is the zero address', () => {
      it('should revert', async () => {
        const verifier = await ethers.deployContract('Verifier');

        await expect(verifier.updateIssuerClaimTopics(ethers.ZeroAddress, [1])).to.be.revertedWith('invalid argument - zero address');
      });
    });

    describe('when issuer is not trusted', () => {
      it('should revert', async () => {
        const [deployer, aliceWallet] = await ethers.getSigners();
        const verifier = await ethers.deployContract('Verifier');
        const claimIssuer = await ethers.deployContract('ClaimIssuer', [aliceWallet.address]);

        await expect(verifier.updateIssuerClaimTopics(claimIssuer.target, [1])).to.be.revertedWith('NOT a trusted issuer');
      });
    });

    describe('when list of topics contains more than 15 topics', () => {
      it('should revert', async () => {
        const [deployer, aliceWallet] = await ethers.getSigners();
        const verifier = await ethers.deployContract('Verifier');
        const claimIssuer = await ethers.deployContract('ClaimIssuer', [aliceWallet.address]);
        await verifier.addTrustedIssuer(claimIssuer.target, [1]);

        await expect(verifier.updateIssuerClaimTopics(claimIssuer.target, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16])).to.be.revertedWith('cannot have more than 15 claim topics');
      });
    });

    describe('when list of topics is empty', () => {
      it('should revert', async () => {
        const [deployer, aliceWallet] = await ethers.getSigners();
        const verifier = await ethers.deployContract('Verifier');
        const claimIssuer = await ethers.deployContract('ClaimIssuer', [aliceWallet.address]);
        await verifier.addTrustedIssuer(claimIssuer.target, [1]);

        await expect(verifier.updateIssuerClaimTopics(claimIssuer.target, [])).to.be.revertedWith('claim topics cannot be empty');
      });
    });
  });

  describe('.getTrustedIssuerClaimTopic', () => {
    describe('when issuer is not trusted', () => {
      it('should revert', async () => {
        const [deployer, aliceWallet] = await ethers.getSigners();
        const verifier = await ethers.deployContract('Verifier');
        const claimIssuer = await ethers.deployContract('ClaimIssuer', [aliceWallet.address]);

        await expect(verifier.getTrustedIssuerClaimTopics(claimIssuer.target)).to.be.revertedWith('trusted Issuer doesn\'t exist');
      });
    });
  });
});
