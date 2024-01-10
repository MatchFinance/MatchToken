// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity =0.8.21;

import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { IVLMatch } from "../interfaces/IVLMatch.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract MatchAirdrop is OwnableUpgradeable {
    address public vlMatch;

    bytes32 public merkleRoot;

    event AirdropClaimed(address indexed user, uint256 amount);

    function initialize(address _vlMatch) public initializer {
        __Ownable_init(msg.sender);
        vlMatch = _vlMatch;
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
}
