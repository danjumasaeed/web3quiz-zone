#!/usr/bin/env bash
set -euo pipefail

# make-zip.sh
# Creates a directory "web3quiz-zone" with the full project scaffold and packages it into web3quiz-zone.zip
# Usage:
#   1. Save this file: make-zip.sh
#   2. chmod +x make-zip.sh
#   3. ./make-zip.sh
#
# After running you'll have web3quiz-zone.zip in the current directory ready to download.

OUT_DIR="web3quiz-zone"
ZIP_NAME="${OUT_DIR}.zip"

if [ -d "$OUT_DIR" ]; then
  read -p "Directory '$OUT_DIR' already exists. Overwrite it? (y/N) " yn
  if [[ "${yn:-n}" != "y" && "${yn:-n}" != "Y" ]]; then
    echo "Aborted."
    exit 1
  fi
  rm -rf "$OUT_DIR"
fi

mkdir -p "$OUT_DIR"/{contracts,scripts,test,frontend/examples/questions,docs,frontend/assets}

cat > "$OUT_DIR/README.md" <<'EOF'
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
EOF

cat > "$OUT_DIR/hardhat.config.ts" <<'EOF'
import { HardhatUserConfig } from "hardhat/config";
import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-ethers";
import "hardhat/types";

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.18"
      }
    ]
  },
  networks: {
    localhost: {
      url: "http://127.0.0.1:8545"
    }
  }
};

export default config;
EOF

cat > "$OUT_DIR/tsconfig.json" <<'EOF'
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "CommonJS",
    "strict": true,
    "esModuleInterop": true,
    "outDir": "dist",
    "resolveJsonModule": true,
    "skipLibCheck": true
  },
  "include": ["./scripts", "./test", "./typechain", "./hardhat.config.ts"]
}
EOF

cat > "$OUT_DIR/package.json" <<'EOF'
{
  "name": "web3quiz-zone",
  "version": "0.1.0",
  "description": "Demo dApp + contracts for quiz campaigns with ETH/ERC20 prize payouts.",
  "main": "index.js",
  "scripts": {
    "test": "hardhat test",
    "start:frontend": "npx http-server ./frontend -p 3000 -c-1",
    "deploy": "hardhat run scripts/deploy.ts --network localhost",
    "build": "hardhat compile",
    "sign:local": "hardhat run scripts/sign-approval.ts --network localhost --"
  },
  "author": "web3quiz-zone",
  "license": "MIT",
  "devDependencies": {
    "@nomiclabs/hardhat-ethers": "^3.0.0",
    "@nomiclabs/hardhat-waffle": "^2.0.0",
    "@types/chai": "^4.3.4",
    "@types/mocha": "^10.0.1",
    "@types/node": "^20.5.1",
    "chai": "^4.3.7",
    "ethers": "^6.9.0",
    "hardhat": "^2.17.0",
    "http-server": "^14.1.1",
    "ts-node": "^10.9.1",
    "typescript": "^5.5.0"
  },
  "dependencies": {
    "@openzeppelin/contracts": "^4.11.0"
  }
}
EOF

cat > "$OUT_DIR/.gitignore" <<'EOF'
node_modules/
artifacts/
cache/
typechain/
dist/
.env
EOF

cat > "$OUT_DIR/LICENSE" <<'EOF'
MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
EOF

cat > "$OUT_DIR/contracts/CampaignFactory.sol" <<'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./QuizCampaign.sol";

contract CampaignFactory {
    address[] public campaigns;
    event CampaignCreated(address indexed campaignAddress, address indexed admin, string title);

    function createCampaign(
        address admin,
        string memory title,
        string memory metadataURI,
        address tokenAddressOrZeroForETH,
        uint256 passingScore,
        uint256 prizePerWinner
    ) external returns (address) {
        QuizCampaign campaign = new QuizCampaign(
            admin,
            metadataURI,
            tokenAddressOrZeroForETH,
            passingScore,
            prizePerWinner
        );

        campaigns.push(address(campaign));
        emit CampaignCreated(address(campaign), admin, title);
        return address(campaign);
    }

    function getCampaigns() external view returns (address[] memory) {
        return campaigns;
    }
}
EOF

