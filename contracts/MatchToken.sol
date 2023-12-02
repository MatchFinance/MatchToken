// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity =0.8.21;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MatchToken is ERC20, Ownable {
    mapping(address user => uint256 role) public userRoles;

    event Mint(address indexed to, uint256 amount);
    event Burn(address indexed from, uint256 amount);

    constructor() ERC20("Match Token", "MATCH") Ownable(msg.sender) {
        _mint(msg.sender, 100 ether);
    }

    function decimals() public pure override returns (uint8) {
        return 18;
    }

    function addMinter(address _newMinter) external onlyOwner {
        userRoles[_newMinter] = 1;
    }

    function removeMinter(address _minter) external onlyOwner {
        userRoles[_minter] = 0;
    }

    function addBurner(address _newBurner) external onlyOwner {
        userRoles[_newBurner] = 2;
    }

    function removeBurner(address _burner) external onlyOwner {
        userRoles[_burner] = 0;
    }

    function mint(address _to, uint256 _amount) external {
        require(userRoles[msg.sender] == 1, "Not a minter");
        _mint(_to, _amount);

        emit Mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) external {
        require(userRoles[msg.sender] == 2, "Not a burner");
        _burn(_from, _amount);

        emit Burn(_from, _amount);
    }
}
