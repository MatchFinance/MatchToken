// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity =0.8.21;

import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IMatchWhitelistSale } from "../interfaces/IMatchWhitelistSale.sol";
import { IDOConstants } from "./IDOConstants.sol";

contract MatchPublicSale is OwnableUpgradeable, ReentrancyGuardUpgradeable, IDOConstants {
    using SafeERC20 for IERC20;

    uint256 ethTargetAmount;

    uint256 public totalEthersReceived;

    address public matchToken;
    address public matchWhitelistSale;

    // Whether the owner has claimed the ether received
    bool public alreadyClaimedByOwner;

    // Amount of match tokens have been allocated to this contract
    // Only after this is true, users can claim their match tokens
    uint256 public matchTokenAllocated;

    struct UserInfo {
        uint256 amount;
        bool claimed;
    }
    mapping(address => UserInfo) public users;

    event PublicSaleInitialized(uint256 ethTarget);
    event PublicRoundPurchased(address indexed user, uint256 amount);
    event MatchTokenAllocated(uint256 amount);
    event MatchTokenClaimed(address indexed user, uint256 amount);

    function initialize() public initializer {
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
    }

    // After public sale is end, this return value is the final amount of match tokens to public sale
    function totalPublicAllocation() public view returns (uint256) {
        uint256 totalEthersReceivedByWhitelist = IMatchWhitelistSale(matchWhitelistSale).totalEthersReceived();

        // Total ETH = Min(375ETH, Ethers Received by WL & Public)
        // Total Match = 1500000 (fixed)
        uint256 portionToPublic = (totalEthersReceived * SCALE) /
            (totalEthersReceivedByWhitelist + totalEthersReceived);

        return (MATCH_CAP_TOTAL * portionToPublic) / SCALE;
    }

    function userClaimableAmount(address _user) public view returns (uint256) {
        uint256 allocation = totalPublicAllocation();

        // If not received any ether, no claimable amount
        if (totalEthersReceived == 0) return 0;

        // If the user has not purchased or already claimed, no claimable amount
        if (users[_user].amount == 0 || users[_user].claimed) {
            return 0;
        }

        return (allocation * users[_user].amount) / totalEthersReceived;
    }

    function refundAmount(address _user) public view returns (uint256) {
        if (totalEthersReceived <= ethTargetAmount) return 0;
        if (users[_user].claimed) return 0;

        // Only if total ethers received exceeeds the cap, refund will be available
        // e.g. CAP = 300 ETH, totalEthersReceived = 600 ETH
        //      will refund the user half of his contribution
        return users[_user].amount - (ethTargetAmount * users[_user].amount) / totalEthersReceived;
    }

    function totalRefundAmount() public view returns (uint256) {
        return totalEthersReceived > ethTargetAmount ? (totalEthersReceived - ethTargetAmount) : 0;
    }

    // Current match token price is calculated with both wl and public sale status
    // price = (totalEthersReceived * SCALE) / MATCH_CAP_TOTAL
    function currentMatchPrice() public view returns (uint256) {
        uint256 ethersReceivedByWhitelist = IMatchWhitelistSale(matchWhitelistSale).totalEthersReceived();

        uint256 totalEthers = totalEthersReceived > ethTargetAmount
            ? (ethTargetAmount + ethersReceivedByWhitelist)
            : (totalEthersReceived + ethersReceivedByWhitelist);

        return (totalEthers * SCALE) / MATCH_CAP_TOTAL;
    }

    function setMatchToken(address _matchToken) external onlyOwner {
        matchToken = _matchToken;
    }

    function setMatchWhitelistSale(address _matchWhitelistSale) external onlyOwner {
        matchWhitelistSale = _matchWhitelistSale;
    }

    function initializePublicSale() external onlyOwner {
        require(ethTargetAmount == 0, "Already initialized");
        require(block.timestamp > WL_END, "Whitelist sale not ended");

        // 375 ETH - whitelist received ether = public sale target amount
        ethTargetAmount = ETH_CAP_TOTAL - IMatchWhitelistSale(matchWhitelistSale).totalEthersReceived();

        emit PublicSaleInitialized(matchTokenAllocated);
    }

    /**
     * @notice Purchase match tokens by sending ethers
     *
     *
     */
    function purchase() external payable nonReentrant {
        require(_withinPeriod(), "IDO public sale not start/finish");
        require(msg.value > 0, "No ether sent");
        require(ethTargetAmount > 0, "Public sale not initialized");

        // Check if overflow
        require(totalEthersReceived + msg.value <= ethTargetAmount, "ETH cap exceeded");

        // Update user and total record
        users[msg.sender].amount += msg.value;
        totalEthersReceived += msg.value;

        emit PublicRoundPurchased(msg.sender, msg.value);
    }

    // Allocate match tokens to users and then can be claimed
    // Only after the public round is also finished
    function allocateMatchTokens() external onlyOwner {
        require(block.timestamp > PUB_END, "IDO public sale not finished");

        uint256 allocation = totalPublicAllocation();
        IERC20(matchToken).safeTransferFrom(msg.sender, address(this), allocation);

        matchTokenAllocated = allocation;

        emit MatchTokenAllocated(allocation);
    }

    // Claim match tokens
    function claim() external {
        require(matchTokenAllocated > 0, "Match tokens not allocated yet");
        require(users[msg.sender].claimed == false, "Already claimed");

        uint256 amountToClaim = userClaimableAmount(msg.sender);
        require(amountToClaim > 0, "No match token to claim");

        users[msg.sender].claimed = true;

        IERC20(matchToken).safeTransfer(msg.sender, amountToClaim);

        emit MatchTokenClaimed(msg.sender, amountToClaim);
    }

    function _withinPeriod() internal view returns (bool) {
        return block.timestamp >= PUB_START && block.timestamp <= PUB_END;
    }
}
