const IERC734 = require('./build/contracts/IERC734');
const IERC735 = require('./build/contracts/IERC735');
const ERC734 = require('./build/contracts/ERC734');
const Identity = require('./build/contracts/Identity');

module.exports = {
  contracts: {
    ERC734,
    Identity,
  },
  interfaces: {
    IERC734,
    IERC735,
  },
};
