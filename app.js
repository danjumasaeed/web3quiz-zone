<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Web3Quiz Zone</title>
    <!-- Load Tailwind CSS -->
    <script src="https://cdn.tailwindcss.com"></script>
    <!-- Load Ethers.js -->
    <script src="https://cdn.jsdelivr.net/npm/ethers@6.8.1/dist/ethers.umd.min.js"></script>
    <style>
        /* Custom styles for better aesthetics */
        body {
            font-family: 'Inter', sans-serif;
            background-color: #111827; /* Dark Slate Background */
            color: #E5E7EB;
        }
        .container-main {
            max-width: 1000px;
        }
        .card {
            background-color: #1F2937; /* Slightly Lighter Card Background */
            box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
        }
        .btn-primary {
            @apply px-4 py-2 font-semibold text-white bg-indigo-600 rounded-lg shadow-md hover:bg-indigo-500 transition duration-150 ease-in-out;
        }
        .btn-secondary {
            @apply px-4 py-2 font-semibold text-gray-200 bg-gray-600 rounded-lg shadow-md hover:bg-gray-500 transition duration-150 ease-in-out;
        }
        .input-field {
            @apply w-full p-3 mb-3 text-gray-900 bg-gray-200 border border-gray-500 rounded-lg focus:ring-indigo-500 focus:border-indigo-500;
        }
        .question .option {
            @apply block cursor-pointer p-3 my-2 border border-gray-600 rounded-lg transition duration-150 ease-in-out hover:bg-gray-700;
        }
        .question input[type="radio"]:checked + .option {
            @apply bg-indigo-700 border-indigo-500;
        }
        .question input[type="radio"] {
            display: none;
        }
    </style>
</head>

