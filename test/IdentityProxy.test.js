const { expect } = require('chai');

const { shouldBehaveLikeERC734 } = require('./ERC734.behavior');
const { shouldBehaveLikeERC735 } = require('./ERC735.behavior');

const Identity = artifacts.require('Identity');
const Implementation = artifacts.require('ImplementationAuthority');
const IdentityProxy = artifacts.require('IdentityProxy');
const NewIdentity = artifacts.require('NewIdentity');

contract('IdentityProxy', function ([
  identityIssuer,
  identityOwner,
  claimIssuer,
  anotherAccount,
]) {

  describe('IdentityProxy', function () {

    beforeEach(async function () {
      this.identityImplementation = await Identity.new(identityIssuer, true, { from: identityIssuer });
      this.implementation = await Implementation.new(
        this.identityImplementation.address
      );
      this.proxy = await IdentityProxy.new(
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

    it('Should prevent interaction with the implementation', async function () {
      expect(this.identityImplementation.removeClaim('0x5fe52eb367804d226afc6386050a629ba0ca6b30bed2f1487dc7afde7db13771')).to.eventually.be.rejectedWith('Returned error: VM Exception while processing transaction: revert Interacting with the library contract is forbidden. -- Reason given: Interacting with the library contract is forbidden..');
    });

    it('Should return version', async function () {
      expect(await this.identity.version()).to.equals("2.0.0");
    });
  });
});
