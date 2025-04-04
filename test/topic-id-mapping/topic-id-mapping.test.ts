import { ethers } from "hardhat";
import { expect } from "chai";

describe("TopicIdMapping", () => {
    const TEST_TOPIC_ID = 10101000100000;
    const TEST_TOPIC_NAME = "INDIVIDUAL_INVESTOR";

  it("should deploy", async () => {
   await ethers.getSigners();
    const topicIdMapping = await ethers.deployContract("TopicIdMapping", []);
    await topicIdMapping.waitForDeployment();

    expect(topicIdMapping.target).to.not.equal(ethers.ZeroAddress);
  });

  it("deployer should be owner", async () => {
    const [deployerWallet] = await ethers.getSigners();
    const topicIdMapping = await ethers.deployContract("TopicIdMapping", []);
    expect(await topicIdMapping.owner()).to.equal(
      deployerWallet.address
    );
  });

  it("only owner can add/modify topic", async () => {
    const [deployerWallet, otherWallet] = await ethers.getSigners();
    const topicIdMapping = await ethers.deployContract("TopicIdMapping", []);
    await expect(
      topicIdMapping.connect(otherWallet).setTopicName(TEST_TOPIC_ID, TEST_TOPIC_NAME)
    ).to.be.revertedWith("Ownable: caller is not the owner");

    await expect(
      topicIdMapping
        .connect(deployerWallet)
        .setTopicName(TEST_TOPIC_ID, TEST_TOPIC_NAME)
    ).to.be.ok;
  });

  it("should set and get topic content correctly", async () => {
    const [deployerWallet] = await ethers.getSigners();
    const topicIdMapping = await ethers.deployContract("TopicIdMapping", []);
    await topicIdMapping
      .connect(deployerWallet)
      .setTopicName(TEST_TOPIC_ID, TEST_TOPIC_NAME);
    expect(
      await topicIdMapping.getTopicName(TEST_TOPIC_ID)
    ).to.equal(TEST_TOPIC_NAME);
  });
});
