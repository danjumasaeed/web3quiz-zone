#!/usr/bin/env bash
set -euo pipefail

# setup-repo.sh
# Create full project scaffold for web3quiz-zone, commit, and push to origin/main.
# Usage: run inside your local clone of the target repo (danjumasaeed/web3quiz-zone)

ROOT_DIR="$(pwd)"
echo "Running in: $ROOT_DIR"

# Confirm we're in the repo directory (basic check)
read -p "Proceed to create files, commit and push to origin/main? (y/N) " confirm
if [[ "${confirm:-n}" != "y" && "${confirm:-n}" != "Y" ]]; then
  echo "Aborted."
  exit 1
fi

# Create directories
mkdir -p contracts scripts test frontend/examples/questions docs frontend/assets

# Write files
cat > README.md <<'EOF'
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

cat > hardhat.config.ts <<'EOF'
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

cat > tsconfig.json <<'EOF'
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

cat > package.json <<'EOF'
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

cat > .gitignore <<'EOF'
node_modules/
artifacts/
cache/
typechain/
dist/
.env
EOF

cat > LICENSE <<'EOF'
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

cat > contracts/CampaignFactory.sol <<'EOF'
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

cat > contracts/QuizCampaign.sol <<'EOF'
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

cat > scripts/deploy.ts <<'EOF'
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

cat > scripts/sign-approval.ts <<'EOF'
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

cat > test/campaigns.test.ts <<'EOF'
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
    await factory.de