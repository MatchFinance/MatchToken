import { task } from "hardhat/config";
import MerkleTree from "merkletreejs";

import { readAddressList, readRealWhitelist, readWhitelist } from "../scripts/contractAddress";
import { toWei } from "../test/helpers";
import { MatchWhitelistSale, MatchWhitelistSale__factory } from "../types";

task("setAddresses", "Set addresses in whitelist and public sale").setAction(async (_taskArgs, hre) => {
  const { network, ethers } = hre;
  const addressList = readAddressList();

  const matchWhitelistSale = await ethers.getContractAt(
    "MatchWhitelistSale",
    addressList[network.name].MatchWhitelistSale,
  );

  const tx1 = await matchWhitelistSale.setMatchPublicSaleContract(addressList[network.name].MatchPublicSale);
  console.log(tx1.hash);

  const matchPublicSale = await ethers.getContractAt("MatchPublicSale", addressList[network.name].MatchPublicSale);
  const tx2 = await matchPublicSale.setMatchWhitelistSale(addressList[network.name].MatchWhitelistSale);
  console.log(tx2.hash);

  // await hre.run("setMatchTokenInWhitelistSale");
  // await hre.run("setMatchTokenInPublicSale");

  // const tx3 = await matchPublicSale.setMatchToken(addressList[network.name].MatchToken);
  // console.log(tx3.hash);

  // const tx4 = await matchPublicSale.setMatchWhitelistSale(addressList[network.name].MatchWhitelistSale);
  // console.log(tx4.hash);
});

task("setMatchTokenInWhitelistSale", "Set MatchToken in whitelist sale", async (_taskArgs, hre) => {
  const { network, ethers } = hre;
  const addressList = readAddressList();

  const matchWhitelistSale = await ethers.getContractAt(
    "MatchWhitelistSale",
    addressList[network.name].MatchWhitelistSale,
  );

  const tx1 = await matchWhitelistSale.setMatchToken(addressList[network.name].MatchToken);
  console.log(tx1.hash);
});

task("setMatchTokenInPublicSale", "Set MatchToken in public sale", async (_taskArgs, hre) => {
  const { network, ethers } = hre;
  const addressList = readAddressList();

  const matchPublicSale = await ethers.getContractAt("MatchPublicSale", addressList[network.name].MatchPublicSale);

  const tx = await matchPublicSale.setMatchToken(addressList[network.name].MatchToken);
  console.log(tx.hash);
});

task("mintMatch", "Mint match token").setAction(async (_taskArgs, hre) => {
  const { network, ethers } = hre;
  const addressList = readAddressList();

  const [dev] = await ethers.getSigners();

  const abi = ["function mint(address,uint256) external", "function addMinter(address) external"];

  const matchToken = await ethers.getContractAt("MatchToken", addressList[network.name].MatchToken);

  // const tx1 = await matchToken.addMinter(dev.address);
  // console.log(tx1.hash);

  const total = await matchToken.totalSupply();
  console.log("total", ethers.formatEther(total));

  const tx = await matchToken.transfer("0x7A3F4AC772BbF92FE520810C1F249D1D13dbC614", ethers.parseEther("10000"));
  console.log(tx.hash);
});

task("setMerkleRoot", "Set merkle root in whitelist sale").setAction(async (_taskArgs, hre) => {
  const { network, ethers } = hre;
  const addressList = readAddressList();
  const whitelist = readRealWhitelist();

  const leaves = whitelist.map((account: any) => ethers.keccak256(account));
  const tree = new MerkleTree(leaves, ethers.keccak256, { sort: true });
  const root = tree.getHexRoot();

  const matchWhitelistSale = await ethers.getContractAt(
    "MatchWhitelistSale",
    addressList[network.name].MatchWhitelistSale,
  );

  const tx = await matchWhitelistSale.setMerkleRoot(root);
  console.log("tx hash", tx.hash);
});

task("purchase", "Purchase whitelist").setAction(async (_, hre) => {
  const { network, ethers } = hre;
  const addressList = readAddressList();
  const whitelist = readRealWhitelist();

  const [dev] = await ethers.getSigners();

  console.log("total amount on whitelist:", whitelist.length);
  console.log("whitelist address", whitelist);

  const leaves = whitelist.map((account: any) => ethers.keccak256(account));
  const tree = new MerkleTree(leaves, ethers.keccak256, { sort: true });
  const root = tree.getHexRoot();
  const proof = tree.getHexProof(ethers.keccak256(dev.address));

  const matchWhitelistSale = await ethers.getContractAt(
    "MatchWhitelistSale",
    addressList[network.name].MatchWhitelistSale,
  );

  console.log("proof", proof);

  const tx = await matchWhitelistSale.purchase(proof, { value: ethers.parseEther("0.01") });
  console.log("tx hash", tx.hash);
});
task("get", "Purchase whitelist").setAction(async (_, hre) => {
  const { network, ethers } = hre;
  const addressList = readAddressList();

  const matchWhitelistSale = await ethers.getContractAt(
    "MatchWhitelistSale",
    addressList[network.name].MatchWhitelistSale,
  );

  const wl_start = await matchWhitelistSale.WL_START();
  console.log("wl_start", wl_start.toString());
});

