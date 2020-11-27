const { expect } = require('chai');
const abi = require('ethereumjs-abi');

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
      const identityImplementation = await Identity.new(identityIssuer, true, { from: identityIssuer });
      this.implementation = await Implementation.new(
        identityImplementation.address
      );
      this.proxy = await Proxy.new(
        this.implementation.address,
        identityIssuer,
      );
      this.identity = await Identity.at(
        this.proxy.address,
      );
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

    it.only('Should return version', async function () {
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
