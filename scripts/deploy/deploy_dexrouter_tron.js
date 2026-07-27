/**
 * DexRouter deploy for TRON (see scripts/deploy/tron/tronSolc.js for the TVM compile story).
 *
 *   node scripts/deploy/deploy_dexrouter_tron.js                        # compile-only (nothing signed)
 *   node scripts/deploy/deploy_dexrouter_tron.js --broadcast            # deploy to TRON mainnet
 *   node scripts/deploy/deploy_dexrouter_tron.js --broadcast --nile     # full-dress rehearsal on Nile
 *
 * Flow (single run — unlike zksync there is no recompile between phases, because linking
 * is a deploy-time bytecode substitution, not a compile-time input):
 *   1. gen ChainConfig for tron (WTRX / TokenApproveProxy / chainId 728126428)
 *   2. forge flatten DexRouter -> TVM source transforms -> tron-solc 0.8.18 (wasm) compile
 *   3. [--broadcast] deploy the 5 router libraries (skipping any already recorded in
 *      deployed/tron/base.js — reruns resume where they stopped)
 *   4. [--broadcast] substitute the recorded library addresses into DexRouter's bytecode
 *      via linkReferences, refuse if any placeholder remains
 *   5. [--broadcast] deploy DexRouter(owner), record newImpl (base58) + constructorArg
 *
 * Env: TRON_PRIVATE_KEY (required for --broadcast, fail-fast — no fallback key),
 *      TRON_RPC_URL (default https://api.trongrid.io),
 *      TRON_FEE_LIMIT_TRX (per-deploy feeLimit cap, default 3000 TRX).
 *
 * Owner is read from deployed/tron/<record>.owner (required, no hardcoded fallback) —
 * matching gen-chainconfig.js's own base.owner requirement. A hardcoded fallback owner
 * is exactly what caused the first mainnet DexRouter deploy to go out with the wrong
 * governance key; the fix was to always read the owner from the same record the rest
 * of the pipeline treats as the single source of truth.
 *
 * Deploy-only, like every other chain: going live still requires the Boss system to call
 * TokenApproveProxy.addProxy(newImpl). Addresses are recorded in base58 (TRON native);
 * convert with tronWeb.address.toHex when the 20-byte form is needed.
 */
require('dotenv').config();
const fs = require('fs');
const path = require('path');
const { generate } = require('./gen-chainconfig');
const { CHAINS } = require('./verify_via_foundry');
const {
  TRON_SOLC_VERSION,
  cleanForTronSolc,
  compileWithTronSolc,
  forgeFlatten,
} = require('./tron/tronSolc');

const PROJECT_ROOT = path.join(__dirname, '..', '..');
const BUILD_DIR = path.join(PROJECT_ROOT, 'cache', 'tron-build'); // gitignored
const FLAT_NAME = 'DexRouter.tron.sol';

// --nile: full-dress rehearsal on the Nile testnet — same flow end to end, but records
// into deployed/tron/nile.js and expects Nile's chainId, so the mainnet record and the
// mainnet wrong-network gate stay untouched. Note the baked ChainConfig constants are
// still the mainnet ones (same byte lengths -> identical bytecode size and energy cost);
// a Nile router is for pipeline/cost rehearsal, not functional swaps.
const IS_NILE = process.argv.includes('--nile');
const NET = IS_NILE
  ? { name: 'nile', rpcDefault: 'https://nile.trongrid.io', chainId: 3448148188, recordFile: 'nile.js' }
  : { name: 'mainnet', rpcDefault: 'https://api.trongrid.io', chainId: null /* CHAINS.tron.chainId */, recordFile: 'base.js' };
const RECORD_PATH = path.join(__dirname, '..', 'deployed', 'tron', NET.recordFile);

// record field -> contract name (same field names as deployed/zkSyncEra/base.js)
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
function saveField(field, value) {
  let txt = fs.readFileSync(RECORD_PATH, 'utf8');
  const re = new RegExp(`(\\n\\s*)${field}:\\s*"[^"]*"`);
  txt = re.test(txt)
    ? txt.replace(re, `$1${field}: "${value}"`)
    : txt.replace(/\n}/, `\n    ${field}: "${value}",\n}`);
  fs.writeFileSync(RECORD_PATH, txt, 'utf8');
  console.log(`  recorded ${field} = ${value}`);
}

