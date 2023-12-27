// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract FundMe is Ownable {
    /* Type declarations */
    enum statusEnum {
        OPEN,
        APPROVED,
        EXPIRED,
        DELETED,
        PAIDOUT
    }

    struct statsStruct {
        uint256 totalCampaigns;
        uint256 totalBackings;
        uint256 totalDonations;
    }

    struct backerStruct {
        address owner;
        uint256 contribution;
        uint256 timestamp;
        bool refunded;
    }

    struct campaignStruct {
        uint256 id;
        address owner;
        string title;
        string description;
        string imageURL;
        uint256 cost;
        uint256 raised;
        uint256 timestamp;
        uint256 expiresAt;
        uint256 numOfBackers;
        statusEnum status;
    }

    /* State variables */
    uint256 private s_platformFeePercent;
    statsStruct private s_stats;
    campaignStruct[] private s_campaigns;
    mapping(uint256 => backerStruct[]) private s_backersOfCampaign;

    /* Events */
    event Action(
        uint256 id,
        string actionType,
        address indexed executor,
        uint256 timestamp
    );

    function createCampaign(
        string memory title,
        string memory description,
        string memory imageURL,
        uint256 cost,
        uint256 expiresAt
    ) external {
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

        campaignStruct memory campaign;
        campaign.id = s_campaigns.length;
        campaign.owner = msg.sender;
        campaign.title = title;
        campaign.description = description;
        campaign.imageURL = imageURL;
        campaign.cost = cost;
        campaign.timestamp = block.timestamp;
        campaign.expiresAt = expiresAt;
        campaign.status = statusEnum.OPEN;

        s_campaigns.push(campaign);
        s_stats.totalCampaigns++;

        emit Action(
            campaign.id,
            "Campaign Created",
            msg.sender,
            block.timestamp
        );
    }

    function updateCampaign(
        uint256 id,
        string memory title,
        string memory description,
        string memory imageURL
    ) external {
        require(id <= s_campaigns.length, "FundMe__CampaignDoesNotExist");

        require(
            s_campaigns[id].owner == msg.sender,
            "FundMe__NotCampaignOwner"
        );

        require(
            s_campaigns[id].status == statusEnum.OPEN,
            "FundMe__CampaignNotOpen"
        );

        require(
            s_campaigns[id].expiresAt >= block.timestamp,
            "FundMe__CampaignHasExpired"
        );

        require(bytes(title).length > 7, "FundMe__TitleRequired");

        require(bytes(description).length > 25, "FundMe__DescriptionRequired");

        require(bytes(imageURL).length > 0, "FundMe__ImageURLRequired");

        s_campaigns[id].title = title;
        s_campaigns[id].description = description;
        s_campaigns[id].imageURL = imageURL;

        emit Action(id, "Campaign Updated", msg.sender, block.timestamp);
    }

    function deleteCampaign(uint256 id) external {
        require(id <= s_campaigns.length, "FundMe__CampaignDoesNotExist");
        require(
            s_campaigns[id].owner == msg.sender || msg.sender == owner(),
            "FundMe__NotCampaignOwner"
        );
        require(
            s_campaigns[id].status == statusEnum.OPEN,
            "FundMe__CampaignNotOpen"
        );
        require(
            s_campaigns[id].expiresAt >= block.timestamp,
            "FundMe__CampaignHasExpired"
        );

        s_campaigns[id].status = statusEnum.DELETED;
        s_stats.totalCampaigns--;
        performRefund(id);

        emit Action(id, "Campaign Deleted", msg.sender, block.timestamp);
    }

    function backCampaign(uint256 id) external payable {
        require(id <= s_campaigns.length, "FundMe__CampaignDoesNotExist");
        require(
            s_campaigns[id].status == statusEnum.OPEN ||
                s_campaigns[id].status == statusEnum.APPROVED,
            "FundMe__CampaignHasClosed"
        );

        require(
            s_campaigns[id].expiresAt >= block.timestamp,
            "FundMe__CampaignHasExpired"
        );

        require(msg.value > 0, "FundMe__AmountMustAboveZero");

        s_campaigns[id].raised += msg.value;
        s_campaigns[id].numOfBackers += 1;

        backerStruct memory backer;
        backer.owner = msg.sender;
        backer.contribution = msg.value;
        backer.timestamp = block.timestamp;
        backer.refunded = false;

        s_backersOfCampaign[id].push(backer);

        s_stats.totalBackings++;
        s_stats.totalDonations += msg.value;

        emit Action(id, "Campaign Backed", msg.sender, block.timestamp);

        if (s_campaigns[id].raised >= s_campaigns[id].cost) {
            s_campaigns[id].status = statusEnum.APPROVED;
        }
    }

    function refundExpiredCampaign(uint256 id) external {
        require(id <= s_campaigns.length, "FundMe__CampaignDoesNotExist");
        require(s_campaigns[id].status == statusEnum.OPEN, "FundMe__CampaignNotOpen");
        require(s_campaigns[id].expiresAt <= block.timestamp, "FundMe__CampaignNotExpired");

        s_campaigns[id].status = statusEnum.EXPIRED;
        performRefund(id);

        emit Action(id, "Campaign Expired", msg.sender, block.timestamp);
    }

    function claimRefund(uint256 id, address owner) external {
        require(id <= s_campaigns.length, "FundMe__CampaignDoesNotExist");
        require(s_campaigns[id].expiresAt <= block.timestamp, "FundMe__CampaignNotExpired");
        require(s_campaigns[id].status == statusEnum.OPEN, "FundMe__CampaignNotOpen");

        if (s_campaigns[id].numOfBackers == 0) {
            s_campaigns[id].status = statusEnum.EXPIRED;
            emit Action(id, "Campaign Expired", msg.sender, block.timestamp);
        }

        uint256 totalRefund = 0;
        for (uint256 i = 0; i < s_backersOfCampaign[id].length; i++) {
            if (
                s_backersOfCampaign[id][i].owner == owner &&
                !s_backersOfCampaign[id][i].refunded
            ) {
                s_backersOfCampaign[id][i].refunded = true;
                s_backersOfCampaign[id][i].timestamp = block.timestamp;
                totalRefund += s_backersOfCampaign[id][i].contribution;

                s_stats.totalBackings -= 1;
                s_stats.totalDonations -= s_backersOfCampaign[id][i]
                    .contribution;

                s_campaigns[id].raised -= s_backersOfCampaign[id][i]
                    .contribution;
                s_campaigns[id].numOfBackers -= 1;
            }
        }

        require(totalRefund != 0, "FundMe__NoRefundAvailable");

        payTo(owner, totalRefund);
        emit Action(id, "Backer Claimed Refund", msg.sender, block.timestamp);

        if (s_campaigns[id].numOfBackers == 0) {
            s_campaigns[id].status = statusEnum.EXPIRED;
            emit Action(id, "Campaign Expired", msg.sender, block.timestamp);
        }
    }

    function payoutCampaign(uint256 id) external {
        require(id <= s_campaigns.length, "FundMe__CampaignDoesNotExist");
        require(s_campaigns[id].owner == msg.sender || msg.sender == owner(), "FundMe__NotCampaignOwner");
        require(s_campaigns[id].status == statusEnum.APPROVED, "FundMe__CampaignNotApproved");
        performPayout(id);
    }

    function performRefund(uint256 id) internal {
        for (uint256 i = 0; i < s_backersOfCampaign[id].length; i++) {
            if (!s_backersOfCampaign[id][i].refunded) {
                s_backersOfCampaign[id][i].refunded = true;
                s_backersOfCampaign[id][i].timestamp = block.timestamp;
                payTo(
                    s_backersOfCampaign[id][i].owner,
                    s_backersOfCampaign[id][i].contribution
                );

                s_stats.totalBackings -= 1;
                s_stats.totalDonations -= s_backersOfCampaign[id][i]
                    .contribution;

                s_campaigns[id].raised -= s_backersOfCampaign[id][i]
                    .contribution;
                s_campaigns[id].numOfBackers -= 1;
            }
        }
    }

    function performPayout(uint256 id) internal {
        uint256 platformFee = (s_campaigns[id].raised * s_platformFeePercent) /
            100;
        uint256 payoutAmount = s_campaigns[id].raised - platformFee;

        payTo(s_campaigns[id].owner, payoutAmount);
        payTo(owner(), platformFee);

        s_campaigns[id].status = statusEnum.PAIDOUT;

        emit Action(id, "Campaign Paid Out", msg.sender, block.timestamp);
    }

    function payTo(address recipient, uint256 amount) internal {
        (bool success, ) = payable(recipient).call{value: amount}("");
        require(success, "Transfer Failed");
    }

    function changePlatformFee(uint256 _platformFeePercent) public onlyOwner {
        require(_platformFeePercent > 0 && _platformFeePercent < 100, "Invalid Platform Fee");
        s_platformFeePercent = _platformFeePercent;
}

    function getCampaign(uint256 id) public view returns (campaignStruct memory) {
    require(id <= s_campaigns.length, "FundMe__CampaignDoesNotExist");
    return s_campaigns[id];
}

    function getCampaigns() public view returns (campaignStruct[] memory) {
        return s_campaigns;
    }

    function getBackers(
        uint256 id
    ) public view returns (backerStruct[] memory) {
        require(id <= s_campaigns.length, "Campaign does not exist");
        return s_backersOfCampaign[id];
    }

    function getPlatformFee() public view returns (uint256) {
        return s_platformFeePercent;
    }

    function getStats() public view returns (statsStruct memory) {
        return s_stats;
    }
}


refactor the entire source code to implement the following changes and recommendations:

