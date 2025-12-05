# Demo Video Script (for judges)

Duration target: 2-4 minutes

0:00 - 0:10 — Intro
- "Hi, this is Web3Quiz Zone — a demo dApp that lets projects create quiz campaigns and reward community members in ETH or ERC-20."

0:10 - 0:40 — Show repo & architecture
- Quick glance at the repository tree: contracts, scripts, frontend, tests.
- Mention CampaignFactory -> QuizCampaign and two claim methods (on-chain hash and admin-signed).

0:40 - 1:20 — Run local demo (record)
- Start Hardhat node:
  - npx hardhat node
- Deploy:
  - npm run build
  - npm run deploy
- Start the frontend:
  - npm run start:frontend
- Open UI and connect MetaMask to localhost:8545.

1:20 - 2:00 — Create & fund campaign
- Show create campaign form (title, metadata URL, token address or ETH, prize amount).
- Create with an address configured as admin.
- Fund campaign (send ETH directly from admin wallet via UI or use hardhat-funded account).
- Or demonstrate ERC-20 flow: approve & fund.

2:00 - 2:40 — Take quiz & claim
- Open a campaign in the UI, load questions from example JSON.
- Fill answers, simulate passing locally.
- Two claim flows:
  - Option A: compute answers hash and send claim (show limitation - hash stored on-chain).
  - Option B (recommended): show admin creating a signature off-chain (use a simple script or Hardhat console), paste signature in UI, and claim reward; show balance update.

2:40 - 3:00 — Tests & wrap up
- Show that tests cover funding, claiming, double-claim prevention, and invalid signature failure by running:
  - npm test
- Closing notes: security tradeoffs, next steps (IPFS management, off-chain admin UI, EIP-712 signatures).

GIF suggestions (short):
- Connect wallet
- Create campaign
- Take quiz and click claim
- Claim success modal / small confetti

Thanks — happy to demo a testnet deployment or add a simple admin server to produce signatures.