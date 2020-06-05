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
let signer;
let signerKey;

contract("ClaimIssuer", function([identityIssuer, issuer, anotherAccount]) {
  describe("ClaimIssuer", function() {
    beforeEach(async function() {
      claimIssuer = await ClaimIssuer.new({ from: issuer });
      identity = await Identity.new({ from: identityIssuer });

      signer = web3.eth.accounts.create();
      signerKey = web3.utils.keccak256(
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

		it("Should remove the given claim if multiple exist for a topic", async () => {
			let newClaimIssuer = await ClaimIssuer.new({ from: issuer });
			await newClaimIssuer.addKey(signerKey, 3, 1, { from: issuer });

			await identity.addClaim(
        7,
        1,
        newClaimIssuer.address,
        signature,
        hexedData,
        "",
        { from: identityIssuer }
      );
			let claimIds = await identity.getClaimIdsByTopic(7);
      await identity.removeClaim(claimIds[1], {
        from: identityIssuer
			});
			claimIds = await identity.getClaimIdsByTopic(7);
      expect(claimIds.length).to.equal(1);
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
		
		it("Should revoke claim if called by the contract", async () => {
			const claimIds = await identity.getClaimIdsByTopic(7);
			const to = await claimIssuer.address;
			const contract = new web3.eth.Contract(ClaimIssuer.abi, claimIssuer.address)
			const data = contract.methods.revokeClaim(claimIds[0], identity.address).encodeABI();
			await claimIssuer.execute(to, 0, data, { from: issuer });
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
  });
});
