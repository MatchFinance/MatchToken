// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity =0.8.21;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IVLMatch is IERC20 {
    function mint(address to, uint256 amount) external;

    function burn(address from, uint256 amount) external;

    function lock(address user, uint256 amount) external;

    function unlock(address user, uint256 amount) external;

    function nonLockedBalance(address user) external view returns(uint256);
}
