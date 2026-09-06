const hre = require("hardhat");

async function main() {
  const DigitalAsset = await hre.ethers.getContractFactory("DigitalAsset");
  const contract = await DigitalAsset.deploy();
  await contract.waitForDeployment();
  
  console.log("DigitalAsset deployed to:", await contract.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});