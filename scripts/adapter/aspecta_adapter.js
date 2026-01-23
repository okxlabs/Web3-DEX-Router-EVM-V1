const { ethers } = require("hardhat");
const deployed = require("../deployed");

async function main() {
    // 获取部署者地址
    const [deployer] = await ethers.getSigners();
    console.log(`Deploying with account: ${deployer.address}`);
    
    AspectaAdapter = await ethers.getContractFactory("AspectaAdapter");
    aspectaAdapter = await AspectaAdapter.deploy(deployed.base.wNativeToken);
    let tx = await aspectaAdapter.deployed();
    console.log(tx);

    console.log(`aspectaAdapter deployed: ${aspectaAdapter.address}`);

    // verify
    await hre.run("verify:verify", {
        address: aspectaAdapter.address,
        constructorArguments: [deployed.base.wNativeToken],
    });
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
