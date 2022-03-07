require('chai').use(require('chai-as-promised')).should();
const EVMRevert = require('./helpers/VMExceptionRevert');
const log = require('./helpers/logger');

const Identity = artifacts.require('Identity');
const Implementation = artifacts.require('ImplementationAuthority');
const Factory = artifacts.require('IdFactory');
const NewIdentity = artifacts.require('NewIdentity');

contract('IDFactory', (accounts) => {
  const owner = accounts[0];
  const user1 = accounts[1];
  const user2 = accounts[2];
  let implementationAuthority;
  let identityImplementation;
  let factory;
  let identity1;
  let identity2;



  beforeEach(async () => {
    identityImplementation = await Identity.new(owner, true, { from: owner });
    implementationAuthority = await Implementation.new(identityImplementation.address, { from: owner });
    factory = await Factory.new(implementationAuthority.address, { from: owner });
    await factory.createIdentity(user1 , 'user1', { from : owner});
    const idAddress = await factory.getIdentity(user1);
    identity1 = await NewIdentity.at(idAddress);
  });

  it('should not deploy 2 identities for 1 wallet', async () => {
    await factory.createIdentity(user1 , 'user2', { from : owner}).should.be.rejectedWith(EVMRevert);
  });

  it('should not deploy another identity with the same salt', async () => {
    await factory.createIdentity(user2 , 'user1', { from : owner}).should.be.rejectedWith(EVMRevert);
  });

  it('should deploy another identity', async () => {
    await factory.createIdentity(user2 , 'user2', { from : owner}).should.be.fulfilled;
  });

  it('cannot unlink the last wallet on an identity', async () => {
    await factory.unlinkWallet(user1, { from : user1}).should.be.rejectedWith(EVMRevert);
  });

  it('should link and unlink a new wallet on an identity', async () => {
    await factory.linkWallet(user2, { from : user1}).should.be.fulfilled;
    await factory.unlinkWallet(user2, { from : user1}).should.be.fulfilled;
  });

  it('cannot link a wallet already linked to another identity', async () => {
    await factory.createIdentity(user2 , 'user2', { from : owner}).should.be.fulfilled;
    await factory.linkWallet(user2, { from : user1}).should.be.rejectedWith(EVMRevert);
  });

  it('cannot unlink a wallet on an identity managed by someone else', async () => {
    await factory.createIdentity(user2 , 'user2', { from : owner}).should.be.fulfilled;
    await factory.unlinkWallet(user2, { from : user1}).should.be.rejectedWith(EVMRevert);
  });


});
