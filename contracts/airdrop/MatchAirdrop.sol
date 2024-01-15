// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity =0.8.21;

import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { IVLMatch } from "../interfaces/IVLMatch.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract MatchAirdrop is OwnableUpgradeable {
    address public vlMatch;
    address public matchToken;

    bytes32 public merkleRoot;

    event AirdropClaimed(address indexed user, uint256 amount);

    function initialize(address _matchToken, address _vlMatch) public initializer {
        __Ownable_init(msg.sender);

        matchToken = _matchToken;
        vlMatch = _vlMatch;
    }

    function setMatchToken(address _matchToken) external onlyOwner {
        matchToken = _matchToken;
    }

    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;
    }

    function claim(uint256 _amount, bytes32[] memory _proof) external {
        // Verify if the user provides correct proof
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, _amount));
        require(MerkleProof.verify(_proof, merkleRoot, leaf), "Invalid proof");

        IVLMatch(vlMatch).mint(msg.sender, _amount);

        emit AirdropClaimed(msg.sender, _amount);
    }

    function send(address[] memory _users, uint256[] memory _amounts) external onlyOwner {
        require(_users.length == _amounts.length, "Invalid input");

        for (uint256 i; i < _users.length; i++) {
            IVLMatch(matchToken).mint(_users[i], _amounts[i]);
            emit AirdropClaimed(_users[i], _amounts[i]);
        }
    }
}
