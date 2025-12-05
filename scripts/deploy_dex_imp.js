const hre = require("hardhat");
const { ethers } = hre;
const { Deployer } = require("@matterlabs/hardhat-zksync-deploy");
const { isZkSyncNetwork, buildZkWallet } = require("./utils/zksync");
const deployed = require('./deployed');

const deployOnEvm = async () => {
    const DexRouter = await ethers.getContractFactory("DexRouter");
    const dexRouter = await DexRouter.deploy();
    // REMARK: Add Gas limit for Ethereum mainnet (chainId 1)
    // dexRouter = await DexRouter.deploy({ gasLimit: 8000000 });
    await dexRouter.deployed();
    return dexRouter.address;
}

const deployOnZkSync = async () => {
    const wallet = buildZkWallet(hre);
    const deployer = new Deployer(hre, wallet);
    const artifact = await deployer.loadArtifact("DexRouter");
    const dexRouter = await deployer.deploy(artifact, []);
    return dexRouter.address;
}

async function main() {
    console.log(deployed.base);
    const address = await (isZkSyncNetwork(hre) ? deployOnZkSync() : deployOnEvm());
    console.log("dexRouter: " + address);
    return address;
}

// Export the main function
module.exports = main;

// Only run if it's the main module
if (require.main === module) {
    main()
        .then(() => process.exit(0))
        .catch(error => {
            console.error(error);
            process.exit(1);
        });
}
