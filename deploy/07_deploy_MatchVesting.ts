import { DeployFunction, ProxyOptions } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

import { readAddressList, readImplList, storeAddressList, storeImplList } from "../scripts/contractAddress";


const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, network } = hre;
  const { deploy } = deployments;

  network.name = network.name == "hardhat" ? "localhost" : network.name;

  const { deployer } = await getNamedAccounts();

  const addressList = readAddressList();
  const implList = readImplList();

  const matchAddress = addressList[network.name].MatchToken;

  const proxyOptions: ProxyOptions = {
    proxyContract: "OpenZeppelinTransparentProxy",
    // viaAdminContract: { name: "MyProxyAdmin", artifact: "MyProxyAdmin" },
    execute: {
      init: {
        methodName: "initialize",
        args: [matchAddress],
      },
    },
  };

  const matchVesting = await deploy("MatchVesting", {
    contract: "MatchVesting",
    from: deployer,
    proxy: proxyOptions,
    args: [],
    log: true,
  });
  addressList[network.name].MatchVesting = matchVesting.address;
  implList[network.name].MatchVesting = matchVesting.implementation;

  storeAddressList(addressList);
  storeImplList(implList);
};

func.tags = ["MatchVesting"];
export default func;
