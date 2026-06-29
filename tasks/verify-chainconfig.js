/**
 * verify-chainconfig — audit per-chain ChainConfig addresses for correctness.
 *
 * Unlike chainConfigGen.validateValues() (which only checks address SHAPE), this
 * verifies the addresses actually point at the right contracts:
 *   - offline: chainId double-source agreement, EIP-55 checksum, permit2 canonical,
 *     WETH cross-chain reuse;
 *   - on-chain (when the RPC is reachable): code presence, TokenApproveProxy.tokenApprove()
 *     == base.tokenApprove (fund gate), WETH decimals/symbol, Permit2 DOMAIN_SEPARATOR.
 *
 * Usage:
 *   npx hardhat verify-chainconfig --chain arb            # one chain
 *   npx hardhat verify-chainconfig --chain all            # every chain with deployed addresses
 *   npx hardhat verify-chainconfig --chain arb --env stg  # staging address set
 *
 * Errors fail the command (exit code 1); warnings are printed but do not fail.
 * Uses --chain (NOT --network); the RPC is resolved from <CHAIN>_RPC_URL / hardhat config.
 */
const { task } = require("hardhat/config");
const { loadDeployed, normalizeEnv } = require("../scripts/deploy/deployedEnv");
const { rpcUrlFor } = require("../scripts/deploy/rpc");
const { verifyChainConfig } = require("../scripts/deploy/verify-chainconfig");

task("verify-chainconfig", "Verify per-chain ChainConfig addresses (offline + on-chain identity) for a chain or all")
  .addParam("chain", "Chain name (e.g. arb) or 'all'")
  .addOptionalParam("env", "Target environment: prod (default) | stg")
  .setAction(async (args, hre) => {
    const { CHAINS, resolveChain } = require("../scripts/deploy/verify_via_foundry");
    const env = normalizeEnv(args.env);

    let chains;
    if (args.chain.toLowerCase() === "all") {
      chains = Object.keys(CHAINS).filter((c) => loadDeployed(c, env));
    } else {
      const c = resolveChain(args.chain);
      if (!c) throw new Error(`Unknown chain "${args.chain}". Known: ${Object.keys(CHAINS).join(", ")}`);
      chains = [c];
    }

    console.log(`verify-chainconfig | env: ${env} | chains: ${chains.join(", ")}\n`);

    const results = [];
    for (const c of chains) {
      const rpcUrl = rpcUrlFor(c, hre, CHAINS);
      const r = await verifyChainConfig(c, env, { rpcUrl });
      results.push(r);

      const icon = r.errors.length ? "❌" : r.onchainSkipped ? "⚠️ " : "✅";
      const tag = r.errors.length ? "FAIL" : r.onchainSkipped ? "OFFLINE-ONLY" : "OK";
      console.log(`${icon} ${c.padEnd(12)} ${tag}`);
      for (const e of r.errors) console.log(`     ❌ ${e}`);
      for (const w of r.warnings) console.log(`     ⚠️  ${w}`);
    }

    const failed = results.filter((r) => r.errors.length);
    const skipped = results.filter((r) => !r.errors.length && r.onchainSkipped);
    const clean = results.filter((r) => !r.errors.length && !r.onchainSkipped);
    console.log(`\n${"=".repeat(60)}`);
    console.log(`Summary — total ${results.length}: ✅ ${clean.length}  ⚠️ offline-only ${skipped.length}  ❌ ${failed.length}`);

    if (failed.length) {
      process.exitCode = 1;
      throw new Error(`ChainConfig verification FAILED for: ${failed.map((r) => r.chain).join(", ")}`);
    }
  });
