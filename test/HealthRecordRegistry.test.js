const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("HealthRecordRegistry", function () {
  let healthRecordRegistry;
  let owner;
  let user1;
  let user2;

  beforeEach(async function () {
    // Get signers
    [owner, user1, user2] = await ethers.getSigners();

    // Deploy contract
    const HealthRecordRegistry = await ethers.getContractFactory("HealthRecordRegistry");
    healthRecordRegistry = await HealthRecordRegistry.deploy();
    await healthRecordRegistry.deployed();
  });

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      expect(await healthRecordRegistry.contractOwner()).to.equal(owner.address);
    });

    it("Should start with zero total records", async function () {
      expect(await healthRecordRegistry.totalRecords()).to.equal(0);
    });

    it("Should start unpaused", async function () {
      expect(await healthRecordRegistry.contractPaused()).to.equal(false);
    });
  });

  describe("Document Storage", function () {
    const recordId = 1;
    const cid = "QmTestCID123456789";
    const metadataHash = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"; // 64 chars

    it("Should store a document successfully", async function () {
      await expect(
        healthRecordRegistry.connect(user1).storeDocument(recordId, cid, metadataHash)
      )
        .to.emit(healthRecordRegistry, "DocumentStored")
        .withArgs(recordId, user1.address, cid, metadataHash, await getBlockTimestamp());

      expect(await healthRecordRegistry.totalRecords()).to.equal(1);
    });

    it("Should reject empty CID", async function () {
      await expect(
        healthRecordRegistry.connect(user1).storeDocument(recordId, "", metadataHash)
      ).to.be.revertedWith("CID cannot be empty");
    });

    it("Should reject invalid metadata hash length", async function () {
      const invalidHash = "123"; // Too short
      await expect(
        healthRecordRegistry.connect(user1).storeDocument(recordId, cid, invalidHash)
      ).to.be.revertedWith("Invalid metadata hash length");
    });

    it("Should reject duplicate record ID", async function () {
      await healthRecordRegistry.connect(user1).storeDocument(recordId, cid, metadataHash);
      
      await expect(
        healthRecordRegistry.connect(user2).storeDocument(recordId, "QmAnotherCID", metadataHash)
      ).to.be.revertedWith("Record ID already exists");
    });

    it("Should reject zero record ID", async function () {
      await expect(
        healthRecordRegistry.connect(user1).storeDocument(0, cid, metadataHash)
      ).to.be.revertedWith("Record ID must be greater than 0");
    });
  });

  describe("Document Retrieval", function () {
    const recordId = 1;
    const cid = "QmTestCID123456789";
    const metadataHash = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";

    beforeEach(async function () {
      await healthRecordRegistry.connect(user1).storeDocument(recordId, cid, metadataHash);
    });

    it("Should retrieve document correctly", async function () {
      const [retrievedCid, retrievedHash, retrievedOwner, timestamp, isActive] = 
        await healthRecordRegistry.getDocument(recordId);

      expect(retrievedCid).to.equal(cid);
      expect(retrievedHash).to.equal(metadataHash);
      expect(retrievedOwner).to.equal(user1.address);
      expect(isActive).to.equal(true);
      expect(timestamp).to.be.gt(0);
    });

    it("Should get user records", async function () {
      const userRecords = await healthRecordRegistry.getUserRecords(user1.address);
      expect(userRecords).to.have.length(1);
      expect(userRecords[0]).to.equal(recordId);
    });

    it("Should get user active records", async function () {
      const activeRecords = await healthRecordRegistry.getUserActiveRecords(user1.address);
      expect(activeRecords).to.have.length(1);
      expect(activeRecords[0]).to.equal(recordId);
    });

    it("Should reject non-existent record", async function () {
      await expect(
        healthRecordRegistry.getDocument(999)
      ).to.be.revertedWith("Record does not exist");
    });
  });

  describe("Document Management", function () {
    const recordId = 1;
    const cid = "QmTestCID123456789";
    const metadataHash = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";
    const newMetadataHash = "fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210";

    beforeEach(async function () {
      await healthRecordRegistry.connect(user1).storeDocument(recordId, cid, metadataHash);
    });

    it("Should update metadata hash", async function () {
      await expect(
        healthRecordRegistry.connect(user1).updateDocumentMetadata(recordId, newMetadataHash)
      )
        .to.emit(healthRecordRegistry, "DocumentUpdated")
        .withArgs(recordId, user1.address, newMetadataHash, await getBlockTimestamp());

      const [, retrievedHash, , ,] = await healthRecordRegistry.getDocument(recordId);
      expect(retrievedHash).to.equal(newMetadataHash);
    });

    it("Should reject update by non-owner", async function () {
      await expect(
        healthRecordRegistry.connect(user2).updateDocumentMetadata(recordId, newMetadataHash)
      ).to.be.revertedWith("Not record owner");
    });

    it("Should deactivate document", async function () {
      await expect(
        healthRecordRegistry.connect(user1).deactivateDocument(recordId)
      )
        .to.emit(healthRecordRegistry, "DocumentDeactivated")
        .withArgs(recordId, user1.address, await getBlockTimestamp());

      const [, , , , isActive] = await healthRecordRegistry.getDocument(recordId);
      expect(isActive).to.equal(false);
    });

    it("Should reject deactivation by non-owner", async function () {
      await expect(
        healthRecordRegistry.connect(user2).deactivateDocument(recordId)
      ).to.be.revertedWith("Not record owner");
    });
  });

  describe("Document Verification", function () {
    const recordId = 1;
    const cid = "QmTestCID123456789";
    const metadataHash = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";

    beforeEach(async function () {
      await healthRecordRegistry.connect(user1).storeDocument(recordId, cid, metadataHash);
    });

    it("Should verify correct metadata hash", async function () {
      const isValid = await healthRecordRegistry.verifyDocument(recordId, metadataHash);
      expect(isValid).to.equal(true);
    });

    it("Should reject incorrect metadata hash", async function () {
      const wrongHash = "fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210";
      const isValid = await healthRecordRegistry.verifyDocument(recordId, wrongHash);
      expect(isValid).to.equal(false);
    });

    it("Should return false for non-existent record", async function () {
      const isValid = await healthRecordRegistry.verifyDocument(999, metadataHash);
      expect(isValid).to.equal(false);
    });
  });

  describe("Admin Functions", function () {
    it("Should pause and unpause contract", async function () {
      await healthRecordRegistry.pauseContract();
      expect(await healthRecordRegistry.contractPaused()).to.equal(true);

      await healthRecordRegistry.unpauseContract();
      expect(await healthRecordRegistry.contractPaused()).to.equal(false);
    });

    it("Should reject pause by non-owner", async function () {
      await expect(
        healthRecordRegistry.connect(user1).pauseContract()
      ).to.be.revertedWith("Only contract owner can call this");
    });

    it("Should transfer ownership", async function () {
      await healthRecordRegistry.transferOwnership(user1.address);
      expect(await healthRecordRegistry.contractOwner()).to.equal(user1.address);
    });

    it("Should reject ownership transfer to zero address", async function () {
      await expect(
        healthRecordRegistry.transferOwnership(ethers.constants.AddressZero)
      ).to.be.revertedWith("New owner cannot be zero address");
    });
  });

  describe("Contract Info", function () {
    it("Should return correct contract info", async function () {
      const [totalRecords, contractOwner, contractPaused] = 
        await healthRecordRegistry.getContractInfo();

      expect(totalRecords).to.equal(0);
      expect(contractOwner).to.equal(owner.address);
      expect(contractPaused).to.equal(false);
    });
  });

  // Helper function to get current block timestamp
  async function getBlockTimestamp() {
    const blockNumber = await ethers.provider.getBlockNumber();
    const block = await ethers.provider.getBlock(blockNumber);
    return block.timestamp;
  }
});