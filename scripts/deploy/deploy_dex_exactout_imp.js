const hre = require("hardhat");
const { ethers } = hre;
const { Deployer } = require("@matterlabs/hardhat-zksync-deploy");
const { isZkSyncNetwork, buildZkWallet } = require("../utils/zksync");
const deployed = require('../deployed');

const deployOnEvm = async () => {
    const DexRouter = await ethers.getContractFactory("DexRouterExactOut");
    const dexRouter = await DexRouter.deploy();
    await dexRouter.deployed();
    const tx = await dexRouter.initialize();
    console.log("dexRouterExactOut initialized", tx);
    await tx.wait();
    console.log("dexRouterExactOut initialized");
    return dexRouter.address;
}

const deployOnZkSync = async () => {
    const wallet = buildZkWallet(hre);
    const deployer = new Deployer(hre, wallet);
    const artifact = await deployer.loadArtifact("DexRouterExactOut");
    const dexRouter = await deployer.deploy(artifact, []);
    const tx = await dexRouter.initialize();
    console.log("dexRouterExactOut initialized", tx);
    await tx.wait();
    console.log("dexRouterExactOut initialized");
    return dexRouter.address;
}

async function main() {
    console.log(deployed.base);
    const address = await (isZkSyncNetwork(hre) ? deployOnZkSync() : deployOnEvm());
    console.log("dexRouterExactOut: " + address);
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
