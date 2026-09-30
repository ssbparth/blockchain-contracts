const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("DigitalAsset Minting & Verification", function () {
  let DigitalAsset, contract;
  let admin, unauthorizedUser, userWallet;

  beforeEach(async function () {
    [admin, unauthorizedUser, userWallet] = await ethers.getSigners();
    DigitalAsset = await ethers.getContractFactory("DigitalAsset");
    contract = await DigitalAsset.deploy();
    await contract.waitForDeployment();
  });

  describe("Minting Constraints", function () {
    it("Admin mint -> succeeds & emits event", async function () {
      const tx = await contract.connect(admin).mintAsset(userWallet.address, "crypto", "Bitcoin", 1, "ipfs://test1");
      const receipt = await tx.wait();
      
      // Verify AssetMinted event is emitted
      const event = receipt.logs.find(log => contract.interface.parseLog(log).name === 'AssetMinted');
      expect(event).to.not.be.undefined;
      
      const parsedEvent = contract.interface.parseLog(event);
      expect(parsedEvent.args.id).to.equal(1n);
      expect(parsedEvent.args.owner).to.equal(userWallet.address);
    });

    it("Unauthorized user mint -> reverts", async function () {
      await expect(
        contract.connect(unauthorizedUser).mintAsset(userWallet.address, "crypto", "Bitcoin", 1, "ipfs://test1")
      ).to.be.revertedWith("Not an admin");
    });

    it("Invalid inputs -> rejected", async function () {
      await expect(
        contract.connect(admin).mintAsset(ethers.ZeroAddress, "crypto", "Bitcoin", 1, "ipfs://test1")
      ).to.be.revertedWith("Invalid owner address");

      await expect(
        contract.connect(admin).mintAsset(userWallet.address, "crypto", "Bitcoin", 0, "ipfs://test1")
      ).to.be.revertedWith("Quantity must be greater than zero");

      await expect(
        contract.connect(admin).mintAsset(userWallet.address, "crypto", "", 1, "ipfs://test1")
      ).to.be.revertedWith("Asset name cannot be empty");
    });
  });

  describe("Mint -> Retrieve -> Revoke Flow", function () {
    it("Completes full lifecycle correctly", async function () {
      // 1. Mint
      await contract.connect(admin).mintAsset(userWallet.address, "stock", "Tesla", 50, "ipfs://meta");
      
      // 2. Retrieve
      const ownerAssets = await contract.getOwnerAssets(userWallet.address);
      expect(ownerAssets.length).to.equal(1);
      const assetId = ownerAssets[0];

      const assetDetails = await contract.assets(assetId);
      expect(assetDetails.owner).to.equal(userWallet.address);
      expect(assetDetails.assetName).to.equal("Tesla");
      expect(assetDetails.isValid).to.be.true;

      // 3. Revoke
      await contract.connect(admin).revokeAsset(assetId);
      
      // 4. Verify Revocation
      const revokedAsset = await contract.assets(assetId);
      expect(revokedAsset.isValid).to.be.false;
    });
  });
});
