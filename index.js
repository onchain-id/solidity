const IClaimIssuer = require('./artifacts/contracts/interface/IClaimIssuer.sol/IClaimIssuer.json');
const IERC734 = require('./artifacts/contracts/interface/IERC734.sol/IERC734.json');
const IERC735 = require('./artifacts/contracts/interface/IERC735.sol/IERC735.json');
const IIdentity = require('./artifacts/contracts/interface/IIdentity.sol/IIdentity.json');
const IImplementationAuthority = require('./artifacts/contracts/interface/IImplementationAuthority.sol/IImplementationAuthority.json');

const ClaimIssuer = require('./artifacts/contracts/ClaimIssuer.sol/ClaimIssuer.json');
const Identity = require('./artifacts/contracts/Identity.sol/Identity.json');
const ImplementationAuthority = require('./artifacts/contracts/proxy/ImplementationAuthority.sol/ImplementationAuthority.json');
const IdentityProxy = require('./artifacts/contracts/proxy/IdentityProxy.sol/IdentityProxy.json');

const types = require('./typechain-types');

module.exports = {
  contracts: {
    ClaimIssuer,
    Identity,
    ImplementationAuthority,
    IdentityProxy,
  },
  interfaces: {
    IClaimIssuer,
    IERC734,
    IERC735,
    IIdentity,
    IImplementationAuthority,
  },
  types,
};
