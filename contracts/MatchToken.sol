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

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MatchToken
 *        (Not Upgradeable)
 *
 * @dev   Match token is the governance token of Match Finance.
 *        It can have an owner and some minters.
 *
 *        Owner can: add or remove minters
 *        Minters can: mint tokens
 *        (Current minters: Owner)
 */

contract MatchToken is ERC20, Ownable {
    // ---------------------------------------------------------------------------------------- //
    // ************************************* Constants **************************************** //
    // ---------------------------------------------------------------------------------------- //

    // Total supply cap is 10 million
    // Can not mint more tokens when reaching this cap
    uint256 public constant TOTAL_SUPPLY = 10_000_000 ether;

    // ---------------------------------------------------------------------------------------- //
    // ************************************* Variables **************************************** //
    // ---------------------------------------------------------------------------------------- //

    mapping(address user => bool isMinter) public isMinter;

    // ---------------------------------------------------------------------------------------- //
    // *************************************** Events ***************************************** //
    // ---------------------------------------------------------------------------------------- //

    event MinterAdded(address indexed newMinter);
    event MinterRemoved(address indexed removedMinter);
    event Mint(address indexed to, uint256 amount);

    // ---------------------------------------------------------------------------------------- //
    // *************************************** Errors ***************************************** //
    // ---------------------------------------------------------------------------------------- //

    error NotMinter();
    error OverCap();

    // ---------------------------------------------------------------------------------------- //
    // ************************************* Constructor ************************************** //
    // ---------------------------------------------------------------------------------------- //

    constructor() ERC20("Match Token", "MATCH") Ownable(msg.sender) {
        // ! The owner is set as an initial minter to distribute tokens to IDO contracts
        // ! Should remove this power after these operations
        isMinter[msg.sender] = true;
    }

    // ---------------------------------------------------------------------------------------- //
    // *********************************** View Functions ************************************* //
    // ---------------------------------------------------------------------------------------- //

    function decimals() public pure override returns (uint8) {
        return 18;
    }

    // ---------------------------------------------------------------------------------------- //
    // *********************************** Set Functions ************************************** //
    // ---------------------------------------------------------------------------------------- //

    function addMinter(address _newMinter) external onlyOwner {
        isMinter[_newMinter] = true;

        emit MinterAdded(_newMinter);
    }

    function removeMinter(address _minter) external onlyOwner {
        isMinter[_minter] = false;

        emit MinterRemoved(_minter);
    }

    // ---------------------------------------------------------------------------------------- //
    // *********************************** Main Functions ************************************* //
    // ---------------------------------------------------------------------------------------- //

    function mint(address _to, uint256 _amount) external {
        if (!isMinter[msg.sender]) revert NotMinter();
        if (totalSupply() + _amount > TOTAL_SUPPLY) revert OverCap();

        _mint(_to, _amount);

        emit Mint(_to, _amount);
    }
}
