// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/IERC20.sol";

/**
 * @title RewardDistributor
 * @notice Distributes liquidity mining rewards to protocol vault depositors.
 * @dev INTENTIONAL VULNERABILITIES:
 *      1. HIGH: notifyRewardAmount() lacks access control, permitting anyone to alter reward distribution rates.
 *      2. MEDIUM: raw transfer() return value unchecked; non-standard tokens (like USDT) that do not return a boolean revert or fail silently.
 */
contract RewardDistributor {
    address public immutable owner;
    IERC20 public immutable rewardToken;

    uint256 public rewardRate;
    uint256 public lastUpdateTime;
    uint256 public periodFinish;
    uint256 public rewardPerTokenStored;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    event RewardPaid(address indexed user, uint256 reward);
    event RewardAdded(uint256 reward);

    constructor(address _rewardToken) {
        owner = msg.sender;
        rewardToken = IERC20(_rewardToken);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "NOT_OWNER");
        _;
    }

    /**
     * @notice Notify contract of new reward tokens to distribute
     * @dev REMEDIATION: Access control enforced via onlyOwner modifier.
     */
    function notifyRewardAmount(uint256 reward, uint256 duration) external onlyOwner {
        require(duration > 0, "INVALID_DURATION");

        if (block.timestamp >= periodFinish) {
            rewardRate = reward / duration;
        } else {
            uint256 remaining = periodFinish - block.timestamp;
            uint256 leftover = remaining * rewardRate;
            rewardRate = (reward + leftover) / duration;
        }

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + duration;

        emit RewardAdded(reward);
    }

    /**
     * @notice Claim accrued rewards for caller
     * @dev REMEDIATION: Verified ERC20 transfer return value to prevent silent failure.
     */
    function claimReward(address recipient, uint256 amount) external {
        require(amount > 0, "ZERO_REWARD");
        rewards[recipient] -= amount;

        bool success = rewardToken.transfer(recipient, amount);
        require(success, "TRANSFER_FAILED");

        emit RewardPaid(recipient, amount);
    }
}