cat > "$OUT_DIR/contracts/QuizCampaign.sol" <<'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract QuizCampaign {
    using ECDSA for bytes32;

    address public admin;
    string public metadataURI;
    address public token; // address(0) == ETH
    uint256 public passingScore;
    uint256 public prizePerWinner;

    // Option A: store answers hash on-chain (simple demo)
    bytes32 public answersHash;

    // Track claims
    mapping(address => bool) public claimed;

    event Funded(address indexed funder, uint256 amount);
    event FundedERC20(address indexed funder, address indexed token, uint256 amount);
    event AnswerHashUpdated(bytes32 answersHash);
    event RewardClaimed(address indexed claimant, uint256 amount);
    event Withdrawn(address indexed admin, uint256 amount);
    event WithdrawnERC20(address indexed admin, address indexed token, uint256 amount);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    constructor(
        address _admin,
        string memory _metadataURI,
        address _token,
        uint256 _passingScore,
        uint256 _prizePerWinner
    ) {
        admin = _admin;
        metadataURI = _metadataURI;
        token = _token;
        passingScore = _passingScore;
        prizePerWinner = _prizePerWinner;
    }

    // --- Funding ---

    // Fund with ETH. Only accept ETH when token == address(0)
    receive() external payable {
        require(token == address(0), "ETH not accepted for ERC20 campaign");
        emit Funded(msg.sender, msg.value);
    }

    function fund() external payable {
        require(token == address(0), "ETH not accepted for ERC20 campaign");
        require(msg.value > 0, "No ETH sent");
        emit Funded(msg.sender, msg.value);
    }

    // Fund with ERC20: approve must be called beforehand by funder
    function fundERC20(uint256 amount) external {
        require(token != address(0), "This campaign accepts ETH");
        require(amount > 0, "Amount must be > 0");
        require(IERC20(token).transferFrom(msg.sender, address(this), amount), "Transfer failed");
        emit FundedERC20(msg.sender, token, amount);
    }

    // --- Admin functions ---
    function setAnswersHash(bytes32 _hash) external onlyAdmin {
        answersHash = _hash;
        emit AnswerHashUpdated(_hash);
    }

    // Allow admin to withdraw leftover ETH
    function withdraw() external onlyAdmin {
        if (token == address(0)) {
            uint256 bal = address(this).balance;
            require(bal > 0, "No ETH to withdraw");
            (bool ok,) = payable(admin).call{value: bal}("");
            require(ok, "ETH withdraw failed");
            emit Withdrawn(admin, bal);
        } else {
            uint256 bal = IERC20(token).balanceOf(address(this));
            require(bal > 0, "No token balance");
            require(IERC20(token).transfer(admin, bal), "Token transfer failed");
            emit WithdrawnERC20(admin, token, bal);
        }
    }

    // --- Claim flows ---

    // Option A: frontend computes answersHash and sends it directly
    function claimWithAnswersHash(bytes32 providedHash) external {
        require(!claimed[msg.sender], "Already claimed");
        require(answersHash != bytes32(0), "Answers hash not set");
        require(providedHash == answersHash, "Incorrect answers hash");

        claimed[msg.sender] = true;
        _payout(msg.sender);
        emit RewardClaimed(msg.sender, prizePerWinner);
    }

    // Option B: admin signs an approval message off-chain after validating user's answers.
    // The message must be: keccak256(abi.encodePacked(claimant, address(this))) eth-signed
    function claimWithSignature(bytes calldata signature) external {
        require(!claimed[msg.sender], "Already claimed");

        bytes32 messageHash = keccak256(abi.encodePacked(msg.sender, address(this)));
        address signer = messageHash.toEthSignedMessageHash().recover(signature);
        require(signer == admin, "Invalid signature");

        claimed[msg.sender] = true;
        _payout(msg.sender);
        emit RewardClaimed(msg.sender, prizePerWinner);
    }

    // Internal payout logic supporting ETH and ERC20
    function _payout(address to) internal {
        if (token == address(0)) {
            uint256 bal = address(this).balance;
            require(bal >= prizePerWinner, "Insufficient ETH in prize pool");
            (bool ok,) = payable(to).call{value: prizePerWinner}("");
            require(ok, "ETH transfer failed");
        } else {
            uint256 bal = IERC20(token).balanceOf(address(this));
            require(bal >= prizePerWinner, "Insufficient token in prize pool");
            require(IERC20(token).transfer(to, prizePerWinner), "Token transfer failed");
        }
    }

    // Convenience getters
    function getBalance() external view returns (uint256) {
        if (token == address(0)) return address(this).balance;
        return IERC20(token).balanceOf(address(this));
    }
}
EOF

