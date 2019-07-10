const { expect } = require('chai');
const { bufferToHex, keccak256 } = require('ethereumjs-util');
const abi = require('ethereumjs-abi');

function shouldBehaveLikeERC734 ({ errorPrefix, identityIssuer, identityOwner }) {
  describe('constructor', function () {
    it('has the the address of the identity issuer as MANAGEMENT key', async function () {
      const keys = await this.identity.getKeysByPurpose(1);

      expect(keys).to.deep.equal([bufferToHex(keccak256(abi.rawEncode(['address'], [identityIssuer])))], `${errorPrefix}: The hash of the owner address should be the only MANAGEMENT key after deploy.`);
    })
  });

  describe('addKey', function () {
    context('when sender has no management key', function () {
      it('reverts for insufficient privileges', async function () {
        this.skip();
      });
    });

    context('when sender has a management key', function () {
      context('when key is already registered with this purpose', function () {
        it('reverts for conflict', async function () {
          this.skip();
        });
      });

      context('when key is already registered but not with this purpose', function () {
        it('adds the purpose to the key and emits a KeyAdded event', async function () {
          this.skip();
        });
      });

      context('when key is not registered', function () {
        it('adds the key with the purpose and emits a KeyAdded event', async function () {
          this.skip();
        });
      });
    });
  });

  describe('getKey', function () {
    context('when identity has not the key', function () {
      it('returns an empty key description', async function () {
        this.skip();
      });
    });

    context('when identity has the key', function () {
      it('returns the key details', async function () {
        this.skip();
      });
    });
  });

  describe('getKeysByPurpose', function () {
    context('when identity never had any key of this purpose', function () {
      it('returns false', async function () {
        this.skip();
      });
    });

    context('when identity has no key of this purpose, but used to have one', function () {
      it('returns false', async function () {
        this.skip();
      });
    });

    context('when identity has key of this purpose', function () {
      it('returns false', async function () {
        this.skip();
      });
    });
  });

  describe('keyHasPurpose', function () {
    context('when identity has no such key', function () {
      it('returns false', async function () {
        this.skip();
      });
    });

    context('when identity has the key which does not have the purpose', function () {
      it('returns false', async function () {
        this.skip();
      });
    });

    context('when identity has the key with the purpose', function () {
      it('returns true', async function () {
        this.skip();
      });
    });

    context('when identity has the key with a management purpose', function () {
      it('returns true', async function () {
        this.skip();
      });
    });
  });

  describe('removeKey', function () {
    context('when sender has no management key', function () {
      it('reverts for insufficient privileges', async function () {
        this.skip();
      });
    });

    context('when sender has a management key', function () {
      context('when the key is not registered', function () {
        it('reverts for non-existing key', async function () {
          this.skip();
        });
      });

      context('when the key is registered but not with the removed purpose', function () {
        it('reverts for non-existing key purpose', async function () {
          this.skip();
        });
      });

      context('when the key is registered with more purpose than the removed one', function () {
        it('removes the purpose from the key and emits a KeyRemoved event', async function () {
          this.skip();
        });
      });

      context('when the key is registered with the removed purpose only', function () {
        it('removes the key and emits a KeyRemoved event', async function () {
          this.skip();
        });
      });
    });
  });
}

module.exports = {
  shouldBehaveLikeERC734,
};
