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

    uint256 public totalStaked;
    uint256 public totalReward;
    uint256 public accRewardPerToken;

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
    }
    mapping(address user => UserInfo userInfo) public users;

    // ---------------------------------------------------------------------------------------- //
    // *************************************** Events ***************************************** //
    // ---------------------------------------------------------------------------------------- //

    event Stake(address indexed user, uint256 amount, uint256 reward);
    event Unstake(address indexed user, uint256 amount, uint256 reward);
    event Harvest(address indexed user, uint256 reward);
    event RewardUpdated(uint256 newReward);
    event EmergencyWithdraw(address token, uint256 amount);

    // ---------------------------------------------------------------------------------------- //
    // ************************************ Initializer *************************************** //
    // ---------------------------------------------------------------------------------------- //

    function initialize() public initializer {
        __Ownable_init(msg.sender);
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

    // ---------------------------------------------------------------------------------------- //
    // *********************************** Main Functions ************************************* //
    // ---------------------------------------------------------------------------------------- //

    function stake(uint256 _amount) external {
        require(_amount > 0, "Zero amount");

        updateReward();

        UserInfo storage user = users[msg.sender];

        // If has reward, first claim it
        uint256 pending;
        if (user.amount > 0) {
            pending = (user.amount * accRewardPerToken) / SCALE - user.rewardDebt;
            IVLMatch(mesLBR).safeTransfer(msg.sender, pending);
        }

        IVLMatch(vlMatch).lock(msg.sender, _amount);

        user.amount += _amount;
        totalStaked += _amount;

        user.rewardDebt = (user.amount * accRewardPerToken) / SCALE;

        emit Stake(msg.sender, _amount, pending);
    }

    function unstake(uint256 _amount) external {
        UserInfo storage user = users[msg.sender];
        require(_amount < user.amount, "Insufficient amount to unstake");

        updateReward();

        uint256 pending = (user.amount * accRewardPerToken) / SCALE - user.rewardDebt;
        IVLMatch(mesLBR).safeTransfer(msg.sender, pending);

        user.amount -= _amount;
        totalStaked -= _amount;

        IVLMatch(vlMatch).unlock(msg.sender, _amount);

        user.rewardDebt = (user.amount * accRewardPerToken) / SCALE;

        emit Unstake(msg.sender, _amount, pending);
    }

    function harvest() external {
        updateReward();

        UserInfo storage user = users[msg.sender];

        uint256 pending = (user.amount * accRewardPerToken) / SCALE - user.rewardDebt;
        IVLMatch(mesLBR).safeTransfer(msg.sender, pending);

        user.rewardDebt = (user.amount * accRewardPerToken) / SCALE;

        emit Harvest(msg.sender, pending);
    }

    function updateReward() public {
        if (totalStaked == 0) return;

        uint256 mesLBRReward = IRewardManager(rewardManager).distributeRewardFromDistributor(mesLBR);

        totalReward += mesLBRReward;

        accRewardPerToken += (mesLBRReward * SCALE) / totalStaked;

        emit RewardUpdated(mesLBRReward);
    }

    function emergencyWithdraw(address _token, uint256 _amount) external onlyOwner {
        IVLMatch(_token).safeTransfer(msg.sender, _amount);
        emit EmergencyWithdraw(_token, _amount);
    }
}
