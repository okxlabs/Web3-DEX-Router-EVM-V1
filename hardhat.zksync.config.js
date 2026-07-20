/**
 * zkSync-only Hardhat config — used exclusively with an explicit --config flag:
 *
 *   npx hardhat --config hardhat.zksync.config.js compile --network zksync
 *   npx hardhat --config hardhat.zksync.config.js run scripts/deploy/deploy_dexrouter_zksync.js --network zksync
 *
 * ⚠️ `--network zksync` is required even for compile: hardhat-zksync-solc only engages
 * zksolc when hre.network.zksync === true. A bare `compile` silently emits vanilla solc
 * EVM bytecode into artifacts-zk-build (undeployable on Era, `__$…$__` placeholders,
 * settings.libraries ignored). Also note hardhat does NOT invalidate its compile cache
 * when settings.libraries changes — recompile with --force after Phase A records them.
 *
 * WHY a separate config: the @matterlabs plugins override Hardhat's compile task globally.
 * The main hardhat.config.js intentionally does not load them, so ~50 ops scripts and the
 * deploy-and-verify pipeline never touch the zk toolchain. This file isolates it completely.
 *
 * LIBRARY LINKING (the key zkSync difference): zksolc resolves linked libraries at COMPILE
 * time via zksolc.settings.libraries — there is no deploy-time linking like forge. The
 * DexRouter deploy is therefore two-phase (see deploy_dexrouter_zksync.js):
 *   Phase A: deploy the 5 router libraries, record them in scripts/deployed/zkSyncEra/base.js
 *   Phase B: recompile (this config auto-picks the recorded addresses up) and deploy DexRouter
 * Compiling DexRouter with unlinked libraries fails — that is expected before Phase A.
 */
require('@matterlabs/hardhat-zksync-solc');
require('@matterlabs/hardhat-zksync-deploy');
require('@matterlabs/hardhat-zksync-verify');
require('dotenv').config();

// Same fail-fast rule as the main config: never fall back to a public test key on mainnet.
const PRIVATE_KEY = (() => {
  if (process.env.PRIVATE_KEY) return process.env.PRIVATE_KEY;
  throw new Error('PRIVATE_KEY is not set — refusing to target zkSync mainnet without it.');
})();

// zksolc needs every linked library's address at compile time. Source them from the deploy
// record so the config stays chain-state-free. zksolc 1.3.22 hard-errors on a missing
// library (no `__$…$__` placeholder fallback like older versions / forge), which would
// make the pre-Phase-A compile impossible — so any *Library field absent from the record
// is filled with LIB_SENTINEL. That keeps Phase A compilable; the sentinel can never leak
// on chain because Phase A only deploys the libraries themselves (self-contained, no
// cross-library references) and Phase B refuses to deploy a DexRouter whose bytecode does
// not embed every RECORDED library address (see deploy_dexrouter_zksync.js).
const LIB_SENTINEL = '0x0000000000000000000000000000000000000001';

const LIB_CONTRACTS = {
  dagRouterLibrary: ['contracts/8/router/DagRouter.sol', 'DagRouter'],
  smartSwapRouterLibrary: ['contracts/8/router/SmartSwapRouter.sol', 'SmartSwapRouter'],
  swapWrapRouterLibrary: ['contracts/8/router/SwapWrapRouter.sol', 'SwapWrapRouter'],
  unxswapRouterLibrary: ['contracts/8/router/UnxswapRouter.sol', 'UnxswapRouter'],
  unxswapV3RouterLibrary: ['contracts/8/router/UnxswapV3Router.sol', 'UnxswapV3Router'],
  // DexRouterExactOut's linked libraries. Not deployed on zkSync yet — until their fields
  // appear in the record they stay sentinel-linked, which only affects the (undeployed)
  // DexRouterExactOut artifact; without them zksolc refuses to compile the project at all.
  unxswapExactOutRouterLibrary: ['contracts/exactout/router/UnxswapExactOutRouter.sol', 'UnxswapExactOutRouter'],
  unxswapV3ExactOutRouterLibrary: ['contracts/exactout/router/UnxswapV3ExactOutRouter.sol', 'UnxswapV3ExactOutRouter'],
};

function recordedLibraries() {
  let record;
  try {
    record = require('./scripts/deployed/zkSyncEra/base.js');
  } catch (e) {
    record = {}; // bare checkout: every library falls back to LIB_SENTINEL
  }
  // The libraries map feeds the solc metadata hash (last 32 bytes of bytecode), so the
  // libraries themselves only byte-match on the explorer when verified against the same
  // compile state they were DEPLOYED from — the all-sentinel Phase A compile. Runtime
  // code is unaffected (verified byte-identical except the metadata tail). To verify the
  // libraries after the record already holds their addresses:
  //   ZKSYNC_LIBS_SENTINEL=1 npx hardhat --config hardhat.zksync.config.js compile --force --network zksync
  //   npx hardhat --config hardhat.zksync.config.js verify --network zksync --contract <FQN> <libAddr>
  //   npx hardhat --config hardhat.zksync.config.js compile --force --network zksync   # restore
  if (process.env.ZKSYNC_LIBS_SENTINEL === '1') record = {};
  const libraries = {};
  for (const [field, [sourcePath, name]] of Object.entries(LIB_CONTRACTS)) {
    const addr = record[field] || LIB_SENTINEL;
    libraries[sourcePath] = { ...(libraries[sourcePath] || {}), [name]: addr };
  }
  return libraries;
}

module.exports = {
  zksolc: {
    // 1.4.1: entire 1.3.x line crashes (LLVM APInt assert) when a library whose address is
    // in settings.libraries is itself compiled (self-link), hit by UnxswapRouter. Verified
    // fixed in 1.4.1. 1.5.x additionally requires the era-solidity solc fork — not worth it.
    version: '1.4.1',
    compilerSource: 'binary',
    settings: {
      libraries: recordedLibraries(),
      optimizer: { enabled: true, mode: '3' },
    },
  },
  solidity: {
    compilers: [
      {
        version: '0.8.17',
        settings: { optimizer: { enabled: true, runs: 200 } },
      },
    ],
  },
  networks: {
    zksync: {
      url: process.env.ZKSYNC_RPC_URL || 'https://mainnet.era.zksync.io',
      ethNetwork: process.env.ZKSYNC_ETH_NETWORK || 'mainnet',
      zksync: true,
      chainId: 324,
      verifyURL: 'https://zksync2-mainnet-explorer.zksync.io/contract_verification',
      accounts: [PRIVATE_KEY],
    },
  },
  paths: {
    // Keep zk artifacts fully separate from the solc ones (both dirs are gitignored).
    // Must end in "-zk": hardhat-zksync-solc appends the suffix itself otherwise, so a
    // non "-zk" name silently splits output across <name>/ (EVM) and <name>-zk/ (EraVM).
    artifacts: './artifacts-zk',
    cache: './cache-zk',
  },
};
