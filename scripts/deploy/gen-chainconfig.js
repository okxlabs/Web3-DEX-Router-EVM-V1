const gasLimitConfig = require('../gas_limit/native_transfer_gas');
const { CHAINS, resolveChain } = require('./verify_via_foundry');
const { writeChainConfig, ZERO_ADDRESS, ZERO_FF_FACTORY, DEFAULT_VALUES } = require('./chainConfigGen');
const { loadDeployed, normalizeEnv } = require('./deployedEnv');

// Generate the gitignored contracts/8/libraries/ChainConfig.sol for a (chain, env) target.
//
// Pure node (no hardhat): chainId/verifier come from the chain; `env` (prod|stg) only
// selects which deployed addresses to inject (deployed/<chain>/base.js vs stg.js).
//
// It does NOT mutate tracked source — it regenerates the gitignored ChainConfig.sol that
// Constants.sol imports/re-exports, so there is nothing to restore. Values are validated
// by chainConfigGen (missing/zero required address or unknown chain fails LOUDLY), and the
// generated _EXPECTED_CHAIN_ID guards against deploying to the wrong chain.
function generate(chainArg, env = 'prod') {
  const chain = resolveChain(chainArg);
  if (!chain) {
    throw new Error(`gen-chainconfig: unknown chain "${chainArg}". Known: ${Object.keys(CHAINS).join(', ')}`);
  }
  env = normalizeEnv(env);

  const base = loadDeployed(chain, env);
  if (!base) {
    throw new Error(`gen-chainconfig: no deployed addresses for ${chain}/${env} (expected deployed/${chain}/${env === 'stg' ? 'stg' : 'base'}.js)`);
  }

  const gasLimit = gasLimitConfig.getGasLimit(chain);
  const permit2 = base.permit2 || ZERO_ADDRESS;
  const ffFactory = base._FF_FACTORY || ZERO_FF_FACTORY;
  const values = {
    chainId: CHAINS[chain].chainId,
    gasLimit,
    weth: base.wNativeToken,
    approveProxy: base.tokenApproveProxy,
    permit2,
    ffFactory,
    owner: base.owner, // undefined -> chainConfigGen applies the fleet prod-owner default
  };

  console.log(`\n========== ChainConfig.sol for ${chain}/${env} (chainId ${values.chainId}) ==========\n`);
  console.log(`  - _EXPECTED_CHAIN_ID = ${values.chainId}`);
  console.log(`  - NATIVE_TOKEN_TRANSFER_GAS_LIMIT = ${gasLimit}`);
  console.log(`  - _WETH          = ${values.weth || '(missing!)'}`);
  console.log(`  - _APPROVE_PROXY = ${values.approveProxy || '(missing!)'}`);
  console.log(`  - _PERMIT2       = ${permit2}${base.permit2 ? '' : ' (not configured, zero)'}`);
  console.log(`  - _FF_FACTORY    = ${ffFactory}${base._FF_FACTORY ? '' : ' (not configured, zero)'}`);
  console.log(`  - _OWNER         = ${base.owner || DEFAULT_VALUES.owner}${base.owner ? '' : ' (default fleet prod owner)'}`);

  writeChainConfig(values, `${chain}/${env}`);
  console.log('\nChainConfig.sol generated!');
  return values;
}

module.exports = { generate };

// CLI: node scripts/deploy/gen-chainconfig.js <chain> [prod|stg]
if (require.main === module) {
  const [chainArg, env] = process.argv.slice(2);
  if (!chainArg) {
    console.error('Usage: node scripts/deploy/gen-chainconfig.js <chain> [prod|stg]');
    process.exit(1);
  }
  generate(chainArg, env);
}
