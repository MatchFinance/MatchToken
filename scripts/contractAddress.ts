/**
 * Remember to use this function in the root path of your hardhat project
 */
import * as fs from "fs";

///
/// Deployed Contract Address Info Record
///
export const readAddressList = function () {
  // const filePath = __dirname + "/address.json"
  return JSON.parse(fs.readFileSync("info/address.json", "utf-8"));
};

export const storeAddressList = function (addressList: object) {
  fs.writeFileSync("info/address.json", JSON.stringify(addressList, null, "\t"));
};

export const readImplList = function () {
  // const filePath = __dirname + "/address.json"
  return JSON.parse(fs.readFileSync("info/implementation.json", "utf-8"));
};

export const storeImplList = function (implList: object) {
  fs.writeFileSync("info/implementation.json", JSON.stringify(implList, null, "\t"));
};

export const clearAddressList = function () {
  const emptyList = {};
  fs.writeFileSync("info/address.json", JSON.stringify(emptyList, null, "\t"));
};

export const readWhitelist = function () {
  return JSON.parse(fs.readFileSync("info/whitelist.json", "utf-8"));
};

export const readRealWhitelist = function () {
  return JSON.parse(fs.readFileSync("info/realWhitelist.json", "utf-8"));
};

export const readVestingList = function () {
  return JSON.parse(fs.readFileSync("info/newVestingList.json", "utf-8"));
};

export const readTeamVestingList = function () {
  return JSON.parse(fs.readFileSync("info/teamVestingList.json", "utf-8"));
};

export const readSendAirdropList = function () {
  return JSON.parse(fs.readFileSync("info/sendAirdrop.json", "utf-8"));
};

export const readAirdropList = function () {
  return JSON.parse(fs.readFileSync("info/airdrop/airdropList.json", "utf-8"));
};