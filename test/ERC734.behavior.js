const { expect } = require('chai');
const { bufferToHex, keccak256 } = require('ethereumjs-util');
const abi = require('ethereumjs-abi');

const expectRevert = require('./helpers/expectRevert');
const expectEvent = require('./helpers/expectEvent');
const { NULL_KEY } = require('./helpers/constants');

function shouldBehaveLikeERC734({
  errorPrefix,
  identityIssuer,
  identityOwner,
  anotherAccount,
}) {
  describe('constructor', function () {
    it('has the the address of the identity issuer as MANAGEMENT key', async function () {
      const keys = await this.identity.getKeysByPurpose(1);

      expect(keys).to.deep.equal(
        [bufferToHex(keccak256(abi.rawEncode(['address'], [identityIssuer])))],
        `${errorPrefix}: The hash of the owner address should be the only MANAGEMENT key after deploy.`
      );
    });
  });

  describe('addKey', function () {
    context('when sender has no management key', function () {
      it('reverts for insufficient privileges', async function () {
        await expectRevert(
          this.identity.addKey(
            bufferToHex(keccak256(abi.rawEncode(['address'], [identityOwner]))),
            1,
            1,
            { from: identityOwner }
          ),
          'Permissions: Sender does not have management key'
        );
      });
    });

    context('when sender has a management key', function () {
      context('when key is already registered with this purpose', function () {
        it('reverts for conflict', async function () {
          await expectRevert(
            this.identity.addKey(
              bufferToHex(
                keccak256(abi.rawEncode(['address'], [identityIssuer]))
              ),
              1,
              1,
              { from: identityIssuer }
            ),
            'Conflict: Key already has purpose'
          );
        });
      });

      context(
        'when key is already registered but not with this purpose',
        function () {
          it('adds the purpose to the key and emits a KeyAdded event', async function () {
            const { logs } = await this.identity.addKey(
              bufferToHex(
                keccak256(abi.rawEncode(['address'], [identityIssuer]))
              ),
              3,
              1,
              { from: identityIssuer }
            );

            expectEvent.inLogs(logs, 'KeyAdded', {
              key: bufferToHex(
                keccak256(abi.rawEncode(['address'], [identityIssuer]))
              ),
              purpose: '3',
              keyType: '1',
            });

            const key = await this.identity.getKey(
              bufferToHex(
                keccak256(abi.rawEncode(['address'], [identityIssuer]))
              )
            );

            expect(key.key).to.equal(
              bufferToHex(
                keccak256(abi.rawEncode(['address'], [identityIssuer]))
              )
            );
            expect(key.keyType).to.be.bignumber.equal('1');
            expect(key.purposes).to.be.an('array').of.length(2);
          });
        }
      );

      context('when key is not registered', function () {
        it('adds the key with the purpose and emits a KeyAdded event', async function () {
          const { logs } = await this.identity.addKey(
            bufferToHex(keccak256(abi.rawEncode(['address'], [identityOwner]))),
            1,
            1,
            { from: identityIssuer }
          );

          expectEvent.inLogs(logs, 'KeyAdded', {
            key: bufferToHex(
              keccak256(abi.rawEncode(['address'], [identityOwner]))
            ),
            purpose: '1',
            keyType: '1',
          });

          const key = await this.identity.getKey(
            bufferToHex(keccak256(abi.rawEncode(['address'], [identityOwner])))
          );

          expect(key.key).to.equal(
            bufferToHex(keccak256(abi.rawEncode(['address'], [identityOwner])))
          );
          expect(key.keyType).to.be.bignumber.equal('1');
          expect(key.purposes).to.be.an('array').of.length(1);
        });
      });
    });
  });

  describe('getKey', function () {
    context('when identity has not the key', function () {
      it('returns an empty key description', async function () {
        const key = await this.identity.getKey(
          bufferToHex(keccak256(abi.rawEncode(['address'], [identityOwner])))
        );

        expect(key.key).to.equal(NULL_KEY);
        expect(key.keyType).to.be.bignumber.equal('0');
        expect(key.purposes).to.be.an('array').of.length(0);
      });
    });

    context('when identity has the key', function () {
      it('returns the key details', async function () {
        const key = await this.identity.getKey(
          bufferToHex(keccak256(abi.rawEncode(['address'], [identityIssuer])))
        );

        expect(key.key).to.equal(
          bufferToHex(keccak256(abi.rawEncode(['address'], [identityIssuer])))
        );
        expect(key.keyType).to.be.bignumber.equal('1');
        expect(key.purposes).to.be.an('array').of.length(1);
      });
    });
  });

  describe('getKeysByPurpose', function () {
    context('when identity never had any key of this purpose', function () {
      it('returns false', async function () {
        const keys = await this.identity.getKeysByPurpose(10);

        expect(keys).to.be.an('array').of.length(0);
      });
    });

    context(
      'when identity has no key of this purpose, but used to have one',
      function () {
        beforeEach('remove key', async function () {
          await this.identity.removeKey(
            bufferToHex(
              keccak256(abi.rawEncode(['address'], [identityIssuer]))
            ),
            1,
            { from: identityIssuer }
          );
        });

        it('returns false', async function () {
          const keys = await this.identity.getKeysByPurpose(10);

          expect(keys).to.be.an('array').of.length(0);
        });
      }
    );

    context('when identity has key of this purpose', function () {
      beforeEach('add keys', async function () {
        await this.identity.addKey(
          bufferToHex(keccak256(abi.rawEncode(['address'], [identityOwner]))),
          1,
          1,
          { from: identityIssuer }
        );

        await this.identity.addKey(
          bufferToHex(keccak256(abi.rawEncode(['address'], [anotherAccount]))),
          3,
          1,
          { from: identityIssuer }
        );
      });

      it('returns false', async function () {
        const keys = await this.identity.getKeysByPurpose(1);

        expect(keys).to.deep.equals([
          bufferToHex(keccak256(abi.rawEncode(['address'], [identityIssuer]))),
          bufferToHex(keccak256(abi.rawEncode(['address'], [identityOwner]))),
        ]);
      });
    });
  });

  describe('keyHasPurpose', function () {
    context('when identity has no such key', function () {
      it('returns false', async function () {
        await expect(
          this.identity.keyHasPurpose(
            bufferToHex(
              keccak256(abi.rawEncode(['address'], [anotherAccount]))
            ),
            1
          )
        ).to.eventually.be.false;
      });
    });

    context(
      'when identity has the key which does not have the purpose',
      function () {
        beforeEach('add key', async function () {
          await this.identity.addKey(
            bufferToHex(
              keccak256(abi.rawEncode(['address'], [anotherAccount]))
            ),
            3,
            1,
            { from: identityIssuer }
          );
        });

        it('returns false', async function () {
          await expect(
            this.identity.keyHasPurpose(
              bufferToHex(
                keccak256(abi.rawEncode(['address'], [anotherAccount]))
              ),
              1
            )
          ).to.eventually.be.false;
        });
      }
    );

    context('when identity has the key with the purpose', function () {
      beforeEach('add keys', async function () {
        await this.identity.addKey(
          bufferToHex(keccak256(abi.rawEncode(['address'], [anotherAccount]))),
          3,
          1,
          { from: identityIssuer }
        );
      });

      it('returns true', async function () {
        await expect(
          this.identity.keyHasPurpose(
            bufferToHex(
              keccak256(abi.rawEncode(['address'], [anotherAccount]))
            ),
            3
          )
        ).to.eventually.be.true;
      });
    });

    context('when identity has the key with a management purpose', function () {
      it('returns true', async function () {
        await expect(
          this.identity.keyHasPurpose(
            bufferToHex(
              keccak256(abi.rawEncode(['address'], [identityIssuer]))
            ),
            3
          )
        ).to.eventually.be.true;
      });
    });
  });

  describe('removeKey', function () {
    context('when sender has no management key', function () {
      it('reverts for insufficient privileges', async function () {
        await expectRevert(
          this.identity.removeKey(
            bufferToHex(
              keccak256(abi.rawEncode(['address'], [identityIssuer]))
            ),
            1,
            { from: identityOwner }
          ),
          'Permissions: Sender does not have management key'
        );
      });
    });

    context('when sender has a management key', function () {
      context('when the key is not registered', function () {
        it('reverts for non-existing key', async function () {
          await expectRevert(
            this.identity.removeKey(
              bufferToHex(
                keccak256(abi.rawEncode(['address'], [identityOwner]))
              ),
              1,
              { from: identityIssuer }
            ),
            "NonExisting: Key isn't registered"
          );
        });
      });

      context(
        'when the key is registered but not with the removed purpose',
        function () {
          it('reverts for non-existing key purpose', async function () {
            await expectRevert(
              this.identity.removeKey(
                bufferToHex(
                  keccak256(abi.rawEncode(['address'], [identityIssuer]))
                ),
                3,
                { from: identityIssuer }
              ),
              "NonExisting: Key doesn't have such purpose"
            );
          });
        }
      );

      context(
        'when the key is registered with more purpose than the removed one',
        function () {
          beforeEach('add key', async function () {
            await this.identity.addKey(
              bufferToHex(
                keccak256(abi.rawEncode(['address'], [identityOwner]))
              ),
              3,
              1,
              { from: identityIssuer }
            );

            await this.identity.addKey(
              bufferToHex(
                keccak256(abi.rawEncode(['address'], [identityOwner]))
              ),
              4,
              1,
              { from: identityIssuer }
            );
          });

          it('removes the purpose from the key and emits a KeyRemoved event', async function () {
            await expect(
              this.identity.keyHasPurpose(
                bufferToHex(
                  keccak256(abi.rawEncode(['address'], [identityOwner]))
                ),
                3
              )
            ).to.eventually.be.true;
            await expect(
              this.identity.keyHasPurpose(
                bufferToHex(
                  keccak256(abi.rawEncode(['address'], [identityOwner]))
                ),
                4
              )
            ).to.eventually.be.true;

            const { logs } = await this.identity.removeKey(
              bufferToHex(
                keccak256(abi.rawEncode(['address'], [identityOwner]))
              ),
              3,
              { from: identityIssuer }
            );

            expectEvent.inLogs(logs, 'KeyRemoved', {
              key: bufferToHex(
                keccak256(abi.rawEncode(['address'], [identityOwner]))
              ),
              purpose: '3',
              keyType: '1',
            });

            await expect(
              this.identity.keyHasPurpose(
                bufferToHex(
                  keccak256(abi.rawEncode(['address'], [identityOwner]))
                ),
                3
              )
            ).to.eventually.be.false;
            await expect(
              this.identity.keyHasPurpose(
                bufferToHex(
                  keccak256(abi.rawEncode(['address'], [identityOwner]))
                ),
                4
              )
            ).to.eventually.be.true;

            await expect(
              this.identity.getKeyPurposes(
                bufferToHex(
                  keccak256(abi.rawEncode(['address'], [identityOwner]))
                )
              )
            )
              .to.eventually.be.an('array')
              .of.length(1);

            await expect(this.identity.getKeysByPurpose(3))
              .to.eventually.an('array')
              .of.length(0);
            await expect(this.identity.getKeysByPurpose(4))
              .to.eventually.an('array')
              .of.length(1);
          });
        }
      );

      context(
        'when the key is registered with the removed purpose only',
        function () {
          beforeEach('add key', async function () {
            await this.identity.addKey(
              bufferToHex(
                keccak256(abi.rawEncode(['address'], [identityOwner]))
              ),
              3,
              1,
              { from: identityIssuer }
            );
          });

          it('removes the key and emits a KeyRemoved event', async function () {
            const { logs } = await this.identity.removeKey(
              bufferToHex(
                keccak256(abi.rawEncode(['address'], [identityOwner]))
              ),
              3,
              { from: identityIssuer }
            );

            expectEvent.inLogs(logs, 'KeyRemoved', {
              key: bufferToHex(
                keccak256(abi.rawEncode(['address'], [identityOwner]))
              ),
              purpose: '3',
              keyType: '1',
            });

            const key = await this.identity.getKey(
              bufferToHex(
                keccak256(abi.rawEncode(['address'], [identityOwner]))
              )
            );

            expect(key.key).to.equal(NULL_KEY);
            expect(key.keyType).to.be.bignumber.equal('0');
            expect(key.purposes).to.be.an('array').of.length(0);
          });
        }
      );
    });
  });
}

module.exports = {
  shouldBehaveLikeERC734,
};
