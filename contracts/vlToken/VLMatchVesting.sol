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
import { IVLMatchStaking } from "../interfaces/IVLMatchStaking.sol";

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

    // VLMatch staking contract to receive penalty reward
    address public vlMatchStaking;

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

    function getVestingId(address _user, uint256 _index) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_user, _index));
    }

    /**
     * @notice Calculate penalty portion (with SCALE)
     *         Day 0: start with 100% penalty (10^18)
     *         Day 90: half penalty (5 * 10^17)
     *         Day 180: full vesting, no penalty (0)
     *
     * @param _startTime  Vesting start time
     * @param _targetTime Target time to calculate
     */
    function getPenaltyPortion(uint256 _startTime, uint256 _targetTime) public pure returns (uint256) {
        // day 0: penalty 100
        // day 180: penalty 0

        uint256 timePassed = _targetTime - _startTime;

        // if vesting is finished, no penalty
        if (timePassed >= FULL_VESTING_TIME) {
            return 0;
        }

        return SCALE - (timePassed * SCALE) / FULL_VESTING_TIME;
    }

    function getPenaltyAmount(
        address _user,
        uint256 _index
    ) public view returns (uint256 availableAmount, uint256 penaltyAmount) {
        bytes32 vestingId = getVestingId(_user, _index);

        uint256 totalAmount = vestings[vestingId].amount;
        uint256 vestingStartTime = vestings[vestingId].startTime;

        uint256 penaltyPortion = getPenaltyPortion(vestingStartTime, block.timestamp);

        // Amount to claim and to be distributed to other vestors
        availableAmount = ((SCALE - penaltyPortion) * totalAmount) / SCALE;
        penaltyAmount = totalAmount - availableAmount;
    }

    function getUserVestings(address _user) external view returns (VestingInfo[] memory userVestings) {
        uint256 totalVestings = userVestingCount[_user];

        for (uint256 i; i < totalVestings; ) {
            bytes32 vestingId = getVestingId(_user, i);
            userVestings[i] = vestings[vestingId];

            unchecked {
                ++i;
            }
        }
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

    function setVLMatchStaking(address _vlMatchStaking) external onlyOwner {
        vlMatchStaking = _vlMatchStaking;
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

    function stakeMatchAndVLMatch(uint256 _amount) external {
        stakeMatchToken(_amount);
        IVLMatchStaking(vlMatchStaking).delegateStake(_amount, msg.sender);
    }

    function unstakeAndStartVesting(uint256 _amount) external {
        IVLMatchStaking(vlMatchStaking).delegateUnstake(_amount, msg.sender);
        startVesting(_amount);
    }

    // Vest vlMatch
    function startVesting(uint256 _amount) public {
        require(_amount > 0, "Amount must be greater than 0");
        require(matchToken != address(0) && vlMatch != address(0), "Not set token address");
        require(IVLMatch(vlMatch).nonLockedBalance(msg.sender) >= _amount, "Not enough non-locked vlMatch");

        IVLMatch(vlMatch).burn(msg.sender, _amount);

        // Get vesting id by hashing user address and current vesting id
        bytes32 vestingId = getVestingId(msg.sender, userVestingCount[msg.sender]);
        vestings[vestingId] = VestingInfo({ startTime: block.timestamp, amount: _amount });

        userVestingCount[msg.sender]++;

        users[msg.sender].vestedVLMatchAmount += _amount;
        totalVestedVLMatch += _amount;

        emit VestingStarted(msg.sender, _amount);
    }

    /**
     * @notice Claim back Match token from an existing vesting
     *
     * @param _index Vesting index
     */
    function claimFromVesting(uint256 _index) external {
        bytes32 vestingId = getVestingId(msg.sender, _index);

        VestingInfo memory vesting = vestings[vestingId];
        require(vesting.amount > 0, "Vesting not found");

        uint256 penaltyPortion = getPenaltyPortion(vesting.startTime, block.timestamp);

        // Amount to claim and to be distributed to other vestors
        uint256 availableAmount = ((SCALE - penaltyPortion) * vesting.amount) / SCALE;
        uint256 penaltyAmount = vesting.amount - availableAmount;

        IVLMatchStaking(vlMatchStaking).updatePenaltyReward(penaltyAmount);

        // Transfer available amount to user
        IERC20(matchToken).safeTransfer(msg.sender, availableAmount);

        // Reward penalty to stakers
        // ! First update total vested amount
        totalVestedVLMatch -= vesting.amount;

        // Clear record of this vesting
        vestings[vestingId].amount = 0;

        emit ClaimFromVesting(msg.sender, _index, availableAmount, penaltyAmount);
    }
}
