const { ethers } = require("hardhat");

async function main() {
  console.log("Starting deployment...");

  const [deployer] = await ethers.getSigners();
  console.log("Deployer:", deployer.address);
  
  const HealthRecordRegistry = await ethers.getContractFactory("HealthRecordRegistry");
  const contract = await HealthRecordRegistry.deploy();
  await contract.waitForDeployment();
  
  const contractAddress = await contract.getAddress();
  console.log("Contract deployed to:", contractAddress);
}

main().catch(console.error);