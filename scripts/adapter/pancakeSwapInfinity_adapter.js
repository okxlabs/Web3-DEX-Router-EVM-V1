const { ethers } = require("hardhat");
const deployed = require("../deployed");

async function main() {
    const Vault = "0x238a358808379702088667322f80aC48bAd5e6c4";
    const CLPoolManager = "0xa0FfB9c1CE1Fe56963B0321B32E7A0302114058b";
    const BinPoolManager = "0xC697d2898e0D09264376196696c51D7aBbbAA4a9";
    
    PancakeSwapInfinityHookAdapter = await ethers.getContractFactory("PancakeSwapInfinityHookAdapter");
    pancakeSwapInfinityHookAdapter = await PancakeSwapInfinityHookAdapter.deploy(
        Vault,
        deployed.base.wNativeToken,
        CLPoolManager,
        BinPoolManager
    );
    let tx = await pancakeSwapInfinityHookAdapter.deployed();
    console.log(tx);

    console.log(`pancakeSwapInfinityHookAdapter deployed: ${pancakeSwapInfinityHookAdapter.address}`);

    // verify
    await hre.run("verify:verify", {
        address: pancakeSwapInfinityHookAdapter.address,
        constructorArguments: [Vault, deployed.base.wNativeToken, CLPoolManager, BinPoolManager],
    });
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
