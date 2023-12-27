// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity =0.8.21;

interface IRewardManager {
    function distributeRewardFromDistributor(address _rewardToken) external returns (uint256);

    function pendingRewardInDistributor(address _rewardToken) external view returns (uint256);
}
