import { DeployFunction, ProxyOptions } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

import { readAddressList, readImplList, storeAddressList, storeImplList } from "../scripts/contractAddress";


const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, network } = hre;
  const { deploy } = deployments;

  network.name = network.name == "hardhat" ? "localhost" : network.name;

  const { deployer } = await getNamedAccounts();

  console.log("deployer address: ", deployer);

  const addressList = readAddressList();
  const implList = readImplList();

  const proxyOptions: ProxyOptions = {
    proxyContract: "OpenZeppelinTransparentProxy",
    // viaAdminContract: { name: "MyProxyAdmin", artifact: "MyProxyAdmin" },
    execute: {
      init: {
        methodName: "initialize",
        args: [],
      },
    },
  };

  const matchWhitelistSale = await deploy("MatchWhitelistSale", {
    contract: "MatchWhitelistSale",
    from: deployer,
    proxy: proxyOptions,
    args: [],
    log: true,
  });
  addressList[network.name].MatchWhitelistSale = matchWhitelistSale.address;
  implList[network.name].MatchWhitelistSale = matchWhitelistSale.implementation;

  storeAddressList(addressList);
  storeImplList(implList);
};

func.tags = ["MatchWhitelistSale"];
export default func;
