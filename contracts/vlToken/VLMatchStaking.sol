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
    }
    mapping(address user => UserInfo userInfo) public users;

    // ---------------------------------------------------------------------------------------- //
    // *************************************** Events ***************************************** //
    // ---------------------------------------------------------------------------------------- //

    event VLMatchVestingSet(address vlMatchVesting);
    event Stake(address indexed user, uint256 amount, uint256 mesLBRReward, uint256 penaltyReward);
    event Unstake(address indexed user, uint256 amount, uint256 mesLBRReward, uint256 penaltyReward);
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

    function pendingReward(address _user) external view returns (uint256) {
        uint256 newPendingReward = IRewardManager(rewardManager).pendingRewardInDistributor(vlMatch);

        UserInfo memory user = users[_user];

        uint256 newAccRewardPerToken = accRewardPerToken + (newPendingReward * SCALE) / totalStaked;

        return (user.amount * newAccRewardPerToken) / SCALE - user.rewardDebt;
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

    // ---------------------------------------------------------------------------------------- //
    // *********************************** Main Functions ************************************* //
    // ---------------------------------------------------------------------------------------- //

    function stake(uint256 _amount) external {
        require(_amount > 0, "Zero amount");

        updateReward();

        UserInfo storage user = users[msg.sender];

        // If has reward, first claim it
        (uint256 pendingMesLBRReward, uint256 pendingPenaltyReward) = _harvestReward(msg.sender);

        IVLMatch(vlMatch).lock(msg.sender, _amount);

        user.amount += _amount;
        totalStaked += _amount;

        _updateUserDebt(msg.sender);

        emit Stake(msg.sender, _amount, pendingMesLBRReward, pendingPenaltyReward);
    }

    function unstake(uint256 _amount) external {
        UserInfo storage user = users[msg.sender];
        require(_amount < user.amount, "Insufficient amount to unstake");

        updateReward();

        // If has reward, first claim it
        (uint256 pendingMesLBRReward, uint256 pendingPenaltyReward) = _harvestReward(msg.sender);

        user.amount -= _amount;
        totalStaked -= _amount;

        IVLMatch(vlMatch).unlock(msg.sender, _amount);

        _updateUserDebt(msg.sender);

        emit Unstake(msg.sender, _amount, pendingMesLBRReward, pendingPenaltyReward);
    }

    function harvest() external {
        updateReward();

        (uint256 pendingMesLBRReward, uint256 pendingPenaltyReward) = _harvestReward(msg.sender);

        _updateUserDebt(msg.sender);

        emit Harvest(msg.sender, pendingMesLBRReward, pendingPenaltyReward);
    }

    function updateReward() public {
        if (totalStaked == 0) return;

        uint256 mesLBRReward = IRewardManager(rewardManager).distributeRewardFromDistributor(mesLBR);

        totalReward += mesLBRReward;

        accRewardPerToken += (mesLBRReward * SCALE) / totalStaked;

        emit RewardUpdated(mesLBRReward);
    }

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

    function _harvestReward(address _user) internal returns (uint256 actualMesLBRReward, uint256 pendingPenaltyReward) {
        UserInfo storage user = users[_user];
        uint256 userAmount = user.amount;

        // If user has no staked amount before, return (0,0)
        if (userAmount > 0) {
            uint256 pendingMesLBRReward = (userAmount * accRewardPerToken) / SCALE - user.rewardDebt;
            actualMesLBRReward = _safeMesLBRTransfer(msg.sender, pendingMesLBRReward);

            // Mint more vlMatch reward to the user
            pendingPenaltyReward = (userAmount * accPenaltyRewardPerToken) / SCALE - user.penaltyRewardDebt;
            IVLMatch(vlMatch).mint(msg.sender, pendingPenaltyReward);
        }
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
