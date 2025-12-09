import { expect } from "chai";
import { ethers } from "hardhat";
import type { Contract } from "ethers";

describe("Web3Quiz Campaigns", function () {
  let factory: Contract;
  let ERC20Mock: Contract;
  let admin: any;
  let alice: any;
  let bob: any;

  beforeEach(async function () {
    [admin, alice, bob] = await ethers.getSigners();

    const Factory = await ethers.getContractFactory("CampaignFactory");
    // Deploy the factory contract
    factory = await Factory.connect(admin).deploy();
    await factory.waitForDeployment();

    // Simple ERC20 mock for tests. We use inline Solidity to define the mock ERC20 contract for faster testing.
    const ERC20Factory = await ethers.getContractFactory(
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
    // Deploy the mock ERC20 token with an initial supply of 1000 tokens (1000 * 10^18)
    ERC20Mock = await ERC20Factory.deploy(ethers.parseEther("1000"));
    await ERC20Mock.waitForDeployment();
  });

  it("creates a campaign, funds it with ETH and allows claim with signature", async function () {
    // Define the prize amount
    const prize = ethers.parseEther("0.01");
    // Create campaign via factory (using ETH, so token address is AddressZero)
    await factory.createCampaign(admin.address, "ETH quiz", "uri", ethers.ZeroAddress, 70, prize);
    const campaigns = await factory.getCampaigns();
    expect(campaigns.length).to.be.greaterThan(0);

    const campaignAddr = campaigns[0];
    // Attach the QuizCampaign ABI to the deployed address
    const campaign = await ethers.getContractAt("QuizCampaign", campaignAddr);

    // Fund the campaign with enough ETH
    await admin.sendTransaction({ to: campaignAddr, value: ethers.parseEther("0.05") });
    expect(await ethers.provider.getBalance(campaignAddr)).to.equal(ethers.parseEther("0.05"));

    // Admin signs an approval message for alice (this is the off-chain flow)
    // The message is keccak256(abi.encodePacked(claimant, campaignAddress))
    const messageHash = ethers.solidityPackedKeccak256(["address", "address"], [alice.address, campaignAddr]);
    // The message must be converted to an Ethereum Signed Message hash before signing
    const signature = await admin.signMessage(ethers.getBytes(messageHash));

    // Alice claims with signature (should succeed)
    // Record Alice's balance before the claim
    const aliceInitialEthBalance = await ethers.provider.getBalance(alice.address);
    const tx = await campaign.connect(alice).claimWithSignature(signature);
    
    // Check for the event and confirm the transaction succeeded
    await expect(tx).to.emit(campaign, "RewardClaimed");

    // Check Alice's balance after the claim (should have increased by the prize amount, minus gas)
    const aliceFinalEthBalance = await ethers.provider.getBalance(alice.address);
    // We cannot check for exact equality due to gas, but we ensure it's greater than initial
    expect(aliceFinalEthBalance).to.be.greaterThan(aliceInitialEthBalance);
    
    // Alice cannot claim twice
    await expect(campaign.connect(alice).claimWithSignature(signature)).to.be.revertedWith("Already claimed");
  });

  it("creates ERC20 campaign and allows claim by answers hash", async function () {
    const prize = ethers.parseEther("1");
    // Create ERC20 campaign
    await factory.createCampaign(admin.address, "ERC20 quiz", "uri", ERC20Mock.target, 80, prize);
    const campaigns = await factory.getCampaigns();
    const campaignAddr = campaigns[campaigns.length - 1];
    const campaign = await ethers.getContractAt("QuizCampaign", campaignAddr);

    // Admin transfers some MockToken to Alice for testing her balance later
    await ERC20Mock.connect(admin).transfer(alice.address, ethers.parseEther("10"));
    
    // Admin funds campaign with ERC20: approve then fundERC20
    await ERC20Mock.connect(admin).approve(campaignAddr, ethers.parseEther("10"));
    await campaign.connect(admin).fundERC20(ethers.parseEther("5"));

    expect(await ERC20Mock.balanceOf(campaignAddr)).to.equal(ethers.parseEther("5"));

    // Admin sets answersHash on-chain (Option A)
    const answers = "Q1:A|Q2:C|Q3:B";
    const answersHash = ethers.keccak256(ethers.toUtf8Bytes(answers));
    await expect(campaign.connect(admin).setAnswersHash(answersHash)).to.emit(campaign, "AnswerHashUpdated").withArgs(answersHash);

    // Record Alice's token balance before claim
    const aliceInitialTokenBalance = await ERC20Mock.balanceOf(alice.address);
    
    // Alice computes answers hash client-side and calls claimWithAnswersHash
    await expect(campaign.connect(alice).claimWithAnswersHash(answersHash)).to.emit(campaign, "RewardClaimed");
    
    // Check Alice's token balance after the claim (should be initial + prize)
    const aliceFinalTokenBalance = await ERC20Mock.balanceOf(alice.address);
    expect(aliceFinalTokenBalance).to.equal(aliceInitialTokenBalance + prize);

    // Double claim prevented
    await expect(campaign.connect(alice).claimWithAnswersHash(answersHash)).to.be.revertedWith("Already claimed");
  });

  it("prevents claim with wrong hash, wrong signature or insufficient funds", async function () {
    const prize = ethers.parseEther("0.02");
    await factory.createCampaign(admin.address, "Small ETH quiz", "uri", ethers.ZeroAddress, 50, prize);
    const campaigns = await factory.getCampaigns();
    const campaignAddr = campaigns[campaigns.length - 1];
    const campaign = await ethers.getContractAt("QuizCampaign", campaignAddr);

    // --- Case 1: Insufficient funds (ETH) ---
    // The campaign is currently unfunded.
    const messageHash = ethers.solidityPackedKeccak256(["address", "address"], [bob.address, campaignAddr]);
    const signature = await admin.signMessage(ethers.getBytes(messageHash));

    // Even with valid signature, payout fails because insufficient funds
    await expect(campaign.connect(bob).claimWithSignature(signature)).to.be.revertedWith("Insufficient ETH in prize pool");
    
    // Fund it now
    await admin.sendTransaction({ to: campaignAddr, value: ethers.parseEther("0.05") });


    // --- Case 2: Wrong Signature ---
    // Bob signs a message for Alice (invalid signer)
    const aliceMessageHash = ethers.solidityPackedKeccak256(["address", "address"], [alice.address, campaignAddr]);
    const badSignature = await bob.signMessage(ethers.getBytes(aliceMessageHash));
    
    await expect(campaign.connect(alice).claimWithSignature(badSignature)).to.be.revertedWith("Invalid signature");

    // --- Case 3: Wrong Answer Hash ---
    const correctAnswers = "Q1:A|Q2:A";
    const correctAnswersHash = ethers.keccak256(ethers.toUtf8Bytes(correctAnswers));
    const wrongAnswers = "Q1:B|Q2:B";
    const wrongAnswersHash = ethers.keccak256(ethers.toUtf8Bytes(wrongAnswers));
    
    // Set the correct hash
    await campaign.connect(admin).setAnswersHash(correctAnswersHash);
    
    // Alice tries to claim with the wrong hash
    await expect(campaign.connect(alice).claimWithAnswersHash(wrongAnswersHash)).to.be.revertedWith("Incorrect answers hash");
    
    // Alice claims with the correct hash (should succeed)
    await expect(campaign.connect(alice).claimWithAnswersHash(correctAnswersHash)).to.emit(campaign, "RewardClaimed");
  });
});
