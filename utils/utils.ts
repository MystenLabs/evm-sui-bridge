import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeploymentSubmission } from "hardhat-deploy/dist/types";
import { DeployProxyOptions } from "@openzeppelin/hardhat-upgrades/dist/utils/options";
import { ethers } from "ethers";

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

export const formatStableCredits = (value: ethers.BigNumberish) => {
  return ethers.formatUnits(value, "mwei");
};

export const parseStableCredits = (value: string) => {
  return ethers.parseUnits(value, "mwei");
};

export const getConfig = () => {
  let adminOwner = process.env.ADMIN_OWNER_ADDRESS;
  let reserveTokenAddress = process.env.RESERVE_TOKEN_ADDRESS;
  return { adminOwner, reserveTokenAddress };
};
