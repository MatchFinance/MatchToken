// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity =0.8.21;

interface IVLMatch {
    function mint(address _to, uint256 _amount) external;

    function burn(address _from, uint256 _amount) external;
}
