/*
 *  ███╗   ███╗ █████╗ ████████╗ ██████╗██╗  ██╗    ███████╗██╗███╗   ██╗ █████╗ ███╗   ██╗ ██████╗███████╗  *
 *  ████╗ ████║██╔══██╗╚══██╔══╝██╔════╝██║  ██║    ██╔════╝██║████╗  ██║██╔══██╗████╗  ██║██╔════╝██╔════╝  *
 *  ██╔████╔██║███████║   ██║   ██║     ███████║    █████╗  ██║██╔██╗ ██║███████║██╔██╗ ██║██║     █████╗    *
 *  ██║╚██╔╝██║██╔══██║   ██║   ██║     ██╔══██║    ██╔══╝  ██║██║╚██╗██║██╔══██║██║╚██╗██║██║     ██╔══╝    *
 *  ██║ ╚═╝ ██║██║  ██║   ██║   ╚██████╗██║  ██║    ██║     ██║██║ ╚████║██║  ██║██║ ╚████║╚██████╗███████╗  *
 *  ╚═╝     ╚═╝╚═╝  ╚═╝   ╚═╝    ╚═════╝╚═╝  ╚═╝    ╚═╝     ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝╚═╝  ╚═══╝ ╚═════╝╚══════╝  *
 */

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity =0.8.21;

import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IVLMatch } from "../interfaces/IVLMatch.sol";

contract VLMatchVesting is OwnableUpgradeable {
    using SafeERC20 for IERC20;

    // ---------------------------------------------------------------------------------------- //
    // ************************************** Constants *************************************** //
    // ---------------------------------------------------------------------------------------- //

    uint256 public constant SCALE = 1e18;

    uint256 public constant FULL_VESTING_TIME = 180 days;

    // ---------------------------------------------------------------------------------------- //
    // ************************************** Variables *************************************** //
    // ---------------------------------------------------------------------------------------- //

    // Match token and vlMatch token
    address public matchToken;
    address public vlMatch;

    struct UserInfo {
        uint256 stakedMatchAmount;
        uint256 vestedVLMatchAmount;
        uint256 rewardDebt;
    }
    mapping(address user => UserInfo userInfo) public users;

    // Total staked Match
    // It is only used for frontend record, not used in contracts
    uint256 public totalStakedMatch;

    // Total vlMatch that starts vesting
    uint256 public totalVestedVLMatch;

    // This reward is from others' "penalty"
    uint256 public accRewardPerVLMatch;

    // Each time when a user starts a vesting, it will be stored as a seperate one
    // Vesting Id is the only key to find this vesting information
    // Vesting Id = keccak256(abi.encodePacked(userAddress, userIndex))
    struct VestingInfo {
        uint256 startTime;
        uint256 amount;
    }
    mapping(bytes32 vestingId => VestingInfo vestingInfo) public vestings;

    // Total vestings of a user
    // Also the next vesting index of a user
    mapping(address user => uint256 totalVestings) public userVestingCount;

    // ---------------------------------------------------------------------------------------- //
    // *************************************** Events ***************************************** //
    // ---------------------------------------------------------------------------------------- //

    event RewardClaimed(address indexed user, uint256 amount);
    event MatchTokenStaked(address indexed user, uint256 amount);
    event VLMatchStaked(address indexed user, uint256 amount);
    event VestingStarted(address indexed user, uint256 amount);
    event ClaimFromVesting(address indexed user, uint256 index, uint256 vestedAmount, uint256 penaltyAmount);

    // ---------------------------------------------------------------------------------------- //
    // ************************************ Initializer *************************************** //
    // ---------------------------------------------------------------------------------------- //

    function initialize(address _matchToken, address _vlMatchToken) public initializer {
        __Ownable_init(msg.sender);

        matchToken = _matchToken;
        vlMatch = _vlMatchToken;
    }

    // ---------------------------------------------------------------------------------------- //
    // ********************************** View Functions ************************************** //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice Calculate a user's pending reward (from penalty)
     */
    function pendingReward(address _user) public view returns (uint256) {
        uint256 vestedAmount = users[_user].vestedVLMatchAmount;
        return accRewardPerVLMatch * vestedAmount - users[msg.sender].rewardDebt;
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

    // ---------------------------------------------------------------------------------------- //
    // *********************************** Set Functions ************************************** //
    // ---------------------------------------------------------------------------------------- //

    function setMatchToken(address _matchToken) external onlyOwner {
        matchToken = _matchToken;
    }

    function setVLMatch(address _vlMatch) external onlyOwner {
        vlMatch = _vlMatch;
    }

    // ---------------------------------------------------------------------------------------- //
    // ********************************** Main Functions ************************************** //
    // ---------------------------------------------------------------------------------------- //

    // Stake match token and get 1:1 vlMatch
    function stakeMatchToken(uint256 _amount) public {
        require(_amount > 0, "Amount must be greater than 0");
        require(matchToken != address(0) && vlMatch != address(0), "Not set token address");

        // Transfer match token to this contract
        IERC20(matchToken).safeTransferFrom(msg.sender, address(this), _amount);

        users[msg.sender].stakedMatchAmount += _amount;
        totalStakedMatch += _amount;

        // 1:1 mint vlMatch token
        IVLMatch(vlMatch).mint(msg.sender, _amount);

        emit MatchTokenStaked(msg.sender, _amount);
    }

    // Vest vlMatch
    function startVesting(uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than 0");
        require(matchToken != address(0) && vlMatch != address(0), "Not set token address");
        require(IVLMatch(vlMatch).nonLockedBalance(msg.sender) >= _amount, "Not enough non-locked vlMatch");

        IVLMatch(vlMatch).burn(msg.sender, _amount);

        // Get vesting id by hashing user address and current vesting id
        bytes32 vestingId = _getVestingId(msg.sender, userVestingCount[msg.sender]);
        vestings[vestingId] = VestingInfo({ startTime: block.timestamp, amount: _amount });

        userVestingCount[msg.sender]++;

        users[msg.sender].vestedVLMatchAmount -= _amount;
        totalVestedVLMatch += _amount;

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

        // Amount to claim and to be distributed to other vestors
        uint256 availableAmount = ((SCALE - penaltyPortion) * vesting.amount) / SCALE;
        uint256 penaltyAmount = vesting.amount - availableAmount;

        // Transfer available amount to user
        IERC20(matchToken).safeTransfer(msg.sender, availableAmount);

        // Reward penalty to stakers
        // ! First update total vested amount
        totalVestedVLMatch -= vesting.amount;
        accRewardPerVLMatch += penaltyAmount / totalVestedVLMatch;

        // Clear record of this vesting
        vestings[vestingId].amount = 0;

        emit ClaimFromVesting(msg.sender, _index, availableAmount, penaltyAmount);
    }

    /**
     * @notice Claim reward
     *         Reward comes from others' vesting penalty
     */
    function claimReward() public {
        UserInfo storage user = users[msg.sender];

        uint256 pending = pendingReward(msg.sender);

        // Mint more vlMatch to the user as reward
        IVLMatch(vlMatch).mint(msg.sender, pending);
        emit RewardClaimed(msg.sender, pending);

        user.rewardDebt = accRewardPerVLMatch * user.vestedVLMatchAmount;
    }

    function _getVestingId(address _user, uint256 _index) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_user, _index));
    }
}
