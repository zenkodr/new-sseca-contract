// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract FundMe is Pausable, Ownable {
    enum Status {
        OPEN,
        APPROVED,
        EXPIRED,
        DELETED,
        PAIDOUT
    }

    struct Stats {
        uint256 totalCampaigns;
        uint256 totalBackings;
        uint256 totalDonations;
    }

    struct Backer {
        address owner;
        uint256 contribution;
        uint256 timestamp;
    }

    struct Campaign {
        uint256 id;
        address owner;
        string title;
        string description;
        string imageURL;
        uint256 targetAmount;
        uint256 amountRaised;
        uint256 timestamp;
        uint256 deadline;
        address[] backers;
        uint256[] donations;
        uint256 numOfBackers;
        Status status;
    }

    /* State variables */
    Stats public stats;
    mapping(uint256 => Campaign) public campaigns;

    mapping(uint256 => Backer[]) public backersOfCampaign;

    uint256 public numberOfCampaigns = 0;

    /* Events */
    event Action(
        uint256 id,
        string actionType,
        address indexed executor,
        uint256 timestamp
    );

    constructor(address initialOwner) Ownable(initialOwner) {}

    function createCampaign(
        address _owner,
        string memory _title,
        string memory _description,
        string memory _imageURL,
        uint256 _targetAmount,
        uint256 _deadline
    ) public returns (uint256) {
        Campaign storage campaign = campaigns[numberOfCampaigns];
        require(
            bytes(_title).length >= 3,
            "The title of atleast 3 characters is required"
        );
        require(
            bytes(_description).length >= 25,
            "The description of atleast 25 characters is required"
        );
        require(bytes(_imageURL).length > 0, "The image URL is required");
        require(
            _targetAmount > 0.1 ether,
            "The target amount must be above 0.1 ether"
        );
        require(
            _deadline > block.timestamp,
            "The deadline must be a future date"
        );

        // Campaign memory campaign;
        campaign.owner = _owner;
        campaign.title = _title;
        campaign.description = _description;
        campaign.targetAmount = _targetAmount;
        campaign.deadline = _deadline;
        campaign.amountRaised = 0;
        campaign.imageURL = _imageURL;

        numberOfCampaigns++;

        emit Action(
            campaign.id,
            "Campaign Created",
            msg.sender,
            block.timestamp
        );

        return numberOfCampaigns - 1;
    }

    function backCampaign(uint256 _id) public payable {
        require(id <= numberOfCampaigns, "Campaign does not exist");
        require(
            campaigns[id].deadline > block.timestamp,
            "The deadline has passed"
        );
        require(msg.value > 0, "The amount must be above 0");
        require(
            campaigns[id].status == Status.OPEN ||
                campaigns[id].status == Status.APPROVED,
            "The campaign is not open"
        );
        require(
            campaigns[id].owner != msg.sender,
            "The campaign owner cannot back their own campaign"
        );

        uint256 amount = msg.value;
        Campaign storage campaign = campaigns[_id];

        campaign.backers.push(msg.sender);
        campaign.donations.push(amount);

        (bool sent, ) = payable(campaign.owner).call{value: amount}("");

        if (sent) {
            campaign.amountCollected = campaign.amountCollected + amount;
        }

        // campaigns[_id].amountRaised += msg.value;
        // campaigns[_id].numOfBackers += 1;

        // Backer memory backer;
        // backer.owner = msg.sender;
        // backer.contribution = msg.value;
        // backer.timestamp = block.timestamp;

        // backersOfCampaign[_id].push(backer);

        // stats.totalBackings++;
        // stats.totalDonations += msg.value;

        emit Action(_id, "Campaign Backed", msg.sender, block.timestamp);
    }

    function getBackers(uint256 _id) public view returns (address[] memory, uint256[] memory) {
        return (campaigns[_id].backers, campaigns[_id].donations);
    }

    function getCampaigns() public view returns (Campaign[] memory) {
        Campaign[] memory allCampaigns = new Campaign[](numberOfCampaigns);

        for (uint i = 0; i < numberOfCampaigns; i++) {
            Campaign storage item = campaigns[i];

            allCampaigns[i] = item;
        }

        return allCampaigns;
    }

    function getStats() public view returns (statsStruct memory) {
        return stats;
    }

    // Pause unPause functions
    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
}
