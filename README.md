# web3quiz-zone

Web3Quiz Zone is a demo dApp + smart contracts to allow EVM projects to create quiz campaigns, fund prize pools (ETH or ERC-20), configure theme colors, and reward community members who pass quizzes. It demonstrates two claiming approaches:
- Option A: On-chain answers hash stored (simple demo).
- Option B: Admin-signed off-chain verification (recommended for secrecy).

This repo contains:
- Hardhat TypeScript project with Solidity contracts
- Frontend static HTML/CSS/JS using ethers.js
- Tests to validate main flows
- Docs explaining trade-offs, deployment, and usage

Quick start (local):
1. Install dependencies
   npm install

2. Start a local Hardhat node in a terminal:
   npx hardhat node

3. Compile & deploy locally (in another terminal):
   npm run build
   npm run deploy

   Note: `deploy` will also write `frontend/config.json` with the deployed factory address so the frontend can load campaigns automatically.

4. Serve frontend:
   npm run start:frontend
   Open http://localhost:3000

5. Create a campaign or use the sample deployed by the deploy script. Connect MetaMask to http://localhost:8545 (import one of the Hardhat accounts if needed).

6. To sign an approval for a claimant (admin flow), run:
   npx hardhat run scripts/sign-approval.ts --network localhost -- <campaignAddress> <claimerAddress>

   Or use the npm convenience command (pass args after --):
   npm run sign:local -- <campaignAddress> <claimerAddress>

7. Run tests:
   npm test

What the deploy script does:
- Deploys CampaignFactory
- Creates a sample campaign
- Writes frontend/config.json { "factoryAddress": "<address>" } so the frontend picks it up automatically.

If you prefer to set `frontend/config.json` manually, create it with:
{
  "factoryAddress": "<deployed factory address>"
}

Security & trade-offs:
- See docs/answers-security.md