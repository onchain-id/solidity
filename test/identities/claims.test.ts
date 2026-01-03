import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

import { deployIdentityFixture } from "../fixtures";

describe("Identity", () => {
  describe("Claims", () => {
    describe("addClaim", () => {
      describe("when the claim is self-attested (issuer is identity address)", () => {
        describe("when the claim is not valid", () => {
          it("should add the claim anyway", async () => {
            const { aliceIdentity, aliceWallet } = await loadFixture(
              deployIdentityFixture,
            );

            const claim = {
              identity: await aliceIdentity.getAddress(),
              issuer: await aliceIdentity.getAddress(),
              topic: 42,
              scheme: 1,
              data: "0x0042",
              signature: "",
              uri: "https://example.com",
            };
            claim.signature = await aliceWallet.signMessage(
              ethers.getBytes(
                ethers.keccak256(
                  ethers.AbiCoder.defaultAbiCoder().encode(
                    ["address", "uint256", "bytes"],
                    [claim.identity, claim.topic, "0x101010"],
                  ),
                ),
              ),
            );

            const tx = await aliceIdentity
              .connect(aliceWallet)
              .addClaim(
                claim.topic,
                claim.scheme,
                claim.issuer,
                claim.signature,
                claim.data,
                claim.uri,
              );
            await expect(tx)
              .to.emit(aliceIdentity, "ClaimAdded")
              .withArgs(
                ethers.keccak256(
                  ethers.AbiCoder.defaultAbiCoder().encode(
                    ["address", "uint256"],
                    [claim.issuer, claim.topic],
                  ),
                ),
                claim.topic,
                claim.scheme,
                claim.issuer,
                claim.signature,
                claim.data,
                claim.uri,
              );
            expect(
              await aliceIdentity.isClaimValid(
                claim.identity,
                claim.topic,
                claim.signature,
                claim.data,
              ),
            ).to.be.false;
          });
        });

        describe("when the claim is valid", () => {
          let claim = {
            identity: "",
            issuer: "",
            topic: 0,
            scheme: 1,
            data: "",
            uri: "",
            signature: "",
          };
          before(async () => {
            const { aliceIdentity, aliceWallet } = await loadFixture(
              deployIdentityFixture,
            );

            claim = {
              identity: await aliceIdentity.getAddress(),
              issuer: await aliceIdentity.getAddress(),
              topic: 42,
              scheme: 1,
              data: "0x0042",
              signature: "",
              uri: "https://example.com",
            };
            claim.signature = await aliceWallet.signMessage(
              ethers.getBytes(
                ethers.keccak256(
                  ethers.AbiCoder.defaultAbiCoder().encode(
                    ["address", "uint256", "bytes"],
                    [claim.identity, claim.topic, claim.data],
                  ),
                ),
              ),
            );
          });

          describe("when caller is the identity itself (execute)", () => {
            it("should add the claim", async () => {
              const { aliceIdentity, aliceWallet, bobWallet } =
                await loadFixture(deployIdentityFixture);

              const action = {
                to: await aliceIdentity.getAddress(),
                value: 0,
                data: aliceIdentity.interface.encodeFunctionData("addClaim", [
                  claim.topic,
                  claim.scheme,
                  claim.issuer,
                  claim.signature,
                  claim.data,
                  claim.uri,
                ]),
              };

              await aliceIdentity
                .connect(bobWallet)
                .execute(action.to, action.value, action.data);
              const tx = await aliceIdentity
                .connect(aliceWallet)
                .approve(0, true);
              await expect(tx)
                .to.emit(aliceIdentity, "ClaimAdded")
                .withArgs(
                  ethers.keccak256(
                    ethers.AbiCoder.defaultAbiCoder().encode(
                      ["address", "uint256"],
                      [claim.issuer, claim.topic],
                    ),
                  ),
                  claim.topic,
                  claim.scheme,
                  claim.issuer,
                  claim.signature,
                  claim.data,
                  claim.uri,
                );
              await expect(tx).to.emit(aliceIdentity, "Approved");
              await expect(tx).to.emit(aliceIdentity, "Executed");
              expect(
                await aliceIdentity.isClaimValid(
                  claim.identity,
                  claim.topic,
                  claim.signature,
                  claim.data,
                ),
              ).to.be.true;
            });
          });

          describe("when caller is a CLAIM or MANAGEMENT key", () => {
            it("should add the claim", async () => {
              it("should add the claim anyway", async () => {
                const { aliceIdentity, aliceWallet } = await loadFixture(
                  deployIdentityFixture,
                );

                const tx = await aliceIdentity
                  .connect(aliceWallet)
                  .addClaim(
                    claim.topic,
                    claim.scheme,
                    claim.issuer,
                    claim.signature,
                    claim.data,
                    claim.uri,
                  );
                await expect(tx)
                  .to.emit(aliceIdentity, "ClaimAdded")
                  .withArgs(
                    ethers.keccak256(
                      ethers.AbiCoder.defaultAbiCoder().encode(
                        ["address", "uint256"],
                        [claim.issuer, claim.topic],
                      ),
                    ),
                    claim.topic,
                    claim.scheme,
                    claim.issuer,
                    claim.signature,
                    claim.data,
                    claim.uri,
                  );
              });
            });
          });

          describe("when caller is not a CLAIM key", () => {
            it("should revert for missing permission", async () => {
              const { aliceIdentity, bobWallet } = await loadFixture(
                deployIdentityFixture,
              );

              await expect(
                aliceIdentity
                  .connect(bobWallet)
                  .addClaim(
                    claim.topic,
                    claim.scheme,
                    claim.issuer,
                    claim.signature,
                    claim.data,
                    claim.uri,
                  ),
              ).to.be.revertedWithCustomError(
                aliceIdentity,
                "SenderDoesNotHaveClaimSignerKey",
              );
            });
          });
        });
      });

      describe("when the claim is from a claim issuer", () => {
        describe("when the claim is not valid", () => {
          it("should revert for invalid claim", async () => {
            const {
              aliceIdentity,
              aliceWallet,
              claimIssuerWallet,
              claimIssuer,
            } = await loadFixture(deployIdentityFixture);

            const claim = {
              identity: await aliceIdentity.getAddress(),
              issuer: await claimIssuer.getAddress(),
              topic: 42,
              scheme: 1,
              data: "0x0042",
              signature: "",
              uri: "https://example.com",
            };
            claim.signature = await claimIssuerWallet.signMessage(
              ethers.getBytes(
                ethers.keccak256(
                  ethers.AbiCoder.defaultAbiCoder().encode(
                    ["address", "uint256", "bytes"],
                    [claim.identity, claim.topic, "0x10101010"],
                  ),
                ),
              ),
            );

            await expect(
              aliceIdentity
                .connect(aliceWallet)
                .addClaim(
                  claim.topic,
                  claim.scheme,
                  claim.issuer,
                  claim.signature,
                  claim.data,
                  claim.uri,
                ),
            ).to.be.revertedWithCustomError(aliceIdentity, "InvalidClaim");
          });
        });

        describe("when the claim is valid", () => {
          let claim = {
            identity: "",
            issuer: "",
            topic: 0,
            scheme: 1,
            data: "",
            uri: "",
            signature: "",
          };
          before(async () => {
            const { aliceIdentity, claimIssuer, claimIssuerWallet } =
              await loadFixture(deployIdentityFixture);

            claim = {
              identity: await aliceIdentity.getAddress(),
              issuer: await claimIssuer.getAddress(),
              topic: 42,
              scheme: 1,
              data: "0x0042",
              signature: "",
              uri: "https://example.com",
            };
            claim.signature = await claimIssuerWallet.signMessage(
              ethers.getBytes(
                ethers.keccak256(
                  ethers.AbiCoder.defaultAbiCoder().encode(
                    ["address", "uint256", "bytes"],
                    [claim.identity, claim.topic, claim.data],
                  ),
                ),
              ),
            );
          });

          describe("when caller is the identity itself (execute)", () => {
            it("should add the claim", async () => {
              const { aliceIdentity, aliceWallet, bobWallet } =
                await loadFixture(deployIdentityFixture);

              const action = {
                to: await aliceIdentity.getAddress(),
                value: 0,
                data: aliceIdentity.interface.encodeFunctionData("addClaim", [
                  claim.topic,
                  claim.scheme,
                  claim.issuer,
                  claim.signature,
                  claim.data,
                  claim.uri,
                ]),
              };

              await aliceIdentity
                .connect(bobWallet)
                .execute(action.to, action.value, action.data);
              const tx = await aliceIdentity
                .connect(aliceWallet)
                .approve(0, true);
              await expect(tx)
                .to.emit(aliceIdentity, "ClaimAdded")
                .withArgs(
                  ethers.keccak256(
                    ethers.AbiCoder.defaultAbiCoder().encode(
                      ["address", "uint256"],
                      [claim.issuer, claim.topic],
                    ),
                  ),
                  claim.topic,
                  claim.scheme,
                  claim.issuer,
                  claim.signature,
                  claim.data,
                  claim.uri,
                );
              await expect(tx).to.emit(aliceIdentity, "Approved");
              await expect(tx).to.emit(aliceIdentity, "Executed");
            });
          });

          describe("when caller is a CLAIM or MANAGEMENT key", () => {
            it("should add the claim", async () => {
              it("should add the claim anyway", async () => {
                const { aliceIdentity, aliceWallet } = await loadFixture(
                  deployIdentityFixture,
                );

                const tx = await aliceIdentity
                  .connect(aliceWallet)
                  .addClaim(
                    claim.topic,
                    claim.scheme,
                    claim.issuer,
                    claim.signature,
                    claim.data,
                    claim.uri,
                  );
                await expect(tx)
                  .to.emit(aliceIdentity, "ClaimAdded")
                  .withArgs(
                    ethers.keccak256(
                      ethers.AbiCoder.defaultAbiCoder().encode(
                        ["address", "uint256"],
                        [claim.issuer, claim.topic],
                      ),
                    ),
                    claim.topic,
                    claim.scheme,
                    claim.issuer,
                    claim.signature,
                    claim.data,
                    claim.uri,
                  );
              });
            });
          });

          describe("when caller is not a CLAIM key", () => {
            it("should revert for missing permission", async () => {
              const { aliceIdentity, bobWallet } = await loadFixture(
                deployIdentityFixture,
              );

              await expect(
                aliceIdentity
                  .connect(bobWallet)
                  .addClaim(
                    claim.topic,
                    claim.scheme,
                    claim.issuer,
                    claim.signature,
                    claim.data,
                    claim.uri,
                  ),
              ).to.be.revertedWithCustomError(
                aliceIdentity,
                "SenderDoesNotHaveClaimSignerKey",
              );
            });
          });
        });
      });
    });

    describe("updateClaim (addClaim)", () => {
      describe("when there is already a claim from this issuer and this topic", () => {
        let aliceIdentity: ethers.Contract;
        let aliceWallet: ethers.Wallet;
        let claimIssuer: ethers.Contract;
        let claimIssuerWallet: ethers.Wallet;
        before(async () => {
          const params = await loadFixture(deployIdentityFixture);
          aliceIdentity = params.aliceIdentity;
          aliceWallet = params.aliceWallet;
          claimIssuer = params.claimIssuer;
          claimIssuerWallet = params.claimIssuerWallet;

          const claim = {
            identity: await aliceIdentity.getAddress(),
            issuer: await claimIssuer.getAddress(),
            topic: 42,
            scheme: 1,
            data: "0x0042",
            signature: "",
            uri: "https://example.com",
          };
          claim.signature = await claimIssuerWallet.signMessage(
            ethers.getBytes(
              ethers.keccak256(
                ethers.AbiCoder.defaultAbiCoder().encode(
                  ["address", "uint256", "bytes"],
                  [claim.identity, claim.topic, claim.data],
                ),
              ),
            ),
          );

          await aliceIdentity
            .connect(aliceWallet)
            .addClaim(
              claim.topic,
              claim.scheme,
              claim.issuer,
              claim.signature,
              claim.data,
              claim.uri,
            );
        });

        it("should replace the existing claim", async () => {
          const claim = {
            identity: await aliceIdentity.getAddress(),
            issuer: await claimIssuer.getAddress(),
            topic: 42,
            scheme: 1,
            data: "0x004200101010",
            signature: "",
            uri: "https://example.com",
          };
          claim.signature = await claimIssuerWallet.signMessage(
            ethers.getBytes(
              ethers.keccak256(
                ethers.AbiCoder.defaultAbiCoder().encode(
                  ["address", "uint256", "bytes"],
                  [claim.identity, claim.topic, claim.data],
                ),
              ),
            ),
          );

          const tx = await aliceIdentity
            .connect(aliceWallet)
            .addClaim(
              claim.topic,
              claim.scheme,
              claim.issuer,
              claim.signature,
              claim.data,
              claim.uri,
            );
          await expect(tx)
            .to.emit(aliceIdentity, "ClaimChanged")
            .withArgs(
              ethers.keccak256(
                ethers.AbiCoder.defaultAbiCoder().encode(
                  ["address", "uint256"],
                  [claim.issuer, claim.topic],
                ),
              ),
              claim.topic,
              claim.scheme,
              claim.issuer,
              claim.signature,
              claim.data,
              claim.uri,
            );
        });
      });
    });

    describe("removeClaim", () => {
      describe("When caller is the identity itself (execute)", () => {
        it("should remove an existing claim", async () => {
          const {
            aliceIdentity,
            aliceWallet,
            bobWallet,
            claimIssuer,
            claimIssuerWallet,
          } = await loadFixture(deployIdentityFixture);
          const claim = {
            identity: await aliceIdentity.getAddress(),
            issuer: await claimIssuer.getAddress(),
            topic: 42,
            scheme: 1,
            data: "0x0042",
            signature: "",
            uri: "https://example.com",
          };
          const claimId = ethers.keccak256(
            ethers.AbiCoder.defaultAbiCoder().encode(
              ["address", "uint256"],
              [claim.issuer, claim.topic],
            ),
          );
          claim.signature = await claimIssuerWallet.signMessage(
            ethers.getBytes(
              ethers.keccak256(
                ethers.AbiCoder.defaultAbiCoder().encode(
                  ["address", "uint256", "bytes"],
                  [claim.identity, claim.topic, claim.data],
                ),
              ),
            ),
          );

          await aliceIdentity
            .connect(aliceWallet)
            .addClaim(
              claim.topic,
              claim.scheme,
              claim.issuer,
              claim.signature,
              claim.data,
              claim.uri,
            );

          const action = {
            to: await aliceIdentity.getAddress(),
            value: 0,
            data: aliceIdentity.interface.encodeFunctionData("removeClaim", [
              claimId,
            ]),
          };

          await aliceIdentity
            .connect(bobWallet)
            .execute(action.to, action.value, action.data);
          const tx = await aliceIdentity.connect(aliceWallet).approve(0, true);
          await expect(tx)
            .to.emit(aliceIdentity, "ClaimRemoved")
            .withArgs(
              claimId,
              claim.topic,
              claim.scheme,
              claim.issuer,
              claim.signature,
              claim.data,
              claim.uri,
            );
        });
      });

      describe("When caller is not a CLAIM key", () => {
        it("should revert for missing permission", async () => {
          const { aliceIdentity, bobWallet, claimIssuer } = await loadFixture(
            deployIdentityFixture,
          );

          const claimId = ethers.keccak256(
            ethers.AbiCoder.defaultAbiCoder().encode(
              ["address", "uint256"],
              [await claimIssuer.getAddress(), 42],
            ),
          );

          await expect(
            aliceIdentity.connect(bobWallet).removeClaim(claimId),
          ).to.be.revertedWithCustomError(
            aliceIdentity,
            "SenderDoesNotHaveClaimSignerKey",
          );
        });
      });

      describe("When claim does not exist", () => {
        it("should revert for non existing claim", async () => {
          const { aliceIdentity, carolWallet, claimIssuer } = await loadFixture(
            deployIdentityFixture,
          );

          const claimId = ethers.keccak256(
            ethers.AbiCoder.defaultAbiCoder().encode(
              ["address", "uint256"],
              [await claimIssuer.getAddress(), 42],
            ),
          );

          await expect(
            aliceIdentity.connect(carolWallet).removeClaim(claimId),
          ).to.be.revertedWithCustomError(aliceIdentity, "ClaimNotRegistered");
        });
      });

      describe("When claim does exist", () => {
        it("should remove the claim", async () => {
          const { aliceIdentity, aliceWallet, claimIssuer, claimIssuerWallet } =
            await loadFixture(deployIdentityFixture);
          const claim = {
            identity: await aliceIdentity.getAddress(),
            issuer: await claimIssuer.getAddress(),
            topic: 42,
            scheme: 1,
            data: "0x0042",
            signature: "",
            uri: "https://example.com",
          };
          const claimId = ethers.keccak256(
            ethers.AbiCoder.defaultAbiCoder().encode(
              ["address", "uint256"],
              [claim.issuer, claim.topic],
            ),
          );
          claim.signature = await claimIssuerWallet.signMessage(
            ethers.getBytes(
              ethers.keccak256(
                ethers.AbiCoder.defaultAbiCoder().encode(
                  ["address", "uint256", "bytes"],
                  [claim.identity, claim.topic, claim.data],
                ),
              ),
            ),
          );

          await aliceIdentity
            .connect(aliceWallet)
            .addClaim(
              claim.topic,
              claim.scheme,
              claim.issuer,
              claim.signature,
              claim.data,
              claim.uri,
            );

          const tx = await aliceIdentity
            .connect(aliceWallet)
            .removeClaim(claimId);
          await expect(tx)
            .to.emit(aliceIdentity, "ClaimRemoved")
            .withArgs(
              claimId,
              claim.topic,
              claim.scheme,
              claim.issuer,
              claim.signature,
              claim.data,
              claim.uri,
            );
        });
      });
    });

    describe("removeClaim edge cases", () => {
      it("should cover the claimIndex >= arrayLength edge case in removeClaim", async () => {
        const { aliceIdentity, aliceWallet, claimIssuer, claimIssuerWallet } =
          await loadFixture(deployIdentityFixture);

        // Add a claim first
        const topic = 42;
        const claim = {
          identity: await aliceIdentity.getAddress(),
          issuer: await claimIssuer.getAddress(),
          topic,
          scheme: 1,
          data: "0x0042",
          signature: "",
          uri: "https://example.com",
        };
        const claimId = ethers.keccak256(
          ethers.AbiCoder.defaultAbiCoder().encode(
            ["address", "uint256"],
            [claim.issuer, claim.topic],
          ),
        );
        claim.signature = await claimIssuerWallet.signMessage(
          ethers.getBytes(
            ethers.keccak256(
              ethers.AbiCoder.defaultAbiCoder().encode(
                ["address", "uint256", "bytes"],
                [claim.identity, claim.topic, claim.data],
              ),
            ),
          ),
        );
        await aliceIdentity
          .connect(aliceWallet)
          .addClaim(
            claim.topic,
            claim.scheme,
            claim.issuer,
            claim.signature,
            claim.data,
            claim.uri,
          );

        // Add another claim with the same topic
        const claim2 = {
          identity: await aliceIdentity.getAddress(),
          issuer: await aliceIdentity.getAddress(),
          topic,
          scheme: 1,
          data: "0x0043",
          signature: "",
          uri: "https://example2.com",
        };
        claim2.signature = await aliceWallet.signMessage(
          ethers.getBytes(
            ethers.keccak256(
              ethers.AbiCoder.defaultAbiCoder().encode(
                ["address", "uint256", "bytes"],
                [claim2.identity, claim2.topic, claim2.data],
              ),
            ),
          ),
        );
        const claimId2 = ethers.keccak256(
          ethers.AbiCoder.defaultAbiCoder().encode(
            ["address", "uint256"],
            [claim2.issuer, claim2.topic],
          ),
        );
        await aliceIdentity
          .connect(aliceWallet)
          .addClaim(
            claim2.topic,
            claim2.scheme,
            claim2.issuer,
            claim2.signature,
            claim2.data,
            claim2.uri,
          );

        // Now remove the second claim first, which will leave the first claim in the array
        await aliceIdentity.connect(aliceWallet).removeClaim(claimId2);

        // Now remove the first claim - this should trigger the edge case
        // because the claim exists in the mapping but the array might be in an inconsistent state
        const tx = await aliceIdentity
          .connect(aliceWallet)
          .removeClaim(claimId);

        await expect(tx)
          .to.emit(aliceIdentity, "ClaimRemoved")
          .withArgs(
            claimId,
            claim.topic,
            claim.scheme,
            claim.issuer,
            claim.signature,
            claim.data,
            claim.uri,
          );

        // Verify the claim was removed
        const retrievedClaim = await aliceIdentity.getClaim(claimId);
        expect(retrievedClaim.topic).to.equal(0);
        expect(retrievedClaim.issuer).to.equal(ethers.ZeroAddress);
      });

      it("should test swap-and-pop logic by removing middle claim from array", async () => {
        const { aliceIdentity, aliceWallet, claimIssuer, claimIssuerWallet } =
          await loadFixture(deployIdentityFixture);

        const topic = 42;

        // Create a second claim issuer to have different issuers
        const claimIssuer2 = await ethers.deployContract("ClaimIssuer", [
          aliceWallet.address,
        ]);

        // Add three claims with different issuers but same topic
        const issuers = [
          await claimIssuer.getAddress(),
          await claimIssuer2.getAddress(),
          await aliceIdentity.getAddress(), // Self-attested
        ];

        const claimIds = [];

        for (let i = 0; i < 3; i++) {
          const claim = {
            identity: await aliceIdentity.getAddress(),
            issuer: issuers[i],
            topic,
            scheme: 1,
            data: `0x004${i}`,
            signature: "",
            uri: `https://example${i}.com`,
          };

          const claimId = ethers.keccak256(
            ethers.AbiCoder.defaultAbiCoder().encode(
              ["address", "uint256"],
              [claim.issuer, claim.topic],
            ),
          );

          // Sign with appropriate wallet
          if (i === 0) {
            claim.signature = await claimIssuerWallet.signMessage(
              ethers.getBytes(
                ethers.keccak256(
                  ethers.AbiCoder.defaultAbiCoder().encode(
                    ["address", "uint256", "bytes"],
                    [claim.identity, claim.topic, claim.data],
                  ),
                ),
              ),
            );
          } else if (i === 1) {
            // For the second claim issuer, we need to sign with aliceWallet since it's the owner
            claim.signature = await aliceWallet.signMessage(
              ethers.getBytes(
                ethers.keccak256(
                  ethers.AbiCoder.defaultAbiCoder().encode(
                    ["address", "uint256", "bytes"],
                    [claim.identity, claim.topic, claim.data],
                  ),
                ),
              ),
            );
          } else {
            // Self-attested claim
            claim.signature = await aliceWallet.signMessage(
              ethers.getBytes(
                ethers.keccak256(
                  ethers.AbiCoder.defaultAbiCoder().encode(
                    ["address", "uint256", "bytes"],
                    [claim.identity, claim.topic, claim.data],
                  ),
                ),
              ),
            );
          }

          claimIds.push(claimId);

          await aliceIdentity
            .connect(aliceWallet)
            .addClaim(
              claim.topic,
              claim.scheme,
              claim.issuer,
              claim.signature,
              claim.data,
              claim.uri,
            );
        }

        // Verify all claims are added to the same topic
        const claimIdsByTopic = await aliceIdentity.getClaimIdsByTopic(topic);
        expect(claimIdsByTopic).to.have.length(3);
        expect(claimIdsByTopic).to.include(claimIds[0]);
        expect(claimIdsByTopic).to.include(claimIds[1]);
        expect(claimIdsByTopic).to.include(claimIds[2]);

        // Remove the middle claim (index 1) - this should trigger swap-and-pop
        await aliceIdentity.connect(aliceWallet).removeClaim(claimIds[1]);

        // Verify the remaining claims
        const remainingClaimIds = await aliceIdentity.getClaimIdsByTopic(topic);
        expect(remainingClaimIds).to.have.length(2);
        expect(remainingClaimIds).to.include(claimIds[0]);
        expect(remainingClaimIds).to.include(claimIds[2]);
        expect(remainingClaimIds).to.not.include(claimIds[1]);

        // Verify the removed claim no longer exists
        const removedClaim = await aliceIdentity.getClaim(claimIds[1]);
        expect(removedClaim.topic).to.equal(0);
        expect(removedClaim.issuer).to.equal(ethers.ZeroAddress);
      });
    });

    describe("getClaim", () => {
      describe("when claim does not exist", () => {
        it("should return an empty struct", async () => {
          const { aliceIdentity, claimIssuer } = await loadFixture(
            deployIdentityFixture,
          );
          const claimId = ethers.keccak256(
            ethers.AbiCoder.defaultAbiCoder().encode(
              ["address", "uint256"],
              [await claimIssuer.getAddress(), 42],
            ),
          );
          const found = await aliceIdentity.getClaim(claimId);
          expect(found.issuer).to.equal(ethers.ZeroAddress);
          expect(found.topic).to.equal(0);
          expect(found.scheme).to.equal(0);
          expect(found.data).to.equal("0x");
          expect(found.signature).to.equal("0x");
          expect(found.uri).to.equal("");
        });
      });

      describe("when claim does exist", () => {
        it("should return the claim", async () => {
          const { aliceIdentity, aliceClaim666 } = await loadFixture(
            deployIdentityFixture,
          );

          const found = await aliceIdentity.getClaim(aliceClaim666.id);
          expect(found.issuer).to.equal(aliceClaim666.issuer);
          expect(found.topic).to.equal(aliceClaim666.topic);
          expect(found.scheme).to.equal(aliceClaim666.scheme);
          expect(found.data).to.equal(aliceClaim666.data);
          expect(found.signature).to.equal(aliceClaim666.signature);
          expect(found.uri).to.equal(aliceClaim666.uri);
        });
      });
    });

    describe("getClaimIdsByTopic", () => {
      it("should return an empty array when there are no claims for the topic", async () => {
        const { aliceIdentity } = await loadFixture(deployIdentityFixture);

        expect(await aliceIdentity.getClaimIdsByTopic(101010)).to.deep.equal(
          [],
        );
      });

      it("should return an array of claim Id existing fo the topic", async () => {
        const { aliceIdentity, aliceClaim666 } = await loadFixture(
          deployIdentityFixture,
        );

        expect(
          await aliceIdentity.getClaimIdsByTopic(aliceClaim666.topic),
        ).to.deep.equal([aliceClaim666.id]);
      });
    });
  });
});
