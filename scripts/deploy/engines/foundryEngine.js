const { execSync } = require('child_process');
const path = require('path');
const { recordDeployment } = require('../foundry_broadcast_record');

const PROJECT_ROOT = path.join(__dirname, '..', '..', '..');
const DEFAULT_DEPLOY_SCRIPT = 'src/deploy/DeployDexRouter.s.sol';

/**
 * Build the `forge script` command for a foundry-engine deploy.
 * @param {string} chain - chain name (used as the foundry rpc alias)
 * @param {Object} options
 * @param {boolean} [options.broadcast]
 * @param {boolean} [options.dryRun]
 * @param {string[]} [options.forgeArgs] - extra args (e.g. ['--legacy'])
 * @param {string} [options.deployScript] - override the .s.sol path
 * @returns {string}
 */
function buildCommand(chain, options = {}) {
  const {
    broadcast = false,
    dryRun = false,
    forgeArgs = [],
    deployScript = DEFAULT_DEPLOY_SCRIPT,
  } = options;

  let cmd = `forge script ${deployScript}`;
  cmd += ` --rpc-url ${chain}`;
  if (forgeArgs.length) cmd += ` ${forgeArgs.join(' ')}`;
  if (broadcast && !dryRun) cmd += ' --broadcast';
  cmd += ' -vvvv';
  return cmd;
}

/**
 * Deploy via Foundry (`forge script`).
 * @param {string} chain
 * @param {Object} options - see buildCommand
 * @returns {Promise<{success: boolean, chain: string, command?: string, dryRun?: boolean, error?: string}>}
 */
async function deploy(chain, options = {}) {
  const { broadcast = false, dryRun = false, forgeArgs = [] } = options;

  if (forgeArgs.length) console.log(`Chain-specific forge args: ${forgeArgs.join(' ')}`);

  const cmd = buildCommand(chain, options);
  console.log('Command:');
  console.log(`  ${cmd}\n`);

  if (dryRun) {
    console.log('🔍 Dry run mode - command not executed');
    return { success: true, dryRun: true, command: cmd };
  }

  console.log('Executing deployment...\n');
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

/**
 * Record deployed addresses into deployed/<chain>/base.js by parsing forge's
 * broadcast/ output. Delegates to the shared recorder.
 * @param {string} chain
 * @param {Object} [deployResult] - result from deploy() (unused; addresses come from broadcast/)
 * @returns {Promise<{success: boolean, chain?: string, addresses?: object, error?: string}>}
 */
async function record(chain, deployResult, opts = {}) {
  return recordDeployment(chain, opts.env);
}

module.exports = {
  name: 'foundry',
  // simulate: forge runs a simulation when --broadcast is absent.
  // orchestrated: participates in the full deploy-and-verify pipeline (record + verify).
  capabilities: { simulate: true, orchestrated: true },
  deploy,
  record,
  buildCommand,
  DEFAULT_DEPLOY_SCRIPT,
};
