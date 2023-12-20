import "@nomicfoundation/hardhat-toolbox";
import * as dotenv from "dotenv";
import "hardhat-deploy";
import type { HardhatUserConfig } from "hardhat/config";
import { vars } from "hardhat/config";
import type { NetworkUserConfig } from "hardhat/types";

import "./tasks/ido";

dotenv.config();

// Run 'npx hardhat vars setup' to see the list of variables that need to be set

const infuraApiKey: string = process.env.INFURA_API_KEY || "";
const tenderlyKey: string = process.env.TENDERLY_KEY || "";
const etherscanApiKey: string = process.env.ETHERSCAN_API_KEY || "";

const chainIds = {
  ganache: 1337,
  hardhat: 31337,
  mainnet: 1,
  sepolia: 11155111,
};

function getChainConfig(chain: keyof typeof chainIds): NetworkUserConfig {
  let jsonRpcUrl: string;
  let accountsList: string[] = [];
  switch (chain) {
    case "sepolia":
      jsonRpcUrl = "https://endpoints.omniatech.io/v1/eth/sepolia/public";
      accountsList = process.env.PK_SEPOLIA ? [process.env.PK_SEPOLIA] : [];
      break;
    default:
      jsonRpcUrl = "https://" + chain + ".infura.io/v3/" + infuraApiKey;
      accountsList = process.env.PK_MAINNET ? [process.env.PK_MAINNET] : [];
    // jsonRpcUrl = "https://" + chain + ".gateway.tenderly.co/" + tenderlyKey;
  }


  return {
    accounts: accountsList,
    chainId: chainIds[chain],
    url: jsonRpcUrl,
  };
}

const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
  namedAccounts: {
    deployer: {
      default: 0,
      sepolia: 0,
      mainnet: 0,
    },
    testAddress: {
      default: 1,
      sepolia: 1,
      mainnet: 1,
    },
  },
  etherscan: {
    apiKey: {
      mainnet: etherscanApiKey,
      sepolia: etherscanApiKey,
    },
  },
  gasReporter: {
    currency: "USD",
    enabled: process.env.REPORT_GAS ? true : false,
    excludeContracts: [],
    src: "./contracts",
  },
  networks: {
    hardhat: {
      chainId: chainIds.hardhat,
    },
    ganache: {
      chainId: chainIds.ganache,
      url: "http://localhost:8545",
    },
    mainnet: getChainConfig("mainnet"),
    sepolia: getChainConfig("sepolia"),
  },
  paths: {
    artifacts: "./artifacts",
    cache: "./cache",
    sources: "./contracts",
    tests: "./test",
  },
  solidity: {
    version: "0.8.21",
    settings: {
      metadata: {
        // Not including the metadata hash
        // https://github.com/paulrberg/hardhat-template/issues/31
        bytecodeHash: "none",
      },
      // Disable the optimizer when debugging
      // https://hardhat.org/hardhat-network/#solidity-optimizer-support
      optimizer: {
        enabled: true,
        runs: 800,
      },
    },
  },
  typechain: {
    outDir: "types",
    target: "ethers-v6",
  },
};

export default config;
