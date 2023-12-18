// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity =0.8.21;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MatchKOLVesting is Ownable {
    using SafeERC20 for IERC20;

    struct VestingInfo {
        uint256 start;
        uint256 cliff;
        uint256 duration;
        uint256 interval;
        uint256 amount;
        uint256 tgeAmount;
        uint256 vestedAmount;
        uint256 vestedPerTime;
    }
    mapping(address kol => VestingInfo vestingInfo) public vestings;

    constructor() Ownable(msg.sender) {}

    function setNewVesting(
        address _kol,
        uint256 _start,
        uint256 _cliff,
        uint256 _duration,
        uint256 _interval,
        uint256 _totalAmount,
        uint256 _tgeAmount
    ) external onlyOwner {}

    function setNewVestings(VestingInfo[] memory _vestings, address[] memory _kols) external onlyOwner {}

    function stopVesting(address _kol) external onlyOwner {}

    function claim() external {}
}
