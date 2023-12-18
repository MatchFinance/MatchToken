// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity =0.8.21;

import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IMatchPublicSale } from "../interfaces/IMatchPublicSale.sol";
import { IDOConstants } from "./IDOConstants.sol";

contract MatchWhitelistSale is OwnableUpgradeable, ReentrancyGuardUpgradeable, IDOConstants {
    using SafeERC20 for IERC20;

    uint256 public totalEthersReceived;

    address public matchToken;
    address public matchPublicSale;

    // Merkle root of the whitelist
    bytes32 public merkleRoot;

    // Whether the owner has claimed the ether received
    bool public alreadyClaimedByOwner;

    // Amount of match tokens finally have been allocated to this contract
    // Only after this is true, users can claim their match tokens
    uint256 public matchTokenAllocated;

    struct UserInfo {
        uint256 amount;
        bool claimed;
    }
    mapping(address => UserInfo) public users;

    event WhitelistRoundPurchased(address indexed user, uint256 amount);
    event MatchTokenAllocated(uint256 amount);
    event MatchTokenClaimed(address indexed user, uint256 amount);

    function initialize() public initializer {
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
    }

    function isSoldOut() public view returns (bool) {
        return totalEthersReceived == ETH_CAP_WL;
    }

    // How many match tokens are finally allocated to whitelist round users
    // After public sale is end, this return value is the final amount of match tokens to whitelist sale
    function totalWhitelistAllocation() public view returns (uint256) {
        uint256 totalEthersReceivedByPublic = IMatchPublicSale(matchPublicSale).totalEthersReceived();

        // Total ETH = Min(375ETH, Ethers Received by WL & Public)
        // Total Match = 1500000 (fixed)
        uint256 portionToWhitelist = (totalEthersReceived * SCALE) /
            (totalEthersReceivedByPublic + totalEthersReceived);

        return (MATCH_CAP_TOTAL * portionToWhitelist) / SCALE;
    }

    function userClaimableAmount(address _user) public view returns (uint256) {
        uint256 allocation = totalWhitelistAllocation();

        if (totalEthersReceived == 0) return 0;

        if (users[_user].amount == 0 || users[_user].claimed) {
            return 0;
        }

        return (allocation * users[_user].amount) / totalEthersReceived;
    }

    function currentMatchPrice() public view returns (uint256) {
        uint256 ethersReceivedByPublicSale = IMatchPublicSale(matchPublicSale).totalEthersReceived();

        uint256 totalEthers = totalEthersReceived + ethersReceivedByPublicSale;

        return (totalEthers * SCALE) / MATCH_CAP_TOTAL;
    }

    function setMatchToken(address _matchToken) external onlyOwner {
        matchToken = _matchToken;
    }

    function setMatchPublicSaleContract(address _matchPublicSale) external onlyOwner {
        matchPublicSale = _matchPublicSale;
    }

    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;
    }

    // Owner claim all funds out of the contract
    function claimFund() external onlyOwner {
        require(block.timestamp > PUB_END, "IDO is not finished yet");
        require(!alreadyClaimedByOwner, "Already claimed by owner");

        alreadyClaimedByOwner = true;

        (bool success, ) = msg.sender.call{ value: address(this).balance }("");
        require(success, "Claim failed");
    }

    function purchase(bytes32[] memory _proof) external payable nonReentrant {
        require(_withinPeriod(), "IDO is not started or finished");
        require(msg.value > 0, "No ether sent");
        require(totalEthersReceived + msg.value <= ETH_CAP_WL, "ETH cap exceeded");

        // Verify if the user provides correct proof
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(MerkleProof.verify(_proof, merkleRoot, leaf), "Invalid proof");

        users[msg.sender].amount += msg.value;
        totalEthersReceived += msg.value;

        emit WhitelistRoundPurchased(msg.sender, msg.value);
    }

    // Allocate match tokens to users and then can be claimed
    // Only after the public round is also finished
    function allocateMatchTokens() external onlyOwner {
        require(block.timestamp > PUB_END, "IDO is not finished yet");

        uint256 allocation = totalWhitelistAllocation();
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
        return block.timestamp >= WL_START && block.timestamp <= WL_END;
    }
}
