require('chai').use(require('chai-as-promised')).should();

const EVMRevert = require('./helpers/VMExceptionRevert');
const {
  Factory,
  ImplementationAuthority,
  Identity,
  ClaimIssuer,
} = require('./helpers/artifacts');

contract('ONCHAINID', (accounts) => {
  let factory;
  let implementationAuthority;
  let identityImplem;
  let claimIssuerContract;
  let user1Key;
  let user1AltKey;
  const signer = web3.eth.accounts.create();
  const signerKey = web3.utils.keccak256(
    web3.eth.abi.encodeParameter('address', signer.address)
  );
  const deployer = accounts[0];
  const claimIssuerWallet = accounts[1];
  const user1 = accounts[2];
  const user2 = accounts[3];
  const tokenFactory = accounts[4];
  const tokenOwner = accounts[5];
  const user1SecondaryWallet = accounts[6];
  const user1ActionAccount = accounts[7];
  const unauthorizedAccount = accounts[8];
  const token1 = '0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174';
  const token2 = '0xc2132D05D31c914a87C6611C10748AEb04B58e8F';
  const zeroAddress = '0x0000000000000000000000000000000000000000';
  let user1Identity;
  let user2Identity;
  let token1Identity;
  let token2Identity;

  before(async () => {
    // environment setup
    identityImplem = await Identity.new(deployer, true, { from: deployer });
    implementationAuthority = await ImplementationAuthority.new(
      identityImplem.address,
      { from: deployer }
    );
    claimIssuerContract = await ClaimIssuer.new(claimIssuerWallet, {
      from: claimIssuerWallet,
    });
    factory = await Factory.new(implementationAuthority.address, {
      from: deployer,
    });
  });

  describe('Testing Factory', () => {
    it('deploy 2 identities from the factory', async () => {
      await factory
        .createIdentity(zeroAddress, 'user1', { from: deployer })
        .should.be.rejectedWith(EVMRevert);
      await factory
        .createIdentity(user1, '', { from: deployer })
        .should.be.rejectedWith(EVMRevert);
      await factory.createIdentity(user1, 'user1', { from: deployer }).should.be
        .fulfilled;
      await factory
        .createIdentity(user1, 'user2', { from: deployer })
        .should.be.rejectedWith(EVMRevert);
      await factory
        .createIdentity(user2, 'user1', { from: deployer })
        .should.be.rejectedWith(EVMRevert);
      const idAddress1 = await factory.getIdentity(user1);
      await factory.createIdentity(user2, 'user2', { from: deployer }).should.be
        .fulfilled;
      const idAddress2 = await factory.getIdentity(user2);
      user1Identity = await Identity.at(idAddress1);
      user2Identity = await Identity.at(idAddress2);
      await user2Identity.getKeysByPurpose(1);
      const result1 = await factory.isSaltTaken('OIDuser1');
      result1.should.equal(true);
      const result2 = await factory.isSaltTaken('user1');
      result2.should.equal(false);
      const result3 = await factory.isSaltTaken('OIDuser2');
      result3.should.equal(true);
      const result4 = await factory.isSaltTaken('user2');
      result4.should.equal(false);
    });

    it('add/remove token Factory address', async () => {
      await factory
        .addTokenFactory(tokenFactory, { from: user1 })
        .should.be.rejectedWith(EVMRevert);
      await factory
        .removeTokenFactory(tokenFactory, { from: deployer })
        .should.be.rejectedWith(EVMRevert);
      const result1 = await factory.isTokenFactory(tokenFactory);
      result1.should.equal(false);
      await factory
        .addTokenFactory(zeroAddress, { from: deployer })
        .should.be.rejectedWith(EVMRevert);
      await factory.addTokenFactory(tokenFactory, { from: deployer }).should.be
        .fulfilled;
      const result2 = await factory.isTokenFactory(tokenFactory);
      result2.should.equal(true);
      await factory
        .addTokenFactory(tokenFactory, { from: deployer })
        .should.be.rejectedWith(EVMRevert);
      await factory
        .removeTokenFactory(tokenFactory, { from: user1 })
        .should.be.rejectedWith(EVMRevert);
      await factory
        .removeTokenFactory(zeroAddress, { from: deployer })
        .should.be.rejectedWith(EVMRevert);
      await factory.removeTokenFactory(tokenFactory, { from: deployer }).should
        .be.fulfilled;
      const result3 = await factory.isTokenFactory(tokenFactory);
      result3.should.equal(false);
    });

    it('test token ID deployment', async () => {
      await factory
        .createTokenIdentity(token1, tokenOwner, 'usdc', { from: tokenFactory })
        .should.be.rejectedWith(EVMRevert);
      await factory.addTokenFactory(tokenFactory, { from: deployer }).should.be
        .fulfilled;
      await factory
        .createTokenIdentity(zeroAddress, tokenOwner, 'usdc', {
          from: tokenFactory,
        })
        .should.be.rejectedWith(EVMRevert);
      await factory
        .createTokenIdentity(token1, zeroAddress, 'usdc', {
          from: tokenFactory,
        })
        .should.be.rejectedWith(EVMRevert);
      await factory
        .createTokenIdentity(token1, tokenOwner, '', { from: tokenFactory })
        .should.be.rejectedWith(EVMRevert);
      await factory.createTokenIdentity(token1, tokenOwner, 'usdc', {
        from: tokenFactory,
      }).should.be.fulfilled;
      await factory
        .createTokenIdentity(token1, tokenOwner, 'usdt', { from: tokenFactory })
        .should.be.rejectedWith(EVMRevert);
      await factory
        .createTokenIdentity(token2, tokenOwner, 'usdc', { from: tokenFactory })
        .should.be.rejectedWith(EVMRevert);
      await factory.createTokenIdentity(token2, tokenOwner, 'usdt', {
        from: deployer,
      }).should.be.fulfilled;
      const result1 = await factory.isSaltTaken('Tokenusdc');
      result1.should.equal(true);
      const result2 = await factory.isSaltTaken('usdc');
      result2.should.equal(false);
      const result3 = await factory.isSaltTaken('Tokenusdt');
      result3.should.equal(true);
      const result4 = await factory.isSaltTaken('usdt');
      result4.should.equal(false);
      const addressTokenId1 = await factory.getIdentity(token1);
      const addressTokenId2 = await factory.getIdentity(token2);
      token1Identity = await Identity.at(addressTokenId1);
      token2Identity = await Identity.at(addressTokenId2);
      await token1Identity.getKeysByPurpose(1);
      await token2Identity.getKeysByPurpose(1);
    });

    it('test link/unlink wallets', async () => {
      await factory
        .linkWallet(user1SecondaryWallet, { from: user1SecondaryWallet })
        .should.be.rejectedWith(EVMRevert);
      await factory
        .linkWallet(zeroAddress, { from: user1 })
        .should.be.rejectedWith(EVMRevert);
      await factory.linkWallet(user1SecondaryWallet, { from: user1 }).should.be
        .fulfilled;
      const idAddress1 = await factory.getIdentity(user1);
      const idAddresses = await factory.getWallets(idAddress1);
      idAddresses.should.deep.equal([user1, user1SecondaryWallet]);
      await factory
        .linkWallet(user1SecondaryWallet, { from: user1 })
        .should.be.rejectedWith(EVMRevert);
      await factory
        .unlinkWallet(zeroAddress, { from: user1 })
        .should.be.rejectedWith(EVMRevert);
      await factory
        .unlinkWallet(user1, { from: user1 })
        .should.be.rejectedWith(EVMRevert);
      await factory
        .unlinkWallet(user2, { from: user1 })
        .should.be.rejectedWith(EVMRevert);
      await factory.unlinkWallet(user1SecondaryWallet, { from: user1 }).should
        .be.fulfilled;
    });
  });

  describe('Testing Key Management', () => {
    it('addKey/removeKey test', async () => {
      user1Key = web3.utils.keccak256(
        web3.eth.abi.encodeParameter('address', user1)
      );
      const result1 = await user1Identity.getKey(user1Key);
      result1[0].toString().should.equal('1');
      result1[1].toString().should.equal('1');
      result1[2].should.equal(user1Key);
      const result2 = await user1Identity.getKeyPurposes(user1Key);
      result2.toString().should.equal('1');
      const result3 = await user1Identity.getKeysByPurpose(1);
      result3[0].should.equal(user1Key);
      result3.length.should.equal(1);
      user1AltKey = web3.utils.keccak256(
        web3.eth.abi.encodeParameter('address', user1SecondaryWallet)
      );
      await user1Identity
        .addKey(user1AltKey, 3, 1, { from: user2 })
        .should.be.rejectedWith(EVMRevert);
      await user1Identity
        .removeKey(user1AltKey, 3, { from: user1 })
        .should.be.rejectedWith(EVMRevert);
      await user1Identity.addKey(user1AltKey, 3, 1, { from: user1 }).should.be
        .fulfilled;
      await user1Identity
        .addKey(user1AltKey, 3, 1, { from: user1 })
        .should.be.rejectedWith(EVMRevert);
      await user1Identity.addKey(user1AltKey, 1, 1, { from: user1 }).should.be
        .fulfilled;
      await user1Identity.addKey(user1AltKey, 2, 1, { from: user1 }).should.be
        .fulfilled;
      await user1Identity.addKey(user1Key, 2, 1, { from: user1 }).should.be
        .fulfilled;
      await user1Identity
        .removeKey(user1AltKey, 2, { from: user2 })
        .should.be.rejectedWith(EVMRevert);
      await user1Identity.removeKey(user1AltKey, 2, { from: user1 }).should.be
        .fulfilled;
      await user1Identity
        .removeKey(user1AltKey, 2, { from: user1 })
        .should.be.rejectedWith(EVMRevert);
      const result4 = await user1Identity.getKeysByPurpose(1);
      result4.length.should.equal(2);
    });
  });

  describe('Testing Claim Management', () => {
    it('issue claims', async () => {
      const hexedData1 = await web3.utils.asciiToHex('kyc approved');
      const hashedDataToSign1 = web3.utils.keccak256(
        web3.eth.abi.encodeParameters(
          ['address', 'uint256', 'bytes'],
          [user1Identity.address, 7, hexedData1]
        )
      );
      const signature1 = (await signer.sign(hashedDataToSign1)).signature;

      // cannot issue invalid claims
      await user1Identity
        .addClaim(
          7,
          1,
          claimIssuerContract.address,
          signature1,
          hexedData1,
          '',
          { from: user1 }
        )
        .should.be.rejectedWith(EVMRevert);
      await claimIssuerContract.addKey(signerKey, 3, 1, {
        from: claimIssuerWallet,
      }).should.be.fulfilled;
      await user1Identity.addClaim(
        7,
        1,
        claimIssuerContract.address,
        signature1,
        hexedData1,
        '',
        { from: user1 }
      ).should.be.fulfilled;
      const revokeStatus = await claimIssuerContract.isClaimRevoked(signature1);
      revokeStatus.should.equal(false);
      const ids = await user1Identity.getClaimIdsByTopic(7);
      const claimId = ids[0];
      await user1Identity.getClaim(claimId);
      await user1Identity.removeClaim(claimId, { from: user1 }).should.be
        .fulfilled;
      await user1Identity
        .removeClaim(claimId, { from: user1 })
        .should.be.rejectedWith(EVMRevert);
      await user1Identity.addClaim(
        7,
        1,
        claimIssuerContract.address,
        signature1,
        hexedData1,
        '',
        { from: user1 }
      ).should.be.fulfilled;
    });

    it('revoke claims', async () => {
      const hexedData1 = await web3.utils.asciiToHex('kyc approved');
      const hashedDataToSign1 = web3.utils.keccak256(
        web3.eth.abi.encodeParameters(
          ['address', 'uint256', 'bytes'],
          [user1Identity.address, 7, hexedData1]
        )
      );
      const signature1 = (await signer.sign(hashedDataToSign1)).signature;
      const ids = await user1Identity.getClaimIdsByTopic(7);
      const claimId = ids[0];
      let claimValidity = await claimIssuerContract.isClaimValid(
        user1Identity.address,
        7,
        signature1,
        hexedData1
      );
      claimValidity.should.equal(true);
      await claimIssuerContract.revokeClaim(claimId, user1Identity.address, {
        from: claimIssuerWallet,
      }).should.be.fulfilled;
      claimValidity = await claimIssuerContract.isClaimValid(
        user1Identity.address,
        7,
        signature1,
        hexedData1
      );
      claimValidity.should.equal(false);
    });
  });

  describe('Testing approve/execute', () => {
    describe('When the sender is a MANAGEMENT key', () => {
      it('should immediately approves the execution', async () => {
        const currentBalance = await web3.eth.getBalance(user2);
        await web3.eth
          .getBalance(user1Identity.address)
          .should.eventually.equal('0');
        await user1Identity.execute(user2, 10, '0x', {
          value: 10,
          from: user1,
        }).should.be.fulfilled;
        const newBalance = await web3.eth.getBalance(user2);
        newBalance.should.equal(
          web3.utils.toBN(currentBalance).add(web3.utils.toBN('10')).toString()
        );
        await web3.eth
          .getBalance(user1Identity.address)
          .should.eventually.equal('0');
      });
    });

    describe('When the sender is a ACTION key', () => {
      it('should immediately approves the execution', async () => {
        await user1Identity.addKey(
          web3.utils.keccak256(
            web3.eth.abi.encodeParameter('address', user1ActionAccount)
          ),
          2,
          2,
          { from: user1 }
        );

        const currentBalance = await web3.eth.getBalance(user2);
        await web3.eth
          .getBalance(user1Identity.address)
          .should.eventually.equal('0');
        await user1Identity.execute(user2, 10, '0x', {
          value: 10,
          from: user1ActionAccount,
        }).should.be.fulfilled;
        await web3.eth
          .getBalance(user1Identity.address)
          .should.eventually.equal('0');
        const newBalance = await web3.eth.getBalance(user2);

        newBalance.should.equal(
          web3.utils.toBN(currentBalance).add(web3.utils.toBN('10')).toString()
        );

        await user1Identity.removeKey(
          web3.utils.keccak256(
            web3.eth.abi.encodeParameter('address', user1ActionAccount)
          ),
          2,
          { from: user1 }
        );
      });
    });

    describe('When the sender is an unknown key', () => {
      it('should store a pending approval', async () => {
        const currentBalance = await web3.eth.getBalance(user1);
        await web3.eth
          .getBalance(user1Identity.address)
          .should.eventually.equal('0');
        await user1Identity.execute(user2, 10, '0x', {
          from: user2,
          value: 10,
        }).should.be.fulfilled;
        await web3.eth
          .getBalance(user1Identity.address)
          .should.eventually.equal('10');
        const newBalance = await web3.eth.getBalance(user1);

        newBalance.should.equal(currentBalance);
      });

      describe('When approving as an unauthorized key', () => {
        it('should revert the approval', async () => {
          const currentBalance = await web3.eth.getBalance(user2);
          await web3.eth
            .getBalance(user1Identity.address)
            .should.eventually.equal('10');
          await user1Identity
            .approve(0, true, {
              from: unauthorizedAccount,
            })
            .should.be.rejectedWith(EVMRevert);
          await web3.eth
            .getBalance(user1Identity.address)
            .should.eventually.equal('10');
          const newBalance = await web3.eth.getBalance(user2);

          newBalance.should.equal(currentBalance);
        });
      });

      describe('When not approving as a MANAGEMENT key', () => {
        it('should be a no-op, leaving the approval status at false', async () => {
          await user1Identity.approve(2, false, {
            from: user1,
          }).should.be.fulfilled;
        });
      });

      describe('When approving as a MANAGEMENT key', () => {
        it('should approve the execution', async () => {
          const currentBalance = await web3.eth.getBalance(user2);
          await web3.eth
            .getBalance(user1Identity.address)
            .should.eventually.equal('10');
          await user1Identity.approve(2, true, {
            from: user1,
          }).should.be.fulfilled;
          await web3.eth
            .getBalance(user1Identity.address)
            .should.eventually.equal('0');
          const newBalance = await web3.eth.getBalance(user2);

          newBalance.should.equal(
            web3.utils
              .toBN(currentBalance)
              .add(web3.utils.toBN('10'))
              .toString()
          );
        });
      });
    });

    describe('When approving with an execution ID that is not assigned yet', () => {
      it('should revert for non-existing execution ID', async () => {
        await user1Identity
          .approve(100, true, {
            from: user1,
          })
          .should.be.rejectedWith(EVMRevert);
      });
    });

    describe('When executing an action over the identity itself', () => {
      describe('When signing with an ACTION key', () => {
        it('should revert the approval for non-authorized', async () => {
          await user1Identity.execute(user1Identity.address, 0, '0x', {
            from: unauthorizedAccount,
          });

          await user1Identity
            .approve(3, true, {
              from: user1ActionAccount,
            })
            .should.be.rejectedWith(EVMRevert);
        });
      });

      describe('When signing with a MANAGEMENT key', () => {
        it('should execute the pending request', async () => {
          await user1Identity.approve(3, true, {
            from: user1,
          }).should.be.fulfilled;
        });
      });
    });
  });
});
