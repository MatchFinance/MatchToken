import { ethers } from "hardhat";

import { MatchWhitelistSale } from "../../types";
import { MatchPublicSale } from "../../types";

export async function deployIDOContracts(): Promise<{
  whitelistSale: MatchWhitelistSale;
  publicSale: MatchPublicSale;
}> {
  const signers = await ethers.getSigners();
  const admin = signers[0];

  const whitelistSaleFactory = await ethers.getContractFactory("MatchWhitelistSale");
  const whitelistSale = await whitelistSaleFactory.connect(admin).deploy();
  await whitelistSale.waitForDeployment();
  await whitelistSale.initialize();

  const publicSaleFactory = await ethers.getContractFactory("MatchPublicSale");
  const publicSale = await publicSaleFactory.connect(admin).deploy();
  await publicSale.waitForDeployment();
  await publicSale.initialize();

  // const publicSaleAddress = await publicSale.getAddress();
  // const whitelistSaleAddress = await whitelistSale.getAddress();

  await whitelistSale.setMatchPublicSaleContract(publicSale.target);
  await publicSale.setMatchWhitelistSale(whitelistSale.target);

  return { whitelistSale, publicSale };
}
