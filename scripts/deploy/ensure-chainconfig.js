const fs = require('fs');
const { CHAIN_CONFIG_PATH, DEFAULT_VALUES, writeChainConfig } = require('./chainConfigGen');

// Ensure the gitignored ChainConfig.sol exists so plain builds work on a fresh
// checkout (it is regenerated per-chain at deploy time by gen-chainconfig.js).
// Run automatically on `npm install` (see package.json), or manually:
//   node scripts/deploy/ensure-chainconfig.js
function ensureChainConfig() {
  if (fs.existsSync(CHAIN_CONFIG_PATH)) {
    return;
  }
  writeChainConfig(DEFAULT_VALUES);
  console.log(`Seeded ${CHAIN_CONFIG_PATH} with default (eth mainnet) values.`);
}

ensureChainConfig();
