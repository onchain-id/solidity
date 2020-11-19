const { expect } = require('chai');

const { shouldBehaveLikeERC734 } = require('./ERC734.behavior');
const { shouldBehaveLikeERC735 } = require('./ERC735.behavior');

const Identity = artifacts.require('Identity');

contract('Identity', function ([
  identityIssuer,
  identityOwner,
  claimIssuer,
  anotherAccount,
]) {

  describe('Identity', function () {
    beforeEach(async function () {
      this.identity = await Identity.new({ from: identityIssuer });
      await this.identity.setManager(identityIssuer);
    });

    shouldBehaveLikeERC734({
      errorPrefix: 'ERC734',
      identityIssuer,
      identityOwner,
      anotherAccount,
    });

    shouldBehaveLikeERC735({
      errorPrefix: 'ERC735',
      identityIssuer,
      identityOwner,
      claimIssuer,
      anotherAccount,
    });

  });
});
