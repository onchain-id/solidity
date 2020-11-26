const { expect } = require('chai');

const { shouldBehaveLikeERC734 } = require('./ERC734.behavior');
const { shouldBehaveLikeERC735 } = require('./ERC735.behavior');

const Identity = artifacts.require('Identity');
const Implementation = artifacts.require('ImplementationAuthority');
const Proxy = artifacts.require('Proxy');
const NewIdentity = artifacts.require('NewIdentity');

contract('Identity', function ([
  identityIssuer,
  identityOwner,
  claimIssuer,
  anotherAccount,
]) {

  describe('Identity', function () {

    beforeEach(async function () {
      this.identity = await Identity.new(identityIssuer, { from: identityIssuer });
      this.implementation = await Implementation.new(
        this.identity.address
      );
      this.proxy = await Proxy.new(this.implementation.address);
      this.identity = await Identity.at(
        this.proxy.address
      );
      await this.identity.setInitialManagementKey(identityIssuer);
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

    it('Should return version', async function () {
      expect(await this.identity.version()).to.equals("1.0.0");
    });

    it('Should replace the implementation with a new one', async function () {
      expect((await this.identity.version()).toString()).to.equals('1.0.0');

      // Deploy & Replace Implementation on AuthorityImplementation with the new Identity Contract
      this.newImplementation = await NewIdentity.new({ from: identityIssuer });
      this.implementation.updateImplementation(this.newImplementation.address);

      expect((await this.identity.version()).toString()).to.equals('2.1.0');
    });

  });
});
