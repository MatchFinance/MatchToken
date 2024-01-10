// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity =0.8.21;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockRewardManager {
    function pendingRewardInDistributor(address _rewardToken, address _receiver) external view returns (uint256) {
        return 100 ether;
    }

    function distributeRewardFromDistributor(address _rewardToken) external returns (uint256) {
        IERC20(_rewardToken).transfer(msg.sender, 100 ether);
        return 100 ether;
    }
}
