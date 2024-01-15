// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity =0.8.21;

interface IRewardDistributorFactory {
    function distribute(address rewardToken) external returns (uint256);
    function pendingReward(address rewardToken, address receiver) external view returns(uint256);
}
