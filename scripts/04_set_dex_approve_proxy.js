const { ethers } = require("hardhat");
const deployed = require('./deployed');

async function main() {
  console.log(deployed);

  // const tokenApprove = await ethers.getContractAt(
  //   "TokenApprove",
  //   deployed.base.tokenApprove
  // )

  // const tokenApproveProxy = await ethers.getContractAt(
  //   "TokenApproveProxy",
  //   deployed.base.tokenApproveProxy
  // )

  // await tokenApprove.setApproveProxy(deployed.base.tokenApproveProxy);
  // console.log("tokenApprove init");

  // await tokenApproveProxy.addProxy(deployed.base.dexRouter);
  // await tokenApproveProxy.setTokenApprove(deployed.base.tokenApprove);
  // console.log("tokenApproveProxy add dexProxy")

  const wNativeRelayer = await ethers.getContractAt(
    "WNativeRelayer",
    deployed.base.wNativeRelayer
  )
  await wNativeRelayer.setCallerOk([deployed.base.newImpl2], [true]);
  console.log("setCallerOk finish");
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
