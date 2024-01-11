import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { deployProxyAndSave, getBridgeDeploymentConfig } from "../utils/utils";

const func: DeployFunction = async function (
  hardhat: HardhatRuntimeEnvironment
) {
  let { ethers, deployments } = hardhat;
  const [owner] = await ethers.getSigners();
  let config = getBridgeDeploymentConfig(hardhat.network.name);

  // If deploying on local network, deploy mock tokens (including wETH)
  if (hardhat.network.name === "hardhat") {
    // deploy wETH
    let wETHAddress = (await deployments.getOrNull("WETH"))?.address;
    if (!wETHAddress) {
      wETHAddress = (
        await deployments.deploy("WETH", {
          from: owner.address,
          args: [],
        })
      ).address;
      console.log("🚀  WETH deployed at ", wETHAddress);
    }
    config.wETHAddress = wETHAddress;

    // deploy mock tokens
    let mockWBTCAddress = (await deployments.getOrNull("MockWBTC"))?.address;
    if (!mockWBTCAddress) {
      mockWBTCAddress = (
        await deployments.deploy("MockWBTC", {
          from: owner.address,
          args: [],
        })
      ).address;
      console.log("🚀  MockWBTC deployed at ", mockWBTCAddress);
    }
    let mockUSDCAddress = (await deployments.getOrNull("MockUSDC"))?.address;
    if (!mockUSDCAddress) {
      mockUSDCAddress = (
        await deployments.deploy("MockUSDC", {
          from: owner.address,
          args: [],
        })
      ).address;
      console.log("🚀  MockUSDC deployed at ", mockUSDCAddress);
    }
    config.supportedTokens = [mockWBTCAddress, wETHAddress, mockUSDCAddress];
  }

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
    limiterAddress = (
      await deployments.deploy("BridgeLimiter", {
        from: owner.address,
        args: [config.dailyBridgeLimits],
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
  await vault.transferOwnership(bridgeCommitteeAddress);
  // transfer limiter ownership to bridge
  let limiter = await ethers.getContractAt("BridgeLimiter", limiterAddress);
  await limiter.transferOwnership(bridgeCommitteeAddress);
};

export default func;
func.tags = ["BRIDGE"];
