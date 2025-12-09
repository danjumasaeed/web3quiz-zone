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
