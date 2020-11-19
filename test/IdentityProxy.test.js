const {replaceAddressOnImplementation} = require("./helpers/utils");
const { expect } = require('chai');

const { shouldBehaveLikeERC734 } = require('./ERC734.behavior');
const { shouldBehaveLikeERC735 } = require('./ERC735.behavior');

const Identity = artifacts.require('Identity');
const Implementation = artifacts.require('ImplementationAuthority');
const Proxy = artifacts.require('Proxy');
const NewIdentity = artifacts.require('NewIdentity');

// const IdentityFactory = artifacts.require('IdentityFactory');

contract('Identity', function ([
  identityIssuer,
  identityOwner,
  claimIssuer,
  anotherAccount,
]) {
  let identityCreated0;

  describe('Identity', function () {

    beforeEach(async function () {
      this.identity = await Identity.new({ from: identityIssuer });
      this.implementation = await Implementation.new(
        this.identity.address
      );
      this.proxy = await Proxy.new(this.implementation.address);
      this.identity = await Identity.at(
        this.proxy.address
      );
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

    it('Should return version', async function () {
      expect(await this.identity.version()).to.equals("1.0.0");
    });

    it('Should replace the implementation with a new one', async function () {
      expect((await this.identity.MANAGEMENT_KEY()).toString()).to.equals('1');
      expect((await this.identity.ACTION_KEY()).toString()).to.equals('2');
      expect((await this.identity.CLAIM_SIGNER_KEY()).toString()).to.equals('3');
      expect((await this.identity.ENCRYPTION_KEY()).toString()).to.equals('4');
      expect((await this.identity.version()).toString()).to.equals('1.0.0');

      // Deploy & Replace Implementation on AuthorityImplementation with the new Identity Contract
      this.newImplementation = await NewIdentity.new({ from: identityIssuer });
      this.implementation.updateImplementation(this.newImplementation.address);

      expect((await this.identity.MANAGEMENT_KEY()).toString()).to.equals('11');
      expect((await this.identity.ACTION_KEY()).toString()).to.equals('22');
      expect((await this.identity.CLAIM_SIGNER_KEY()).toString()).to.equals('33');
      expect((await this.identity.ENCRYPTION_KEY()).toString()).to.equals('44');
      expect((await this.identity.version()).toString()).to.equals('2.1.0');
    });

  });
});
