import { task } from "hardhat/config";
import MerkleTree from "merkletreejs";
import nestCsv from "neat-csv";

import {
  readAddressList,
  readRealWhitelist,
  readSendAirdropList,
  readTeamVestingList,
  readVestingList,
  readWhitelist,
} from "../scripts/contractAddress";
import { toWei } from "../test/helpers";
import { MatchWhitelistSale, MatchWhitelistSale__factory } from "../types";

const TGE = 1705327200;

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

  const matchToken = await ethers.getContractAt("MatchToken", addressList[network.name].MatchToken);

  // const tx1 = await matchToken.addMinter(dev.address);
  // console.log(tx1.hash);

  const total = await matchToken.totalSupply();
  console.log("total", ethers.formatEther(total));

  const tx = await matchToken.mint(dev.address, ethers.parseEther("200"));
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

task("initPublic").setAction(async (_, hre) => {
  const { network, ethers } = hre;
  const addressList = readAddressList();

  const matchPublicSale = await ethers.getContractAt("MatchPublicSale", addressList[network.name].MatchPublicSale);

  const tx = await matchPublicSale.initializePublicSale();
  console.log(tx.hash);
});

task("getUserIDORelease", async (_, hre) => {
  const { network, ethers } = hre;
  const addressList = readAddressList();

  const [dev] = await ethers.getSigners();

  const matchPublicSale = await ethers.getContractAt("MatchPublicSale", addressList[network.name].MatchPublicSale);
  const matchWhitelistSale = await ethers.getContractAt(
    "MatchWhitelistSale",
    addressList[network.name].MatchWhitelistSale,
  );

  const userAddress = "0xaaEdbBa4fE83E5FA8579A1bA4158872Cd644488d";

  const all1 = await matchPublicSale.userClaimableAmount(userAddress);
  console.log("User claimable amount in public sale:", ethers.formatEther(all1));

  const rel1 = await matchPublicSale.userCurrentRelease(userAddress);
  console.log("User current release in public sale:", ethers.formatEther(rel1));

  const kk1 = await matchPublicSale.userClaimedAmount(userAddress);
  console.log("User claimed amount in public sale:", ethers.formatEther(kk1));

  const all2 = await matchWhitelistSale.userClaimableAmount(userAddress);
  console.log("User claimable amount in whitelist sale:", ethers.formatEther(all2));

  const rel2 = await matchWhitelistSale.userCurrentRelease(userAddress);
  console.log("User current release in whitelist sale:", ethers.formatEther(rel2));
});

task("getIDOContractInfo", async (_, hre) => {
  const { network, ethers } = hre;
  const addressList = readAddressList();

  const [dev] = await ethers.getSigners();

  const matchPublicSale = await ethers.getContractAt("MatchPublicSale", addressList[network.name].MatchPublicSale);
  const matchWhitelistSale = await ethers.getContractAt(
    "MatchWhitelistSale",
    addressList[network.name].MatchWhitelistSale,
  );

  const tokenBal1 = await matchPublicSale.matchTokenAllocated();
  console.log("Match allocated in match public sale:", ethers.formatEther(tokenBal1));

  const tokenBal2 = await matchWhitelistSale.matchTokenAllocated();
  console.log("Match allocated in match whitelist sale", ethers.formatEther(tokenBal2));
});

