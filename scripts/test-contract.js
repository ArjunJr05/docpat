const { ethers } = require("hardhat");

async function main() {
  // Contract address from deployment
  const contractAddress = "0x5FbDB2315678afecb367f032d93F642f64180aa3";
  
  // Get signers
  const [owner, user1] = await ethers.getSigners();
  
  // Connect to deployed contract
  const HealthRecordRegistry = await ethers.getContractFactory("HealthRecordRegistry");
  const contract = HealthRecordRegistry.attach(contractAddress);
  
  console.log("Testing HealthRecordRegistry contract...\n");
  
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
  console.log("   Transaction hash:", storeTx.hash);
  
  // Test 3: Retrieve the document
  console.log("\n3. Retrieving the document...");
  const [retrievedCid, retrievedHash, owner_addr, timestamp, isActive] = await contract.getDocument(recordId);
  console.log("   CID:", retrievedCid);
  console.log("   Metadata Hash:", retrievedHash);
  console.log("   Owner:", owner_addr);
  console.log("   Timestamp:", new Date(timestamp * 1000).toISOString());
  console.log("   Is Active:", isActive);
  
  // Test 4: Get user records
  console.log("\n4. User records:");
  const userRecords = await contract.getUserRecords(user1.address);
  console.log("   User records:", userRecords.map(id => id.toString()));
  
  // Test 5: Verify document
  console.log("\n5. Document verification:");
  const isValid = await contract.verifyDocument(recordId, metadataHash);
  console.log("   Document is valid:", isValid);
  
  console.log("\n✅ All tests completed successfully!");
}

main().catch(console.error);