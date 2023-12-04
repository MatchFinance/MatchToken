// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity =0.8.21;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract MatchToken is ERC20, Ownable {
    mapping(address => bool) public isMinter;
    mapping(address => bool) public isBurner;

    event Mint(address indexed to, uint256 amount);
    event Burn(address indexed from, uint256 amount);

    constructor() ERC20("Match Token", "MATCH") Ownable(msg.sender) {}

    function decimals() public pure override returns (uint8) {
        return 18;
    }

    function addMinter(address _newMinter) external onlyOwner {
        isMinter[_newMinter] = true;
    }

    function removeMinter(address _minter) external onlyOwner {
        isMinter[_minter] = false;
    }

    function addBurner(address _newBurner) external onlyOwner {
        isBurner[_newBurner] = true;
    }

    function removeBurner(address _burner) external onlyOwner {
        isBurner[_burner] = false;
    }

    function mint(address _to, uint256 _amount) external {
        require(isMinter[msg.sender], "Not a minter");
        _mint(_to, _amount);

        emit Mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) external {
        require(isBurner[msg.sender], "Not a burner");
        _burn(_from, _amount);

        emit Burn(_from, _amount);
    }
}
