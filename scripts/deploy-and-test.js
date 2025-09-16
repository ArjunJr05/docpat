const { ethers } = require("hardhat");

async function main() {
  console.log("Deploying and testing HealthRecordRegistry...\n");

  // Get signers
  const [owner, user1] = await ethers.getSigners();
  console.log("Deployer:", owner.address);
  console.log("User1:", user1.address);

  // Deploy the contract
  const HealthRecordRegistry = await ethers.getContractFactory("HealthRecordRegistry");
  const contract = await HealthRecordRegistry.deploy();
  await contract.waitForDeployment();
  
  const contractAddress = await contract.getAddress();
  console.log("Contract deployed to:", contractAddress);

  console.log("\n=== Testing Contract Functions ===\n");
  
  // Test 1: Get contract info
  console.log("1. Contract Info:");
  const contractInfo = await contract.getContractInfo();
  console.log("   Total Records:", contractInfo.totalRecords_.toString());
  console.log("   Contract Owner:", contractInfo.contractOwner_);
  console.log("   Contract Paused:", contractInfo.contractPaused_);
  
  // Test 2: Store a document
  console.log("\n2. Storing a test document...");
  const recordId = 1;
  const cid = "QmTestCID123456789";
  const metadataHash = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";
  
  const storeTx = await contract.connect(user1).storeDocument(recordId, cid, metadataHash);
  await storeTx.wait();
  console.log("   Document stored successfully!");
  console.log("   Record ID:", recordId);
  
  // Test 3: Retrieve the document
  console.log("\n3. Retrieving the document...");
  const [retrievedCid, retrievedHash, ownerAddr, timestamp, isActive] = await contract.getDocument(recordId);
  console.log("   CID:", retrievedCid);
  console.log("   Metadata Hash:", retrievedHash.substring(0, 20) + "...");
  console.log("   Owner:", ownerAddr);
  console.log("   Is Active:", isActive);
  
  // Test 4: Get user records
  console.log("\n4. User records:");
  const userRecords = await contract.getUserRecords(user1.address);
  console.log("   Total records for user:", userRecords.length);
  console.log("   Record IDs:", userRecords.map(id => id.toString()));
  
  // Test 5: Get record counts
  console.log("\n5. Record counts:");
  const [total, active] = await contract.getUserRecordCount(user1.address);
  console.log("   Total records:", total.toString());
  console.log("   Active records:", active.toString());
  
  // Test 6: Verify document
  console.log("\n6. Document verification:");
  const isValid = await contract.verifyDocument(recordId, metadataHash);
  console.log("   Document is valid:", isValid);
  
  // Test 7: Check record status
  console.log("\n7. Record status:");
  const [exists, activeStatus] = await contract.recordStatus(recordId);
  console.log("   Record exists:", exists);
  console.log("   Record is active:", activeStatus);
  
  // Test 8: Contract statistics after storing document
  console.log("\n8. Final contract info:");
  const finalInfo = await contract.getContractInfo();
  console.log("   Total Records:", finalInfo.totalRecords_.toString());
  
  console.log("\n✅ All tests completed successfully!");
  console.log(`\n📋 For Flutter integration, use:`);
  console.log(`   CONTRACT_ADDRESS=${contractAddress}`);
  console.log(`   CHAIN_ID=31337`);
  console.log(`   RPC_URL=http://localhost:8545`);
}

main().catch(console.error);