import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { deployProxyAndSave } from "../utils/utils";

const func: DeployFunction = async function (
  hardhat: HardhatRuntimeEnvironment
) {
  let { ethers, deployments } = hardhat;
  const [owner] = await ethers.getSigners();

  // deploy 4 mock tokens with appropriate names
  // deploy wBTC
  let wBTCAddress = (await deployments.getOrNull("WBTC"))?.address;
  if (!wBTCAddress) {
    wBTCAddress = (
      await deployments.deploy("WBTC", {
        from: owner.address,
        args: ["Wrapped Bitcoin", "wBTC"],
      })
    ).address;
  }

  // deploy USDC
  let USDCAddress = (await deployments.getOrNull("USDC"))?.address;
  if (!USDCAddress) {
    USDCAddress = (
      await deployments.deploy("USDC", {
        from: owner.address,
        args: ["USD Coin", "USDC"],
      })
    ).address;
  }
};

export default func;
func.tags = ["MOCK"];
