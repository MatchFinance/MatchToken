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
    address public treasury;

    struct UserInfo {
        uint256 stakedMatchAmount;
        uint256 stakedVLMatchAmount;
        uint256 rewardDebt;
        uint256 incomeDebt;
        uint256 pendingReward;
        uint256 pendingIncome;
    }
    mapping(address => UserInfo) public users;

    uint256 public totalStakedMatch;
    uint256 public totalStakedVLMatch;

    uint256 public accRewardPerVLMatch;

    address public incomeToken;
    uint256 public totalProtocolIncome;
    uint256 public accProtocolIncomePerVLMatch;

    struct VestingInfo {
        uint256 startTime;
        uint256 amount;
    }
    mapping(bytes32 vestingId => VestingInfo vestingInfo) public vestings;

    // Total vestings of a user
    mapping(address user => uint256 totalVestings) public userVestingCount;

    event RewardClaimed(address indexed user, uint256 amount);
    event MatchTokenStaked(address indexed user, uint256 amount);
    event VLMatchStaked(address indexed user, uint256 amount);
    event VestingStarted(address indexed user, uint256 amount);
    event ClaimFromVesting(address indexed user, uint256 index, uint256 vestedAmount, uint256 penaltyAmount);

    /**
     * @notice Calculate a user's pending reward
     */
    function pendingReward(address _user) public view returns (uint256) {
        uint256 stakedAmount = users[_user].stakedVLMatchAmount;
        return accRewardPerVLMatch * stakedAmount - users[msg.sender].rewardDebt;
    }

    function pendingProtocolIncome(address _user) public view returns (uint256) {
        uint256 stakedAmount = users[_user].stakedVLMatchAmount;
        return accProtocolIncomePerVLMatch * stakedAmount - users[msg.sender].incomeDebt;
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

    /**
     * @notice Stake match token and vlMatch at the same time
     *         Match -> vlMatch(unstaked) -> vlMatch(staked)
     *
     * @param _amount Amount of match token to stake
     */
    function stakeMatchAndVLMatch(uint256 _amount) external {
        stakeMatchToken(_amount);
        stakeVLMatch(_amount);
    }

    // Stake match token and get 1:1 vlMatch
    function stakeMatchToken(uint256 _amount) public {
        require(_amount > 0, "Amount must be greater than 0");

        IERC20(matchToken).safeTransferFrom(msg.sender, address(this), _amount);

        users[msg.sender].stakedMatchAmount += _amount;
        totalStakedMatch += _amount;

        // 1:1 mint vlMatch token
        IVLMatch(vlMatch).mint(msg.sender, _amount);

        emit MatchTokenStaked(msg.sender, _amount);
    }

    function stakeVLMatch(uint256 _amount) public {
        _updateReward(msg.sender);
        _updateProtocolIncome(msg.sender);

        users[msg.sender].stakedVLMatchAmount += _amount;
        totalStakedVLMatch += _amount;

        // Record the current reward debt
        users[msg.sender].rewardDebt = accRewardPerVLMatch * users[msg.sender].stakedVLMatchAmount;
        users[msg.sender].incomeDebt = accProtocolIncomePerVLMatch * users[msg.sender].stakedVLMatchAmount;

        emit VLMatchStaked(msg.sender, _amount);
    }

    // Vest vlMatch
    function startVesting(uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than 0");
        require(users[msg.sender].stakedVLMatchAmount >= _amount, "Not enough staked vlMatch");

        IVLMatch(vlMatch).burn(msg.sender, _amount);

        VestingInfo memory vesting = VestingInfo({ startTime: block.timestamp, amount: _amount });

        // Get vesting id by hashing user address and current vesting id
        bytes32 vestingId = _getVestingId(msg.sender, userVestingCount[msg.sender]);
        vestings[vestingId] = vesting;

        userVestingCount[msg.sender]++;

        users[msg.sender].stakedVLMatchAmount -= _amount;
        totalStakedVLMatch -= _amount;

        emit VestingStarted(msg.sender, _amount);
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

    /**
     * @notice New protocol income comes in from treasury
     */
    function newProtocolIncome(uint256 _amount) external {
        require(msg.sender == treasury, "Not treasury");

        totalProtocolIncome += _amount;

        accProtocolIncomePerVLMatch += _amount / totalStakedVLMatch;
    }

    /**
     * @notice Claim reward
     *         Comes from 1) Others' vesting penalty
     *                    2) Protocol income
     */
    function claimReward() public {
        _updateReward(msg.sender);
        _updateProtocolIncome(msg.sender);

        UserInfo storage user = users[msg.sender];

        // Mint more vlMatch to the user as reward
        IVLMatch(vlMatch).mint(msg.sender, user.pendingReward);
        IERC20(incomeToken).safeTransfer(msg.sender, user.pendingIncome);

        emit RewardClaimed(msg.sender, user.pendingReward);

        // Clear the record
        user.pendingReward = 0;
        user.rewardDebt = accRewardPerVLMatch * user.stakedVLMatchAmount;
    }

    /**
     * @notice Update a user's pending reward
     *         Called when a user stake more vlMatch or claim reward
     *
     *         ! Every time after calling this function, need to update the reward debt manually
     *
     * @param _user User address
     */
    function _updateReward(address _user) internal {
        uint256 pending = pendingReward(_user);

        // Only update pending reward record, the real claim happens in claimReward()
        users[_user].pendingReward += pending;
    }

    function _updateProtocolIncome(address _user) internal {
        uint256 pending = pendingProtocolIncome(_user);

        // Only update pending reward record, the real claim happens in claimReward()
        users[_user].pendingIncome += pending;
    }

    function _getVestingId(address _user, uint256 _index) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_user, _index));
    }
}
