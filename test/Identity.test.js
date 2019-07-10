const { expect } = require('chai');
const { bufferToHex, keccak256 } = require('ethereumjs-util');
const abi = require('ethereumjs-abi');

const Identity = artifacts.require('Identity');

contract('Identity', function ([identityIssuer, identityOwner, claimIssuer, anotherAccount]) {
  describe('Identity', function () {
    beforeEach(async function () {
      this.identity = await Identity.new();
    });

    describe('contract creation', function () {
      it('adds the sender address as management key', async function () {
        const keys = await this.identity.getKeysByPurpose(1);

        expect(keys).to.deep.equal([bufferToHex(keccak256(abi.rawEncode(['address'], [identityIssuer])))], 'The hash of the owner address should be the only MANAGEMENT key after deploy.');
      });
    });
  });
});
