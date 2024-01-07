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

  const matchToken = new ethers.Contract("0xafEAD1d7e31A13fA839e66fFff437D4cfC9335E0", abi, dev);

  // const tx1 = await matchToken.addMinter(dev.address);
  // console.log(tx1.hash);

  const tx = await matchToken.mint("0x32eB34d060c12aD0491d260c436d30e5fB13a8Cd", ethers.parseEther("10000000"));
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
  console.log("all", all.toString());

  const rel = await matchPublicSale.userCurrentRelease(dev.address);
  console.log("rel", rel.toString());
  // const tx = await matchWhitelistSale.allocateMatchTokens();
  // console.log(tx.hash);
});
