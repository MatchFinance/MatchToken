import { DeployFunction, ProxyOptions } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

import { readAddressList, readImplList, storeAddressList, storeImplList } from "../scripts/contractAddress";

// * Deploy Match Public Sale
// * It is a proxy deployment
// * Contract:
// *   - MatchPublicSale
// * Tags:
// *   - MatchPublicSale

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, network } = hre;
  const { deploy } = deployments;

  network.name = network.name == "hardhat" ? "localhost" : network.name;

  const { deployer } = await getNamedAccounts();

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

  const matchPublicSale = await deploy("MatchPublicSale", {
    contract: "MatchPublicSale",
    from: deployer,
    proxy: proxyOptions,
    args: [],
    log: true,
  });
  addressList[network.name].MatchPublicSale = matchPublicSale.address;
  implList[network.name].MatchPublicSale = matchPublicSale.implementation;

  storeAddressList(addressList);
  storeImplList(implList);
};

func.tags = ["MatchPublicSale"];
export default func;
