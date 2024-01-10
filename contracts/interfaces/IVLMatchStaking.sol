// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity =0.8.21;

interface IVLMatchStaking {
    function updatePenaltyReward(uint256 newReward) external;

    function delegateStake(uint256 amount, address user) external;

    function delegateUnstake(uint256 amount, address user) external;
}
