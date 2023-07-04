import {ethers} from "hardhat";
import {expect} from "chai";

describe('VerifierUser', () => {
  describe('when calling a verified function not as an identity', () => {
    it('should revert', async () => {
      const verifierUser = await ethers.deployContract('VerifierUser', []);

      await verifierUser.addClaimTopic(666);

      await expect(verifierUser.doSomething()).to.be.reverted;
    });
  });

  describe('when identity is verified', () => {
    it('should return', async () => {
      const [deployer, aliceWallet, claimIssuerWallet] = await ethers.getSigners();
      const claimIssuer = await ethers.deployContract('ClaimIssuer', [claimIssuerWallet.address]);
      const aliceIdentity = await ethers.deployContract('Identity', [aliceWallet.address, false]);
      const verifierUser = await ethers.deployContract('VerifierUser', []);

      await verifierUser.addClaimTopic(666);
      await verifierUser.addTrustedIssuer(claimIssuer.address, [666]);

      const aliceClaim666 = {
        id: '',
        identity: aliceIdentity.address,
        issuer: claimIssuer.address,
        topic: 666,
        scheme: 1,
        data: '0x0042',
        signature: '',
        uri: 'https://example.com',
      };
      aliceClaim666.signature = await claimIssuerWallet.signMessage(ethers.utils.arrayify(ethers.utils.keccak256(ethers.utils.defaultAbiCoder.encode(['address', 'uint256', 'bytes'], [aliceClaim666.identity, aliceClaim666.topic, aliceClaim666.data]))));
      await aliceIdentity.connect(aliceWallet).addClaim(
        aliceClaim666.topic,
        aliceClaim666.scheme,
        aliceClaim666.issuer,
        aliceClaim666.signature,
        aliceClaim666.data,
        aliceClaim666.uri,
      );

      const action = {
        to: verifierUser.address,
        value: 0,
        data: new ethers.utils.Interface(['function doSomething()']).encodeFunctionData('doSomething'),
      };

      const tx = await aliceIdentity.connect(aliceWallet).execute(
        action.to,
        action.value,
        action.data,
      );
      expect(tx).to.emit(aliceIdentity, 'Executed');
    });
  });

  describe('when identity is not verified', () => {
    it('should revert', async () => {
      const [deployer, aliceWallet, claimIssuerWallet] = await ethers.getSigners();
      const claimIssuer = await ethers.deployContract('ClaimIssuer', [claimIssuerWallet.address]);
      const aliceIdentity = await ethers.deployContract('Identity', [aliceWallet.address, false]);
      const verifierUser = await ethers.deployContract('VerifierUser', []);

      await verifierUser.addClaimTopic(666);
      await verifierUser.addTrustedIssuer(claimIssuer.address, [666]);

      const aliceClaim666 = {
        id: '',
        identity: aliceIdentity.address,
        issuer: claimIssuer.address,
        topic: 666,
        scheme: 1,
        data: '0x0042',
        signature: '',
        uri: 'https://example.com',
      };
      aliceClaim666.signature = await claimIssuerWallet.signMessage(ethers.utils.arrayify(ethers.utils.keccak256(ethers.utils.defaultAbiCoder.encode(['address', 'uint256', 'bytes'], [aliceClaim666.identity, aliceClaim666.topic, aliceClaim666.data]))));
      await aliceIdentity.connect(aliceWallet).addClaim(
        aliceClaim666.topic,
        aliceClaim666.scheme,
        aliceClaim666.issuer,
        aliceClaim666.signature,
        aliceClaim666.data,
        aliceClaim666.uri,
      );

      await claimIssuer.connect(claimIssuerWallet).revokeClaimBySignature(aliceClaim666.signature);

      const action = {
        to: verifierUser.address,
        value: 0,
        data: new ethers.utils.Interface(['function doSomething()']).encodeFunctionData('doSomething'),
      };

      const tx = await aliceIdentity.connect(aliceWallet).execute(
        action.to,
        action.value,
        action.data,
      );
      expect(tx).to.emit(aliceIdentity, 'ExecutionFailed');
    });
  });
});
