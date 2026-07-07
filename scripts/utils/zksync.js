const DEFAULT_DEPLOYER_PRIVATE_KEY =
  "ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";

let zksyncModule;

const ensureZkSyncModule = () => {
  if (!zksyncModule) {
    try {
      zksyncModule = require("zksync-web3");
    } catch (error) {
      throw new Error(
        'Package "zksync-web3" is required. Please run `npm install` before using zkSync workflows.',
      );
    }
  }

  return zksyncModule;
};

const assertNetworkConfig = (hre, networkName = hre.network.name) => {
  const config = hre.config.networks?.[networkName];
  if (!config || !config.url) {
    throw new Error(
      `Missing RPC url for network "${networkName}". Please check hardhat.config.js.`,
    );
  }

  return config;
};

const isZkSyncNetwork = (hre, networkName = hre.network.name) =>
  networkName === "zksync";

const buildZkProvider = (hre, networkName = hre.network.name) => {
  const { url } = assertNetworkConfig(hre, networkName);
  const { Provider } = ensureZkSyncModule();
  return new Provider(url);
};

const buildZkWallet = (hre, networkName = hre.network.name) => {
  const provider = buildZkProvider(hre, networkName);
  // zkSync wallet ops only happen on a real network — fail fast rather than silently
  // signing with the public test key when PRIVATE_KEY is missing.
  if (!process.env.PRIVATE_KEY) {
    throw new Error(
      `PRIVATE_KEY is not set — refusing to build a zkSync wallet with the public test key ` +
        `on network "${networkName}". Set PRIVATE_KEY in your .env.`,
    );
  }
  const privateKey = process.env.PRIVATE_KEY;
  const { Wallet } = ensureZkSyncModule();
  return new Wallet(privateKey, provider);
};

const getZkContract = async (
  hre,
  contractName,
  address,
  provider = buildZkProvider(hre),
) => {
  const artifact = await hre.artifacts.readArtifact(contractName);
  const { Contract } = ensureZkSyncModule();
  return new Contract(address, artifact.abi, provider);
};

module.exports = {
  DEFAULT_DEPLOYER_PRIVATE_KEY,
  assertNetworkConfig,
  isZkSyncNetwork,
  buildZkProvider,
  buildZkWallet,
  getZkContract,
};