task("setTGETimestamp", async (_, hre) => {
  const { network, ethers } = hre;
  const addressList = readAddressList();

  const [dev] = await ethers.getSigners();

  const matchPublicSale = await ethers.getContractAt("MatchPublicSale", addressList[network.name].MatchPublicSale);
  const matchWhitelistSale = await ethers.getContractAt(
    "MatchWhitelistSale",
    addressList[network.name].MatchWhitelistSale,
  );

  const tx1 = await matchPublicSale.setTGETimestamp(TGE);
  console.log(tx1.hash);

  const tx2 = await matchWhitelistSale.setTGETimestamp(TGE);
  console.log(tx2.hash);
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

  const tx = await matchWhitelistSale.allocateMatchTokens();
  console.log(tx.hash);

  // const tx = await matchPublicSale.allocateMatchTokens();
  // console.log(tx.hash);
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

  const tx = await matchToken.addMinter(addressList[network.name].MatchAirdrop);
  console.log(tx.hash);

  // const isMinter1 = await matchToken.isMinter(addressList[network.name].MatchAirdrop);
  // console.log(isMinter1);

  // const isMinter2 = await vlMatch.isLocker(addressList[network.name].VLMatchStaking);
  // console.log(isMinter2);

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

task("setVestingInStaking", async (_, hre) => {
  const { network, ethers } = hre;
  const addressList = readAddressList();

  const [dev] = await ethers.getSigners();

  const vlMatchStaking = await ethers.getContractAt("VLMatchStaking", addressList[network.name].VLMatchStaking);
  const vlMatchVesting = await ethers.getContractAt("VLMatchVesting", addressList[network.name].VLMatchVesting);

  // const tx = await vlMatchStaking.setVLMatchVesting(addressList[network.name].VLMatchVesting);
  // console.log(tx.hash);

  // const tx = await vlMatchVesting.setVLMatchStaking(addressList[network.name].VLMatchStaking);
  // console.log(tx.hash);

  const tx = await vlMatchVesting.setMatchToken(addressList[network.name].MatchToken);
  console.log(tx.hash);
});
task("setFactory", async (_, hre) => {
  const { network, ethers } = hre;
  const addressList = readAddressList();

  const [dev] = await ethers.getSigners();

  const vlMatchStaking = await ethers.getContractAt("VLMatchStaking", addressList[network.name].VLMatchStaking);
  const vlMatchVesting = await ethers.getContractAt("VLMatchVesting", addressList[network.name].VLMatchVesting);

  const tx = await vlMatchStaking.setRewardDistributorFactory(addressList[network.name].RewardDistributorFactory);
  console.log(tx.hash);
});

task("setTGETimestamp", async (_, hre) => {
  const { network, ethers } = hre;
  const addressList = readAddressList();

  const [dev] = await ethers.getSigners();

  const matchPublicSale = await ethers.getContractAt("MatchPublicSale", addressList[network.name].MatchPublicSale);
  const matchWhitelistSale = await ethers.getContractAt(
    "MatchWhitelistSale",
    addressList[network.name].MatchWhitelistSale,
  );

  const tge = await matchPublicSale.tgeTimestamp();
  console.log(tge.toString());

  const tge2 = await matchWhitelistSale.tgeTimestamp();
  console.log(tge2.toString());

  // const tx = await matchPublicSale.setTGETimestamp(TGE);
  // console.log(tx.hash);

  const allo1 = await matchPublicSale.totalPublicAllocation();
  console.log(ethers.formatEther(allo1.toString()));

  const allo2 = await matchWhitelistSale.totalWhitelistAllocation();
  console.log(ethers.formatEther(allo2.toString()));
});

task("addVestings", async (_, hre) => {
  const { network, ethers } = hre;
  const addressList = readAddressList();

  const [dev] = await ethers.getSigners();

  // const list = readVestingList();
  const list = readTeamVestingList();
  console.log("Total vestings: ", list.length);
  console.log("Vesting list: ", list);

  const matchVesting = await ethers.getContractAt("MatchVesting", addressList[network.name].MatchVesting);

  let vestingList = [];
  let receiverList = [];

  for (let i = 0; i < list.length; i++) {
    const vesting = list[i];

    vestingList.push({
      start: vesting.start,
      cliff: vesting.start + vesting.toCliffSecond,
      duration: vesting.durationSecond,
      interval: vesting.interval,
      amount: ethers.parseEther(vesting.totalAmount.toString()),
      tgeAmount: ethers.parseEther(vesting.tgeAmount.toString()),
      vestedAmount: 0,
      vestedPerTime: 0,
    });
    receiverList.push(vesting.address);
  }

  console.log("Vesting list: ", vestingList);
  console.log("Receiver list: ", receiverList);

  const tx = await matchVesting.setNewVestings(vestingList, receiverList);
  console.log(tx.hash);
});

task("checkMinters", async (_, hre) => {
  const { network, ethers } = hre;
  const addressList = readAddressList();

  const [dev] = await ethers.getSigners();

  const matchToken = await ethers.getContractAt("MatchToken", addressList[network.name].MatchToken);
  const vlMatch = await ethers.getContractAt("VLMatch", addressList[network.name].VLMatch);
  const matchVesting = await ethers.getContractAt("MatchVesting", addressList[network.name].MatchVesting);
  const matchAirdrop = await ethers.getContractAt("MatchAirdrop", addressList[network.name].MatchAirdrop);
  const vlMatchStaking = await ethers.getContractAt("VLMatchStaking", addressList[network.name].VLMatchStaking);

  const s1 = await matchToken.isMinter(addressList[network.name].MatchAirdrop);
  console.log("Match airdrop is match token minter:", s1);

  const s2 = await vlMatch.isMinter(addressList[network.name].VLMatchStaking);
  console.log("VLMatch staking is vl match minter:", s2);

  const s3 = await vlMatch.isMinter(addressList[network.name].VLMatchVesting);
  console.log("VLMatch vesting is vl match minter:", s3);
});

task("sendAirdrop", async (_, hre) => {
  const { network, ethers } = hre;
  const addressList = readAddressList();

  const [dev] = await ethers.getSigners();

  const list = readSendAirdropList();
  console.log("Total airdrop: ", list.length);
  console.log("Airdrop list: ", list);

  let amountList = [];
  let receiverList = [];

  for (let i = 0; i < list.length; i++) {
    const vesting = list[i];

    amountList.push(ethers.parseEther(vesting.amount.toString()));
    receiverList.push(vesting.account_address);
  }
  console.log("Amount list: ", amountList);
  console.log("Receiver list: ", receiverList);

  const matchAirdrop = await ethers.getContractAt("MatchAirdrop", addressList[network.name].MatchAirdrop);
  const tx = await matchAirdrop.send(receiverList, amountList);
  console.log(tx.hash);
});
