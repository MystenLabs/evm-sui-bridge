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

  // deploy Sui Bridge
  let bridgeAddress = (await deployments.getOrNull("SuiBridge"))?.address;
  if (!bridgeAddress) {
    bridgeCommitteeAddress = await deployProxyAndSave(
      "SuiBridge",
      [
        config.supportedTokens,
        bridgeCommitteeAddress,
        vaultAddress,
        config.wETHAddress,
        config.sourceChainId,
      ],
      hardhat,
      { kind: "uups" }
    );
  }
};

export default func;
func.tags = ["BRIDGE"];
