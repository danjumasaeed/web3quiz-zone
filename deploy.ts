import { ethers } from "hardhat";
import fs from "fs";
import path from "path";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with account:", deployer.address);

  const Factory = await ethers.getContractFactory("CampaignFactory");
  const factory = await Factory.deploy();
  await factory.deployed();
  console.log("CampaignFactory deployed to:", factory.address);

  // Example: create a campaign using the factory for demonstration.
  const tx = await factory.createCampaign(
    deployer.address,
    "Demo Quiz Campaign",
    "http://localhost:3000/examples/questions/sample-questions.json",
    ethers.constants.AddressZero,
    70,
    ethers.utils.parseEther("0.01") // prize per winner
  );
  await tx.wait();

  const campaigns = await factory.getCampaigns();
  console.log("Factory campaigns:", campaigns);

  // Write frontend config so the UI can pick up the factory address automatically
  const frontendConfig = {
    factoryAddress: factory.address
  };

  const outPath = path.join(__dirname, "..", "frontend", "config.json");
  fs.writeFileSync(outPath, JSON.stringify(frontendConfig, null, 2));
  console.log("Wrote frontend config to:", outPath);
  console.log("You can now run: npm run start:frontend and open http://localhost:3000");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});