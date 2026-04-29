const { ethers, network } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  const configPath = path.join(__dirname, "security-manager-config.json");
  const config = JSON.parse(fs.readFileSync(configPath, "utf8"));

  const chainConfig = config[network.name];
  if (!chainConfig) {
    throw new Error(`No config for network: ${network.name}`);
  }

  const { tokenApproveProxy, admin, initialWhitelist } = chainConfig;
  if (!tokenApproveProxy || tokenApproveProxy.startsWith("<")) {
    throw new Error(`tokenApproveProxy not configured for ${network.name}`);
  }
  if (!admin || admin.startsWith("<")) {
    throw new Error(`admin not configured for ${network.name}`);
  }
  if (!Array.isArray(initialWhitelist) || initialWhitelist.length === 0) {
    throw new Error(`initialWhitelist empty for ${network.name}; baseline audit required`);
  }

  console.log(`Deploying SecurityManager on ${network.name}`);
  console.log(`  tokenApproveProxy: ${tokenApproveProxy}`);
  console.log(`  admin (multisig):  ${admin}`);
  console.log(`  initialWhitelist:  ${initialWhitelist.length} addresses`);

  const SecurityManager = await ethers.getContractFactory("SecurityManager");
  const sm = await SecurityManager.deploy(tokenApproveProxy, admin, initialWhitelist);
  await sm.deployed();

  console.log(`SecurityManager deployed at: ${sm.address}`);
  console.log("");
  console.log("=== Manual follow-up actions (via multisig) ===");
  console.log(`1. ${tokenApproveProxy}.transferOwnership(${sm.address})`);
  console.log(`2. ${sm.address}.grantRole(SECURITY_ROLE, <安全公司地址>)`);
  console.log("");
  console.log("=== Verification ===");
  console.log(`Length:    ${(await sm.whitelistLength()).toString()}`);
  console.log(`Whitelist: ${JSON.stringify(await sm.getWhitelist())}`);
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
