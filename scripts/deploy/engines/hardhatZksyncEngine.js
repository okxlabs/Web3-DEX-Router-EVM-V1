const { execSync } = require('child_process');
const path = require('path');

const PROJECT_ROOT = path.join(__dirname, '..', '..', '..');

/**
 * Build the `npx hardhat run` command for a zkSync deploy.
 * @param {string} chain
 * @param {Object} options
 * @param {string} options.script - hardhat script to run (e.g. scripts/deploy/deploy_dex_exactout_imp.js)
 * @param {string} [options.hardhatNetwork] - --network value (defaults to chain)
 * @returns {string}
 */
function buildCommand(chain, options = {}) {
  const { script, hardhatNetwork } = options;
  if (!script) {
    throw new Error(`hardhat-zksync engine: missing "script" in deploy config for chain "${chain}"`);
  }
  const network = hardhatNetwork || chain;
  return `npx hardhat run ${script} --network ${network}`;
}

/**
 * Deploy via Hardhat + @matterlabs/hardhat-zksync (zkSync chains).
 *
 * Unlike `forge script`, hardhat scripts have no simulation-only mode — running the
 * script broadcasts. So a non-broadcast, non-dry-run call is treated as a no-op
 * (nothing is sent) to avoid an accidental real deployment in "simulation" flows.
 * @param {string} chain
 * @param {Object} options - see buildCommand, plus { broadcast, dryRun }
 * @returns {Promise<{success: boolean, chain: string, command?: string, dryRun?: boolean, simulated?: boolean, error?: string}>}
 */
async function deploy(chain, options = {}) {
  const { broadcast = false, dryRun = false } = options;
  const cmd = buildCommand(chain, options);

  console.log('Command:');
  console.log(`  ${cmd}\n`);

  if (dryRun) {
    console.log('🔍 Dry run mode - command not executed');
    return { success: true, dryRun: true, command: cmd };
  }

  if (!broadcast) {
    console.log('⚠️  Hardhat has no simulation-only mode — skipping execution (no transactions sent).');
    console.log('   Use --broadcast to actually deploy on zkSync.');
    return { success: true, simulated: true, command: cmd };
  }

  console.log('Executing zkSync deployment via Hardhat...\n');
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
  'zkSync uses a separate deploy flow and is not orchestrated by deploy-and-verify. ' +
  'It deploys via `npx hardhat run scripts/deploy/deploy_dex_exactout_imp.js --network zksync`, ' +
  'produces no foundry broadcast/ artifact, and records addresses manually into ' +
  'deployed/<chain>/base.js. Wiring record/verify here is tracked as future work (see deploy.config.js).';

/**
 * Not supported: zkSync deploys do not produce a foundry broadcast/ artifact, so
 * there is no automated recorder. Surfaced explicitly rather than failing obscurely.
 */
async function record() {
  throw new Error(`hardhat-zksync engine: record() not implemented. ${SEPARATE_FLOW_MSG}`);
}

/**
 * Not supported: zkSync verification typically needs hardhat-zksync-verify, and the
 * foundry rpc alias / custom verifier path is not wired up. Surfaced explicitly.
 */
async function verify() {
  throw new Error(`hardhat-zksync engine: verify() not implemented. ${SEPARATE_FLOW_MSG}`);
}

module.exports = {
  name: 'hardhat-zksync',
  // simulate: hardhat scripts always broadcast (no dry simulation mode).
  // orchestrated: false -> deploy-and-verify refuses this engine up front (no half-run pipeline).
  capabilities: { simulate: false, orchestrated: false },
  deploy,
  record,
  verify,
  buildCommand,
};
