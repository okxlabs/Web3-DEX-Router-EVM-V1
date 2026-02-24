const { execSync } = require('child_process');
const path = require('path');
const { CHAINS, resolveChain } = require('./verify_via_foundry');

const PROJECT_ROOT = path.join(__dirname, '..');
const DEPLOY_SCRIPT = 'src/deploy/DeployDexRouter.s.sol';

// Chain-specific forge script arguments
// These are extra arguments needed for specific chains due to their unique requirements
const CHAIN_DEPLOY_ARGS = {
  // conflux: gas estimation issues, need higher multiplier
  conflux: ['--gas-estimate-multiplier', '500'],
  // metis, merlin, iotex: legacy transaction format required
  metis: ['--legacy'],
  merlin: ['--legacy'],
  iotex: ['--legacy'],
};

/**
 * Build forge script command for deploying DexRouter
 * @param {string} chain - Chain name
 * @param {Object} options - Deployment options
 * @returns {string} - Complete forge script command
 */
function buildDeployCommand(chain, options = {}) {
  const { broadcast = false, dryRun = false } = options;
  
  let cmd = 'forge script';
  cmd += ` ${DEPLOY_SCRIPT}`;
  cmd += ` --rpc-url ${chain}`;
  
  // Add chain-specific arguments
  const chainArgs = CHAIN_DEPLOY_ARGS[chain];
  if (chainArgs) {
    cmd += ` ${chainArgs.join(' ')}`;
  }
  
  // Add broadcast flag (actually send transactions)
  if (broadcast && !dryRun) {
    cmd += ' --broadcast';
  }
  
  // Add verbosity for better output
  cmd += ' -vvvv';
  
  return cmd;
}

/**
 * Deploy DexRouter to a specific chain
 * @param {string} chainArg - Chain name argument
 * @param {Object} options - Deployment options
 * @returns {Object} - Deployment result
 */
async function deployDexRouter(chainArg, options = {}) {
  const { broadcast = false, dryRun = false } = options;
  
  // Resolve chain name
  const chain = resolveChain(chainArg);
  if (!chain) {
    throw new Error(`Unknown chain "${chainArg}". Supported chains: ${Object.keys(CHAINS).join(', ')}`);
  }
  
  const chainConfig = CHAINS[chain];
  console.log(`\n${'='.repeat(60)}`);
  console.log(`Deploying DexRouter to ${chain.toUpperCase()}`);
  console.log(`${'='.repeat(60)}`);
  console.log(`Chain ID: ${chainConfig.chainId}`);
  console.log(`Broadcast: ${broadcast}`);
  console.log(`Dry Run: ${dryRun}`);
  
  // Check for chain-specific arguments
  const chainArgs = CHAIN_DEPLOY_ARGS[chain];
  if (chainArgs) {
    console.log(`Chain-specific args: ${chainArgs.join(' ')}`);
  }
  console.log('');
  
  // Build command
  const cmd = buildDeployCommand(chain, options);
  console.log('Command:');
  console.log(`  ${cmd}`);
  console.log('');
  
  if (dryRun) {
    console.log('🔍 Dry run mode - command not executed');
    return { success: true, dryRun: true, command: cmd };
  }
  
  // Execute deployment
  console.log('Executing deployment...\n');
  
  try {
    const output = execSync(cmd, {
      cwd: PROJECT_ROOT,
      encoding: 'utf8',
      stdio: 'inherit', // Show output in real-time
      env: { ...process.env },
    });
    
    console.log(`\n✅ Deployment command completed for ${chain}`);
    
    if (broadcast) {
      console.log('');
      console.log('Next steps:');
      console.log(`  1. Record deployment: node scripts/foundry_broadcast_record.js ${chain}`);
      console.log(`  2. Verify contracts:  node scripts/verify_via_foundry.js ${chain}`);
    }
    
    return { success: true, chain, output };
  } catch (error) {
    console.error(`\n❌ Deployment failed for ${chain}`);
    console.error('Error:', error.message);
    return { success: false, chain, error: error.message };
  }
}

// CLI interface
function main() {
  const args = process.argv.slice(2);
  
  if (args.length === 0 || args[0] === '--help' || args[0] === '-h') {
    console.log('Usage: node scripts/deploy_dex_imp.js <chain> [options]');
    console.log('');
    console.log('Deploy DexRouter contract using Foundry');
    console.log('');
    console.log('Options:');
    console.log('  --broadcast    Actually broadcast transactions (default: simulation only)');
    console.log('  --dry-run      Show command without executing');
    console.log('');
    console.log('Chain-specific arguments (automatically applied):');
    for (const [chain, chainArgs] of Object.entries(CHAIN_DEPLOY_ARGS)) {
      console.log(`  ${chain}: ${chainArgs.join(' ')}`);
    }
    console.log('');
    console.log('Supported chains:');
    console.log(`  ${Object.keys(CHAINS).join(', ')}`);
    console.log('');
    console.log('Examples:');
    console.log('  node scripts/deploy_dex_imp.js arb                    # Simulate deployment on Arbitrum');
    console.log('  node scripts/deploy_dex_imp.js arb --broadcast        # Deploy on Arbitrum');
    console.log('  node scripts/deploy_dex_imp.js conflux --broadcast    # Deploy on Conflux (with --gas-estimate-multiplier 500)');
    console.log('  node scripts/deploy_dex_imp.js metis --broadcast      # Deploy on Metis (with --legacy)');
    console.log('');
    console.log('After deployment, run:');
    console.log('  node scripts/foundry_broadcast_record.js <chain>      # Record addresses to base.js');
    console.log('  node scripts/verify_via_foundry.js <chain>            # Verify contracts');
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
  buildDeployCommand,
  CHAIN_DEPLOY_ARGS,
};

// Run CLI if called directly
if (require.main === module) {
  main();
}
