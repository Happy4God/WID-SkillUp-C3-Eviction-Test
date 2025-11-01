// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title StudyTokenStaking
 * @dev Staking contract for Web3 Uni students to stake STUDY tokens and earn rewards
 */
contract StudyTokenStaking is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    // Staking token (STUDY)
    IERC20 public immutable stakingToken;
    
    // Staking period in seconds (e.g., 30 days)
    uint256 public stakingPeriod;
    
    // Annual reward rate (in basis points, e.g., 1000 = 10%)
    uint256 public rewardRate;
    
    // Total staked tokens
    uint256 public totalStaked;

    // Stake information
    struct Stake {
        uint256 amount;
        uint256 startTime;
        uint256 rewardDebt;
        bool exists;
    }

    // User stakes mapping
    mapping(address => Stake) public stakes;

    // Events
    event Staked(address indexed user, uint256 amount, uint256 startTime);
    event Unstaked(address indexed user, uint256 amount, uint256 reward);
    event RewardRateUpdated(uint256 newRate);
    event StakingPeriodUpdated(uint256 newPeriod);
    event EmergencyWithdraw(address indexed user, uint256 amount);

    /**
     * @dev Constructor
     * @param _stakingToken Address of the STUDY token
     * @param _stakingPeriod Minimum staking period in seconds
     * @param _rewardRate Annual reward rate in basis points (e.g., 1000 = 10%)
     */
    constructor(
        address _stakingToken,
        uint256 _stakingPeriod,
        uint256 _rewardRate
    ) Ownable(msg.sender) {
        require(_stakingToken != address(0), "Invalid token address");
        require(_stakingPeriod > 0, "Staking period must be positive");
        require(_rewardRate > 0 && _rewardRate <= 10000, "Invalid reward rate");
        
        stakingToken = IERC20(_stakingToken);
        stakingPeriod = _stakingPeriod;
        rewardRate = _rewardRate;
    }

    /**
     * @dev Stake tokens
     * @param amount Amount of tokens to stake
     */
    function stake(uint256 amount) external nonReentrant {
        require(amount > 0, "Cannot stake 0 tokens");
        require(!stakes[msg.sender].exists, "Already staking");

        // Transfer tokens from user to contract
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);

        // Create stake record
        stakes[msg.sender] = Stake({
            amount: amount,
            startTime: block.timestamp,
            rewardDebt: 0,
            exists: true
        });

        totalStaked += amount;

        emit Staked(msg.sender, amount, block.timestamp);
    }

    /**
     * @dev Unstake tokens and claim rewards
     */
    function unstake() external nonReentrant {
        Stake storage userStake = stakes[msg.sender];
        require(userStake.exists, "No active stake");
        
        uint256 stakedAmount = userStake.amount;
        uint256 reward = calculateReward(msg.sender);

        // Check if staking period has passed
        require(
            block.timestamp >= userStake.startTime + stakingPeriod,
            "Staking period not completed"
        );

        // Delete stake record
        delete stakes[msg.sender];
        totalStaked -= stakedAmount;

        // Transfer staked tokens back to user
        stakingToken.safeTransfer(msg.sender, stakedAmount);

        // Transfer rewards if available
        if (reward > 0) {
            uint256 contractBalance = stakingToken.balanceOf(address(this));
            uint256 availableReward = contractBalance >= totalStaked + reward 
                ? reward 
                : contractBalance > totalStaked 
                    ? contractBalance - totalStaked 
                    : 0;
            
            if (availableReward > 0) {
                stakingToken.safeTransfer(msg.sender, availableReward);
            }
        }

        emit Unstaked(msg.sender, stakedAmount, reward);
    }

    /**
     * @dev Emergency withdraw without rewards (only in case of issues)
     */
    function emergencyWithdraw() external nonReentrant {
        Stake storage userStake = stakes[msg.sender];
        require(userStake.exists, "No active stake");
        
        uint256 stakedAmount = userStake.amount;

        // Delete stake record
        delete stakes[msg.sender];
        totalStaked -= stakedAmount;

        // Transfer staked tokens back to user (no rewards)
        stakingToken.safeTransfer(msg.sender, stakedAmount);

        emit EmergencyWithdraw(msg.sender, stakedAmount);
    }

    /**
     * @dev Calculate reward for a user
     * @param user Address of the user
     * @return Calculated reward amount
     */
    function calculateReward(address user) public view returns (uint256) {
        Stake memory userStake = stakes[user];
        if (!userStake.exists) {
            return 0;
        }

        uint256 stakingDuration = block.timestamp - userStake.startTime;
        
        // Reward calculation: (amount * rate * duration) / (10000 * 365 days)
        // This gives a proportional reward based on annual rate
        uint256 reward = (userStake.amount * rewardRate * stakingDuration) / (10000 * 365 days);
        
        return reward;
    }

    /**
     * @dev Get stake information for a user
     * @param user Address of the user
     * @return amount Staked amount
     * @return startTime Stake start timestamp
     * @return reward Current calculated reward
     * @return canUnstake Whether the user can unstake
     */
    function getStakeInfo(address user) 
        external 
        view 
        returns (
            uint256 amount,
            uint256 startTime,
            uint256 reward,
            bool canUnstake
        ) 
    {
        Stake memory userStake = stakes[user];
        amount = userStake.amount;
        startTime = userStake.startTime;
        reward = calculateReward(user);
        canUnstake = userStake.exists && (block.timestamp >= userStake.startTime + stakingPeriod);
    }

    /**
     * @dev Update reward rate (only owner)
     * @param newRate New reward rate in basis points
     */
    function updateRewardRate(uint256 newRate) external onlyOwner {
        require(newRate > 0 && newRate <= 10000, "Invalid reward rate");
        rewardRate = newRate;
        emit RewardRateUpdated(newRate);
    }

    /**
     * @dev Update staking period (only owner)
     * @param newPeriod New staking period in seconds
     */
    function updateStakingPeriod(uint256 newPeriod) external onlyOwner {
        require(newPeriod > 0, "Staking period must be positive");
        stakingPeriod = newPeriod;
        emit StakingPeriodUpdated(newPeriod);
    }

    /**
     * @dev Fund the contract with reward tokens (only owner)
     * @param amount Amount of tokens to add as rewards
     */
    function fundRewards(uint256 amount) external onlyOwner {
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
    }

    /**
     * @dev Withdraw excess tokens (only owner)
     * @param amount Amount to withdraw
     */
    function withdrawExcess(uint256 amount) external onlyOwner {
        uint256 contractBalance = stakingToken.balanceOf(address(this));
        require(contractBalance >= totalStaked + amount, "Insufficient excess balance");
        stakingToken.safeTransfer(msg.sender, amount);
    }
}