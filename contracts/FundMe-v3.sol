// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

interface ICampaign {
    function depositFunds() external payable;
    function withdrawFunds() external;
}

contract FundMe is Ownable, ReentrancyGuard, Pausable {

    using Address for address payable;
    using Strings for uint256;

    bytes32 public constant CAMPAIGN_MANAGER_ROLE = keccak256("CAMPAIGN_MANAGER");

    enum CampaignStatus {
        Open,
        Closed,
        Deleted
    }

    string[] public categories = ["Art", "Charity", "Technology"];

    struct Campaign {
        address payable owner;
        string title;
        string description;
        string imageCID;
        uint256 targetAmount;
        uint256 amountRaised;
        uint256 expiresAt;
        CampaignStatus status;
        string category;
    }

    mapping(uint256 => Campaign) public campaigns;

    uint256 public totalCampaigns;

    event CampaignCreated(uint256 indexed id, address indexed owner, string title, string category);

    event CampaignStatusUpdated(uint256 indexed id, CampaignStatus status);

    event CampaignFunded(uint256 indexed id, address indexed funder, uint256 amount);

    event PlatformFeeChanged(uint256 feePercent);

    event FundsWithdrawn(address indexed receiver, uint256 amount);

    /**
     * @dev Create campaign
     */
    function createCampaign(
        string memory title,
        string memory description,
        string memory imageCID,
        uint256 targetAmount,
        uint256 expiresAt,
        string memory category
    )
        external
        onlyOwner
        whenNotPaused
    {
        // Input validation
        require(bytes(title).length > 0, "Invalid title");
        require(bytes(description).length > 0, "Invalid description");
        require(bytes(imageCID).length > 0, "Invalid image");
        require(targetAmount > 0, "Invalid target");
        require(expiresAt > block.timestamp, "Invalid expiry");
        require(isValidCategory(category), "Invalid category");

        Campaign storage campaign = campaigns[totalCampaigns];
        campaign.owner = payable(msg.sender);
        campaign.title = title;
        campaign.description = description;
        campaign.imageCID = imageCID;
        campaign.targetAmount = targetAmount;
        campaign.expiresAt = expiresAt;
        campaign.status = CampaignStatus.Open;
        campaign.category = category;

        totalCampaigns++;

        emit CampaignCreated(totalCampaigns, msg.sender, title, category);
    }

    /**
     * @dev Fund campaign
     */
    function fundCampaign(uint256 id)
        external
        payable
        nonReentrant
        whenNotPaused
    {
        Campaign storage campaign = campaigns[id];

        require(campaign.status == CampaignStatus.Open, "Campaign not open");
        require(msg.value > 0, "Invalid amount");

        campaign.amountRaised += msg.value;

        ICampaign(campaign.owner).depositFunds{value: msg.value}();

        emit CampaignFunded(id, msg.sender, msg.value);
    }

    /**
     * @dev Get filtered campaigns
     */
    function getCampaigns(
        CampaignStatus status,
        string memory category,
        uint256 offset,
        uint256 limit
    )
        external
        view
        returns (Campaign[] memory)
    {
        // Filter campaigns based on status and category
        // Pagination

        return campaigns;
    }

    /**
     * @dev Change platform fee
     */
    function changePlatformFee(uint256 feePercent)
        external
        onlyOwner
    {
        require(feePercent <= 25, "Invalid fee");

        emit PlatformFeeChanged(feePercent);
    }

    /**
     * @dev Withdraw funds to receiver
     */
    function withdrawFunds(address payable receiver)
        external
        onlyOwner
        nonReentrant
    {
        uint256 amount = address(this).balance;
        receiver.sendValue(amount);

        emit FundsWithdrawn(receiver, amount);
    }

    // Other functions

    function isValidCategory(string memory category) public view returns (bool) {
        // check if category is valid
        return false;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

}