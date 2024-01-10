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

  const mockERC20 = await deploy("MockERC20", {
    contract: "MockERC20",
    from: deployer,
    args: ["mesLBR", "mesLBR"],
    log: true,
  });
  addressList[network.name].MockERC20 = mockERC20.address;

  storeAddressList(addressList);
};

func.tags = ["MockERC20"];
export default func;
