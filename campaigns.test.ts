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