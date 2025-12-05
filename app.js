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