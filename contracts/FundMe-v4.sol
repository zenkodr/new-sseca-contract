//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title CampaignFactory
 * @notice Creates Campaign contracts
 */
contract CampaignFactory is Ownable {

    event CampaignCreated(address indexed campaign);

    function createCampaign() external returns (address) {
        Campaign campaign = new Campaign();
        emit CampaignCreated(address(campaign));
        return address(campaign);
    }

}

/**
 * @title Campaign
 * @notice Crowdfunding campaign
 */
contract Campaign is ReentrancyGuard {

    struct Backer {
        address backer;
        uint256 amount;
        uint256 rewardIndex;
    }

    struct RewardTier {
        string description;
        uint256 minimumAmount;
    }

    address public factory;

    address public vault;

    RewardTier[] public rewardTiers;

    Backer[] public backers;

    uint256 public minimumFunding;

    uint256 public amountRaised;

    constructor() {
        factory = msg.sender;
    }

    /**
     * @notice Fund campaign
     */
    function fund(uint256 rewardIndex) external payable nonReentrant {
        require(msg.value >= rewardTiers[rewardIndex].minimumAmount, "Insufficient amount for reward");

        Backer memory backer = Backer({
            backer: msg.sender,
            amount: msg.value,
            rewardIndex: rewardIndex
        });

        backers.push(backer);
        amountRaised += msg.value;

        IVault(vault).deposit{value: msg.value}();

        emit CampaignFunded(msg.sender, msg.value, rewardIndex);
    }

    /**
     * @notice Withdraw funds to vault
     */
    function withdrawFunds() external nonReentrant {
        require(msg.sender == factory || msg.sender == owner(), "Unauthorized");
        require(amountRaised >= minimumFunding, "Minimum not reached");

        IVault(vault).withdraw(amountRaised);
        amountRaised = 0;

        emit FundsWithdrawn(amountRaised);
    }

    // Other functions

    function getBackers(uint offset, uint limit) external view returns (Backer[] memory) {
        // Return paginated list of backers
    }

    function setVault(address _vault) external {
        require(msg.sender == factory, "Unauthorized");
        vault = _vault;
    }

}

/**
 * @title Vault
 * @notice Manages campaign funds
 */
interface IVault {
    function deposit() external payable;
    function withdraw(uint256 amount) external;
}

/**
 * @title Vault
 * @notice Manages campaign funds
 */
contract Vault is IVault {

    event Deposited(address indexed sender, uint256 amount);

    event Withdrawn(address indexed receiver, uint256 amount);

    receive() external payable {
        emit Deposited(msg.sender, msg.value);
    }

    function deposit() external payable override {
        emit Deposited(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external override {
        payable(msg.sender).transfer(amount);
        emit Withdrawn(msg.sender, amount);
    }

}