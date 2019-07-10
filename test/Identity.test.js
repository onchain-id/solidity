const { expect } = require('chai');
const { shouldBehaveLikeERC734 } = require('./ERC734.behavior');

const Identity = artifacts.require('Identity');

contract('Identity', function ([identityIssuer, identityOwner, claimIssuer, anotherAccount]) {
  describe('Identity', function () {
    beforeEach(async function () {
      this.identity = await Identity.new();
    });

    shouldBehaveLikeERC734({
      errorPrefix: 'ERC734',
      identityIssuer,
      identityOwner,
    });
  });
});
