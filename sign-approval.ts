import { ethers } from "hardhat";

/**
 * Usage:
 *  npx hardhat run scripts/sign-approval.ts --network localhost -- <campaignAddress> <claimerAddress>
 *
 * Example:
 *  npx hardhat run scripts/sign-approval.ts --network localhost -- 0xCampaignAddr 0xClaimerAddr
 *
 * The script uses the first Hardhat signer (deployer/admin) to sign an approval message for <claimerAddress>
 * bound to the <campaignAddress>. It prints an Ethereum signature you can paste into the frontend to call claimWithSignature.
 */

async function main() {
  const args = process.argv.slice(2);
  if (args.length < 2) {
    console.error("Missing args. Usage: <campaignAddress> <claimerAddress>");
    process.exit(1);
  }
  const [campaignAddr, claimerAddr] = args;

  const signers = await ethers.getSigners();
  const admin = signers[0];

  // Message: keccak256(abi.encodePacked(claimer, campaign))
  const messageHash = ethers.utils.solidityKeccak256(["address", "address"], [claimerAddr, campaignAddr]);
  const signature = await admin.signMessage(ethers.utils.arrayify(messageHash));

  console.log("Admin address (signer):", admin.address);
  console.log("Campaign address:", campaignAddr);
  console.log("Claimer address:", claimerAddr);
  console.log("Message hash:", messageHash);
  console.log("Signature (paste into frontend prompt):", signature);

  console.log("\nExample curl (frontend submission):");
  console.log(`curl -X POST -d '{"signature":"${signature}"}' http://localhost:3000/`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});