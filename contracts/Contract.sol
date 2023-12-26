// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title CrowdFunding Contract
 * @notice This contract allows to create and manage crowdfunding campaigns.
 */
contract CrowdFunding is AccessControl, ReentrancyGuard, Pausable {
    using Address for address payable;

    // Structure representing a Campaign
    struct Campaign {
        address payable owner;
        string title;
        string description;
        uint256 target;
        uint256 deadline;
        uint256 amountCollected;
        string image;
        mapping(address => uint256) donations;
    }

    // Structure representing CampaignBasicInfo
    struct CampaignData {
        address owner;
        string title;
        string description;
        uint256 target;
        uint256 deadline;
        uint256 amountCollected;
        string image;
    }

    // Define Roles for pausing and unpause
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    mapping(uint256 => Campaign) private campaigns;
    uint256 public numberOfCampaigns = 0;

    // Define Events
    event CampaignCreated(uint256 campaignId, address owner);
    event DonationReceived(uint256 campaignId, address donor, uint256 amount);
    event FundsWithdrawn(uint256 campaignId, uint256 amount);
    event CampaignPaused(uint256 campaignId);
    event CampaignUnpaused(uint256 campaignId);

    // Constructor to define roles
    constructor(address defaultAdmin, address pauser) {
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(PAUSER_ROLE, pauser);
    }

    // Define Modifiers
    modifier onlyOwner(uint256 _campaignId) {
        require(msg.sender == campaigns[_campaignId].owner, "Not the campaign owner");
        _;
    }

    modifier campaignExists(uint256 _campaignId) {
        require(_campaignId < numberOfCampaigns, "Campaign does not exist");
        _;
    }

    /**
    * @notice function to create a campaign.
    * @param _title Title of the campaign
    * @param _description Description of the campaign
    * @param _target Target amount to be raised
    * @param _deadline Deadline to reach the target
    * @param _image Image URL for the campaign
    */
    function createCampaign(string memory _title, string memory _description, uint256 _target, uint256 _deadline, string memory _image) public whenNotPaused onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_deadline > block.timestamp, "The deadline should be a date in the future.");
        require(_target > 0, "Target must be greater than 0");

        Campaign storage campaign = campaigns[numberOfCampaigns];
        campaign.owner = payable(msg.sender);
        campaign.title = _title;
        campaign.description = _description;
        campaign.target = _target;
        campaign.deadline = _deadline;
        campaign.amountCollected = 0;
        campaign.image = _image;

        emit CampaignCreated(numberOfCampaigns, msg.sender);

        numberOfCampaigns++;
    }

    /**
    * @notice function to donate to a campaign.
    * @param _campaignId Campaign ID to donate
    */
    function donateToCampaign(uint256 _campaignId) public payable whenNotPaused campaignExists(_campaignId) nonReentrant {
        Campaign storage campaign = campaigns[_campaignId];
        require(block.timestamp < campaign.deadline, "The campaign is over");
        require(msg.value > 0, "Donation must be greater than 0");

        campaign.donations[msg.sender] += msg.value;
        campaign.amountCollected += msg.value;

        emit DonationReceived(_campaignId, msg.sender, msg.value);

        campaign.owner.sendValue(msg.value);
    }

    /**
    * @notice function to retrieve campaigns.
    * @param startIndex start index for the campaigns retrieve
    * @param endIndex end index for the campaigns retrieve
    */
    function getCampaigns(uint256 startIndex, uint256 endIndex) public view returns (CampaignData[] memory) {
        require(startIndex < endIndex && endIndex <= numberOfCampaigns, "Invalid index range");

        uint256 length = endIndex - startIndex;
        CampaignData[] memory campaignDataArray = new CampaignData[](length);

        for(uint i = startIndex; i < endIndex; i++) {
            Campaign storage campaign = campaigns[i];
            campaignDataArray[i - startIndex] = CampaignData({
                owner: campaign.owner,
                title: campaign.title,
                description: campaign.description,
                target: campaign.target,
                deadline: campaign.deadline,
                amountCollected: campaign.amountCollected,
                image: campaign.image
            });
        }

        return campaignDataArray;
    }

    // Function to unpause the contract
    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
    * @notice function to withdraw funds from a campaign.
    * @param _campaignId Campaign ID to withdraw from
    */
    function withdrawFunds(uint256 _campaignId) public onlyOwner(_campaignId) nonReentrant whenNotPaused {
        Campaign storage campaign = campaigns[_campaignId];
        require(campaign.amountCollected > 0, "No funds to withdraw");

        uint256 amount = campaign.amountCollected;
        campaign.amountCollected = 0;

        emit FundsWithdrawn(_campaignId, amount);

        campaign.owner.sendValue(amount);
    }

    fallback() external payable {
        revert("Direct payments not allowed");
    }

    // receive function to receive Ether
    receive() external payable {
        revert("Direct payments not allowed");
    }
}