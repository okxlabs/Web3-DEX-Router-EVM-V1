const { ethers } = require("hardhat");
const deployed = require('./deployed');

async function main() {
    console.log(deployed);

    const dexRouter = await ethers.getContractAt(
        "DexRouter",
        deployed.base.dexRouter
    )
    const signers = deployed.base.signers
    for (signer of signers) {
        console.log("set signer", signer)
        await dexRouter.setValidSigner(signer, true)
    }

    console.log("set signer finish");
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
