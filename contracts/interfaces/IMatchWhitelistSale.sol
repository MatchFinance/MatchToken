// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity =0.8.21;

interface IMatchWhitelistSale {
    function totalEthersReceived() external view returns (uint256);

    function claimFromPublicSale(address user) external;
}
