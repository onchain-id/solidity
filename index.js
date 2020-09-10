const IClaimIssuer = require('./build/contracts/IClaimIssuer');
const IERC734 = require('./build/contracts/IERC734');
const IERC735 = require('./build/contracts/IERC735');
const ClaimIssuer = require('./build/contracts/ClaimIssuer');
const ERC734 = require('./build/contracts/ERC734');
const Identity = require('./build/contracts/Identity');
const IIdentity = require('./build/contracts/IIdentity');
const IdentityFactory = require('./build/contracts/IdentityFactory.json');
const CloneFactory = require('./build/contracts/CloneFactory.json');

module.exports = {
  contracts: {
    ClaimIssuer,
    ERC734,
    Identity,
    IdentityFactory,
    CloneFactory,
  },
  interfaces: {
    IClaimIssuer,
    IERC734,
    IERC735,
    IIdentity,
  },
};