/** base58 TRON address -> 20-byte lowercase hex (no 0x, no 41 prefix), for bytecode linking */
function base58ToHex40(tronWeb, addr) {
  const hex41 = tronWeb.address.toHex(addr); // "41" + 40 hex chars
  if (!/^41[0-9a-fA-F]{40}$/.test(hex41)) {
    throw new Error(`unexpected TRON hex address for ${addr}: ${hex41}`);
  }
  return hex41.slice(2).toLowerCase();
}

/** Substitute library addresses into bytecode using solc linkReferences (position-based). */
function linkBytecode(bytecode, linkReferences, libAddrHex40ByName) {
  let linked = bytecode;
  for (const [, libs] of Object.entries(linkReferences || {})) {
    for (const [libName, positions] of Object.entries(libs)) {
      const addr = libAddrHex40ByName[libName];
      if (!addr) throw new Error(`no deployed address for linked library ${libName}`);
      for (const { start, length } of positions) {
        if (length !== 20) throw new Error(`unexpected link length ${length} for ${libName}`);
        linked = linked.slice(0, start * 2) + addr + linked.slice(start * 2 + 40);
      }
    }
  }
  if (linked.includes('__$')) {
    throw new Error('bytecode still contains unlinked placeholders after substitution');
  }
  return linked;
}

