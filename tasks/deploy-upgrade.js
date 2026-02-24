/**
 * Deploy DexRouter using Foundry
 * 
 * Usage:
 *   npx hardhat deploy-upgrade --network <chain> [options]
 * 
 * Options:
 *   --network <chain>   Target network (arb, base, eth, bsc, op, polygon, etc.)
 *   --broadcast         Actually broadcast transactions (default: simulation only)
 *   --dry-run           Show commands without executing
 * 
 * Examples:
 *   npx hardhat deploy-upgrade --network arb                 # Simulate
 *   npx hardhat deploy-upgrade --network arb --broadcast     # Deploy
 */


const { exec } = require('child_process');
const util = require('util');
const execPromise = util.promisify(exec);

// Files that need to be saved/restored
const FILES_TO_SAVE = [
  'contracts/8/libraries/Constants.sol',
  'contracts/8/router/UnxswapV3Router.sol',
  'contracts/8/router/UnxswapV3ExactOutRouter.sol'
];

/**
 * Restore modified files to git state
 */
async function restoreFiles() {
  try {
    const files = FILES_TO_SAVE.join(' ');
    await execPromise(`git checkout -- ${files}`);
    console.log("  ✅ Files restored");
  } catch (e) {
    console.log("  ⚠️ Warning: Could not restore files:", e.message);
  }
}

/**
 * Execute command with real-time output
 */
async function execWithOutput(cmd, options = {}) {
  return new Promise((resolve, reject) => {
    const child = exec(cmd, {
      cwd: process.cwd(),
      encoding: 'utf8',
      ...options,
    });

    let stdout = '';
    let stderr = '';

    if (child.stdout) {
      child.stdout.on('data', (data) => {
        stdout += data;
        process.stdout.write(data);
      });
    }

    if (child.stderr) {
      child.stderr.on('data', (data) => {
        stderr += data;
        process.stderr.write(data);
      });
    }

    child.on('close', (code) => {
      if (code === 0) {
        resolve({ stdout, stderr });
      } else {
        const error = new Error(`Command failed with code ${code}`);
        error.stdout = stdout;
        error.stderr = stderr;
        reject(error);
      }
    });

    child.on('error', reject);
  });
}

task("deploy-upgrade", "Deploy DexRouter using Foundry, record addresses, and verify contracts")
  .addFlag("broadcast", "Actually broadcast transactions (default: simulation only)")
  .addFlag("dryRun", "Show commands without executing")
  .setAction(async (taskArgs, hre) => {
    const { deployDexRouter } = require('../scripts/deploy_dex_imp');
    const { verifyContracts, CHAINS, resolveChain } = require('../scripts/verify_via_foundry');
    
    try {
      const { broadcast, dryRun } = taskArgs;
      
      // Get network name from Hardhat (specified via --network parameter)
      const network = hre.network.name;
      
      // Validate chain name
      const chain = resolveChain(network);
      if (!chain) {
        console.error(`❌ Unknown chain: "${network}"`);
        console.error(`Supported chains: ${Object.keys(CHAINS).join(', ')}`);
        console.error(`\nPlease use --network parameter to specify network, e.g.:`);
        console.error(`  npx hardhat deploy-upgrade --network arb --broadcast`);
        return;
      }

      const chainConfig = CHAINS[chain];

      console.log(`\n${'='.repeat(60)}`);
      console.log(`🚀 DexRouter Deployment - ${chain.toUpperCase()} (Chain ID: ${chainConfig.chainId})`);
      console.log(`${'='.repeat(60)}`);
      console.log(`  Broadcast: ${broadcast ? 'Yes' : 'No (simulation only)'}`);
      console.log(`  Dry Run: ${dryRun ? 'Yes' : 'No'}`);

      // Step 1: Git save current state
      console.log("\n[Step 1/6] Saving current state...");
      try {
        const files = FILES_TO_SAVE.join(' ');
        await execPromise(`git add ${files}`);
        console.log("  ✅ Git add completed");
      } catch (e) {
        console.log("  ⚠️ Warning: Git add failed:", e.message);
      }

      // Step 2: Run ureplace.js to replace network constants (using original Hardhat run method)
      console.log("\n[Step 2/6] Replacing network constants (ureplace.js)...");
      try {
        await hre.run("run", {
          script: "scripts/tools/ureplace.js",
        });
        console.log("  ✅ Constants replacement completed");
      } catch (e) {
        throw new Error(`ureplace.js execution failed: ${e.message}`);
      }

      // Step 3: Deploy using Foundry
      console.log("\n[Step 3/6] Deploying DexRouter using Foundry...");
      const deployResult = await deployDexRouter(chain, { broadcast, dryRun });
      
      if (!deployResult.success) {
        throw new Error(`Deployment failed: ${deployResult.error || 'Unknown error'}`);
      }

      // If dry run mode, stop here
      if (dryRun) {
        console.log("\n🔍 Dry run mode - skipping remaining steps");
        console.log("\n[Step 6/6] Restoring original files...");
        await restoreFiles();
        return;
      }

      // If not broadcasting, stop here
      if (!broadcast) {
        console.log("\n⚠️  Simulation mode - transactions not broadcasted");
        console.log("  Use --broadcast flag to actually deploy");
        console.log("\n[Step 6/6] Restoring original files...");
        await restoreFiles();
        return;
      }

      // Step 4: Record deployment addresses from broadcast to base.js
      console.log("\n[Step 4/6] Recording deployment addresses to base.js...");
      const recordCmd = `node scripts/foundry_broadcast_record.js ${chain}`;
      console.log(`  Command: ${recordCmd}\n`);
      try {
        await execWithOutput(recordCmd);
      } catch (e) {
        throw new Error(`foundry_broadcast_record.js execution failed: ${e.message}`);
      }

      // Step 5: Verify contracts
      console.log("\n[Step 5/6] Verifying contracts...");
      try {
        const verifyResult = await verifyContracts(chain, { dryRun: false });
        
        if (verifyResult.success) {
          console.log("  ✅ All contracts verified successfully");
        } else {
          console.log("  ⚠️ Some contracts failed verification, but deployment was successful");
          console.log("  You can run verification manually later:");
          console.log(`    node scripts/verify_via_foundry.js ${chain}`);
        }
      } catch (e) {
        console.log(`  ⚠️ Verification error: ${e.message}`);
        console.log("  Deployment was successful, you can verify manually later:");
        console.log(`    node scripts/verify_via_foundry.js ${chain}`);
      }

      // Step 6: Restore original files
      console.log("\n[Step 6/6] Restoring original files...");
      await restoreFiles();

      // Completed
      console.log(`\n${'='.repeat(60)}`);
      console.log("✅ Deployment process completed!");
      console.log(`${'='.repeat(60)}`);
      console.log("\nNext steps:");
      console.log(`  1. Check addresses: scripts/deployed/${chain}/base.js`);
      console.log(`  2. Upgrade proxy contract if needed`);
      
    } catch (error) {
      console.error(`\n❌ Deployment error: ${error.message}`);
      
      // Try to restore files even on error
      console.log("\nAttempting to restore files...");
      await restoreFiles();
      
      throw error;
    }
  });
