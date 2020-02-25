const { expect } = require("chai");
const { shouldBehaveLikeERC734 } = require("./ERC734.behavior");
const { shouldBehaveLikeERC735 } = require("./ERC735.behavior");
const expectRevert = require("./helpers/expectRevert");
const expectEvent = require("./helpers/expectEvent");

const ClaimIssuer = artifacts.require("ClaimIssuer");
const Identity = artifacts.require("Identity");
let claimIssuer;
let identity;
let signature;
let hexedData;

contract("ClaimIssuer", function([identityIssuer, issuer, anotherAccount]) {
  describe("ClaimIssuer", function() {
    beforeEach(async function() {
      claimIssuer = await ClaimIssuer.new({ from: issuer });
      identity = await Identity.new({ from: identityIssuer });

      let signer = web3.eth.accounts.create();
      const signerKey = web3.utils.keccak256(
        web3.eth.abi.encodeParameter("address", signer.address)
      );

      await claimIssuer.addKey(signerKey, 3, 1, { from: issuer });

      // identity gets signature from claim issuer
      hexedData = await web3.utils.asciiToHex(
        "Yea no, this guy is totes legit"
      );
      const hashedDataToSign = web3.utils.keccak256(
        web3.eth.abi.encodeParameters(
          ["address", "uint256", "bytes"],
          [identity.address, 7, hexedData]
        )
      );

      signature = (await signer.sign(hashedDataToSign)).signature;

      // identity adds claim to identity contract
      await identity.addClaim(
        7,
        1,
        claimIssuer.address,
        signature,
        hexedData,
        "",
        { from: identityIssuer }
      );
    });

    it("Should revoke claim if sender has management key", async () => {
      const claimIds = await identity.getClaimIdsByTopic(7);
      await claimIssuer.revokeClaim(claimIds[0], identity.address, {
        from: issuer
      });
      expect(await claimIssuer.isClaimRevoked(signature)).to.equal(true);
    });

    it("Should revoke claim if sender does not have management key", async () => {
      const claimIds = await identity.getClaimIdsByTopic(7);
      await expectRevert(
        claimIssuer.revokeClaim(claimIds[0], identity.address, {
          from: anotherAccount
        }),
        "Permissions: Sender does not have management key."
      );
      expect(await claimIssuer.isClaimRevoked(signature)).to.equal(false);
    });

    it("Should return true of claim is valid", async () => {
      let result = await claimIssuer.isClaimValid(
        identity.address,
        7,
        signature,
        hexedData,
        {
          from: issuer
        }
      );
      expect(result).to.equal(true);
    });

    it("Should return false if claim is revoked", async () => {
      const claimIds = await identity.getClaimIdsByTopic(7);
      await claimIssuer.revokeClaim(claimIds[0], identity.address, {
        from: issuer
      });
      expect(await claimIssuer.isClaimRevoked(signature)).to.equal(true);
      let result = await claimIssuer.isClaimValid(
        identity.address,
        7,
        signature,
        hexedData,
        {
          from: issuer
        }
      );
      expect(result).to.equal(false);
    });

    it("Should return true of claim is valid", async () => {
      let result = await claimIssuer.isClaimValid(
        identity.address,
        7,
        "0x000",
        hexedData,
        {
          from: issuer
        }
      );
      expect(result).to.equal(false);
    });
  });
});
