const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("AgentGuard", function () {
  let contract;
  let owner, user1, user2;

  before(async function () {
    [owner, user1, user2] = await ethers.getSigners();
    const Contract = await ethers.getContractFactory("AgentGuard");
    contract = await Contract.deploy();
    await contract.waitForDeployment();
  });

  it("should set the right owner", async function () {
    expect(await contract.owner()).to.equal(owner.address);
  });

  it("should allow owner to record deployment", async function () {
    const tx = await contract.connect(owner).recordDeployment();
    await tx.wait();
  });

  it("should read deployment info", async function () {
    const data = await contract.getDeploymentInfo();
    expect(data.deployer).to.equal(owner.address);
  });

  it("should reject unauthorized updater change", async function () {
    await expect(
      contract.connect(user1).setUpdater(user2.address)
    ).to.be.reverted;
  });
});