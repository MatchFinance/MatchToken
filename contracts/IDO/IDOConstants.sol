// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity =0.8.21;

abstract contract IDOConstants {
    uint256 public constant SCALE = 1e18;

    uint256 public constant MATCH_CAP_TOTAL = 1500000 ether;

    uint256 public constant ETH_CAP_TOTAL = 375 ether;

    // Maximum 75 ETH will be received by IDO Whitelist Round
    uint256 public constant ETH_CAP_WL = 75 ether;

    uint256 public constant WL_START = 0;
    uint256 public constant WL_END = 0;

    uint256 public constant PUB_START = 0;
    uint256 public constant PUB_END = 0;
}
