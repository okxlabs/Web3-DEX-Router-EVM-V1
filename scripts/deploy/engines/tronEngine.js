const { execSync } = require('child_process');
const path = require('path');

const PROJECT_ROOT = path.join(__dirname, '..', '..', '..');

/**
 * Build the command for a TRON deploy.
 * @param {string} chain
 * @param {Object} options
 * @param {string} options.script - node script to run (scripts/deploy/deploy_dexrouter_tron.js)
 * @param {boolean} [options.broadcast] - forwarded as --broadcast (without it the script
 *   is compile-only: it produces and checks artifacts but sends nothing)
 * @returns {string}
 */
function buildCommand(chain, options = {}) {
  const { script, broadcast = false } = options;
  if (!script) {
    throw new Error(`tron engine: missing "script" in deploy config for chain "${chain}"`);
  }
  return `node ${script}${broadcast ? ' --broadcast' : ''}`;
}

/**
 * Deploy via the standalone tron-solc + tronweb script (TVM chains).
 *
 * Unlike forge there is no simulation mode on TRON, but the script itself has a safe
 * default: without --broadcast it runs the whole compile pipeline (gen ChainConfig ->
 * flatten -> TVM transforms -> tron-solc) and stops before signing anything.
 * @param {string} chain
 * @param {Object} options - see buildCommand, plus { dryRun }
 * @returns {Promise<{success: boolean, chain: string, command?: string, dryRun?: boolean, error?: string}>}
 */
async function deploy(chain, options = {}) {
  const { dryRun = false } = options;
  const cmd = buildCommand(chain, options);

  console.log('Command:');
  console.log(`  ${cmd}\n`);

  if (dryRun) {
    console.log('🔍 Dry run mode - command not executed');
    return { success: true, dryRun: true, command: cmd };
  }

  console.log('Executing TRON deployment script...\n');
  try {
    execSync(cmd, {
      cwd: PROJECT_ROOT,
      encoding: 'utf8',
      stdio: 'inherit',
      env: { ...process.env },
    });
    console.log(`\n✅ Deployment command completed for ${chain}`);
    return { success: true, chain };
  } catch (error) {
    console.error(`\n❌ Deployment failed for ${chain}`);
    console.error('Error:', error.message);
    return { success: false, chain, error: error.message };
  }
}

const SEPARATE_FLOW_MSG =
  'TRON uses a separate deploy flow and is not orchestrated by deploy-and-verify. ' +
  'It deploys via `node scripts/deploy/deploy_dexrouter_tron.js --broadcast`, produces no ' +
  'foundry broadcast/ artifact (the script records addresses into deployed/tron/base.js ' +
  'itself), and is verified manually on TronScan with the cleaned flattened source.';

/**
 * Not supported: the deploy script records addresses itself (base58 + hex) — there is no
 * foundry broadcast/ artifact to parse. Surfaced explicitly rather than failing obscurely.
 */
async function record() {
  throw new Error(`tron engine: record() not implemented. ${SEPARATE_FLOW_MSG}`);
}

/**
 * Not supported: TronScan verification is manual (flattened source + compiler v0.8.18 +
 * optimizer runs 200 + the 5 linked library addresses). The deploy script prints the
 * exact recipe at the end of a broadcast run.
 */
async function verify() {
  throw new Error(`tron engine: verify() not implemented. ${SEPARATE_FLOW_MSG}`);
}

module.exports = {
  name: 'tron',
  // simulate: the script's no-broadcast default is compile-only, not a chain simulation.
  // orchestrated: false -> deploy-and-verify refuses this engine up front (no half-run pipeline).
  capabilities: { simulate: false, orchestrated: false },
  deploy,
  record,
  verify,
  buildCommand,
};