task("initPublic").setAction(async (_, hre) => {
  const { network, ethers } = hre;
  const addressList = readAddressList();

  const matchPublicSale = await ethers.getContractAt("MatchPublicSale", addressList[network.name].MatchPublicSale);

  const tx = await matchPublicSale.initializePublicSale();
  console.log(tx.hash);
});

task("allocate").setAction(async (_, hre) => {
  const { network, ethers } = hre;
  const addressList = readAddressList();

  const [dev] = await ethers.getSigners();

  // const matchToken = await ethers.getContractAt("MatchToken", addressList[network.name].MatchToken);
  // const tx1 = await matchToken.approve(addressList[network.name].MatchWhitelistSale, ethers.parseEther("10000000"));

  const matchPublicSale = await ethers.getContractAt("MatchPublicSale", addressList[network.name].MatchPublicSale);

  const matchWhitelistSale = await ethers.getContractAt(
    "MatchWhitelistSale",
    addressList[network.name].MatchWhitelistSale,
  );

  const all = await matchPublicSale.userClaimableAmount(dev.address);
  console.log("all", ethers.formatEther(all));

  const rel = await matchPublicSale.userCurrentRelease(dev.address);
  console.log("rel", ethers.formatEther(rel));
  // const tx = await matchWhitelistSale.allocateMatchTokens();
  // console.log(tx.hash);

  // const tx1 = await matchPublicSale.setTGETimestamp(1704866400);
  // console.log(tx1.hash);

  // const tx2 = await matchWhitelistSale.setTGETimestamp(1704866400);
  // console.log(tx2.hash);

  const tokenBal1 = await matchPublicSale.matchTokenAllocated();
  console.log("tokenBal1", ethers.formatEther(tokenBal1));

  const tokenBal2 = await matchWhitelistSale.matchTokenAllocated();
  console.log("tokenBal2", ethers.formatEther(tokenBal2));
});

task("mintMockERC20", async (_, hre) => {
  const { network, ethers } = hre;
  const addressList = readAddressList();

  const [dev] = await ethers.getSigners();

  const MockERC20 = await ethers.getContractAt("MockERC20", addressList[network.name].mesLBR);
  const tx = await MockERC20.mint(addressList[network.name].MockRewardManager, ethers.parseEther("10000000000000"));
  console.log(tx.hash);
});

task("addMinter", async (_, hre) => {
  const { network, ethers } = hre;
  const addressList = readAddressList();

  const [dev] = await ethers.getSigners();

  const vlMatch = await ethers.getContractAt("VLMatch", addressList[network.name].VLMatch);
  const matchToken = await ethers.getContractAt("MatchToken", addressList[network.name].MatchToken);
  const tx = await vlMatch.addMinter(addressList[network.name].VLMatchStaking);
  console.log(tx.hash);

  // const user = "0xaaEdbBa4fE83E5FA8579A1bA4158872Cd644488d";

  // const mbal = await matchToken.balanceOf(user);
  // console.log(ethers.formatEther(mbal.toString()));

  // const bal = await vlMatch.balanceOf(user);
  // console.log(ethers.formatEther(bal.toString()));

  // const locked = await vlMatch.userLocked(user);
  // console.log(ethers.formatEther(locked.toString()));

  // const nonLocked = await vlMatch.nonLockedBalance(user);
  // console.log(ethers.formatEther(nonLocked.toString()));

  // const allowance = await matchToken.allowance(user, addressList[network.name].VLMatchVesting);
  // console.log(ethers.formatEther(allowance.toString()));
});

task("setVesting", async (_, hre) => {
  const { network, ethers } = hre;
  const addressList = readAddressList();

  const [dev] = await ethers.getSigners();

  const matchVesting = await ethers.getContractAt("MatchVesting", addressList[network.name].MatchVesting);

  const tx = await matchVesting.setNewVesting(
    "0xaaEdbBa4fE83E5FA8579A1bA4158872Cd644488d",
    1704706200,
    1704706200,
    30 * 3600,
    5 * 3600,
    ethers.parseEther("1000"),
    ethers.parseEther("100"),
  );
  console.log(tx.hash);
});

task("setKK", async (_, hre) => {
  const { network, ethers } = hre;
  const addressList = readAddressList();

  const [dev] = await ethers.getSigners();

  const vlMatchStaking = await ethers.getContractAt("VLMatchStaking", addressList[network.name].VLMatchStaking);
  const vlMatchVesting = await ethers.getContractAt("VLMatchVesting", addressList[network.name].VLMatchVesting);
  const vlMatch = await ethers.getContractAt("VLMatch", addressList[network.name].VLMatch);

  // const tx = await vlMatchVesting.setVLMatchStaking(addressList[network.name].VLMatchStaking);
  // console.log(tx.hash);

  const v1 = await vlMatchVesting.vlMatch();
  console.log(v1);

  const v2 = await vlMatchVesting.matchToken();
  console.log(v2);

  const v3 = await vlMatchStaking.vlMatch();
  console.log(v3);

  const v4 = await vlMatchStaking.vlMatchVesting();
  console.log(v4);

  const isBurner = await vlMatch.isMinter(addressList[network.name].VLMatchVesting);
  console.log(isBurner);
});
