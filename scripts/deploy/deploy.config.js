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
  // conflux: gas estimation is unreliable, bump the multiplier
  conflux: { engine: 'foundry', forgeArgs: ['--gas-estimate-multiplier', '500'] },
  // metis / merlin / iotex: require legacy (pre-EIP-1559) transactions
  metis: { engine: 'foundry', forgeArgs: ['--legacy'] },
  merlin: { engine: 'foundry', forgeArgs: ['--legacy'] },
  iotex: { engine: 'foundry', forgeArgs: ['--legacy'] },

  // --- Hardhat (zkSync) engine ---
  // Standard `forge` cannot produce zkSync bytecode (needs zksolc), so zkSync deploys
  // through the @matterlabs/hardhat-zksync path instead of the foundry pipeline.
  //
  // NOTE: this engine is NOT orchestrated by deploy-and-verify (capabilities.orchestrated
  // = false). It is a standalone deploy only. Several gaps remain before zkSync could
  // be a first-class orchestrated chain (tracked as future work):
  //   - the script below deploys DexRouterExactOut, NOT the main DexRouter the foundry
  //     pipeline deploys — the two are different contracts;
  //   - it records addresses manually (no broadcast/ artifact, no auto recorder);
  //   - verification needs hardhat-zksync-verify and a zksync rpc endpoint;
  //   - deployed dir casing is `zkSyncEra` vs CHAINS key `zksyncEra`.
  zksyncEra: {
    engine: 'hardhat-zksync',
    hardhatNetwork: 'zksync',
    script: 'scripts/deploy/deploy_dex_exactout_imp.js',
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