cat > "$OUT_DIR/scripts/deploy.ts" <<'EOF'
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
EOF

cat > "$OUT_DIR/scripts/sign-approval.ts" <<'EOF'
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
EOF

cat > "$OUT_DIR/test/campaigns.test.ts" <<'EOF'
import { expect } from "chai";
import { ethers } from "hardhat";
import type { Contract } from "ethers";

describe("Web3Quiz Campaigns", function () {
  let factory: Contract;
  let QuizCampaign: Contract;
  let ERC20Mock: Contract;
  let admin: any;
  let alice: any;
  let bob: any;

  beforeEach(async function () {
    [admin, alice, bob] = await ethers.getSigners();

    const Factory = await ethers.getContractFactory("CampaignFactory");
    factory = await Factory.connect(admin).deploy();
    await factory.deployed();

    // Simple ERC20 mock for tests (we'll use OpenZeppelin's ERC20 inlined here for speed)
    const ERC20 = await ethers.getContractFactory(
      `contract ERC20Mock {
        string public name = "MockToken";
        string public symbol = "MTK";
        uint8 public decimals = 18;
        uint256 public totalSupply;
        mapping(address => uint256) public balanceOf;
        mapping(address => mapping(address => uint256)) public allowance;
        constructor(uint256 initialSupply) {
          totalSupply = initialSupply;
          balanceOf[msg.sender] = initialSupply;
        }
        function transfer(address to, uint256 amount) external returns(bool) {
          require(balanceOf[msg.sender] >= amount, "bal");
          balanceOf[msg.sender] -= amount;
          balanceOf[to] += amount;
          return true;
        }
        function transferFrom(address from, address to, uint256 amount) external returns(bool) {
          if (from != msg.sender) {
            require(allowance[from][msg.sender] >= amount, "allow");
            allowance[from][msg.sender] -= amount;
          }
          require(balanceOf[from] >= amount, "bal");
          balanceOf[from] -= amount;
          balanceOf[to] += amount;
          return true;
        }
        function approve(address spender, uint256 amount) external returns(bool) {
          allowance[msg.sender][spender] = amount;
          return true;
        }
      }`
    );
    ERC20Mock = await ERC20.deploy(ethers.utils.parseEther("1000"));
    await ERC20Mock.deployed();
  });

  it("creates a campaign, funds it with ETH and allows claim with signature", async function () {
    // Create campaign via factory (ETH)
    const prize = ethers.utils.parseEther("0.01");
    await factory.createCampaign(admin.address, "ETH quiz", "uri", ethers.constants.AddressZero, 70, prize);
    const campaigns = await factory.getCampaigns();
    expect(campaigns.length).to.be.greaterThan(0);

    const campaignAddr = campaigns[0];
    const campaign = await ethers.getContractAt("QuizCampaign", campaignAddr);

    // Fund the campaign with enough ETH
    await admin.sendTransaction({ to: campaign.address, value: ethers.utils.parseEther("0.05") });
    expect(await ethers.provider.getBalance(campaign.address)).to.equal(ethers.utils.parseEther("0.05"));

    // Admin signs an approval message for alice
    const messageHash = ethers.utils.solidityKeccak256(["address", "address"], [alice.address, campaign.address]);
    const signature = await admin.signMessage(ethers.utils.arrayify(messageHash));

    // Alice claims with signature (should succeed)
    await expect(campaign.connect(alice).claimWithSignature(signature))
      .to.emit(campaign, "RewardClaimed");

    // Alice cannot claim twice
    await expect(campaign.connect(alice).claimWithSignature(signature)).to.be.revertedWith("Already claimed");
  });

  it("creates ERC20 campaign and allows claim by answers hash", async function () {
    const prize = ethers.utils.parseEther("1");
    // Create ERC20 campaign
    await factory.createCampaign(admin.address, "ERC20 quiz", "uri", ERC20Mock.address, 80, prize);
    const campaigns = await factory.getCampaigns();
    const campaignAddr = campaigns[campaigns.length - 1];
    const campaign = await ethers.getContractAt("QuizCampaign", campaignAddr);

    // Admin funds campaign with ERC20: approve then fundERC20
    await ERC20Mock.connect(admin).approve(campaign.address, ethers.utils.parseEther("10"));
    await campaign.connect(admin).fundERC20(ethers.utils.parseEther("5"));

    expect(await ERC20Mock.balanceOf(campaign.address)).to.equal(ethers.utils.parseEther("5"));

    // Admin sets answersHash on-chain (Option A)
    const answers = "Q1:A|Q2:C|Q3:B";
    const answersHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(answers));
    await campaign.connect(admin).setAnswersHash(answersHash);

    // Alice computes answers hash client-side and calls claimWithAnswersHash
    await expect(campaign.connect(alice).claimWithAnswersHash(answersHash)).to.emit(campaign, "RewardClaimed");

    // Double claim prevented
    await expect(campaign.connect(alice).claimWithAnswersHash(answersHash)).to.be.revertedWith("Already claimed");
  });

  it("prevents claim with wrong signature or insufficient funds", async function () {
    const prize = ethers.utils.parseEther("0.02");
    await factory.createCampaign(admin.address, "Small ETH quiz", "uri", ethers.constants.AddressZero, 50, prize);
    const campaigns = await factory.getCampaigns();
    const campaignAddr = campaigns[campaigns.length - 1];
    const campaign = await ethers.getContractAt("QuizCampaign", campaignAddr);

    // not funded -> claim should fail due to insufficient funds when payout attempted
    const messageHash = ethers.utils.solidityKeccak256(["address", "address"], [bob.address, campaign.address]);
    const signature = await admin.signMessage(ethers.utils.arrayify(messageHash));

    // Even with valid signature, payout fails because insufficient funds
    await expect(campaign.connect(bob).claimWithSignature(signature)).to.be.revertedWith("Insufficient ETH in prize pool");
  });
});
EOF

