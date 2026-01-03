import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { deployIdentityFixture, deployIdentityWithProxy } from "./fixtures";

describe("Proxy", () => {
  it("should revert because implementation is Zero address", async () => {
    const [deployerWallet, identityOwnerWallet] = await ethers.getSigners();

    const IdentityProxy = await ethers.getContractFactory("IdentityProxy");
    await expect(
      IdentityProxy.connect(deployerWallet).deploy(
        ethers.ZeroAddress,
        identityOwnerWallet.address,
      ),
    ).to.be.revertedWithCustomError(IdentityProxy, "ZeroAddress");
  });

  it("should revert because implementation is not an identity", async () => {
    const [deployerWallet, identityOwnerWallet] = await ethers.getSigners();

    const claimIssuer = await ethers.deployContract("Test");

    const authority = await ethers.deployContract("ImplementationAuthority", [
      claimIssuer.target,
    ]);

    const IdentityProxy = await ethers.getContractFactory("IdentityProxy");
    await expect(
      IdentityProxy.connect(deployerWallet).deploy(
        authority.target,
        identityOwnerWallet.address,
      ),
    ).to.be.revertedWithCustomError(IdentityProxy, "InitializationFailed");
  });

  it("should revert because initial key is Zero address", async () => {
    const [deployerWallet] = await ethers.getSigners();

    const implementation = await ethers.deployContract("Identity", [
      deployerWallet.address,
      true,
    ]);
    const implementationAuthority = await ethers.deployContract(
      "ImplementationAuthority",
      [implementation.target],
    );

    const IdentityProxy = await ethers.getContractFactory("IdentityProxy");
    await expect(
      IdentityProxy.connect(deployerWallet).deploy(
        implementationAuthority.target,
        ethers.ZeroAddress,
      ),
    ).to.be.revertedWithCustomError(IdentityProxy, "ZeroAddress");
  });

  it("should prevent creating an implementation authority with a zero address implementation", async () => {
    const [deployerWallet] = await ethers.getSigners();

    const ImplementationAuthority = await ethers.getContractFactory(
      "ImplementationAuthority",
    );
    await expect(
      ImplementationAuthority.connect(deployerWallet).deploy(
        ethers.ZeroAddress,
      ),
    ).to.be.revertedWithCustomError(ImplementationAuthority, "ZeroAddress");
  });

  it("should prevent updating to a Zero address implementation", async () => {
    const { implementationAuthority, deployerWallet } = await loadFixture(
      deployIdentityFixture,
    );

    await expect(
      implementationAuthority
        .connect(deployerWallet)
        .updateImplementation(ethers.ZeroAddress),
    ).to.be.revertedWithCustomError(implementationAuthority, "ZeroAddress");
  });

  it("should prevent updating when not owner", async () => {
    const { implementationAuthority, aliceWallet } = await loadFixture(
      deployIdentityFixture,
    );

    await expect(
      implementationAuthority
        .connect(aliceWallet)
        .updateImplementation(ethers.ZeroAddress),
    ).to.be.revertedWithCustomError(
      implementationAuthority,
      "OwnableUnauthorizedAccount",
    );
  });

  it("should update the implementation address", async () => {
    const [deployerWallet] = await ethers.getSigners();

    // Deploy Identity using proxy from fixtures
    const identityProxy = await deployIdentityWithProxy(deployerWallet.address);

    // Get the ImplementationAuthority from the proxy
    const proxyAddress = await identityProxy.getAddress();
    const IdentityProxy = await ethers.getContractFactory("IdentityProxy");
    const proxyContract = IdentityProxy.attach(proxyAddress);
    const implementationAuthorityAddress =
      await proxyContract.implementationAuthority();
    const implementationAuthority = await ethers.getContractAt(
      "ImplementationAuthority",
      implementationAuthorityAddress,
    );

    // Deploy new implementation
    const Identity = await ethers.getContractFactory("Identity");
    const newImplementation = await Identity.deploy(
      deployerWallet.address,
      false, // Deploy as regular contract (implementation)
    );

    const tx = await implementationAuthority
      .connect(deployerWallet)
      .updateImplementation(await newImplementation.getAddress());
    await expect(tx)
      .to.emit(implementationAuthority, "UpdatedImplementation")
      .withArgs(await newImplementation.getAddress());
  });
});
