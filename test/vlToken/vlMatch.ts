import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import { loadFixture, time } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

import { VLMatchVesting__factory, VLMatch__factory } from "../../types";
import { toWei } from "../helpers";
import { deployMatchTokenFixture } from "../token.fixture";
import { deployVLMatchContracts } from "./vlMatch.fixture";

describe("Unit tests for vlMatch and vesting", function () {
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

  describe("VL Match", function () {
    it("should not allow vlMatch to transfer", async function () {
      const { vlMatch } = await loadFixture(deployVLMatchContracts);

      await vlMatch.mint(user1.address, toWei(100));
      await vlMatch.mint(user2.address, toWei(100));

      await expect(vlMatch.connect(user1).transfer(user2.address, toWei(100))).to.be.reverted;
      await expect(vlMatch.connect(user2).transfer(user1.address, toWei(100))).to.be.reverted;
    });
    it("should allow users to stake Match and get vlMatch", async function () {
      const { vlMatch, vlMatchVesting } = await loadFixture(deployVLMatchContracts);

      const { matchToken } = await loadFixture(deployMatchTokenFixture);

      await vlMatchVesting.setMatchToken(matchToken.target);
      await vlMatch.setRole(vlMatchVesting.target);
      await matchToken.addMinter(admin.address);
      await matchToken.mint(user1.address, toWei(100));
      await matchToken.connect(user1).approve(vlMatchVesting.target, toWei(100));

      expect(await matchToken.balanceOf(user1.address)).to.equal(toWei(100));
      expect(await vlMatchVesting.FULL_VESTING_TIME()).to.equal(86400n * 180n);

      expect(await vlMatchVesting.matchToken()).to.equal(matchToken.target);

      await expect(vlMatchVesting.connect(user1).stakeMatchToken(0)).to.be.reverted;

      await expect(vlMatchVesting.connect(user1).stakeMatchToken(toWei(100)))
        .to.emit(vlMatchVesting, "MatchTokenStaked")
        .withArgs(user1.address, toWei(100));

      expect(await vlMatchVesting.totalStakedMatch()).to.equal(toWei(100));

      expect(await matchToken.balanceOf(user1.address)).to.equal(toWei(0));
      expect(await vlMatch.balanceOf(user1.address)).to.equal(toWei(100));
    });
    it("should allow users to stake vlMatch", async function () {
      const { vlMatch, vlMatchVesting } = await loadFixture(deployVLMatchContracts);

      await vlMatch.setRole(vlMatchVesting.target);
      await vlMatch.mint(user1.address, toWei(100));
      await vlMatch.connect(user1).approve(vlMatchVesting.target, toWei(100));

      await expect(vlMatchVesting.connect(user1).stakeVLMatch(toWei(0))).to.be.reverted;

      await expect(vlMatchVesting.connect(user1).stakeVLMatch(toWei(100)))
        .to.emit(vlMatchVesting, "VLMatchStaked")
        .withArgs(user1.address, toWei(100));

      expect(await vlMatchVesting.totalStakedVLMatch()).to.equal(toWei(100));

      expect(await vlMatch.balanceOf(user1.address)).to.equal(toWei(100));
      expect(await vlMatch.staked(user1.address)).to.equal(toWei(100));
      // expect(await vlMatchVesting.balanceOf(user1.address)).to.equal(toWei(100));
    });
  });
});
