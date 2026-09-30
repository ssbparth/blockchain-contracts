const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("DigitalAsset Identity & Audit", function () {
  let DigitalAsset, contract;
  let admin, user1;

  beforeEach(async function () {
    [admin, user1] = await ethers.getSigners();
    DigitalAsset = await ethers.getContractFactory("DigitalAsset");
    contract = await DigitalAsset.deploy();
    await contract.waitForDeployment();
  });

  describe("User Registry", function () {
    it("should allow a user to be registered on-chain", async function () {
      const tx = await contract.connect(user1).registerUser(user1.address, "ipfs://profile1");
      const receipt = await tx.wait();
      
      const event = receipt.logs.find(log => contract.interface.parseLog(log).name === 'UserRegistered');
      expect(event).to.not.be.undefined;
      
      const parsedEvent = contract.interface.parseLog(event);
      expect(parsedEvent.args.identity).to.equal(user1.address);
      expect(parsedEvent.args.profileURI).to.equal("ipfs://profile1");

      const profile = await contract.getUserProfile(user1.address);
      expect(profile.wallet).to.equal(user1.address);
      expect(profile.profileURI).to.equal("ipfs://profile1");
      expect(profile.isRegistered).to.be.true;
    });

    it("should auto-register a user when they are minted an asset", async function () {
      await contract.connect(admin).mintAsset(user1.address, "crypto", "BTC", 1, "ipfs://meta");
      
      const profile = await contract.getUserProfile(user1.address);
      expect(profile.isRegistered).to.be.true;
    });

    it("should prevent duplicate registration", async function () {
      await contract.connect(user1).registerUser(user1.address, "ipfs://profile1");
      await expect(
        contract.connect(user1).registerUser(user1.address, "ipfs://profile2")
      ).to.be.revertedWith("User already registered");
    });
  });

  describe("Audit Logging", function () {
    it("should allow admin to write audit logs", async function () {
      const tx = await contract.connect(admin).logAudit("USER_LOGIN", "User logged in from new IP");
      const receipt = await tx.wait();
      
      const event = receipt.logs.find(log => contract.interface.parseLog(log).name === 'AuditLog');
      expect(event).to.not.be.undefined;
      
      const parsedEvent = contract.interface.parseLog(event);
      expect(parsedEvent.args.actor).to.equal(admin.address);
      expect(parsedEvent.args.action).to.equal("USER_LOGIN");
      expect(parsedEvent.args.details).to.equal("User logged in from new IP");
    });

    it("should revert if non-admin tries to write audit log", async function () {
      await expect(
        contract.connect(user1).logAudit("MALICIOUS", "I am hacking")
      ).to.be.revertedWith("Not an admin");
    });
  });
});
