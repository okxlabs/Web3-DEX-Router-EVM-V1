/**
 * Deploy the DexRouter implementation, record its addresses, and verify it.
 *
 * Note: this deploys a fresh implementation (DeployDexRouter.s.sol -> `new DexRouter`)
 * and verifies it. It does NOT perform a proxy upgrade — that is a separate step
 * (see scripts/23_upgrade.js).
 *
 * Usage:
 *   npx hardhat deploy-and-verify --network <chain> [options]
 *
 * Options:
 *   --network <chain>   Target network (arb, base, eth, bsc, op, polygon, etc.)
 *   --broadcast         Actually broadcast transactions (default: simulation only)
 *   --dry-run           Show commands without executing
 *
 * Examples:
 *   npx hardhat deploy-and-verify --network arb                 # Simulate
 *   npx hardhat deploy-and-verify --network arb --broadcast     # Deploy
 */


// Note: per-chain constants are generated into the gitignored ChainConfig.sol by
// gen-chainconfig.js (Step 1). Nothing tracked is mutated, so there is no save/restore step.

task("deploy-and-verify", "Deploy the DexRouter implementation, record addresses, and verify contracts")
  .addFlag("broadcast", "Actually broadcast transactions (default: simulation only)")
  .addFlag("dryRun", "Show commands without executing")
  .addOptionalParam("env", "Target environment: prod (default) | stg")
  .setAction(async (taskArgs, hre) => {
    const { deployDexRouter } = require('../scripts/deploy/deploy_dex_imp');
    const { verifyContracts, CHAINS, resolveChain } = require('../scripts/deploy/verify_via_foundry');
    const { getDeployConfig } = require('../scripts/deploy/deploy.config');
    const { getEngine } = require('../scripts/deploy/engines');
    const { generate } = require('../scripts/deploy/gen-chainconfig');
    const { normalizeEnv } = require('../scripts/deploy/deployedEnv');

    try {
      const { broadcast, dryRun } = taskArgs;
      const env = normalizeEnv(taskArgs.env); // throws on unknown env
      
      // Get network name from Hardhat (specified via --network parameter)
      const network = hre.network.name;
      
      // Validate chain name
      const chain = resolveChain(network);
      if (!chain) {
        console.error(`❌ Unknown chain: "${network}"`);
        console.error(`Supported chains: ${Object.keys(CHAINS).join(', ')}`);
        console.error(`\nPlease use --network parameter to specify network, e.g.:`);
        console.error(`  npx hardhat deploy-and-verify --network arb --broadcast`);
        return;
      }

      const chainConfig = CHAINS[chain];

      // Resolve the deploy engine and refuse engines that aren't wired into this
      // orchestration (e.g. hardhat-zksync) BEFORE deploying — so we never deploy and
      // then break at the record step. Such chains use their own standalone flow.
      const deployConfig = getDeployConfig(chain);
      const engine = getEngine(deployConfig.engine);
      if (!engine.capabilities || !engine.capabilities.orchestrated) {
        console.error(`❌ Chain "${chain}" uses the "${deployConfig.engine}" engine, which is not orchestrated by deploy-and-verify.`);
        console.error(`   This pipeline (constant injection → deploy → record → verify) only supports foundry-family chains.`);
        console.error(`   Deploy "${chain}" via its standalone flow instead (see scripts/config/deploy.config.js).`);
        return;
      }

      console.log(`\n${'='.repeat(60)}`);
      console.log(`🚀 DexRouter Deployment - ${chain.toUpperCase()} (Chain ID: ${chainConfig.chainId})`);
      console.log(`${'='.repeat(60)}`);
      console.log(`  Engine: ${deployConfig.engine}`);
      console.log(`  Env: ${env}`);
      console.log(`  Broadcast: ${broadcast ? 'Yes' : 'No (simulation only)'}`);
      console.log(`  Dry Run: ${dryRun ? 'Yes' : 'No'}`);

      // Step 1: Generate per-chain ChainConfig.sol for (chain, env) — gitignored, nothing tracked mutated
      console.log("\n[Step 1/4] Generating per-chain constants (chain + env)...");
      try {
        generate(chain, env);
        console.log("  ✅ ChainConfig.sol generated");
      } catch (e) {
        throw new Error(`ChainConfig generation failed: ${e.message}`);
      }

      // Step 1b: Verify the just-generated ChainConfig addresses are real & correct
      // BEFORE deploying. Catches typo'd-but-valid addresses (wrong WETH / permit2 /
      // approveProxy) that the shape-only validator misses and that no getter can
      // surface post-deploy. Errors abort; on-chain checks degrade to a warning when
      // the RPC is unreachable. See scripts/deploy/verify-chainconfig.js.
      console.log("\n[Step 1b/4] Verifying ChainConfig addresses (offline + on-chain identity)...");
      {
        const { rpcUrlFor } = require('../scripts/deploy/rpc');
        const { verifyChainConfig } = require('../scripts/deploy/verify-chainconfig');
        const rpcUrl = rpcUrlFor(chain, hre, CHAINS);
        const res = await verifyChainConfig(chain, env, { rpcUrl });
        for (const w of res.warnings) console.log(`  ⚠️  ${w}`);
        if (res.onchainSkipped) {
          console.log("  ⚠️  On-chain identity checks SKIPPED (RPC unreachable) — only offline cross-checks ran.");
        }
        if (res.errors.length) {
          for (const e of res.errors) console.error(`  ❌ ${e}`);
          throw new Error(`ChainConfig verification failed (${res.errors.length} error(s)) — aborting before deploy.`);
        }
        console.log("  ✅ ChainConfig addresses verified");
      }

      // Step 2: Deploy via the chain's engine
      // Chains flagged `bigBlocks` (hyperevm) need the deployer account switched to
      // HyperCore "big blocks" (30M gas limit) for the broadcast — small blocks (2-3M)
      // cannot fit our deploy txs. The flag is account-level state on the L1, so it is
      // enabled just-in-time and ALWAYS restored afterwards (finally), keeping block
      // modes invisible to the caller. Simulations don't broadcast, so no toggle needed.
      const needsBigBlocks = !!deployConfig.bigBlocks && broadcast && !dryRun;
      let deployResult;
      if (needsBigBlocks) {
        const { setUsingBigBlocks } = require('../scripts/deploy/hyperliquidBigBlocks');
        console.log("\n[Step 2/4] Deploying DexRouter (via HyperCore big blocks)...");
        console.log("  Switching deployer to big blocks...");
        await setUsingBigBlocks(process.env.PRIVATE_KEY, true);
        console.log("  ✅ Deployer targets big blocks (30M gas limit)");
        try {
          deployResult = await deployDexRouter(chain, { broadcast, dryRun });
        } finally {
          try {
            await setUsingBigBlocks(process.env.PRIVATE_KEY, false);
            console.log("  ✅ Deployer restored to small blocks");
          } catch (e) {
            console.warn(`  ⚠️ Failed to restore small blocks: ${e.message}`);
            console.warn("     Restore manually: node scripts/deploy/hyperliquidBigBlocks.js small");
          }
        }
      } else {
        console.log("\n[Step 2/4] Deploying DexRouter...");
        deployResult = await deployDexRouter(chain, { broadcast, dryRun });
      }

      if (!deployResult.success) {
        throw new Error(`Deployment failed: ${deployResult.error || 'Unknown error'}`);
      }

      // If dry run mode, stop here
      if (dryRun) {
        console.log("\n🔍 Dry run mode - skipping remaining steps");
        return;
      }

      // If not broadcasting, stop here
      if (!broadcast) {
        console.log("\n⚠️  Simulation mode - transactions not broadcasted");
        console.log("  Use --broadcast flag to actually deploy");
        return;
      }

      // Step 3: Record deployment addresses to base.js (engine-specific)
      console.log("\n[Step 3/4] Recording deployment addresses to base.js...");
      try {
        const recordResult = await engine.record(chain, deployResult, { env });
        if (recordResult && recordResult.success === false) {
          throw new Error(recordResult.error || 'Unknown error');
        }
      } catch (e) {
        throw new Error(`Recording addresses failed: ${e.message}`);
      }

      // Step 4: Verify contracts (engine may override; default is shared forge verify)
      console.log("\n[Step 4/4] Verifying contracts...");
      try {
        const verifyResult = engine.verify
          ? await engine.verify(chain, { dryRun: false, env })
          : await verifyContracts(chain, { dryRun: false, env });

        if (verifyResult.success) {
          console.log("  ✅ All contracts verified successfully");
        } else {
          console.log("  ⚠️ Some contracts failed verification, but deployment was successful");
          console.log("  You can run verification manually later:");
          console.log(`    node scripts/deploy/verify_via_foundry.js ${chain}`);
        }
      } catch (e) {
        console.log(`  ⚠️ Verification error: ${e.message}`);
        console.log("  Deployment was successful, you can verify manually later:");
        console.log(`    node scripts/deploy/verify_via_foundry.js ${chain}`);
      }

      // Completed
      console.log(`\n${'='.repeat(60)}`);
      console.log("✅ Deployment process completed!");
      console.log(`${'='.repeat(60)}`);
      console.log("\nNext steps:");
      console.log(`  1. Check addresses: scripts/deployed/${chain}/${env === 'stg' ? 'stg' : 'base'}.js`);
      console.log(`  2. Add the new DexRouter to the TokenApproveProxy whitelist (go-live gate)`);

    } catch (error) {
      console.error(`\n❌ Deployment error: ${error.message}`);
      throw error;
    }
  });
