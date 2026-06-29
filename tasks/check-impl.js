/**
 * check-impl — verify the deployed DexRouter implementation for one chain or all.
 *
 * Usage:
 *   npx hardhat check-impl --chain arb     # one chain
 *   npx hardhat check-impl --chain all     # every chain that has a deployed newImpl
 *
 * What it does (per chain):
 *   1) regenerate the gitignored ChainConfig.sol with that chain's constants,
 *   2) compile, so the local DexRouter artifact reflects those constants,
 *   3) diff the locally compiled deployedBytecode against the on-chain code at newImpl.
 *
 * This is the only meaningful impl check for the current DexRouter: its per-chain
 * constants (_WETH / _APPROVE_PROXY / _PERMIT2 / _FF_FACTORY) are compile-time
 * `constant`s baked into the bytecode, NOT external getters — so they can only be
 * verified by comparing bytecode, not by eth_call.
 *
 * DexRouter only (ExactOut is a separate flow). Uses --chain, NOT --network.
 * Note: `--chain all` recompiles once per chain, so it is slow.
 */
const { task } = require("hardhat/config");
const path = require("path");
const { ethers } = require("ethers");
const { loadDeployed, normalizeEnv } = require("../scripts/deploy/deployedEnv");
const { rpcUrlFor } = require("../scripts/deploy/rpc");

async function checkBytecode(chain, hre, CHAINS, env) {
  const { generate } = require("../scripts/deploy/gen-chainconfig");

  const base = loadDeployed(chain, env);
  if (!base || !base.newImpl) { console.log(`⏭️  ${chain}/${env}: no newImpl, skipped`); return { chain, status: "SKIP" }; }
  const url = rpcUrlFor(chain, hre, CHAINS);
  if (!url) { console.log(`⏭️  ${chain}/${env}: no RPC url, skipped`); return { chain, status: "SKIP" }; }

  // 1) regenerate the gitignored ChainConfig.sol for (chain, env) — validated by chainConfigGen
  generate(chain, env);

  // 2) compile so the local artifact reflects this chain's constants
  await hre.run("compile");

  // 3) compare locally compiled deployedBytecode against the on-chain code
  const artPath = path.join(hre.config.paths.artifacts, "contracts/8/DexRouter.sol/DexRouter.json");
  delete require.cache[require.resolve(artPath)];
  const compiled = String(require(artPath).deployedBytecode).toLowerCase();

  const provider = new ethers.providers.JsonRpcProvider(url);
  const onchain = (await provider.getCode(base.newImpl)).toLowerCase();

  // Normalize away the expected per-deployment differences so the comparison reflects
  // logic, not addresses:
  //   - linked router libraries: artifact has `__$<hash>$__` placeholders; on-chain has
  //     the real library addresses (from base.js *Library fields).
  //   - immutable owner (constructor arg): artifact has a zero placeholder; on-chain has
  //     the real owner.
  const ZERO40 = "0".repeat(40);

  // Strip the trailing Solidity CBOR metadata (its length is the last 2 bytes). It differs
  // between the forge-deployed code and the hardhat-compiled artifact even for identical
  // logic, so we drop it before comparing.
  const stripMeta = (code) => {
    const hex = code.startsWith("0x") ? code.slice(2) : code;
    if (hex.length < 4) return hex;
    const cut = (parseInt(hex.slice(-4), 16) + 2) * 2;
    return cut > 0 && cut < 400 && cut <= hex.length ? hex.slice(0, hex.length - cut) : hex;
  };

  const owner = (base.constructorArg || "").toLowerCase().replace(/^0x/, "");
  const libAddrs = Object.entries(base)
    .filter(([k, v]) => /Library$/.test(k) && typeof v === "string" && /^0x[0-9a-fA-F]{40}$/.test(v))
    .map(([, v]) => v.toLowerCase().replace(/^0x/, ""));

  const normalize = (code, isArtifact) => {
    let c = stripMeta(code);
    if (isArtifact) c = c.replace(/__\$[0-9a-f]{34}\$__/g, ZERO40); // unlinked library placeholders
    for (const a of [owner, ...libAddrs]) if (a && /^[0-9a-f]{40}$/.test(a)) c = c.split(a).join(ZERO40);
    return c;
  };
  const a = normalize(onchain, false);
  const b = normalize(compiled, true);

  if (a === b) {
    console.log(`✅ ${chain}: bytecode identical (libraries + owner normalized) [impl ${base.newImpl}]`);
    return { chain, status: "OK" };
  }
  let diff = Math.abs(a.length - b.length);
  const n = Math.min(a.length, b.length);
  for (let i = 0; i < n; i++) if (a[i] !== b[i]) diff++;
  console.log(`❌ ${chain}: bytecode differs by ${diff} hex chars after normalization (onchain ${onchain.length} vs compiled ${compiled.length}) [impl ${base.newImpl}]`);
  console.log(`   (small residual is usually the trailing metadata hash; inspect if large)`);
  return { chain, status: "FAIL", diff };
}

task("check-impl", "Verify the deployed DexRouter bytecode matches source for a chain or all")
  .addParam("chain", "Chain name (e.g. arb) or 'all'")
  .addOptionalParam("env", "Target environment: prod (default) | stg")
  .setAction(async (args, hre) => {
    const { CHAINS, resolveChain } = require("../scripts/deploy/verify_via_foundry");
    const env = normalizeEnv(args.env);

    let chains;
    if (args.chain.toLowerCase() === "all") {
      chains = Object.keys(CHAINS).filter((c) => { const b = loadDeployed(c, env); return b && b.newImpl; });
    } else {
      const c = resolveChain(args.chain);
      if (!c) throw new Error(`Unknown chain "${args.chain}". Known: ${Object.keys(CHAINS).join(", ")}`);
      chains = [c];
    }

    console.log(`check-impl (bytecode) | env: ${env} | chains: ${chains.join(", ")}`);
    if (chains.length > 1) console.log(`⚠️  recompiles once per chain — this is slow for ${chains.length} chains.`);
    console.log("");

    const results = [];
    for (const c of chains) results.push(await checkBytecode(c, hre, CHAINS, env));

    // leave ChainConfig at eth defaults so the working tree isn't left chain-specific
    const { writeChainConfig, DEFAULT_VALUES } = require("../scripts/deploy/chainConfigGen");
    writeChainConfig(DEFAULT_VALUES);

    const ok = results.filter((r) => r.status === "OK").length;
    const fail = results.filter((r) => r.status === "FAIL").length;
    const skip = results.filter((r) => r.status === "SKIP").length;
    console.log(`\n${"=".repeat(60)}\nSummary — total ${results.length}: ✅ ${ok}  ❌ ${fail}  ⏭️ ${skip}\n(ChainConfig.sol reset to default)`);
  });