async function main() {
  const broadcast = process.argv.includes('--broadcast');

  // ---- 1. per-chain constants ------------------------------------------------------
  generate('tron', 'prod');

  // ---- 2. flatten + TVM transforms + tron-solc compile ------------------------------
  console.log('\nFlattening DexRouter and applying TVM source transforms...');
  const flatRaw = forgeFlatten('contracts/8/DexRouter.sol', path.join(BUILD_DIR, 'DexRouter.flat.sol'));
  const cleaned = cleanForTronSolc(flatRaw);
  const cleanedPath = path.join(BUILD_DIR, FLAT_NAME);
  fs.writeFileSync(cleanedPath, cleaned);
  console.log(`  cleaned source: ${path.relative(PROJECT_ROOT, cleanedPath)} (${cleaned.split('\n').length} lines)`);

  console.log(`\nCompiling with tron-solc ${TRON_SOLC_VERSION} ...`);
  const { contracts, errors } = compileWithTronSolc(FLAT_NAME, cleaned);
  if (errors.length) {
    errors.slice(0, 5).forEach((e) => console.error((e.formattedMessage || e.message).split('\n')[0]));
    throw new Error(`tron-solc reported ${errors.length} error(s)`);
  }
  const artifacts = {};
  for (const name of [...Object.values(LIB_FIELDS), 'DexRouter']) {
    const c = contracts[name];
    if (!c || !c.evm || !c.evm.bytecode || !c.evm.bytecode.object) {
      throw new Error(`tron-solc output is missing contract ${name}`);
    }
    artifacts[name] = { abi: c.abi, bytecode: c.evm.bytecode.object, linkReferences: c.evm.bytecode.linkReferences };
    console.log(`  ${name}: ${Math.round(artifacts[name].bytecode.length / 2)} bytes`);
  }
  const placeholders = new Set(artifacts.DexRouter.bytecode.match(/__\$[0-9a-f]{34}\$__/g) || []);
  console.log(`  DexRouter library placeholders: ${placeholders.size} (linked at deploy time)`);

  if (!broadcast) {
    console.log('\nCompile-only run complete — nothing was signed or sent.');
    console.log('Use --broadcast to deploy (requires TRON_PRIVATE_KEY in .env).');
    return;
  }

  // ---- 3. tronweb setup + sanity gates ----------------------------------------------
  if (!process.env.TRON_PRIVATE_KEY) {
    throw new Error('TRON_PRIVATE_KEY is not set — refusing to deploy to TRON without it.');
  }
  const { TronWeb } = require('tronweb');
  const rpcUrl = IS_NILE ? NET.rpcDefault : process.env.TRON_RPC_URL || NET.rpcDefault;
  const tronWeb = new TronWeb({ fullHost: rpcUrl, privateKey: process.env.TRON_PRIVATE_KEY });
  const feeLimitSun = Math.round(Number(process.env.TRON_FEE_LIMIT_TRX || 3000) * 1e6);

  // guard against deploying to the wrong network (e.g. a Nile URL left in .env)
  const expectedChainId = NET.chainId || CHAINS.tron.chainId;
  const chainIdResp = await fetch(`${rpcUrl.replace(/\/$/, '')}/jsonrpc`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ jsonrpc: '2.0', method: 'eth_chainId', params: [], id: 1 }),
  }).then((r) => r.json());
  const rpcChainId = parseInt(chainIdResp.result, 16);
  if (rpcChainId !== expectedChainId) {
    throw new Error(`RPC chainId ${rpcChainId} != expected ${expectedChainId} (tron ${NET.name}) — wrong TRON_RPC_URL?`);
  }
  console.log(`\nNetwork: tron ${NET.name} (chainId ${rpcChainId}) | record: deployed/tron/${NET.recordFile}`);

  const deployer = tronWeb.defaultAddress.base58;
  const balanceSun = await tronWeb.trx.getBalance(deployer);
  console.log(`\nDeployer: ${deployer}`);
  console.log(`Balance:  ${(balanceSun / 1e6).toFixed(2)} TRX | feeLimit per deploy: ${feeLimitSun / 1e6} TRX`);

  let record = loadRecord();
  if (!record.owner) {
    throw new Error(`deployed/tron/${NET.recordFile} has no "owner" field — refusing to deploy without one.`);
  }
  const owner20 = record.owner.replace(/^0x/, '');
  const ownerBase58 = tronWeb.address.fromHex('41' + owner20);
  console.log(`Owner:    0x${owner20} (${ownerBase58})`);

  // ---- 4. deploy libraries (resume-safe: skip fields already recorded) ---------------
  const deployContract = async (name, { abi, bytecode }, parameters = []) => {
    const contract = await tronWeb.contract().new({
      abi,
      bytecode,
      feeLimit: feeLimitSun,
      callValue: 0,
      userFeePercentage: 100,
      parameters,
    });
    return tronWeb.address.fromHex(contract.address); // -> base58
  };

  const missing = Object.entries(LIB_FIELDS).filter(([field]) => !record[field]);
  if (missing.length > 0) {
    console.log(`\nDeploying ${missing.length} router librar${missing.length === 1 ? 'y' : 'ies'}...`);
    for (const [field, name] of missing) {
      const addr = await deployContract(name, artifacts[name]);
      console.log(`  ${name}: ${addr}`);
      saveField(field, addr);
    }
    record = loadRecord();
  } else {
    console.log('\nAll 5 router libraries already recorded — reusing them.');
  }

  // ---- 5. link + deploy DexRouter ----------------------------------------------------
  const libAddrHex40ByName = {};
  for (const [field, name] of Object.entries(LIB_FIELDS)) {
    libAddrHex40ByName[name] = base58ToHex40(tronWeb, record[field]);
  }
  const linkedBytecode = linkBytecode(
    artifacts.DexRouter.bytecode,
    artifacts.DexRouter.linkReferences,
    libAddrHex40ByName
  );

  console.log('\nDeploying DexRouter...');
  const dexRouterAddr = await deployContract('DexRouter', { abi: artifacts.DexRouter.abi, bytecode: linkedBytecode }, [ownerBase58]);
  console.log(`DexRouter impl: ${dexRouterAddr} (hex 41${base58ToHex40(tronWeb, dexRouterAddr)})`);
  saveField('newImpl', dexRouterAddr);
  saveField('constructorArg', `0x${owner20}`);

  // ---- 6. next steps -----------------------------------------------------------------
  console.log('\nDeploy complete.');
  console.log('TronScan verification (manual): upload the cleaned flattened source');
  console.log(`  ${path.relative(PROJECT_ROOT, path.join(BUILD_DIR, FLAT_NAME))}`);
  console.log(`  compiler tron-solc ${TRON_SOLC_VERSION}, optimizer enabled, runs 200,`);
  console.log('  plus the 5 recorded library name/address pairs.');
  console.log('Go-live gate (Boss system): TokenApproveProxy.addProxy(newImpl).');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
