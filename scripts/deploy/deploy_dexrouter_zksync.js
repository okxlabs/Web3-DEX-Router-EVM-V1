/**
 * Two-phase DexRouter deploy for zkSync Era (see hardhat.zksync.config.js for why).
 *
 *   npx hardhat --config hardhat.zksync.config.js run scripts/deploy/deploy_dexrouter_zksync.js --network zksync
 *
 * zksolc links libraries at COMPILE time, so unlike the forge pipeline (deploy libs and
 * DexRouter in one broadcast) this must run twice around a recompile:
 *
 *   Phase A (any *Library field missing from the record): deploys the missing router
 *     libraries and records them in scripts/deployed/zkSyncEra/base.js, then stops and
 *     prints the recompile + rerun instructions.
 *   Phase B (all libraries recorded): expects the artifact to have been recompiled with
 *     those addresses (hardhat.zksync.config.js reads them from the record); refuses to
 *     deploy unless every recorded library address is embedded in the bytecode (guards
 *     against a stale artifact linked to the compile-only sentinel), then deploys
 *     DexRouter(owner) and records newImpl + constructorArg.
 *
 * Deploy-only, like every other chain: going live still requires the Boss system to call
 * TokenApproveProxy.addProxy(newImpl).
 */
const hre = require('hardhat');
const fs = require('fs');
const path = require('path');
const { Deployer } = require('@matterlabs/hardhat-zksync-deploy');
const { buildZkWallet } = require('../utils/zksync');

// DexRouter owner (privileged: pause / transferOwnership / setReporter). Read from the
// zkSyncEra base.js `owner` field so the privileged address is visible/reviewable in the
// record; absent -> this fleet prod-owner default (same value the foundry pipeline uses).
const DEFAULT_OWNER = '0xAcE2B3E7c752d5deBca72210141d464371b3B9b1';
const ADDR_RE = /^0x[0-9a-fA-F]{40}$/;

const RECORD_PATH = path.join(__dirname, '../deployed/zkSyncEra/base.js');

const LIB_FIELDS = {
  dagRouterLibrary: 'DagRouter',
  smartSwapRouterLibrary: 'SmartSwapRouter',
  swapWrapRouterLibrary: 'SwapWrapRouter',
  unxswapRouterLibrary: 'UnxswapRouter',
  unxswapV3RouterLibrary: 'UnxswapV3Router',
};

function loadRecord() {
  delete require.cache[require.resolve(RECORD_PATH)];
  return require(RECORD_PATH);
}

// Update `field: "…",` in place, or append it before the closing brace.
function saveField(field, addr) {
  let txt = fs.readFileSync(RECORD_PATH, 'utf8');
  const re = new RegExp(`(\\n\\s*)${field}:\\s*"[^"]*"`);
  txt = re.test(txt)
    ? txt.replace(re, `$1${field}: "${addr}"`)
    : txt.replace(/\n}/, `\n    ${field}: "${addr}",\n}`);
  fs.writeFileSync(RECORD_PATH, txt, 'utf8');
  console.log(`  recorded ${field} = ${addr}`);
}

async function main() {
  if (hre.network.name !== 'zksync') {
    throw new Error(`This script targets the "zksync" network only (got "${hre.network.name}").`);
  }
  const wallet = buildZkWallet(hre);
  const deployer = new Deployer(hre, wallet);

  const record = loadRecord();
  const missing = Object.entries(LIB_FIELDS).filter(([field]) => !record[field]);

  if (missing.length > 0) {
    console.log(`Phase A: deploying ${missing.length} router libraries...`);
    for (const [field, contractName] of missing) {
      const artifact = await deployer.loadArtifact(contractName);
      const lib = await deployer.deploy(artifact, []);
      console.log(`  ${contractName}: ${lib.address}`);
      saveField(field, lib.address);
    }
    console.log('\nPhase A complete. Recompile so zksolc links the recorded libraries, then rerun for Phase B:');
    console.log('  npx hardhat --config hardhat.zksync.config.js compile --force --network zksync');
    console.log('  npx hardhat --config hardhat.zksync.config.js run scripts/deploy/deploy_dexrouter_zksync.js --network zksync');
    return;
  }

  console.log('Phase B: all libraries recorded — deploying DexRouter...');
  const artifact = await deployer.loadArtifact('DexRouter');
  // zksolc links at compile time (never emits __$…$__ placeholders — it either embeds an
  // address or refuses to compile). The artifact may therefore predate Phase A and carry
  // the compile-only LIB_SENTINEL (see hardhat.zksync.config.js) instead of the real
  // libraries: refuse unless every RECORDED library address is embedded in the bytecode.
  const bytecode = (artifact.bytecode || '').toLowerCase();
  const notLinked = Object.entries(LIB_FIELDS).filter(
    ([field]) => !bytecode.includes(record[field].slice(2).toLowerCase())
  );
  if (notLinked.length > 0) {
    throw new Error(
      `DexRouter artifact is not linked against the recorded ${notLinked.map(([, n]) => n).join(', ')}. ` +
      'Recompile first: npx hardhat --config hardhat.zksync.config.js compile --force --network zksync'
    );
  }
  const owner = record.owner || DEFAULT_OWNER;
  if (!ADDR_RE.test(owner)) {
    throw new Error(`Invalid DexRouter owner ${JSON.stringify(owner)} — set a valid 0x-address in deployed/zkSyncEra/base.js "owner".`);
  }
  console.log(`Owner: ${owner}${record.owner ? ' [base.js]' : ' [default fleet owner]'}`);
  const dexRouter = await deployer.deploy(artifact, [owner]);
  console.log(`DexRouter impl: ${dexRouter.address}`);
  saveField('newImpl', dexRouter.address);
  saveField('constructorArg', owner);
  console.log('\nDeploy complete. Go-live gate (Boss system): TokenApproveProxy.addProxy(newImpl).');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
