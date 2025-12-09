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
