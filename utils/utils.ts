import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeploymentSubmission } from "hardhat-deploy/dist/types";
import { DeployProxyOptions } from "@openzeppelin/hardhat-upgrades/dist/utils/options";
import { readFileSync, existsSync } from "fs";

export const deployProxyAndSave = async (
  name: string,
  args: any,
  hardhat: HardhatRuntimeEnvironment,
  deployOptions?: DeployProxyOptions
): Promise<string> => {
  return await deployProxyAndSaveAs(name, name, args, hardhat, deployOptions);
};

export const deployProxyAndSaveAs = async (
  factoryName: string,
  name: string,
  args: any,
  hardhat: HardhatRuntimeEnvironment,
  deployOptions?: DeployProxyOptions
): Promise<string> => {
  const contractFactory = await hardhat.ethers.getContractFactory(factoryName);
  let deployment = await hardhat.deployments.getOrNull(name);

  if (deployment) {
    console.log("✅ ", name, " already deployed");
    return deployment.address;
  }

  let abi = (await hardhat.artifacts.readArtifact(name)).abi;

  let contract = await hardhat.upgrades.deployProxy(
    contractFactory,
    args,
    deployOptions
  );

  contract = await contract.waitForDeployment();

  let receipt = await contract.deploymentTransaction();
  let tx = await receipt?.getTransaction();
  let proxyAddress = await contract.getAddress();
  const implAddress = await hardhat.upgrades.erc1967.getImplementationAddress(
    proxyAddress
  );
  if (!receipt || !tx || !proxyAddress) return "";

  const contractDeployment = {
    address: proxyAddress,
    abi,
    receipt: {
      from: receipt.from,
      transactionHash: receipt.hash,
      blockHash: receipt.blockHash,
      blockNumber: receipt.blockNumber,
      transactionIndex: tx.index,
      cumulativeGasUsed: 0,
      gasUsed: 0,
    },
    metadata: "implementationAddress: " + implAddress,
  } as DeploymentSubmission;

  await hardhat.deployments.save(name, contractDeployment);

  console.log("🚀 ", name, " deployed at ", proxyAddress);
  return proxyAddress;
};

export interface BridgeDeploymentConfig {
  committeeMembers: string[];
  committeeMemberStake: number[];
  wETHAddress: string;
  supportedTokens: string[];
  sourceChainId: number;
}

export const getBridgeDeploymentConfig = (
  network: string
): BridgeDeploymentConfig => {
  const path = `./deploy_configs/${network}.json`;
  if (!existsSync(path)) throw new Error(`Config file not found at ${path}`);

  var obj = JSON.parse(readFileSync(path, "utf8"));

  if (!obj.committeeMembers)
    throw new Error("committeeMembers not provided in config");
  if (!obj.committeeMemberStake)
    throw new Error("committeeMemberStake not provided in config");
  if (!obj.wETHAddress) throw new Error("wETHAddress not provided in config");
  if (!obj.supportedTokens)
    throw new Error("supportedTokens not provided in config");
  if (obj.sourceChainId == undefined || obj.sourceChainId == null)
    throw new Error("sourceChainId not provided in config");

  return {
    committeeMembers: obj.committeeMembers,
    committeeMemberStake: obj.committeeMemberStake,
    supportedTokens: obj.supportedTokens,
    wETHAddress: obj.wETHAddress,
    sourceChainId: obj.sourceChainId,
  };
};
