import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

import { readAddressList, storeAddressList } from "../scripts/contractAddress";

// * Deploy Match Token
// * It is a non-proxy deployment
// * Contract:
// *   - ProxyAdmin
// * Tags:
// *   - ProxyAdmin

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, network } = hre;
  const { deploy } = deployments;

  network.name = network.name == "hardhat" ? "localhost" : network.name;

  const { deployer } = await getNamedAccounts();
  
  const addressList = readAddressList();

  const matchToken = await deploy("MatchToken", {
    contract: "MatchToken",
    from: deployer,
    args: [],
    log: true,
  });
  addressList[network.name].MatchToken = matchToken.address;

  storeAddressList(addressList);
};

func.tags = ["MatchToken"];
export default func;
