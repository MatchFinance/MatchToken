// fixture for Match token test
import { ethers } from "hardhat";

import { MatchToken } from "../types";

export async function deployMatchTokenFixture(): Promise<{
  matchToken: MatchToken;
}> {
  const signers = await ethers.getSigners();
  const admin = signers[0];
  const matchTokenFactory = await ethers.getContractFactory("MatchToken");
  const matchToken = await matchTokenFactory.connect(admin).deploy();
  return { matchToken };
}