cat > "$OUT_DIR/examples/questions/sample-questions.json" <<'EOF'
{
  "title": "Sample Web3Quiz",
  "description": "A short demo quiz about web3 basics.",
  "questions": [
    {
      "id": 1,
      "question": "What does EVM stand for?",
      "options": ["Ethereum Virtual Machine", "Encrypted Value Mapping", "External Variable Manager", "Ether Vault Manager"]
    },
    {
      "id": 2,
      "question": "Which function is used to send ETH in Solidity safely?",
      "options": ["transfer()", "send()", "call{value:...}()", "push()"]
    },
    {
      "id": 3,
      "question": "Which standard is ERC-20?",
      "options": ["Token interface", "Storage standard", "Consensus protocol", "Wallet spec"]
    }
  ],
  "answersExampleFormat": "Q1:A|Q2:C|Q3:A"
}
EOF

cat > "$OUT_DIR/frontend/index.html" <<'EOF'
<!doctype html>
<html>
<head>
  <meta charset="utf-8" />
  <title>Web3Quiz Zone</title>
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <link rel="stylesheet" href="styles.css" />
</head>
<body>
  <header>
    <h1>Web3Quiz Zone</h1>
    <div id="wallet">
      <button id="connectBtn">Connect Wallet</button>
      <span id="addr"></span>
    </div>
  </header>

  <main>
    <section class="panel" id="createPanel">
      <h2>Create Campaign (Admin)</h2>
      <form id="createForm">
        <label>Title: <input name="title" required /></label>
        <label>Metadata JSON URL (questions): <input name="metadataURI" value="http://localhost:3000/examples/questions/sample-questions.json" /></label>
        <label>Theme color: <input name="theme" type="color" value="#2b6cb0" /></label>
        <label>Token (address or 0x000..0 for ETH): <input name="token" value="0x0000000000000000000000000000000000000000" /></label>
        <label>Passing Score (percentage): <input name="passingScore" type="number" value="70" /></label>
        <label>Prize per winner (in ETH or token units): <input name="prize" value="0.01" /></label>
        <button type="submit">Create Campaign</button>
      </form>
      <div id="createStatus"></div>
    </section>

    <section class="panel" id="campaignsPanel">
      <h2>Campaigns</h2>
      <div id="campaignList">Loading campaigns...</div>
    </section>

    <section class="panel" id="campaignDetail" style="display:none">
      <h2 id="campTitle">Campaign</h2>
      <div id="campMeta"></div>
      <div id="questionArea"></div>
      <div id="quizActions"></div>
    </section>
  </main>

  <footer>
    <small>Demo: option A (on-chain hash) and option B (admin-signed). See docs for security notes.</small>
  </footer>

  <script src="https://cdn.jsdelivr.net/npm/ethers@6.9.0/dist/ethers.umd.min.js"></script>
  <script src="app.js"></script>
