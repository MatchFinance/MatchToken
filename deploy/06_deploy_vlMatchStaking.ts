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

  const vlMatchAddress = addressList[network.name].VLMatch;
  const mesLBRAddress = addressList[network.name].mesLBR;

  const proxyOptions: ProxyOptions = {
    proxyContract: "OpenZeppelinTransparentProxy",
    // viaAdminContract: { name: "MyProxyAdmin", artifact: "MyProxyAdmin" },
    execute: {
      init: {
        methodName: "initialize",
        args: [vlMatchAddress, mesLBRAddress],
      },
    },
  };

  const vlMatchStaking = await deploy("VLMatchStaking", {
    contract: "VLMatchStaking",
    from: deployer,
    proxy: proxyOptions,
    args: [],
    log: true,
  });
  addressList[network.name].VLMatchStaking = vlMatchStaking.address;
  implList[network.name].VLMatchStaking = vlMatchStaking.implementation;

  storeAddressList(addressList);
  storeImplList(implList);
};

func.tags = ["vlMatchStaking"];
export default func;
