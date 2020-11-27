const IClaimIssuer = require('./build/contracts/IClaimIssuer');
const IIdentity = require('./build/contracts/IClaimIssuer');
const IERC734 = require('./build/contracts/IERC734');
const IERC735 = require('./build/contracts/IERC735');

const ClaimIssuer = require('./build/contracts/ClaimIssuer');
const Identity = require('./build/contracts/Identity');
const Proxy = require('./build/contracts/Proxy');

module.exports = {
  contracts: {
    ClaimIssuer,
    Identity,
    Proxy,
  },
  interfaces: {
    IClaimIssuer,
    IERC734,
    IERC735,
    IIdentity,
  },
};
