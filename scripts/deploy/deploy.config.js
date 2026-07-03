/**
 * Per-chain deployment configuration.
 *
 * Selects which deploy "engine" (tool) each chain uses, and carries engine-specific
 * options. Chains not listed here fall back to DEFAULT_ENGINE ('foundry') with no
 * extra arguments — i.e. a plain `forge script` deploy.
 *
 * Engines are implemented under scripts/deploy/engines/. To onboard a chain that
 * needs a different deploy tool, add (or reuse) an engine there and point the chain
 * at it here. This is the single place that knows "chain X deploys with tool Y".
 *
 * Engine-specific option fields:
 *   foundry        -> forgeArgs?: string[]        extra `forge script` args
 *                     deployScript?: string       override the .s.sol path
 *   hardhat-zksync -> script: string              hardhat script to `npx hardhat run`
 *                     hardhatNetwork?: string      --network value (defaults to chain)
 */

const DEFAULT_ENGINE = 'foundry';

const DEPLOY_CONFIG = {
  // --- Foundry engine, with chain-specific forge args ---
  // conflux: forge's gas ESTIMATE is broken-low, so a multiplier is needed to reach a usable
  // per-tx gasLimit. But conflux also (a) has a 30M block gas limit and (b) won't mine the large
  // deploy txs unless the gas PRICE is high (~2000 gwei; eth_gasPrice under-reports ~20). The old
  // 500x multiplier at that price needs ~186 CFX (over the deployer balance) and each tx must stay
  // < 30M. 250x lands per-tx gasLimit ~6-9M (> actual, < 30M) and, with --with-gas-price 2000gwei,
  // keeps the required balance ~93 CFX. Deployed & verified 6/6 with these. (Prereq: an
  // unrate-limited CONFLUX_RPC_URL — the public one caps at ~5 req and breaks the broadcast.)
  conflux: { engine: 'foundry', forgeArgs: ['--gas-estimate-multiplier', '250', '--with-gas-price', '2000000000000'] },
  // metis / merlin / polyzkevm: require legacy (pre-EIP-1559) transactions
  metis: { engine: 'foundry', forgeArgs: ['--legacy'] },
  merlin: { engine: 'foundry', forgeArgs: ['--legacy'] },
  // iotex: needs legacy txs AND a gas-estimate multiplier. IoTeX charges intrinsic gas per
  // payload byte at a far higher rate than Ethereum, so forge's local simulation (+30%
  // default buffer) under-estimates the large deploy txs by ~10-15% — all 5 txs of the
  // 2026-07-02 broadcast mined but failed at 99-100% gas used (IoTeX status 106
  // ExecutionReverted on the CREATE2 libs, 102 CodeStoreOutOfGas on DexRouter). 200%
  // lands per-tx gasLimit ~5-6.5M; at the fixed 1000 gwei (1 Qev) min gas price the
  // full-run escrow is ~30 IOTX.
  iotex: { engine: 'foundry', forgeArgs: ['--legacy', '--gas-estimate-multiplier', '200'] },
  // polyzkevm: RPC rejects EIP-1559 fee estimation (unsupported feature: eip1559)
  polyzkevm: { engine: 'foundry', forgeArgs: ['--legacy'] },
  // zeta: RPC rejects EIP-1559 fee estimation (eth_gasPrice not available), needs legacy
  zeta: { engine: 'foundry', forgeArgs: ['--legacy'] },
  // hyperevm: dual-block architecture — small blocks (default, 2-3M gas limit) cannot fit
  // our ~3-4M-gas deploy txs (every plain broadcast dies with `-32603: exceeds block gas
  // limit`). bigBlocks flips the deployer account to 30M "big blocks" on HyperCore for the
  // duration of the broadcast and restores small blocks afterwards — handled transparently
  // by deploy-and-verify via scripts/deploy/hyperliquidBigBlocks.js.
  hyperevm: { engine: 'foundry', bigBlocks: true },

  // --- Hardhat (zkSync) engine ---
  // Standard `forge` cannot produce zkSync bytecode (needs zksolc), so zkSync deploys
  // through the @matterlabs/hardhat-zksync path instead of the foundry pipeline.
  //
  // NOTE: this engine is NOT orchestrated by deploy-and-verify (capabilities.orchestrated
  // = false), and structurally cannot be: the DexRouter deploy is TWO-PHASE with a
  // mandatory recompile in between (zksolc links libraries at compile time — see
  // hardhat.zksync.config.js), and hardhat has no simulation-only mode. The standalone
  // flow (deploy_dexrouter_zksync.js) deploys the main DexRouter + its 5 router
  // libraries, records into deployed/zkSyncEra/base.js automatically, and verification
  // works via `hardhat --config hardhat.zksync.config.js verify` (hardhat-zksync-verify).
  // Remaining gap: deployed dir casing is `zkSyncEra` vs CHAINS key `zksyncEra`.
  zksyncEra: {
    engine: 'hardhat-zksync',
    hardhatNetwork: 'zksync',
    hardhatConfig: 'hardhat.zksync.config.js',
    script: 'scripts/deploy/deploy_dexrouter_zksync.js',
  },
};

/**
 * Resolve the effective deploy config for a chain (with defaults applied).
 * @param {string} chain - resolved chain name (as keyed in DEPLOY_CONFIG / CHAINS)
 * @returns {{engine: string, [key:string]: any}}
 */
function getDeployConfig(chain) {
  const cfg = DEPLOY_CONFIG[chain] || {};
  return { engine: DEFAULT_ENGINE, ...cfg };
}

module.exports = { DEFAULT_ENGINE, DEPLOY_CONFIG, getDeployConfig };
