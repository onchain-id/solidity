const { expect } = require('chai');

const { shouldBehaveLikeERC734 } = require('./ERC734.behavior');
const { shouldBehaveLikeERC735 } = require('./ERC735.behavior');

const Identity = artifacts.require('Identity');
const IdentityFactory = artifacts.require('IdentityFactory');

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
      this.identityFactory = await IdentityFactory.new(this.identity.address, {
        from: identityIssuer,
      });
      identityCreated0 = await this.identityFactory.createIdentity(
        identityIssuer
      );
      this.identity = await Identity.at(
        identityCreated0.logs[0].args.newIdentityAddress
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

    it('Should be a Cloned Identity', async function () {
      expect(
        await this.identityFactory.isClonedIdentity(this.identity.address)
      ).to.equals(true);
    });

    it('Should set a new LibraryAddress', async function () {
      const newIdentity = await Identity.new({ from: identityIssuer });
      await this.identityFactory.setLibraryAddress(newIdentity.address);
      expect(await this.identityFactory.libraryAddress()).to.equals(
        newIdentity.address
      );
    });

    it('Should not be able to set an Identity twice', async function () {
      const identity0 = identityCreated0.logs[0].args.newIdentityAddress;
      const loadedIdentityWithAnotherAccount = await Identity.at(identity0);
      await expect(
        loadedIdentityWithAnotherAccount.set(anotherAccount, {
          from: anotherAccount,
        })
      ).to.be.rejectedWith(Error);
    });
  });
});
