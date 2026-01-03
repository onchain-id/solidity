import { expect } from "chai";
import { ethers } from "hardhat";
import { deployIdentityWithProxy } from "../fixtures";

describe("Identity Proxy Pattern", () => {
  it("should deploy Identity through proxy and work correctly", async () => {
    const [deployerWallet, aliceWallet] = await ethers.getSigners();

    // Deploy Identity through proxy
    const identityProxy = await deployIdentityWithProxy(deployerWallet.address);

    // The proxy should be initialized and have the correct version
    expect(await identityProxy.version()).to.equal("3.0.0");

    // The proxy should have the correct management key
    const hashedKey = ethers.keccak256(
      ethers.AbiCoder.defaultAbiCoder().encode(
        ["address"],
        [deployerWallet.address],
      ),
    );
    expect(await identityProxy.keyHasPurpose(hashedKey, 1)).to.be.true; // MANAGEMENT purpose

    // Test adding and managing keys
    const aliceKey = ethers.keccak256(
      ethers.AbiCoder.defaultAbiCoder().encode(
        ["address"],
        [aliceWallet.address],
      ),
    );
    await identityProxy.addKey(aliceKey, 2, 1); // ACTION purpose, ECDSA type

    // Verify key was added and proxy maintains state
    expect(await identityProxy.keyHasPurpose(aliceKey, 2)).to.be.true;
  });
});
