const chai = require('chai');
const chaiBN = require('chai-bn');
const chaiAsPromised = require('chai-as-promised');

const { BN } = web3.utils;

chai.use(chaiBN(BN));
chai.use(chaiAsPromised);
