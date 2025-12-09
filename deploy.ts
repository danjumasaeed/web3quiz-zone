import { ethers } from "hardhat";
import fs from "fs";
import path from "path";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with account:", deployer.address);

  // Get the ContractFactory for CampaignFactory
  const Factory = await ethers.getContractFactory("CampaignFactory");
  
  // Deploy the Factory contract
  const factory = await Factory.deploy();
  await factory.waitForDeployment(); // Use waitForDeployment for modern ethers

  const factoryAddress = await factory.getAddress();
  console.log("CampaignFactory deployed to:", factoryAddress);

  // Example: create a campaign using the factory for demonstration.
  // Note: ethers.ZeroAddress is the modern equivalent of ethers.constants.AddressZero
  const tx = await factory.createCampaign(
    deployer.address,
    "Demo Quiz Campaign",
    // NOTE: This URL must be accessible to fetch the quiz questions!
    "http://localhost:3000/examples/questions/sample-questions.json", 
    ethers.ZeroAddress,
    70,
    ethers.parseEther("0.01") // prize per winner
  );
  console.log("Creating sample campaign...");
  await tx.wait();

  const campaigns = await factory.getCampaigns();
  console.log("Factory campaigns:", campaigns);

  // Write frontend config so the UI can pick up the factory address automatically
  const frontendConfig = {
    factoryAddress: factoryAddress
  };

  const outPath = path.join(__dirname, "..", "frontend", "config.json");
  // Ensure the directory exists before writing the file
  fs.mkdirSync(path.dirname(outPath), { recursive: true }); 
  fs.writeFileSync(outPath, JSON.stringify(frontendConfig, null, 2));
  console.log("Wrote frontend config to:", outPath);
  console.log("You can now run: npm run start:frontend and open http://localhost:3000");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
