import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import { loadFixture, time } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { MerkleTree } from "merkletreejs";

import { toWei } from "../helpers";
import { deployMatchTokenFixture } from "../token.fixture";
import { deployIDOContracts } from "./IDO.fixture";

describe("Unit tests for Match Token IDO", function () {
  let admin: SignerWithAddress;
  let user1: SignerWithAddress;
  let user2: SignerWithAddress;
  let user3: SignerWithAddress;
  let user4: SignerWithAddress;

  before(async function () {
    const signers = await ethers.getSigners();
    admin = signers[0];
    user1 = signers[1];
    user2 = signers[2];
    user3 = signers[3];
    user4 = signers[4];
  });

  describe("Whitelist & Public Sale", function () {
    it("should have the correct constants for whitelist sale", async function () {
      const { whitelistSale } = await loadFixture(deployIDOContracts);

      expect(await whitelistSale.MATCH_CAP_TOTAL()).to.equal(toWei(1500000));
      expect(await whitelistSale.ETH_CAP_TOTAL()).to.equal(toWei(375));
    });

    it("should have correct duration for whitelist sale", async function () {
      const { whitelistSale } = await loadFixture(deployIDOContracts);

      const startTime = await whitelistSale.WL_START();
      const endTime = await whitelistSale.WL_END();
      expect(endTime).to.equal(startTime + 43200n);
    });

    it("should allow users to purchase when on whitelist", async function () {
      const whitelist = [user1.address, user2.address];

      const { whitelistSale } = await loadFixture(deployIDOContracts);

      const leaves = whitelist.map((account) => ethers.keccak256(account));
      const tree = new MerkleTree(leaves, ethers.keccak256, { sort: true });
      const root = tree.getHexRoot();
      await whitelistSale.setMerkleRoot(root);

      const proof = tree.getHexProof(ethers.keccak256(user1.address));

      await time.setNextBlockTimestamp((await whitelistSale.WL_START()) + 1n);
      await expect(whitelistSale.connect(user1).purchase(proof, { value: toWei(1) }))
        .to.emit(whitelistSale, "WhitelistRoundPurchased")
        .withArgs(user1.address, toWei(1));

      // #
      // # should have correct record after purchase
      // #
      expect(await whitelistSale.totalEthersReceived()).to.equal(toWei(1));
      expect((await whitelistSale.users(user1.address)).amount).to.equal(toWei(1));

      // #
      // # should not allow users to purchase more than whitelist cap
      // #
      await expect(whitelistSale.connect(user2).purchase(proof, { value: toWei(75) })).to.be.revertedWith(
        "ETH cap exceeded",
      );

      await expect(whitelistSale.connect(user1).purchase(proof, { value: toWei(74) }))
        .to.emit(whitelistSale, "WhitelistRoundPurchased")
        .withArgs(user1.address, toWei(74));

      // #
      // # Should not allow users to purchase when ended
      // #
      await time.setNextBlockTimestamp((await whitelistSale.WL_END()) + 1n);
      await expect(whitelistSale.connect(user1).purchase(proof, { value: toWei(1) })).to.be.revertedWith(
        "IDO is not started or finished",
      );

      expect(await whitelistSale.totalWhitelistAllocation()).to.equal(toWei(1500000));
    });

    it("should allow users to participate in public sale", async function () {
      const { whitelistSale, publicSale } = await loadFixture(deployIDOContracts);

      // #
      // # Whitelist sale preparation
      // # Whitelist sale get 1 ETH, publcic sale should have 374 ether cap
      // #
      const whitelist = [user1.address, user2.address];
      const leaves = whitelist.map((account) => ethers.keccak256(account));
      const tree = new MerkleTree(leaves, ethers.keccak256, { sort: true });
      const root = tree.getHexRoot();
      await whitelistSale.setMerkleRoot(root);
      const proof = tree.getHexProof(ethers.keccak256(user1.address));

      await time.setNextBlockTimestamp((await whitelistSale.WL_START()) + 1n);
      await whitelistSale.connect(user1).purchase(proof, { value: toWei(15) });

      await time.setNextBlockTimestamp((await publicSale.PUB_START()) + 1n);
      await publicSale.initializePublicSale();

      // # Check initial status of public sale
      expect(await publicSale.ethTargetAmount()).to.equal(toWei(360));

      await expect(publicSale.connect(user1).purchase({ value: toWei(1) }))
        .to.emit(publicSale, "PublicRoundPurchased")
        .withArgs(user1.address, toWei(1));

      expect(await publicSale.totalEthersReceived()).to.equal(toWei(1));
      expect((await publicSale.users(user1.address)).amount).to.equal(toWei(1));

      // # Can not buy 374 eth, because 1 + 1 + 374 = 376 > 375, exceed public sale cap
      await expect(publicSale.connect(user2).purchase({ value: toWei(360) })).to.be.revertedWith("ETH cap exceeded");

      // # Can buy 373 eth, 1 + 1 + 373 = 375 <= 375, not exceed public sale cap
      await expect(publicSale.connect(user1).purchase({ value: toWei(359) }))
        .to.emit(publicSale, "PublicRoundPurchased")
        .withArgs(user1.address, toWei(359));

      expect(await publicSale.currentMatchPrice()).to.equal(toWei(0.00025));

      // # whitelist sale 15 eth, public sale 360 eth
      // # allocation should be: 60000 + 1440000 = 1500000 Match Token
      expect(await publicSale.totalPublicAllocation()).to.equal(toWei(1440000));
      expect(await whitelistSale.totalWhitelistAllocation()).to.equal(toWei(60000));
    });

    it("should be able to allocate tokens and claim tokens", async function () {
      const { whitelistSale, publicSale } = await loadFixture(deployIDOContracts);
      const { matchToken } = await loadFixture(deployMatchTokenFixture);

      const whitelist = [user1.address, user2.address];
      const leaves = whitelist.map((account) => ethers.keccak256(account));
      const tree = new MerkleTree(leaves, ethers.keccak256, { sort: true });
      const root = tree.getHexRoot();
      await whitelistSale.setMerkleRoot(root);
      const proof = tree.getHexProof(ethers.keccak256(user1.address));

      await time.setNextBlockTimestamp((await whitelistSale.WL_START()) + 1n);
      await whitelistSale.connect(user1).purchase(proof, { value: toWei(75) });

      await time.setNextBlockTimestamp((await publicSale.PUB_START()) + 1n);
      await publicSale.initializePublicSale();

      await publicSale.connect(user2).purchase({ value: toWei(300) });

      // # whitelist 75 eth by user1
      // # public sale 300 eth by user2

      await time.setNextBlockTimestamp((await publicSale.PUB_END()) + 1n);

      await whitelistSale.setMatchToken(matchToken.target);
      await publicSale.setMatchToken(matchToken.target);

      await matchToken.addMinter(admin.address);
      await matchToken.mint(admin.address, toWei(1500000));

      await matchToken.approve(whitelistSale.target, toWei(1500000));

      await expect(whitelistSale.allocateMatchTokens())
        .to.emit(whitelistSale, "MatchTokenAllocated")
        .withArgs(toWei(300000));

      await matchToken.approve(publicSale.target, toWei(1500000));

      await expect(publicSale.allocateMatchTokens())
        .to.emit(publicSale, "MatchTokenAllocated")
        .withArgs(toWei(1200000));

      expect(await whitelistSale.connect(user1).claim())
        .to.emit(whitelistSale, "MatchTokenClaimed")
        .withArgs(user1.address, toWei(300000));

      expect(await publicSale.connect(user2).claim())
        .to.emit(publicSale, "MatchTokenClaimed")
        .withArgs(user2.address, toWei(1200000));
    });
  });
});
