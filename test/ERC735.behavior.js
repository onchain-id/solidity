const { bufferToHex, keccak256 } = require('ethereumjs-util');
const { expect } = require('chai');
const abi = require('ethereumjs-abi');

const { NULL_ADDRESS, NULL_KEY } = require('./helpers/constants');
const expectRevert = require('./helpers/expectRevert');
const expectEvent = require('./helpers/expectEvent');

function shouldBehaveLikeERC735({ errorPrefix, identityIssuer, identityOwner, claimIssuer, anotherAccount }) {
  describe('addClaim', function () {
    context('when sender has no CLAIM key', function () {
      it('reverts for insufficient privileges', async function () {
        await expectRevert(this.identity.addClaim(
          1,
          1,
          claimIssuer,
          '0x989',
          '0x10984',
          '',
          { from: identityOwner },
        ), 'Permissions: Sender does not have claim signer key');
      });
    });

    context('when sender has a CLAIM key', function () {
      context('when claim already exists', function () {
        beforeEach('add claim', async function () {
          await this.identity.addClaim(
            1,
            2,
            claimIssuer,
            '0x234564',
            '0x9087946767',
            '',
            { from: identityIssuer },
          );
        });

        it('updates the claim and emits a ClaimChanged event', async function () {
          const { logs } = await this.identity.addClaim(
            1,
            2,
            claimIssuer,
            '0x0989',
            '0x110984',
            '',
            { from: identityIssuer },
          );

          expectEvent.inLogs(logs, 'ClaimChanged', {
            claimId: bufferToHex(keccak256(abi.rawEncode(['address', 'uint256'], [claimIssuer, 1]))),
            topic: '1',
            scheme: '2',
            issuer: claimIssuer,
            signature: '0x0989',
            data: '0x110984',
            uri: '',
          });

          await expect(this.identity.getClaimIdsByTopic(1)).to.eventually.be.deep.equal([
            bufferToHex(keccak256(abi.rawEncode(['address', 'uint256'], [claimIssuer, 1])))
          ]);

          const claim = await this.identity.getClaim(bufferToHex(keccak256(abi.rawEncode(['address', 'uint256'], [claimIssuer, 1]))));
          expect(claim.topic).to.be.bignumber.equals('1');
          expect(claim.scheme).to.be.bignumber.equals('2');
          expect(claim.issuer).to.equals(claimIssuer);
          expect(claim.signature).to.equals('0x0989');
          expect(claim.data).to.equals('0x110984');
          expect(claim.uri).to.equals('');
        });
      });

      context('when claim does not already exist', function () {
        it('adds the claim and emits a ClaimAdded event', async function () {
          const { logs } = await this.identity.addClaim(
            1,
            2,
            claimIssuer,
            '0x0989',
            '0x12010984',
            '',
            { from: identityIssuer },
          );

          expectEvent.inLogs(logs, 'ClaimAdded', {
            claimId: bufferToHex(keccak256(abi.rawEncode(['address', 'uint256'], [claimIssuer, 1]))),
            topic: '1',
            scheme: '2',
            issuer: claimIssuer,
            signature: '0x0989',
            data: '0x12010984',
            uri: '',
          });

          await expect(this.identity.getClaimIdsByTopic(1)).to.eventually.be.deep.equal([
            bufferToHex(keccak256(abi.rawEncode(['address', 'uint256'], [claimIssuer, 1])))
          ]);

          const claim = await this.identity.getClaim(bufferToHex(keccak256(abi.rawEncode(['address', 'uint256'], [claimIssuer, 1]))));
          expect(claim.topic).to.be.bignumber.equals('1');
          expect(claim.scheme).to.be.bignumber.equals('2');
          expect(claim.issuer).to.equals(claimIssuer);
          expect(claim.signature).to.equals('0x0989');
          expect(claim.data).to.equals('0x12010984');
          expect(claim.uri).to.equals('');
        });
      });
    });

    context('when sender is Identity contract', function () {
      it('adds the claim through execute method', async function () {
        await expect(this.identity.getClaimIdsByTopic(1)).to.eventually.be.an('array').that.is.empty;
        const to = await this.identity.address;
        const value = 0;
        const data = bufferToHex(abi.simpleEncode(
          "addClaim(uint256,uint256,address,bytes,bytes,string)",
          1,
          2,
          claimIssuer,
          '0x234564',
          '0x9087946767',
          ''
        ));
        await this.identity.execute(to, 0, data, { from: identityIssuer });
        await expect(this.identity.getClaimIdsByTopic(1)).to.eventually.deep.equal([
          bufferToHex(keccak256(abi.rawEncode(['address', 'uint256'], [claimIssuer, 1])))
        ]);
      });
    });

  });

  describe('getClaim', function () {
    context('when claim does not exist', function () {
      it('returns an empty claim object', async function () {
        const claim = await this.identity.getClaim('0x9883');

        expect(claim.topic).to.be.bignumber.equals('0', 'topic was not 0');
        expect(claim.scheme).to.be.bignumber.equals('0', 'scheme was not 0');
        expect(claim.issuer).to.equals(NULL_ADDRESS, 'issuer was not null address');
        expect(claim.signature, 'signature was not null').to.be.null;
        expect(claim.data, 'data was not null').to.be.null;
        expect(claim.uri).to.equals('', 'uri was not an empty string');
      });
    });

    context('when claim does exist', function () {
      beforeEach('add claim', async function () {
        await this.identity.addClaim(
          1,
          2,
          claimIssuer,
          '0x234564',
          '0x9087946767',
          'https://localhost',
          { from: identityIssuer },
        );
      });

      it('returns the claim object', async function () {
        const claim = await this.identity.getClaim(
          bufferToHex(keccak256(abi.rawEncode(['address', 'uint256'], [claimIssuer, 1])))
        );

        expect(claim.topic).to.be.bignumber.equals('1', 'topic was not 1');
        expect(claim.scheme).to.be.bignumber.equals('2', 'scheme was not 2');
        expect(claim.issuer).to.equals(claimIssuer, 'issuer was not the correct address');
        expect(claim.signature).to.equals('0x234564', 'signature was not the one expected (beware of padding, bytes must be even)');
        expect(claim.data).to.equals('0x9087946767', 'data was not the one expected (beware of padding, bytes must be even)');
        expect(claim.uri).to.equals('https://localhost', 'uri was not the one expected');
      });
    });
  });

  describe('getClaimIdsByTopic', function () {
    context('when there are no claims for this topic', function () {
      it('returns an empty array', async function () {
        await expect(this.identity.getClaimIdsByTopic(1)).to.eventually.be.an('array').that.is.empty;
      });
    });

    context('when there are claims for this topic', function () {
      beforeEach('add claim', async function () {
        await this.identity.addClaim(
          1,
          2,
          claimIssuer,
          '0x234564',
          '0x9087946767',
          'https://localhost',
          { from: identityIssuer },
        );
      });

      it('returns an array of claim IDs', async function () {
        await expect(this.identity.getClaimIdsByTopic(1)).to.eventually.deep.equal([
          bufferToHex(keccak256(abi.rawEncode(['address', 'uint256'], [claimIssuer, 1])))
        ]);
      });
    });
  });

  describe('removeClaim', function () {
    context('when sender has no CLAIM key', function () {
      it('reverts for insufficient privileges', async function () {
        await expectRevert(this.identity.removeClaim(
          bufferToHex(keccak256(abi.rawEncode(['address', 'uint256'], [claimIssuer, 1]))),
          { from: identityOwner },
        ), 'Permissions: Sender does not have CLAIM key');
      });
    });

    context('when sender has a CLAIM key', function () {
      context('when claim does not exist', function () {
        it('reverts with non-existing claim error', async function () {
          await expectRevert(this.identity.removeClaim(
            bufferToHex(keccak256(abi.rawEncode(['address', 'uint256'], [claimIssuer, 1])))
          ), 'NonExisting: There is no claim with this ID');
        });
      });

      context('when claim does exist', function () {
        beforeEach('add claim', async function () {
          await this.identity.addClaim(
            1,
            2,
            claimIssuer,
            '0x234564',
            '0x9087946767',
            'https://localhost',
            { from: identityIssuer },
          );

          await this.identity.addClaim(
            1,
            2,
            anotherAccount,
            '0x234564',
            '0x9087946767',
            'https://localhost',
            { from: identityIssuer },
          );
        });

        it('removes the claim and emits a ClaimRemoved event', async function () {
          const { logs } = await this.identity.removeClaim(
            bufferToHex(keccak256(abi.rawEncode(['address', 'uint256'], [claimIssuer, 1]))),
            { from: identityIssuer },
          );

          await expectEvent.inLogs(logs, 'ClaimRemoved', {
            claimId: bufferToHex(keccak256(abi.rawEncode(['address', 'uint256'], [claimIssuer, 1]))),
            topic: '1',
            scheme: '2',
            issuer: claimIssuer,
            signature: '0x234564',
            data: '0x9087946767',
            uri: 'https://localhost',
          });

          await expect(this.identity.getClaimIdsByTopic(1)).to.eventually.deep.equals([
            bufferToHex(keccak256(abi.rawEncode(['address', 'uint256'], [anotherAccount, 1]))),
          ]);

          const claim = await this.identity.getClaim(bufferToHex(keccak256(abi.rawEncode(['address', 'uint256'], [claimIssuer, 1]))));

          expect(claim.topic).to.be.bignumber.equals('0', 'topic was not 0');
          expect(claim.scheme).to.be.bignumber.equals('0', 'scheme was not 0');
          expect(claim.issuer).to.equals(NULL_ADDRESS, 'issuer was not null address');
          expect(claim.signature, 'signature was not null').to.be.null;
          expect(claim.data, 'data was not null').to.be.null;
          expect(claim.uri).to.equals('', 'uri was not an empty string');
        });
      });
    });

    context('when sender is Identity contract', function () {
      it('removes the claim through execute method', async function () {
        await this.identity.addClaim(
          1,
          2,
          claimIssuer,
          '0x234564',
          '0x9087946767',
          '',
          { from: identityIssuer }
        );
        let claimId = await this.identity.getClaimIdsByTopic(1);
        const to = await this.identity.address;
        const value = 0;
        const data = bufferToHex(abi.simpleEncode("removeClaim(bytes32)", claimId[0]));
        await this.identity.execute(to, value, data, { from: identityIssuer });
        claimId = await this.identity.getClaimIdsByTopic(1);
        await expect(this.identity.getClaimIdsByTopic(1)).to.eventually.be.an('array').that.is.empty;
      });
    });
  });
}

module.exports = {
  shouldBehaveLikeERC735,
};
