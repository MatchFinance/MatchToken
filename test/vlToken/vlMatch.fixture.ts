import { ethers } from "hardhat";

import { VLMatch, VLMatchVesting, VLMatchVesting__factory, VLMatch__factory } from "../../types/";

export async function deployVLMatchContracts(): Promise<{
  vlMatch: VLMatch;
  vlMatchVesting: VLMatchVesting;
}> {
  const signers = await ethers.getSigners();
  const admin = signers[0];

  const vlMatch = await new VLMatch__factory(admin).deploy();
  await vlMatch.waitForDeployment();
  await vlMatch.initialize();

  const vlMatchVesting = await new VLMatchVesting__factory(admin).deploy();
  await vlMatchVesting.waitForDeployment();
  await vlMatchVesting.initialize();

  await vlMatchVesting.setVLMatch(vlMatch.target);

  return { vlMatch, vlMatchVesting };
}
