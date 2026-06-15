const { CHAINS, resolveChain } = require('./verify_via_foundry');
const { getDeployConfig } = require('./deploy.config');
const { getEngine } = require('./engines');

/**
 * Deploy DexRouter to a specific chain.
 *
 * Thin dispatcher: resolves the chain, looks up its deploy engine (foundry by
 * default, hardhat-zksync for zkSync, etc. — see scripts/config/deploy.config.js),
 * and delegates to that engine. Engine-specific options (forge args, hardhat script,
 * …) come straight from the chain's deploy config.
 *
 * @param {string} chainArg - chain name or alias
 * @param {Object} options
 * @param {boolean} [options.broadcast] - actually send transactions
 * @param {boolean} [options.dryRun] - print the command without executing
 * @returns {Promise<{success: boolean, chain?: string, error?: string, [key:string]: any}>}
 */
async function deployDexRouter(chainArg, options = {}) {
  const { broadcast = false, dryRun = false } = options;

  const chain = resolveChain(chainArg);
  if (!chain) {
    throw new Error(`Unknown chain "${chainArg}". Supported chains: ${Object.keys(CHAINS).join(', ')}`);
  }

  const chainConfig = CHAINS[chain];
  const deployConfig = getDeployConfig(chain);
  const engine = getEngine(deployConfig.engine);

  console.log(`\n${'='.repeat(60)}`);
  console.log(`Deploying DexRouter to ${chain.toUpperCase()}`);
  console.log(`${'='.repeat(60)}`);
  console.log(`Chain ID:  ${chainConfig.chainId}`);
  console.log(`Engine:    ${deployConfig.engine}`);
  console.log(`Broadcast: ${broadcast}`);
  console.log(`Dry Run:   ${dryRun}`);
  console.log('');

  // Engine-specific options (forgeArgs / deployScript / script / hardhatNetwork)
  // are carried on deployConfig and passed through verbatim.
  return engine.deploy(chain, { ...deployConfig, broadcast, dryRun });
}

// CLI interface
function main() {
  const args = process.argv.slice(2);

  if (args.length === 0 || args[0] === '--help' || args[0] === '-h') {
    const { DEPLOY_CONFIG, DEFAULT_ENGINE } = require('./deploy.config');
    console.log('Usage: node scripts/deploy/deploy_dex_imp.js <chain> [options]');
    console.log('');
    console.log("Deploy DexRouter using the chain's configured deploy engine.");
    console.log('');
    console.log('Options:');
    console.log('  --broadcast    Actually broadcast transactions (default: simulation only)');
    console.log('  --dry-run      Show command without executing');
    console.log('');
    console.log(`Default engine: ${DEFAULT_ENGINE}. Per-chain overrides:`);
    for (const [chain, cfg] of Object.entries(DEPLOY_CONFIG)) {
      const extra = cfg.forgeArgs ? ` (${cfg.forgeArgs.join(' ')})` : cfg.script ? ` (${cfg.script})` : '';
      console.log(`  ${chain}: ${cfg.engine}${extra}`);
    }
    console.log('');
    console.log('Supported chains:');
    console.log(`  ${Object.keys(CHAINS).join(', ')}`);
    console.log('');
    console.log('Examples:');
    console.log('  node scripts/deploy/deploy_dex_imp.js arb                    # Simulate deployment on Arbitrum');
    console.log('  node scripts/deploy/deploy_dex_imp.js arb --broadcast        # Deploy on Arbitrum');
    console.log('  node scripts/deploy/deploy_dex_imp.js conflux --broadcast    # Deploy on Conflux (with --gas-estimate-multiplier 500)');
    console.log('  node scripts/deploy/deploy_dex_imp.js zksyncEra --broadcast  # Deploy on zkSync (via hardhat-zksync)');
    console.log('');
    console.log('After deployment, run:');
    console.log('  node scripts/deploy/foundry_broadcast_record.js <chain>      # Record addresses to base.js');
    console.log('  node scripts/deploy/verify_via_foundry.js <chain>            # Verify contracts');
    process.exit(0);
  }

  const chainArg = args[0];
  const broadcast = args.includes('--broadcast');
  const dryRun = args.includes('--dry-run');

  deployDexRouter(chainArg, { broadcast, dryRun })
    .then(result => {
      process.exit(result.success ? 0 : 1);
    })
    .catch(error => {
      console.error('Error:', error.message);
      process.exit(1);
    });
}

// Export for use as module
module.exports = {
  deployDexRouter,
};

// Run CLI if called directly
if (require.main === module) {
  main();
}
