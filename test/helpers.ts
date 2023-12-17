import { BigNumberish } from "ethers";
import { ethers } from "hardhat";

export const toWei = (value: number | string): BigNumberish => {
  return ethers.parseEther(value.toString());
};
