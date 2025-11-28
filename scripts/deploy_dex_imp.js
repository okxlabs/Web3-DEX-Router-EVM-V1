const { ethers, upgrades } = require("hardhat");
const deployed = require('./deployed');

async function main() {
    console.log(deployed.base);

    DexRouter = await ethers.getContractFactory("DexRouter");
    dexRouter = await DexRouter.deploy();
    // REMARK: Add Gas limit for Ethereum mainnet (chainId 1)
    // dexRouter = await DexRouter.deploy({ gasLimit: 8000000 });
    await dexRouter.deployed();
    console.log("dexRouter: " + dexRouter.address);
    // let tx = await dexRouter.initialize();
    // console.log("dexRouter initialized", tx);
    // await tx.wait();
    // console.log("dexRouter initialized");
    // tx2 = await dexRouter.transferOwnership("0xace2b3e7c752d5debca72210141d464371b3b9b1")
    // console.log("dexRouter transferOwnership", tx2);
    // await tx2.wait();
    // console.log("dexRouter transferOwnership");

    // Return the address
    return dexRouter.address;
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
