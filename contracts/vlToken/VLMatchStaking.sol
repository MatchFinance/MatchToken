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

import { IVLMatch } from "../interfaces/IVLMatch.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IRewardManager } from "../interfaces/IRewardManager.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract VLMatchStaking is OwnableUpgradeable {
    using SafeERC20 for IVLMatch;

    // ---------------------------------------------------------------------------------------- //
    // ************************************* Constants **************************************** //
    // ---------------------------------------------------------------------------------------- //

    uint256 public constant SCALE = 1e18;

    // ---------------------------------------------------------------------------------------- //
    // ************************************** Variables *************************************** //
    // ---------------------------------------------------------------------------------------- //

    // Token to stake, and reward token to claim
    address public vlMatch;
    address public mesLBR;

    // Reward manager contract to manage the distribution logic
    address public rewardManager;

    address public vlMatchVesting;

    uint256 public totalStaked;
    uint256 public totalReward;
    uint256 public accRewardPerToken;
    uint256 public accPenaltyRewardPerToken;

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 penaltyRewardDebt;
        uint256 pendingReward;
        uint256 pendingPenaltyReward;
    }
    mapping(address user => UserInfo userInfo) public users;

    bool public claimAvailable;

    // ---------------------------------------------------------------------------------------- //
    // *************************************** Events ***************************************** //
    // ---------------------------------------------------------------------------------------- //

    event VLMatchVestingSet(address vlMatchVesting);
    event Stake(address indexed user, uint256 amount);
    event Unstake(address indexed user, uint256 amount);
    event Harvest(address indexed user, uint256 mesLBRReward, uint256 penaltyReward);
    event RewardUpdated(uint256 newReward);
    event PenaltyRewardUpdated(uint256 newReward);
    event EmergencyWithdraw(address token, uint256 amount);

    // ---------------------------------------------------------------------------------------- //
    // ************************************ Initializer *************************************** //
    // ---------------------------------------------------------------------------------------- //

    function initialize(address _vlMatch, address _mesLBR, address _rewardManager) public initializer {
        __Ownable_init(msg.sender);

        vlMatch = _vlMatch;
        mesLBR = _mesLBR;

        rewardManager = _rewardManager;
    }

    // ---------------------------------------------------------------------------------------- //
    // *********************************** View Functions ************************************* //
    // ---------------------------------------------------------------------------------------- //

    function pendingReward(
        address _user
    ) external view returns (uint256 pendingMesLBRReward, uint256 pendingPenaltyReward) {
        // New pending mesLBR reward
        uint256 newPendingReward = IRewardManager(rewardManager).pendingRewardInDistributor(vlMatch, address(this));
        uint256 newAccRewardPerToken = accRewardPerToken + (newPendingReward * SCALE) / totalStaked;

        UserInfo memory user = users[_user];

        // New reward and those pending reward which has not been claimed
        pendingMesLBRReward = (user.amount * newAccRewardPerToken) / SCALE - user.rewardDebt + user.pendingReward;
        pendingPenaltyReward =
            (user.amount * accPenaltyRewardPerToken) /
            SCALE -
            user.penaltyRewardDebt +
            user.pendingPenaltyReward;
    }

    function getUserStakedAmount(address _user) external view returns (uint256) {
        return users[_user].amount;
    }

    // ---------------------------------------------------------------------------------------- //
    // *********************************** Set Functions ************************************** //
    // ---------------------------------------------------------------------------------------- //

    function setVLMatchVesting(address _vlMatchVesting) external onlyOwner {
        vlMatchVesting = _vlMatchVesting;
        emit VLMatchVestingSet(_vlMatchVesting);
    }

    function openClaim() external onlyOwner {
        claimAvailable = true;
    }

    // ---------------------------------------------------------------------------------------- //
    // *********************************** Main Functions ************************************* //
    // ---------------------------------------------------------------------------------------- //

    function stake(uint256 _amount) external {
        _stake(_amount, msg.sender);
    }

    // Delegate stake comes from vlMatch vesting contract
    // Users will do "stake Match" & "stake vlMatch" in one transaction
    function delegateStake(uint256 _amount, address _user) external {
        require(msg.sender == vlMatchVesting, "Only vesting can call");
        _stake(_amount, _user);
    }

    function unstake(uint256 _amount) external {
        _unstake(_amount, msg.sender);
    }

    // Delegate unstake comes from vlMatch vesting contract
    // Users will do "unstake" & "vest" in one transaction
    function delegateUnstake(uint256 _amount, address _user) external {
        require(msg.sender == vlMatchVesting, "Only vesting can call");
        _unstake(_amount, _user);
    }

    function harvest() external {
        updateReward();

        _recordUserReward(msg.sender);
        _updateUserDebt(msg.sender);

        (uint256 actualMesLBRReward, uint256 actualPenaltyReward) = _claimUserReward(msg.sender);

        emit Harvest(msg.sender, actualMesLBRReward, actualPenaltyReward);
    }

    function updateReward() public {
        if (totalStaked == 0) return;

        uint256 mesLBRReward = IRewardManager(rewardManager).distributeRewardFromDistributor(mesLBR);

        totalReward += mesLBRReward;

        accRewardPerToken += (mesLBRReward * SCALE) / totalStaked;

        emit RewardUpdated(mesLBRReward);
    }

    // Every time when a user claims his vesting in vlMatch vesting contract with a penalty
    // The penalty reward will be recorded here
    // "Immediately distributed" to all vlMatch stakers (in the form of vlMatch)
    function updatePenaltyReward(uint256 _newReward) external {
        require(msg.sender == vlMatchVesting, "Only vesting can call");

        accPenaltyRewardPerToken += (_newReward * SCALE) / totalStaked;

        emit PenaltyRewardUpdated(_newReward);
    }

    function emergencyWithdraw(address _token, uint256 _amount) external onlyOwner {
        IVLMatch(_token).safeTransfer(msg.sender, _amount);
        emit EmergencyWithdraw(_token, _amount);
    }

    // ---------------------------------------------------------------------------------------- //
    // ********************************* Internal Functions *********************************** //
    // ---------------------------------------------------------------------------------------- //

    function _stake(uint256 _amount, address _user) internal {
        require(_amount > 0, "Zero amount");

        updateReward();

        UserInfo storage user = users[_user];

        // If has reward, first claim it
        _recordUserReward(_user);

        IVLMatch(vlMatch).lock(_user, _amount);

        user.amount += _amount;
        totalStaked += _amount;

        _updateUserDebt(_user);

        emit Stake(_user, _amount);
    }

    function _unstake(uint256 _amount, address _user) internal {
        UserInfo storage user = users[_user];
        require(_amount <= user.amount, "Insufficient amount to unstake");

        updateReward();

        // If has reward, first claim it
        _recordUserReward(_user);

        user.amount -= _amount;
        totalStaked -= _amount;

        IVLMatch(vlMatch).unlock(_user, _amount);

        _updateUserDebt(_user);

        emit Unstake(_user, _amount);
    }

    function _recordUserReward(address _user) internal {
        UserInfo storage user = users[_user];
        uint256 userAmount = user.amount;

        // If user has no staked amount before, return (0,0)
        if (userAmount > 0) {
            uint256 pendingMesLBRReward = (userAmount * accRewardPerToken) / SCALE - user.rewardDebt;
            user.pendingReward += pendingMesLBRReward;

            // Mint more vlMatch reward to the user
            uint256 pendingPenaltyReward = (userAmount * accPenaltyRewardPerToken) / SCALE - user.penaltyRewardDebt;
            user.pendingPenaltyReward += pendingPenaltyReward;
        }
    }

    function _claimUserReward(
        address _user
    ) internal returns (uint256 actualMesLBRReward, uint256 actualPenaltyReward) {
        require(claimAvailable, "Claim not available");
        UserInfo storage user = users[_user];

        // Claim reward
        actualMesLBRReward = _safeMesLBRTransfer(_user, user.pendingReward);

        actualPenaltyReward = user.pendingPenaltyReward;
        IVLMatch(vlMatch).mint(_user, actualPenaltyReward);

        // Clear pending reward record
        user.pendingReward -= actualMesLBRReward;
        user.pendingPenaltyReward = 0;
    }

    function _updateUserDebt(address _user) internal {
        UserInfo storage user = users[_user];
        uint256 userAmount = user.amount;

        user.rewardDebt = (userAmount * accRewardPerToken) / SCALE;
        user.penaltyRewardDebt = (userAmount * accPenaltyRewardPerToken) / SCALE;
    }

    function _safeMesLBRTransfer(address _to, uint256 _amount) internal returns (uint256 actualAmount) {
        uint256 balance = IVLMatch(mesLBR).balanceOf(address(this));

        if (_amount > balance) {
            IVLMatch(mesLBR).safeTransfer(_to, balance);
            actualAmount = balance;
        } else {
            IVLMatch(mesLBR).safeTransfer(_to, _amount);
            actualAmount = _amount;
        }
    }
}
