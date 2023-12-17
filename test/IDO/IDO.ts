import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import { loadFixture, time } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { MerkleTree } from "merkletreejs";

import { toWei } from "../helpers";
import { deployMatchTokenFixture } from "../token.fixture";
import { deployIDOContracts } from "./IDO.fixture";

describe("Unit tests for Match Token IDO", function () {
  before(async function () {
    this.signers = {} as SignerWithAddress[];

    const signers = await ethers.getSigners();
    this.signers.admin = signers[0];
    this.signers.user1 = signers[1];
    this.signers.user2 = signers[2];
  });

  describe("Whitelist Sale", function () {
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
      const whitelist = [this.signers.user1.address, this.signers.user2.address];

      const { whitelistSale } = await loadFixture(deployIDOContracts);

      const leaves = whitelist.map((account) => ethers.keccak256(account));
      const tree = new MerkleTree(leaves, ethers.keccak256, { sort: true });
      const root = tree.getHexRoot();
      await whitelistSale.setMerkleRoot(root);

      const proof = tree.getHexProof(ethers.keccak256(this.signers.user1.address));

      await time.setNextBlockTimestamp((await whitelistSale.WL_START()) + 1n);
      await expect(whitelistSale.connect(this.signers.user1).purchase(proof, { value: toWei(1) }))
        .to.emit(whitelistSale, "WhitelistRoundPurchased")
        .withArgs(this.signers.user1.address, toWei(1));

      // #
      // # should have correct record after purchase
      // #
      expect(await whitelistSale.totalEthersReceived()).to.equal(toWei(1));
      expect((await whitelistSale.users(this.signers.user1.address)).amount).to.equal(toWei(1));

      // #
      // # should not allow users to purchase more than whitelist cap
      // #
      await expect(whitelistSale.connect(this.signers.user2).purchase(proof, { value: toWei(75) })).to.be.revertedWith(
        "ETH cap exceeded",
      );

      await expect(whitelistSale.connect(this.signers.user1).purchase(proof, { value: toWei(74) }))
        .to.emit(whitelistSale, "WhitelistRoundPurchased")
        .withArgs(this.signers.user1.address, toWei(74));

      // #
      // # Should not allow users to purchase when ended
      // #
      await time.setNextBlockTimestamp((await whitelistSale.WL_END()) + 1n);
      await expect(whitelistSale.connect(this.signers.user1).purchase(proof, { value: toWei(1) })).to.be.revertedWith(
        "IDO is not started or finished",
      );
    });
  });
});
