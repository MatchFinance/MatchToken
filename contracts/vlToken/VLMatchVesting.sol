// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity =0.8.21;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IVLMatch } from "../interfaces/IVLMatch.sol";

contract VLMatchVesting {
    using SafeERC20 for IERC20;

    uint256 public constant SCALE = 1e18;

    uint256 public constant FULL_VESTING_TIME = 180 days;

    address public matchToken;
    address public vlMatch;

    struct UserInfo {
        uint256 stakedMatchAmount;
        uint256 stakedVLMatchAmount;
        uint256 rewardDebt;
        uint256 pendingReward;
    }
    mapping(address => UserInfo) public users;

    uint256 public totalStakedMatch;
    uint256 public totalStakedVLMatch;

    uint256 public accRewardPerVLMatch;

    struct VestingInfo {
        uint256 startTime;
        uint256 amount;
    }
    mapping(bytes32 => VestingInfo) public vestings;

    // Total vestings of a user
    mapping(address => uint256) public totalVested;

    event RewardClaimed(address indexed user, uint256 amount);
    event MatchTokenStaked(address indexed user, uint256 amount);
    event VLMatchStaked(address indexed user, uint256 amount);
    event ClaimFromVesting(address indexed user, uint256 index, uint256 vestedAmount, uint256 penaltyAmount);

    /**
     * @notice Calculate a user's pending reward
     */
    function pendingReward(address _user) public view returns (uint256) {
        uint256 stakedAmount = users[_user].stakedVLMatchAmount;
        return accRewardPerVLMatch * stakedAmount - users[msg.sender].rewardDebt;
    }

    /**
     * @notice Update a user's pending reward
     *         Called when a user stake more vlMatch or claim reward
     *
     *         Every time after calling this function, need to update the reward debt
     *
     * @param _user User address
     */
    function updateReward(address _user) public {
        uint256 pending = pendingReward(_user);

        UserInfo storage user = users[_user];

        // Only update pending reward record, the real claim happens in claimReward()
        user.pendingReward += pending;
    }

    function claimReward() public {
        updateReward(msg.sender);

        UserInfo storage user = users[msg.sender];

        // Mint more vlMatch to the user as reward
        IVLMatch(vlMatch).mint(msg.sender, user.pendingReward);

        emit RewardClaimed(msg.sender, user.pendingReward);

        // Clear the record
        user.pendingReward = 0;
        user.rewardDebt = accRewardPerVLMatch * user.stakedVLMatchAmount;
    }

    function stakeMatchAndVLMatch(uint256 _amount) external {
        stakeMatchToken(_amount);
        stakeVLMatch(_amount);
    }

    // Stake match token and get 1:1 vlMatch
    function stakeMatchToken(uint256 _amount) public {
        require(_amount > 0, "Amount must be greater than 0");

        IERC20(matchToken).safeTransferFrom(msg.sender, address(this), _amount);

        users[msg.sender].stakedMatchAmount += _amount;

        // 1:1 mint vlMatch token
        IVLMatch(vlMatch).mint(msg.sender, _amount);

        emit MatchTokenStaked(msg.sender, _amount);
    }

    function stakeVLMatch(uint256 _amount) public {
        updateReward(msg.sender);

        users[msg.sender].stakedVLMatchAmount += _amount;
        totalStakedVLMatch += _amount;

        // Record the current reward debt
        users[msg.sender].rewardDebt = accRewardPerVLMatch * users[msg.sender].stakedVLMatchAmount;

        emit VLMatchStaked(msg.sender, _amount);
    }

    /**
     * @notice Calculate penalty portion (with SCALE)
     *         Day 0: start with 99% penalty
     *         Day 180: full vesting, no penalty
     *
     * @param _startTime  Vesting start time
     * @param _targetTime Target time to calculate
     */
    function getPenaltyPortion(uint256 _startTime, uint256 _targetTime) public pure returns (uint256) {
        // day 0: penalty 99
        // day 180: penalty 0

        uint256 timePassed = _targetTime - _startTime;

        // if vesting is finished, no penalty
        if (timePassed >= FULL_VESTING_TIME) {
            return 0;
        }

        return 99 * (SCALE - (timePassed * SCALE) / FULL_VESTING_TIME);
    }

    // Vest vlMatch
    function startVesting(uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than 0");
        require(users[msg.sender].stakedVLMatchAmount >= _amount, "Not enough staked vlMatch");

        IVLMatch(vlMatch).burn(msg.sender, _amount);

        VestingInfo memory vesting = VestingInfo({ startTime: block.timestamp, amount: _amount });

        // Get vesting id by hashing user address and current vesting id
        bytes32 vestingId = _getVestingId(msg.sender, totalVested[msg.sender]);
        vestings[vestingId] = vesting;

        totalVested[msg.sender]++;

        users[msg.sender].stakedVLMatchAmount -= _amount;
        totalStakedVLMatch -= _amount;
    }

    /**
     * @notice Claim back Match token from an existing vesting
     *
     * @param _index Vesting index
     */
    function claimFromVesting(uint256 _index) external {
        bytes32 vestingId = _getVestingId(msg.sender, _index);

        VestingInfo memory vesting = vestings[vestingId];
        require(vesting.amount > 0, "Vesting not found");

        uint256 penaltyPortion = getPenaltyPortion(vesting.startTime, block.timestamp);

        uint256 availableAmount = ((SCALE - penaltyPortion) * vesting.amount) / SCALE;
        uint256 penaltyAmount = vesting.amount - availableAmount;

        // Transfer available amount to user
        IERC20(matchToken).safeTransfer(msg.sender, availableAmount);

        // Reward penalty to stakers
        accRewardPerVLMatch += penaltyAmount / totalStakedVLMatch;

        // Clear record of this vesting
        vestings[vestingId].amount = 0;

        emit ClaimFromVesting(msg.sender, _index, availableAmount, penaltyAmount);
    }

    function _getVestingId(address _user, uint256 _index) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_user, _index));
    }
}
