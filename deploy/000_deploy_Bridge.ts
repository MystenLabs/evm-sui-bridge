import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { deployProxyAndSave } from "../utils/utils";

const func: DeployFunction = async function (
  hardhat: HardhatRuntimeEnvironment
) {
  let { ethers, deployments } = hardhat;
  const [owner] = await ethers.getSigners();

  // deploy Messages Library contract
  let messagesAddress = (await deployments.getOrNull("Messages"))?.address;
  if (!messagesAddress) {
    messagesAddress = (
      await deployments.deploy("Messages", {
        from: owner.address,
        args: [],
      })
    ).address;
  }

  // deploy Bridge Committee
  let bridgeCommitteeAddress = (await deployments.getOrNull("BridgeCommittee"))
    ?.address;
  if (!bridgeCommitteeAddress) {
    // TODO: get deployment args from a provided config file
    let bridgeCommitteeArgs = [[], []];
    let factory = await ethers.getContractFactory("BridgeCommittee", {
      libraries: {
        Messages: messagesAddress,
      },
    });
    bridgeCommitteeAddress = await deployProxyAndSave(
      "BridgeCommittee",
      bridgeCommitteeArgs,
      hardhat,
      { kind: "uups" }
    );
  }

  // deploy vault
  let vaultAddress = (await deployments.getOrNull("Vault"))?.address;
  if (!vaultAddress) {
    vaultAddress = (
      await deployments.deploy("Vault", {
        from: owner.address,
        args: [],
      })
    ).address;
  }

  // deploy Sui Bridge
  let bridgeAddress = (await deployments.getOrNull("Bridge"))?.address;
  if (!bridgeAddress) {
    // TODO: get deployment args from a provided config file
    const supportedTokens = [];
    const wETH = "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1";
    bridgeCommitteeAddress = await deployProxyAndSave(
      "BridgeCommittee",
      [supportedTokens, bridgeCommitteeAddress, vaultAddress, wETH],
      hardhat,
      { kind: "uups" }
    );
  }
};

export default func;
