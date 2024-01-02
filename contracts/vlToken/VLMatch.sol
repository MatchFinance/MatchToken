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

    // ---------------------------------------------------------------------------------------- //
    // ************************************* Variables **************************************** //
    // ---------------------------------------------------------------------------------------- //

    mapping(address user => bool isMinter) public isMinter;
    mapping(address user => bool isBurner) public isBurner;
    mapping(address user => bool isLocker) public isLocker;

    mapping(address user => uint256 lockedAmount) public userLocked;

    // ---------------------------------------------------------------------------------------- //
    // *************************************** Events ***************************************** //
    // ---------------------------------------------------------------------------------------- //

    event MinterAdded(address minter);
    event MinterRemoved(address minter);
    event BurnerAdded(address burner);
    event BurnerRemoved(address burner);
    event LockerAdded(address user);
    event LockerRemoved(address user);
    event Mint(address user, uint256 amount);
    event Burn(address user, uint256 amount);
    event Lock(address user, uint256 amount);
    event Unlock(address user, uint256 amount);

    function initialize() public initializer {
        __Ownable_init(msg.sender);
        __ERC20_init("Value Locked Match Token", "vlMatch");
    }

    // ---------------------------------------------------------------------------------------- //
    // *********************************** View Functions ************************************* //
    // ---------------------------------------------------------------------------------------- //

    function nonLockedBalance(address _user) external view returns (uint256) {
        return balanceOf(_user) - userLocked[_user];
    }

    // ---------------------------------------------------------------------------------------- //
    // *********************************** Set Functions ************************************** //
    // ---------------------------------------------------------------------------------------- //

    function addMinter(address _user) external onlyOwner {
        isMinter[_user] = true;
        emit MinterAdded(_user);
    }

    function removeMinter(address _user) external onlyOwner {
        isMinter[_user] = false;
        emit MinterRemoved(_user);
    }

    function addBurner(address _user) external onlyOwner {
        isBurner[_user] = true;
        emit BurnerAdded(_user);
    }

    function removeBurner(address _user) external onlyOwner {
        isBurner[_user] = false;
        emit BurnerRemoved(_user);
    }

    function addLocker(address _user) external onlyOwner {
        isLocker[_user] = true;
        emit LockerAdded(_user);
    }

    function removeLocker(address _user) external onlyOwner {
        isLocker[_user] = false;
        emit LockerRemoved(_user);
    }

    // ---------------------------------------------------------------------------------------- //
    // *********************************** Main Functions ************************************* //
    // ---------------------------------------------------------------------------------------- //

    function mint(address _to, uint256 _amount) external {
        require(isMinter[msg.sender], "Not a minter");
        _mint(_to, _amount);

        emit Mint(_to, _amount);
    }

    function burn(address _to, uint256 _amount) external {
        require(isBurner[msg.sender], "Not a burner");
        _burn(_to, _amount);

        emit Burn(_to, _amount);
    }

    function lock(address _user, uint256 _amount) external {
        require(isLocker[msg.sender], "Not a locker");
        require(userLocked[_user] + _amount <= balanceOf(_user), "Not enough balance to lock");
        userLocked[_user] += _amount;

        emit Lock(_user, _amount);
    }

    function unlock(address _user, uint256 _amount) external {
        require(isLocker[msg.sender], "Not a locker");
        require(_amount <= userLocked[_user], "Not enough locked");
        userLocked[_user] -= _amount;

        emit Unlock(_user, _amount);
    }

    // ---------------------------------------------------------------------------------------- //
    // ********************************* Intetnal Functions *********************************** //
    // ---------------------------------------------------------------------------------------- //

    // Transfer is not allowed for vlMatch
    function _update(address from, address to, uint256 value) internal virtual override {
        if (from != address(0) && to != address(0)) revert();
        super._update(from, to, value);
    }
}
