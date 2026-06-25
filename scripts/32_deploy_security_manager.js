const { ethers } = require("hardhat");

// Fill these before running. INITIAL_WHITELIST must match the baseline
// whitelist on the target chain's TokenApproveProxy.
const TOKEN_APPROVE_PROXY = "";
const ADMIN = "";
const INITIAL_WHITELIST = [];

async function main() {
  const SecurityManager = await ethers.getContractFactory("SecurityManager");
  const sm = await SecurityManager.deploy(TOKEN_APPROVE_PROXY, ADMIN, INITIAL_WHITELIST);
  await sm.deployed();
  console.log("SecurityManager: " + sm.address);

  console.log("Follow-up (via multisig):");
  console.log(`  1. ${TOKEN_APPROVE_PROXY}.transferOwnership(${sm.address})`);
  console.log(`  2. ${sm.address}.grantRole(SECURITY_ROLE, <security company>)`);
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