<body class="p-4 sm:p-8 min-h-screen">
    <div class="container-main mx-auto">
        <!-- Header & Wallet Connect -->
        <header class="flex flex-col sm:flex-row justify-between items-center p-4 mb-8 bg-gray-800 rounded-xl shadow-2xl">
            <h1 class="text-3xl font-bold text-indigo-400 mb-4 sm:mb-0">Web3Quiz Zone 🧠</h1>
            <div class="flex items-center space-x-3">
                <span id="addr" class="text-sm font-medium text-gray-400 truncate">Wallet Not Connected</span>
                <button id="connectBtn" class="btn-primary">
                    Connect Wallet
                </button>
            </div>
        </header>

        <!-- Main Content Area -->
        <main class="grid grid-cols-1 lg:grid-cols-3 gap-8">
            
            <!-- Column 1: Campaign Creation -->
            <section class="lg:col-span-1 card p-6 rounded-xl">
                <h2 class="text-2xl font-semibold mb-4 text-indigo-300">Create New Campaign</h2>
                <form id="createForm">
                    <input type="text" id="title" name="title" placeholder="Quiz Title" required class="input-field">
                    <input type="text" id="metadataURI" name="metadataURI" placeholder="Metadata URI (e.g., sample-questions.json)" required class="input-field">
                    <input type="text" id="token" name="token" placeholder="Prize Token Address (0x0 for ETH)" value="0x0000000000000000000000000000000000000000" required class="input-field">
                    <input type="number" id="passingScore" name="passingScore" placeholder="Passing Score (e.g., 2)" required class="input-field">
                    <input type="number" id="prize" name="prize" step="any" placeholder="Prize Amount per Winner (in ETH/Tokens)" required class="input-field">
                    <button type="submit" class="btn-primary w-full mt-4">Create Campaign</button>
                    <p id="createStatus" class="mt-4 text-sm text-yellow-400"></p>
                </form>
            </section>

            <!-- Column 2 & 3: Campaign List and Detail -->
            <div class="lg:col-span-2 grid grid-cols-1 md:grid-cols-2 gap-8">
                
                <!-- Campaign List -->
                <section class="md:col-span-1 card p-6 rounded-xl">
                    <h2 class="text-2xl font-semibold mb-4 text-indigo-300">Active Campaigns</h2>
                    <div id="campaignList" class="space-y-3">
                        <div class="text-center text-gray-400 py-8">Loading campaigns...</div>
                    </div>
                </section>

                <!-- Campaign Detail (Quiz/Claim Area) -->
                <section id="campaignDetail" class="md:col-span-1 card p-6 rounded-xl" style="display: none;">
                    <h2 id="campTitle" class="text-2xl font-semibold mb-2 text-indigo-300"></h2>
                    <div id="campMeta" class="mb-4 space-y-1 text-gray-400"></div>

                    <h3 class="text-xl font-medium mb-3 border-b border-gray-700 pb-2">Quiz Questions</h3>
                    <div id="questionArea" class="space-y-4">
                        <div class="text-center text-gray-400">Loading quiz data...</div>
                    </div>
                </section>

            </div>

        </main>
    </div>

    <!-- The actual script logic is embedded here -->
    <script>
        // Frontend minimal JS to interact with factory & campaigns
        // Fetches factory address from frontend/config.json written by deploy script.
        
        // Use ethers global variable for convenience
        const ethers = window.ethers; 

        // Helper function for user-friendly message boxes instead of alert()
        function showMessage(message, isError = false) {
            const statusEl = document.getElementById("createStatus"); // Reusing this for general messages
            statusEl.textContent = message;
            statusEl.className = isError ? "mt-4 text-sm text-red-400" : "mt-4 text-sm text-green-400";
        }


        (async () => {
        
            // Load config to get factory address
            let factoryAddress = null;
            try {
                // NOTE: In a real environment, config.json must be present in the deployed static folder
                const cfgResp = await fetch("config.json");
                const cfg = await cfgResp.json();
                factoryAddress = cfg.factoryAddress;
                document.getElementById("createStatus").textContent = `Factory: ${factoryAddress.slice(0, 8)}...`;
            } catch (err) {
                console.warn("Could not load frontend/config.json. Defaulting to placeholder address (will likely fail on testnet).", err);
                document.getElementById("createStatus").textContent = "Warning: Factory address not set via config.json.";
            }

            // Fallback for local development if config.json fails (assuming Hardhat default chain ID)
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
                try {
                    await provider.send("eth_requestAccounts", []);
                    signer = await provider.getSigner();
                    userAddress = await signer.getAddress();
                    document.getElementById("addr").textContent = short(userAddress);
                    document.getElementById("connectBtn").textContent = "Connected";
                    document.getElementById("connectBtn").disabled = true;
                    refreshCampaigns();
                } catch (error) {
                    console.error("Wallet connection failed:", error);
                    showMessage("Wallet connection failed. Check MetaMask/Wallet extension.", true);
                }
            });

            // Create campaign
            document.getElementById("createForm").addEventListener("submit", async (e) => {
                e.preventDefault();
                if (!signer) return showMessage("Connect wallet first", true);
                if (!factoryAddress) return showMessage("Factory address not configured. Deploy first.", true);

                const form = e.target;
                const title = form.title.value;
                const metadataURI = form.metadataURI.value;
                const token = form.token.value;
                const passingScore = parseInt(form.passingScore.value);
                const prizeRaw = form.prize.value;
                
                // For simplicity assume ETH decimals, convert to wei
                let prize;
                try {
                    prize = ethers.parseEther(prizeRaw);
                } catch (err) {
                    return showMessage("Invalid prize amount format.", true);
                }


                const factory = new ethers.Contract(factoryAddress, factoryAbi, signer);
                try {
                    showMessage("Creating campaign... please confirm transaction.");
                    const tx = await factory.createCampaign(userAddress, title, metadataURI, token, passingScore, prize);
                    showMessage("Creating campaign... waiting for transaction to be mined.");
                    await tx.wait();
                    showMessage("Campaign created successfully! Refreshing list...", false);
                    await refreshCampaigns();
                } catch (err) {
                    showMessage("Campaign creation failed. See console for details.", true);
                    console.error("Create campaign transaction failed:", err);
                }
            });

            async function refreshCampaigns() {
                try {
                    if (!factoryAddress) {
                        document.getElementById("campaignList").innerHTML = `<div class="p-4 text-yellow-400">Factory address not configured in config.json. Cannot load campaigns.</div>`;
                        return;
                    }
                    const signerOrProvider = signer || provider;
                    const factory = new ethers.Contract(factoryAddress, factoryAbi, signerOrProvider);
                    const campaigns = await factory.getCampaigns();
                    const listEl = document.getElementById("campaignList");
                    listEl.innerHTML = "";
                    
                    if (campaigns.length === 0) {
                        listEl.innerHTML = `<div class="text-center text-gray-500 py-4">No campaigns found. Create one above!</div>`;
                    }

                    for (let addr of campaigns) {
                        const card = document.createElement("div");
                        card.className = "campaignCard flex justify-between items-center p-3 bg-gray-700 hover:bg-gray-600 rounded-lg transition duration-150 ease-in-out cursor-pointer";
                        
                        const addrEl = document.createElement("span");
                        addrEl.textContent = short(addr);
                        addrEl.className = "font-mono text-sm";
                        card.appendChild(addrEl);
                        
                        const btn = document.createElement("button");
                        btn.textContent = "Open Quiz";
                        btn.className = "btn-secondary text-xs py-1 px-2 bg-indigo-600 hover:bg-indigo-500";
                        btn.onclick = (e) => {
                            e.stopPropagation(); // Prevent card from also firing click if it had one
                            openCampaign(addr);
                        };
                        card.appendChild(btn);
                        listEl.appendChild(card);
                    }
                } catch (err) {
                    console.error(err);
                    document.getElementById("campaignList").innerHTML = `<div class="p-4 text-red-400">Error loading campaigns. Are contracts deployed and network correct?</div>`;
                }
            }

            async function openCampaign(addr) {
                document.getElementById("campaignDetail").style.display = "block";
                document.getElementById("questionArea").innerHTML = `<div class="text-center text-gray-400">Fetching campaign details...</div>`;
                
                try {
                    const signerOrProvider = signer || provider;
                    const campaign = new ethers.Contract(addr, campaignAbi, signerOrProvider);
                    
                    const [metaURI, token, prize, balance] = await Promise.all([
                        campaign.metadataURI(),
                        campaign.token(),
                        campaign.prizePerWinner(),
                        campaign.getBalance()
                    ]);

                    document.getElementById("campTitle").textContent = "Campaign: " + short(addr);
                    document.getElementById("campMeta").innerHTML = `
                        <div class="small text-gray-300">Prize Pool: ${ethers.formatEther(balance)} ${token === ethers.ZeroAddress ? "ETH" : short(token)}</div>
                        <div class="small text-gray-300">Prize per winner: ${ethers.formatEther(prize)} ${token === ethers.ZeroAddress ? "ETH" : short(token)}</div>
                        <div class="small text-gray-500 truncate">Metadata URI: <a href="${metaURI}" target="_blank" class="text-indigo-400 hover:text-indigo-300">${metaURI}</a></div>
                    `;
                    
                    // Fetch questions JSON
                    const resp = await fetch(metaURI);
                    const json = await resp.json();
                    renderQuiz(addr, json);
                } catch (err) {
                    console.error(err);
                    document.getElementById("questionArea").innerHTML = `<div class="small text-red-400">Failed to load campaign data or metadata: ${err.message || 'Check console.'}</div>`;
                }
            }

            function renderQuiz(campaignAddr, meta) {
                const area = document.getElementById("questionArea");
                area.innerHTML = "";
                const form = document.createElement("form");
                form.id = "quizForm";
                
                // Add note about scoring/claim process
                const note = document.createElement("p");
                note.className = "text-sm text-yellow-400 mb-4 p-3 bg-gray-800 rounded-lg";
                note.textContent = "NOTE: This demo requires the correct answers string for claiming. You will be prompted for it after clicking Submit.";
                area.appendChild(note);


                meta.questions.forEach((q, i) => {
                    const qDiv = document.createElement("div");
                    qDiv.className = "question p-3 border border-gray-700 rounded-lg mb-3";
                    
                    const qTitle = document.createElement("p");
                    qTitle.className = "font-semibold mb-2 text-white";
                    qTitle.innerHTML = `Q${i + 1}: ${q.question}`;
                    qDiv.appendChild(qTitle);

                    q.options.forEach((opt, idx) => {
                        const uniqueId = `q${i}_${idx}_${campaignAddr}`;
                        const input = document.createElement("input");
                        input.type = "radio";
                        input.name = `q${i}`;
                        input.value = String.fromCharCode(65 + idx); // A, B, C...
                        input.id = uniqueId;
                        
                        const label = document.createElement("label");
                        label.className = "option block w-full"; // Apply option class here for styling
                        label.setAttribute('for', uniqueId);
                        
                        // Wrap input and text inside the label
                        label.innerHTML = `<span class="mr-2 font-mono text-indigo-300">${String.fromCharCode(65 + idx)}:</span> ${opt}`;
                        
                        // Append the input separately for better styling control (using CSS display: none for input)
                        qDiv.appendChild(input); 
                        qDiv.appendChild(label);
                    });
                    form.appendChild(qDiv);
                });

                const submit = document.createElement("button");
                submit.type = "button";
                submit.textContent = "Submit & Claim Reward";
                submit.className = "btn-primary w-full mt-4";
                
                submit.onclick = async () => {
                    if (!signer) return showMessage("Connect wallet to claim", true);

                    // --- CLAIMING SIMULATION ---
                    const answers = prompt(`Enter the correct answers string (for keccak256 hash). Format: Q1:A|Q2:C|Q3:B. Example: ${meta.answersExampleFormat || 'Q1:A|Q2:B'}`);
                    if (!answers) return;
                    
                    // Compute hash like on-chain would: keccak256(utf8)
                    const hash = ethers.keccak256(ethers.toUtf8Bytes(answers));
                    
                    const mode = prompt("Claim mode: A for on-chain hash, B for admin-signed (recommended).", "B");
                    const signerContract = new ethers.Contract(campaignAddr, campaignAbi, signer);

                    try {
                        let tx;
                        if (mode === "A") {
                            // Option A: claimWithAnswersHash
                            showMessage("Claiming via Answers Hash (Option A)... Please confirm transaction.");
                            tx = await signerContract.claimWithAnswersHash(hash);
                        } else {
                            // Option B: claimWithSignature (requires off-chain admin signing)
                            const signature = prompt("Paste admin signature (off-chain) for your address & campaign. Admin must sign hash(claimer, campaignAddress).");
                            if (!signature) return showMessage("Signature required for Option B.", true);
                            showMessage("Claiming via Admin Signature (Option B)... Please confirm transaction.");
                            tx = await signerContract.claimWithSignature(signature);
                        }

                        showMessage("Transaction sent, waiting for confirmation...");
                        await tx.wait();
                        showMessage("Claim transaction mined successfully! Check your wallet for the reward.", false);
                        
                    } catch (err) {
                        const errorMsg = err?.reason || err?.data?.message || err?.message || 'An unknown error occurred.';
                        showMessage(`Claim failed: ${errorMsg}`, true);
                        console.error("Claim transaction failed:", err);
                    }
                };
                
                form.appendChild(submit);
                area.appendChild(form);
            }

            // Initial attempt to refresh campaigns (factory must be configured)
            await refreshCampaigns();
        })();
    </script>
</body>
</html>