</body>
</html>
EOF

cat > "$OUT_DIR/frontend/styles.css" <<'EOF'
:root {
  --bg: #0f172a;
  --panel: #0b1220;
  --text: #e6eef8;
  --accent: #2b6cb0;
}

* { box-sizing: border-box; font-family: Inter, ui-sans-serif, system-ui, -apple-system, "Segoe UI", Roboto, "Helvetica Neue", Arial; }
body {
  margin: 0;
  min-height: 100vh;
  background: linear-gradient(180deg, #071029 0%, #071a2c 100%);
  color: var(--text);
  padding: 16px;
}
header {
  display:flex; align-items:center; justify-content:space-between;
  margin-bottom: 16px;
}
h1 { margin: 0; font-size: 20px; color: var(--accent); }
.panel {
  background: rgba(255,255,255,0.02);
  border: 1px solid rgba(255,255,255,0.03);
  padding: 12px;
  border-radius: 8px;
  margin-bottom: 12px;
}
label { display:block; margin:6px 0; font-size:14px; color:#cfe6ff; }
input, select, button {
  padding: 8px;
  border-radius: 6px;
  border: 1px solid rgba(255,255,255,0.06);
  background: rgba(255,255,255,0.02);
  color: var(--text);
}
button { cursor:pointer; background: var(--accent); color: #fff; border: none; }
#campaignList { display:grid; grid-template-columns: repeat(auto-fit,minmax(220px,1fr)); gap:12px; }
.campaignCard { padding:12px; border-radius:8px; background: rgba(255,255,255,0.02); border:1px solid rgba(255,255,255,0.03); }
.campaignCard h3 { margin:0 0 6px 0; font-size:16px; }
.small { font-size:12px; color:#a9c7e6; }
.question { margin-bottom:10px; padding:8px; background: rgba(255,255,255,0.01); border-radius:6px; }
.option { display:block; margin:6px 0; }
footer { margin-top: 18px; color:#7696b8; font-size:13px; }
EOF

cat > "$OUT_DIR/frontend/app.js" <<'EOF'
// Frontend minimal JS to interact with factory & campaigns
// Fetches factory address from frontend/config.json written by deploy script.
(async () => {
  // Load config to get factory address
  let factoryAddress = null;
  try {
    const cfgResp = await fetch("config.json");
    const cfg = await cfgResp.json();
    factoryAddress = cfg.factoryAddress;
  } catch (err) {
    console.warn("Could not load frontend/config.json. Make sure deploy wrote the file or set a factoryAddress manually.", err);
  }

  const provider = new ethers.BrowserProvider(window.ethereum || new ethers.JsonRpcProvider("http://127.0.0.1:8545"));
  let signer;
  let userAddress;

  // ABI excerpts (minimal)
  const factoryAbi = [
    "function getCampaigns() view returns (address[])",
    "function createCampaign(address admin,string title,string metadataURI,address tokenAddressOrZeroForETH,uint256 passingScore,uint256 prizePerWinner) returns (address)",
    "event CampaignCreated(address indexed campaignAddress, address indexed admin, string title)"
  ];
  const campaignAbi = [
    "function admin() view returns (address)",
    "function metadataURI() view returns (string)",
    "function token() view returns (address)",
    "function prizePerWinner() view returns (uint256)",
    "function getBalance() view returns (uint256)",
    "function claimWithAnswersHash(bytes32) payable",
    "function claimWithSignature(bytes)",
    "function setAnswersHash(bytes32)",
    "function fund() payable",
    "function fundERC20(uint256)"
  ];

  // Helper to format address display
  function short(addr) { return addr ? addr.slice(0,6) + "..." + addr.slice(-4) : ""; }

  // Connect wallet
  document.getElementById("connectBtn").addEventListener("click", async () => {
    await provider.send("eth_requestAccounts", []);
    signer = await provider.getSigner();
    userAddress = await signer.getAddress();
    document.getElementById("addr").textContent = short(userAddress);
    refreshCampaigns();
  });

  // Create campaign
  document.getElementById("createForm").addEventListener("submit", async (e) => {
    e.preventDefault();
    if (!signer) return alert("Connect wallet first");
    if (!factoryAddress) return alert("Factory address not configured. Deploy first.");

    const form = e.target;
    const title = form.title.value;
    const metadataURI = form.metadataURI.value;
    const token = form.token.value;
    const passingScore = parseInt(form.passingScore.value);
    const prizeRaw = form.prize.value;
    // For simplicity assume ETH decimals, convert to wei
    const prize = ethers.parseEther(prizeRaw);

    const factory = new ethers.Contract(factoryAddress, factoryAbi, signer);
    const tx = await factory.createCampaign(userAddress, title, metadataURI, token, passingScore, prize);
    document.getElementById("createStatus").textContent = "Creating campaign... waiting for tx";
    await tx.wait();
    document.getElementById("createStatus").textContent = "Campaign created. Refreshing list...";
    await refreshCampaigns();
  });

  async function refreshCampaigns() {
    try {
      if (!factoryAddress) {
        document.getElementById("campaignList").textContent = "Factory address not configured in frontend/config.json";
        return;
      }
      const signerOrProvider = signer || provider;
      const factory = new ethers.Contract(factoryAddress, factoryAbi, signerOrProvider);
      const campaigns = await factory.getCampaigns();
      const listEl = document.getElementById("campaignList");
      listEl.innerHTML = "";
      for (let addr of campaigns) {
        const card = document.createElement("div");
        card.className = "campaignCard";
        const rent = document.createElement("h3");
        rent.textContent = addr;
        card.appendChild(rent);
        const btn = document.createElement("button");
        btn.textContent = "Open";
        btn.onclick = () => openCampaign(addr);
        card.appendChild(btn);
        listEl.appendChild(card);
      }
    } catch (err) {
      console.error(err);
      document.getElementById("campaignList").textContent = "Error loading campaigns. Are contracts deployed?";
    }
  }

  async function openCampaign(addr) {
    const signerOrProvider = signer || provider;
    const campaign = new ethers.Contract(addr, campaignAbi, signerOrProvider);
    const metaURI = await campaign.metadataURI();
    const token = await campaign.token();
    const prize = await campaign.prizePerWinner();
    document.getElementById("campaignDetail").style.display = "block";
    document.getElementById("campTitle").textContent = "Campaign: " + addr;
    document.getElementById("campMeta").innerHTML = `
      <div class="small">Prize per winner: ${ethers.formatEther(prize)} ${token === ethers.ZeroAddress ? "ETH" : token}</div>
      <div class="small">Metadata: ${metaURI}</div>
    `;
    // Fetch questions JSON
    try {
      const resp = await fetch(metaURI);
      const json = await resp.json();
      renderQuiz(addr, json);
    } catch (err) {
      document.getElementById("questionArea").innerHTML = `<div class="small">Failed to fetch metadata: ${err}</div>`;
    }
  }

  function renderQuiz(campaignAddr, meta) {
    const area = document.getElementById("questionArea");
    area.innerHTML = "";
    const form = document.createElement("form");
    form.id = "quizForm";
    meta.questions.forEach((q, i) => {
      const qDiv = document.createElement("div");
      qDiv.className = "question";
      qDiv.innerHTML = `<strong>${q.question}</strong>`;
      q.options.forEach((opt, idx) => {
        const input = document.createElement("input");
        input.type = "radio";
        input.name = `q${i}`;
        input.value = String.fromCharCode(65 + idx); // A, B, C...
        input.id = `q${i}_${idx}`;
        const label = document.createElement("label");
        label.className = "option";
        label.appendChild(input);
        label.appendChild(document.createTextNode(" " + opt));
        qDiv.appendChild(label);
      });
      form.appendChild(qDiv);
    });

    const submit = document.createElement("button");
    submit.type = "button";
    submit.textContent = "Submit Answers (simulate pass locally)";
    submit.onclick = async () => {
      // Very simple client-side scoring: assume admin publishes correct answers externally.
      // For demo, we just ask user to enter a answers string (Q1:A|Q2:C|Q3:B) to simulate
      const answers = prompt("Enter users' answers in format Q1:A|Q2:C|Q3:B (demo)", meta.answersExampleFormat || "");
      if (!answers) return;
      // Compute hash like on-chain would: keccak256(utf8)
      const hash = ethers.keccak256(ethers.toUtf8Bytes(answers));
      // Ask user: use Option A (send hash) or Option B (request admin-signed message)
      const mode = prompt("Claim mode: A for on-chain hash, B for admin-signed (recommended)", "B");
      if (mode === "A") {
        // Call claimWithAnswersHash
        if (!signer) return alert("Connect wallet to claim");
        const signerContract = new ethers.Contract(campaignAddr, campaignAbi, signer);
        try {
          const tx = await signerContract.claimWithAnswersHash(hash);
          alert("Tx sent, waiting for confirmation...");
          await tx.wait();
          alert("Claim transaction mined. You should receive the reward if funded.");
        } catch (err) {
          alert("Claim failed: " + (err?.message || err));
          console.error(err);
        }
      } else {
        // Option B: request admin to sign message off-chain after validating answers, then paste signature here
        const signature = prompt("Paste admin signature (off-chain) for your address & campaign. Admin must sign hash(claimer, campaignAddress).");
        if (!signature) return;
        if (!signer) return alert("Connect wallet to claim");
        const signerContract = new ethers.Contract(campaignAddr, campaignAbi, signer);
        try {
          const tx = await signerContract.claimWithSignature(signature);
          alert("Tx sent, waiting for confirmation...");
          await tx.wait();
          alert("Claim transaction mined. You should receive the reward if funded.");
        } catch (err) {
          alert("Claim failed: " + (err?.message || err));
          console.error(err);
        }
      }
    };
    form.appendChild(submit);
    area.appendChild(form);
  }

  // Initial attempt to refresh campaigns (factory must be configured)
  await refreshCampaigns();
})();
EOF

cat > "$OUT_DIR/frontend/config.json" <<'EOF'
{
  "factoryAddress": "PASTE_FACTORY_ADDRESS_HERE"
}
EOF

cat > "$OUT_DIR/docs/answers-security.md" <<'EOF'
# Answers storage & verification approaches

This repository demonstrates two approaches for verifying that a user passed a quiz and is eligible to claim a reward.

Option A — On-chain answers hash (simple demo)
- Admin computes a salted canonical representation of correct answers, e.g. "Q1:A|Q2:B|salt:0xabc".
- Admin calls setAnswersHash(keccak256(bytes(...))) to store the bytes32 on-chain.
- Frontend computes the same hash from user's answers and sends claimWithAnswersHash(hash).
- Contract compares provided hash against stored answersHash and pays out.

Pros:
- Simple to implement.
- No off-chain signing required.

Cons:
- The hash is stored on-chain and can be inspected by anyone. If answers are guessable or unsalted, they can be brute-forced.
- Reveals deterministic information; use a strong salt, but salts may also be brute-forced for small answer spaces.

Option B — Admin-signed off-chain verification (recommended)
- Admin verifies the user's answers off-chain (e.g. by computing answers and scoring) and only signs an approval message tying the claim to the user's address and the campaign address.
- Frontend collects that signature and calls claimWithSignature(signature). Contract recovers the signer and compares to admin.
- Because the admin does verification off-chain, correct answers need not be stored on-chain, preventing leakage.

Pros:
- Keeps answers secret.
- Avoids on-chain exposure and brute-force risk.
- Flexible: admin can add metadata, expiration, partial rewards, and nonces in signed payloads.

Cons:
- Requires an off-chain signer (admin) and a way to distribute signatures.
- Admin must run a secure process to verify and sign claims.

General recommendations for production:
- Use Option B. Include timestamps and nonces in the admin-signed payload to prevent signature replay across campaigns or time windows.
- Use per-user nonces or include claimant address and campaign address in the signed message (this demo includes claimant + campaign binding).
- Use standardized signature formats and EIP-712 if you need structured & extensible signed messages.
- Ensure prize pools are sized or rate-limited to prevent draining via many small claims. Consider allowing admin to set claim limits, or require claim requests to be queued & reviewed.
EOF

cat > "$OUT_DIR/docs/how-to-add-questions.md" <<'EOF'
# How to add Quiz Questions (IPFS vs On-chain)

You have two main options to provide quiz metadata:

1) Off-chain JSON (recommended)
- Host your questions JSON at a static URL or IPFS CID.
- The JSON should contain:
  - title, description
  - questions: array of { id, question, options: [] }
  - optional answersExampleFormat field to help demo users
- Example: examples/questions/sample-questions.json
- When creating a campaign, include the metadata URL (IPFS CID or HTTPS) as metadataURI.

2) On-chain (not recommended for full text)
- You could store small strings on-chain, but it's expensive and not needed.
- Store only a pointer (IPFS CID) on-chain using metadataURI.

Security note:
- If you use Option A (answersHash on-chain), never publish the correct answers in the same metadata JSON. Instead, produce a hashed/salted representation and only set the hash using the admin interface.
EOF

cat > "$OUT_DIR/docs/video-script.md" <<'EOF'
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
EOF

echo "All files written to $OUT_DIR."

# Create zip
if command -v zip >/dev/null 2>&1; then
  echo "Creating zip archive: $ZIP_NAME"
  zip -r "$ZIP_NAME" "$OUT_DIR" >/dev/null
  echo "Created $ZIP_NAME"
else
  echo "zip not found. Creating a tar.gz instead: ${OUT_DIR}.tar.gz"
  tar -czf "${OUT_DIR}.tar.gz" "$OUT_DIR"
  echo "Created ${OUT_DIR}.tar.gz"
fi

echo "Done. You can now download $ZIP_NAME (or ${OUT_DIR}.tar.gz if zip missing)."