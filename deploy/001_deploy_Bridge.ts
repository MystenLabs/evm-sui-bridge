import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { deployProxyAndSave, getBridgeDeploymentConfig } from "../utils/utils";

const func: DeployFunction = async function (
  hardhat: HardhatRuntimeEnvironment
) {
  let { ethers, deployments } = hardhat;
  const [owner] = await ethers.getSigners();
  const config = getBridgeDeploymentConfig(hardhat.network.name);

  // deploy Bridge Committee
  let bridgeCommitteeAddress = (await deployments.getOrNull("BridgeCommittee"))
    ?.address;
  if (!bridgeCommitteeAddress) {
    let bridgeCommitteeArgs = [
      config.committeeMembers,
      config.committeeMemberStake,
    ];
    bridgeCommitteeAddress = await deployProxyAndSave(
      "BridgeCommittee",
      bridgeCommitteeArgs,
      hardhat,
      { kind: "uups" }
    );
  }

  // deploy vault
  let vaultAddress = (await deployments.getOrNull("BridgeVault"))?.address;
  if (!vaultAddress) {
    vaultAddress = (
      await deployments.deploy("BridgeVault", {
        from: owner.address,
        args: [config.wETHAddress],
      })
    ).address;
    console.log("🚀  Vault deployed at ", vaultAddress);
  }

  // deploy limiter
  let limiterAddress = (await deployments.getOrNull("BridgeLimiter"))?.address;
  if (!limiterAddress) {
    // _dailyLimitStart, _dailyBridgeLimits

    let dailyLimitStart =
      ((await ethers.provider.getBlock(await ethers.provider.getBlockNumber()))
        ?.timestamp || 0) +
      60 * 60 * 24;
    limiterAddress = (
      await deployments.deploy("BridgeLimiter", {
        from: owner.address,
        args: [dailyLimitStart, config.dailyBridgeLimits],
      })
    ).address;
    console.log("🚀  Limiter deployed at ", limiterAddress);
  }

  // deploy Sui Bridge
  let bridgeAddress = (await deployments.getOrNull("SuiBridge"))?.address;
  if (!bridgeAddress) {
    bridgeCommitteeAddress = await deployProxyAndSave(
      "SuiBridge",
      [
        bridgeCommitteeAddress,
        vaultAddress,
        limiterAddress,
        config.wETHAddress,
        config.sourceChainId,
        config.supportedTokens,
      ],
      hardhat,
      { kind: "uups" }
    );
  }

  // transfer vault ownership to bridge
  let vault = await ethers.getContractAt("BridgeVault", vaultAddress);
  await vault.transferOwnership(bridgeAddress);
  // transfer limiter ownership to bridge
  let limiter = await ethers.getContractAt("BridgeLimiter", limiterAddress);
  await limiter.transferOwnership(bridgeAddress);
};

export default func;
func.tags = ["BRIDGE"];
