const { expect } = require("chai");

const { shouldBehaveLikeERC734 } = require("./ERC734.behavior");
const { shouldBehaveLikeERC735 } = require("./ERC735.behavior");

const Identity = artifacts.require("Identity");
const IdentityFactory = artifacts.require("IdentityFactory");

contract("Identity", function ([
  identityIssuer,
  identityOwner,
  claimIssuer,
  anotherAccount,
]) {
  describe("Identity", function () {
    beforeEach(async function () {
      this.identity = await Identity.new({ from: identityIssuer });
      this.identityFactory = await IdentityFactory.new(this.identity.address, {
        from: identityIssuer,
      });
      await this.identityFactory.createIdentity(identityIssuer);
      this.identity = await Identity.at(
        await this.identityFactory.identityAddresses(0)
      );
    });

    shouldBehaveLikeERC734({
      errorPrefix: "ERC734",
      identityIssuer,
      identityOwner,
      anotherAccount,
    });

    shouldBehaveLikeERC735({
      errorPrefix: "ERC735",
      identityIssuer,
      identityOwner,
      claimIssuer,
      anotherAccount,
    });

    it("Should be a Cloned Identity", async function () {
      expect(
        await this.identityFactory.isClonedIdentity(this.identity.address)
      ).to.equals(true);
    });

    it("Should returns Identities", async function () {
      await this.identityFactory.createIdentity(identityIssuer);
      await this.identityFactory.createIdentity(identityIssuer);

      const identity0 = await this.identityFactory.identityAddresses(0);
      const identity1 = await this.identityFactory.identityAddresses(1);
      const identity2 = await this.identityFactory.identityAddresses(2);

      expect(await this.identityFactory.getIdentities()).to.include(
        identity0,
        identity1,
        identity2
      );
    });

    it("Should set a new LibraryAddress", async function () {
      const newIdentity = await Identity.new({ from: identityIssuer });
      await this.identityFactory.setLibraryAddress(newIdentity.address);
      expect(await this.identityFactory.libraryAddress()).to.equals(
        newIdentity.address
      );
    });

    it("Should not be able to set an Identity", async function () {
      const loadedIdentityWithAnotherAccount = await Identity.at(
        await this.identityFactory.identityAddresses(0)
      );
      await expect(
        loadedIdentityWithAnotherAccount.set(anotherAccount, {
          from: anotherAccount,
        })
      ).to.be.rejectedWith(Error);
    });
  });
});
