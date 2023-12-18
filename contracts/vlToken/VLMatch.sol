// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity =0.8.21;

import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @notice Value-locked Match Token
 *
 * @dev Can mint/burn, but can not transfer
 */
contract VLMatch is OwnableUpgradeable, ERC20Upgradeable {
    using SafeERC20 for IERC20;

    // 0: No mint/burn power
    // 1: Mint & burn power
    mapping(address => uint256) public roles;

    mapping(address => uint256) public staked;

    function initialize() public initializer {
        __Ownable_init(msg.sender);
        __ERC20_init("Value Locked Match Token", "vlMatch");

        // Give the owner the mint/burn power
        roles[msg.sender] = 1;
    }

    function nonLockedBalance(address _user) external view returns (uint256) {
        return balanceOf(_user) - staked[_user];
    }

    function setRole(address _user) external onlyOwner {
        roles[_user] = 1;
    }

    function mint(address _to, uint256 _amount) external {
        require(roles[msg.sender] == 1, "Not a minter");
        _mint(_to, _amount);
    }

    function burn(address _to, uint256 _amount) external {
        require(roles[msg.sender] == 1, "Not a burner");
        _burn(_to, _amount);
    }

    function lock(address _user, uint256 _amount) external {
        require(roles[msg.sender] == 1, "Not a locker");
        require(staked[_user] + _amount <= balanceOf(_user), "Not enough balance to lock");
        staked[_user] += _amount;
    }

    function unlock(address _user, uint256 _amount) external {
        require(roles[msg.sender] == 1, "Not an unlocker");
        staked[_user] -= _amount;
    }

    // Transfer is not allowed for vlMatch
    function _update(address from, address to, uint256 value) internal virtual override {
        if (from != address(0) && to != address(0)) revert();
        super._update(from, to, value);
    }
}
