const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("DigitalAsset Social Recovery", function () {
  let DigitalAsset, contract;
  let owner, newOwner;
  let guardians = [];

  beforeEach(async function () {
    let signers = await ethers.getSigners();
    owner = signers[0];
    guardians = signers.slice(1, 6);
    newOwner = signers[6];

    DigitalAsset = await ethers.getContractFactory("DigitalAsset");
    contract = await DigitalAsset.deploy();
    await contract.waitForDeployment();
  });

  describe("Guardian Management", function () {
    it("should allow adding a guardian and rejecting duplicates", async function () {
      await contract.connect(owner).addGuardian(guardians[0].address);
      const list = await contract.getGuardians(owner.address);
      expect(list).to.include(guardians[0].address);

      await expect(
        contract.connect(owner).addGuardian(guardians[0].address)
      ).to.be.revertedWith("Already a guardian");
    });
  });

  describe("Recovery Flow", function () {
    beforeEach(async function () {
      for (let i = 0; i < 5; i++) {
        await contract.connect(owner).addGuardian(guardians[i].address);
      }
      await contract.connect(owner).setRecoveryThreshold(3);
      await contract.connect(owner).mintAsset(owner.address, "gold", "GoldBar", 500, "ipfs://test");
    });

    it("should execute recovery successfully and retain assets", async function () {
      await contract.connect(newOwner).requestRecovery(owner.address, newOwner.address);
      const recoveryId = await contract.activeRecoveryId(owner.address);
      
      await contract.connect(guardians[0]).approveRecovery(recoveryId);
      await contract.connect(guardians[1]).approveRecovery(recoveryId);
      await contract.connect(guardians[2]).approveRecovery(recoveryId);

      await contract.connect(guardians[0]).executeRecovery(recoveryId);

      expect(await contract.getActiveWallet(owner.address)).to.equal(newOwner.address);
      expect(await contract.getIdentity(newOwner.address)).to.equal(owner.address);

      const assets = await contract.getOwnerAssets(newOwner.address);
      expect(assets.length).to.equal(1);
    });
  });
});
