const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying AgentGuard with account:", deployer.address);
  const balance = await hre.ethers.provider.getBalance(deployer.address);
  console.log("Account balance:", hre.ethers.formatEther(balance), "USDC");

  const Contract = await hre.ethers.getContractFactory("AgentGuard");
  const contract = await Contract.deploy();
  await contract.waitForDeployment();

  const address = await contract.getAddress();
  console.log("AgentGuard deployed to:", address);

  const fs = require("fs");
  const deployInfo = {
    contract: "AgentGuard",
    address: address,
    network: "arcTestnet",
    deployer: deployer.address,
    timestamp: new Date().toISOString(),
  };
  fs.writeFileSync("deployment.json", JSON.stringify(deployInfo, null, 2));
  console.log("Deployment info saved to deployment.json");
}

main().then(() => process.exit(0)).catch((error) => { console.error(error); process.exit(1); });