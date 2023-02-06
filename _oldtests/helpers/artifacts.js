const Factory = artifacts.require('../contracts/factory/IdFactory.sol');
const IdentityProxy = artifacts.require('../contracts/proxy/IdentityProxy.sol');
const ImplementationAuthority = artifacts.require('../contracts/proxy/ImplementationAuthority.sol');
const Identity = artifacts.require('../contracts/Identity.sol');
const ClaimIssuer = artifacts.require('../contracts/ClaimIssuer.sol');

module.exports = {
  Factory,
  IdentityProxy,
  ImplementationAuthority,
  Identity,
  ClaimIssuer,
};
