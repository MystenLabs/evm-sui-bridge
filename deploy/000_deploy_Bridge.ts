import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { deployProxyAndSave } from "../utils/utils";

const func: DeployFunction = async function (
  hardhat: HardhatRuntimeEnvironment
) {
  let { ethers, deployments } = hardhat;
  const [owner] = await ethers.getSigners();

  // deploy Bridge Committee
  let bridgeCommitteeAddress = (await deployments.getOrNull("BridgeCommittee"))
    ?.address;
  if (!bridgeCommitteeAddress) {
    // TODO: get deployment args from a provided config file
    let bridgeCommitteeArgs = [[], []];
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
        args: [],
      })
    ).address;
  }

  // deploy Sui Bridge
  let bridgeAddress = (await deployments.getOrNull("SuiBridge"))?.address;
  if (!bridgeAddress) {
    // TODO: get deployment args from a provided config file
    const supportedTokens = [];
    const wETH = "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1";
    const sourceChainId = 0;
    bridgeCommitteeAddress = await deployProxyAndSave(
      "SuiBridge",
      [
        supportedTokens,
        bridgeCommitteeAddress,
        vaultAddress,
        wETH,
        sourceChainId,
      ],
      hardhat,
      { kind: "uups" }
    );
  }
};

export default func;
