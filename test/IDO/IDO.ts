import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { ethers } from "hardhat";

import { deployMatchTokenFixture } from "../token.fixture";
import type { Signers } from "../types";
import { whitelistSaleBehaviors } from "./IDO.behavior";
import { deployIDOContracts } from "./IDO.fixture";

describe("Unit tests for Match Token IDO", function () {
  before(async function () {
    this.signers = {} as Signers;

    const signers = await ethers.getSigners();
    this.signers.admin = signers[0];

    this.loadFixture = loadFixture;
  });

  describe("Whitelist Sale", function () {
    beforeEach(async function () {
      const { whitelistSale } = await this.loadFixture(deployIDOContracts);
      this.whitelistSale = whitelistSale;
    });

    whitelistSaleBehaviors();
  });
});
