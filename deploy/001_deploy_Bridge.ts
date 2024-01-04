import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { deployProxyAndSave } from "../utils/utils";

const func: DeployFunction = async function (
  hardhat: HardhatRuntimeEnvironment
) {
  let { ethers, deployments } = hardhat;
  const [owner] = await ethers.getSigners();
  const wBTC = "0x0112D7B36726B3077b72DDb457A9f9c94D9cd71c";
  const wETH = "0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14";
  const USDC = "0x80bF6fb931C8eB99Ab32aeD543ACCFd168fd2a47";

  // deploy Bridge Committee
  let bridgeCommitteeAddress = (await deployments.getOrNull("BridgeCommittee"))
    ?.address;
  if (!bridgeCommitteeAddress) {
    // TODO: get deployment args from a provided config file
    let bridgeCommitteeArgs = [
      ["0x0000000000000000000000000000000000000000"],
      [10000],
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
        args: [wETH],
      })
    ).address;
    console.log("🚀 Vault deployed at ", vaultAddress);
  }

  // deploy Sui Bridge
  let bridgeAddress = (await deployments.getOrNull("SuiBridge"))?.address;
  if (!bridgeAddress) {
    // TODO: get deployment args from a provided config file
    const supportedTokens = [wBTC, wETH, USDC];
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
func.tags = ["BRIDGE"];
