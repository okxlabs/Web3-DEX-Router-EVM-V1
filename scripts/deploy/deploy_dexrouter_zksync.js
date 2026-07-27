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

// contracts/8/libraries/ChainConfig.sol is a single gitignored file SHARED with the foundry
// pipeline — check-impl/other chains' deploys regenerate and reset it constantly. Unlike
// DeployDexRouter.s.sol (which asserts block.chainid == _EXPECTED_CHAIN_ID at deploy time),
// this script had no equivalent guard, so a stale/wrong-chain ChainConfig.sol silently
// compiled into a real deployment once (2026-07-27, eth's config deployed to zkSync — see
// scripts/deployed/zkSyncEra/base.js history). Fail fast instead of trusting whatever is on
// disk: regenerate immediately before running this script, and this reads back what actually
// got compiled in.
const CHAIN_CONFIG_PATH = path.join(__dirname, '../../contracts/8/libraries/ChainConfig.sol');
function assertChainConfigMatches(expectedChainId) {
  const src = fs.readFileSync(CHAIN_CONFIG_PATH, 'utf8');
  const m = src.match(/_EXPECTED_CHAIN_ID\s*=\s*(\d+)\s*;/);
  if (!m) {
    throw new Error(`Could not find _EXPECTED_CHAIN_ID in ${CHAIN_CONFIG_PATH} — regenerate it first: node scripts/deploy/gen-chainconfig.js zksyncEra prod`);
  }
  const found = Number(m[1]);
  if (found !== expectedChainId) {
    throw new Error(
      `ChainConfig.sol mismatch: it was generated for chainId ${found}, but this script targets zkSync (chainId ${expectedChainId}). ` +
      `Regenerate the correct config first: node scripts/deploy/gen-chainconfig.js zksyncEra prod — then recompile before deploying.`
    );
  }
}

// DexRouter owner (privileged: pause / transferOwnership / setReporter). REQUIRED in the
// zkSyncEra base.js `owner` field — no default fallback (mirrors the foundry pipeline, which
// requires base.js owner too). Kept visible/reviewable in the record.
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
  assertChainConfigMatches(324); // zkSync Era mainnet
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
  const owner = record.owner;
  if (!ADDR_RE.test(owner || '')) {
    throw new Error(`DexRouter owner missing/invalid — set a valid 0x-address in deployed/zkSyncEra/base.js "owner" (got ${JSON.stringify(owner)}).`);
  }
  console.log(`Owner: ${owner} [base.js]`);
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
