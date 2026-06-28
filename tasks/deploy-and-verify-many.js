/**
 * Deploy the DexRouter implementation to MANY chains IN PARALLEL.
 *
 * This is a thin orchestrator on top of the single-chain `deploy-and-verify` task.
 * It does NOT reimplement any deploy logic — for each chain it spawns
 *   `npx hardhat deploy-and-verify --network <chain> [--env <env>] [--broadcast] [--dry-run]`
 * and lets that task run the canonical 4-step pipeline (gen ChainConfig → deploy →
 * record → verify).
 *
 * WHY WORKTREES (isolation is mandatory, not an optimization)
 * -----------------------------------------------------------
 * The single-chain pipeline mutates SHARED, per-run paths:
 *   - contracts/8/libraries/ChainConfig.sol  (gitignored; regenerated per chain, baked
 *     into bytecode — every chain compiles DIFFERENT bytecode)
 *   - artifacts/ , cache/ , broadcast/        (forge out / cache / run artifacts)
 * Running N chains from the same checkout would let them clobber ChainConfig.sol and
 * race in the forge out dir. So each chain gets its own `git worktree` (a separate
 * checkout sharing the same .git), and the deploys run concurrently across worktrees.
 *
 * Each worktree is a bare checkout of HEAD, so the gitignored deps it needs are wired
 * in before running:
 *   - node_modules    -> symlink to the main repo's (huge; never copy)
 *   - lib/forge-std   -> symlink (submodule, not populated in a fresh worktree)
 *   - .env            -> copied (RPC URLs + PRIVATE_KEY; hardhat.config throws without it)
 *
 * After a broadcast deploy, the freshly recorded addresses file
 * (scripts/deployed/<chain>/{base,stg}.js — a TRACKED file) is copied back from the
 * worktree into the main checkout, since that is the only durable artifact.
 *
 * NOTE: worktrees check out HEAD — uncommitted local edits in the main tree are NOT
 * deployed. Commit first if you mean to deploy local changes.
 *
 * Usage:
 *   npx hardhat deploy-and-verify-many --chains "arb,base,op" [options]
 *
 * Options:
 *   --chains <list>     Comma/space separated chain names (required)
 *   --env <env>         prod (default) | stg                — passed through to each child
 *   --broadcast         Actually broadcast (default: simulation only)
 *   --jobs <n>          Max concurrent deploys (default: min(chains, 4))
 *   --dry-run           Show each child command without executing
 *   --keep-worktrees    Do not remove worktrees afterwards (for debugging)
 *
 * Examples:
 *   npx hardhat deploy-and-verify-many --chains "arb,base,op"                       # simulate 3 chains
 *   npx hardhat deploy-and-verify-many --chains "arb,base,op" --broadcast           # prod deploy
 *   npx hardhat deploy-and-verify-many --chains "arb,base" --env stg --broadcast    # staging deploy
 *   npx hardhat deploy-and-verify-many --chains "eth,bsc,polygon,base" --jobs 2 --broadcast
 */

const fs = require("fs");
const os = require("os");
const path = require("path");
const { spawn, execFileSync } = require("child_process");

const PROJECT_ROOT = path.join(__dirname, "..");

task("deploy-and-verify-many", "Deploy DexRouter to many chains in parallel (isolated git worktrees)")
  .addParam("chains", "Comma/space separated chain names, e.g. \"arb,base,op\"")
  .addFlag("broadcast", "Actually broadcast transactions (default: simulation only)")
  .addFlag("dryRun", "Show each child command without executing")
  .addFlag("keepWorktrees", "Do not remove the per-chain worktrees afterwards (debugging)")
  .addOptionalParam("env", "Target environment: prod (default) | stg")
  .addOptionalParam("jobs", "Max concurrent deploys (default: min(#chains, 4))")
  .setAction(async (taskArgs, hre) => {
    const { broadcast, dryRun, keepWorktrees } = taskArgs;

    const { CHAINS, resolveChain } = require("../scripts/deploy/verify_via_foundry");
    const { getDeployConfig } = require("../scripts/deploy/deploy.config");
    const { getEngine } = require("../scripts/deploy/engines");
    const { normalizeEnv, deployedPath } = require("../scripts/deploy/deployedEnv");

    // ---- Resolve & validate the env --------------------------------------------------
    const env = normalizeEnv(taskArgs.env); // throws on unknown env

    // ---- Resolve & validate the chain list -------------------------------------------
    const requested = String(taskArgs.chains)
      .split(/[,\s]+/)
      .map((s) => s.trim())
      .filter(Boolean);

    if (requested.length === 0) {
      throw new Error(`No chains given. Use --chains "arb,base,op".`);
    }

    const seen = new Set();
    const chains = [];
    for (const raw of requested) {
      const chain = resolveChain(raw);
      if (!chain) {
        throw new Error(
          `Unknown chain "${raw}". Supported: ${Object.keys(CHAINS).join(", ")}`
        );
      }
      // Reject engines the single-chain pipeline itself refuses (e.g. hardhat-zksync),
      // so we fail before creating any worktree rather than mid-flight.
      const engine = getEngine(getDeployConfig(chain).engine);
      if (!engine.capabilities || !engine.capabilities.orchestrated) {
        throw new Error(
          `Chain "${chain}" uses the "${getDeployConfig(chain).engine}" engine, which is not ` +
            `orchestrated by deploy-and-verify. Deploy it via its standalone flow instead.`
        );
      }
      if (seen.has(chain)) continue; // de-dupe
      seen.add(chain);
      chains.push(chain);
    }

    const jobs = Math.max(1, Math.min(parseInt(taskArgs.jobs, 10) || 4, chains.length));

    // ---- Pre-flight: the gitignored deps a fresh worktree will be missing ------------
    const requiredDeps = [
      { p: path.join(PROJECT_ROOT, "node_modules"), kind: "symlink", label: "node_modules" },
      { p: path.join(PROJECT_ROOT, "lib", "forge-std"), kind: "symlink", label: "lib/forge-std" },
      { p: path.join(PROJECT_ROOT, ".env"), kind: "copy", label: ".env" },
    ];
    for (const dep of requiredDeps) {
      if (!fs.existsSync(dep.p)) {
        throw new Error(
          `Missing "${dep.label}" in the repo (${dep.p}). It is required to seed each ` +
            `worktree. Run \`npm install\` / \`git submodule update --init\` / create \`.env\` first.`
        );
      }
    }

    // Warn (do not block) if the working tree is dirty — worktrees deploy HEAD, not edits.
    let dirty = "";
    try {
      dirty = execFileSync("git", ["status", "--porcelain"], { cwd: PROJECT_ROOT, encoding: "utf8" }).trim();
    } catch (_) {}

    const ts = new Date().toISOString().replace(/[:.]/g, "-");
    // Worktree base MUST stay short: forge derives a Unix-domain socket path from the
    // project dir, and macOS caps sun_path at ~104 chars. The old timestamped dir name
    // (os.tmpdir()/dexrouter-deploy-<ISO>/<chain>) overflowed it and surfaced as a misleading
    // "Internal transport error: local socket name length exceeds capacity" for any chain
    // whose --rpc-url alias forge can't resolve. os.tmpdir() itself is writable (the sandbox
    // blocks $HOME), so keep tmpdir but use a tiny, un-timestamped subdir; cross-run
    // idempotency is handled by removeWorktree() before each add.
    const wtBase = path.join(os.tmpdir(), "dxr");
    const logDir = path.join(PROJECT_ROOT, "deploy-logs", ts);
    fs.mkdirSync(logDir, { recursive: true });

    console.log(`\n${"=".repeat(64)}`);
    console.log(`🚀 Parallel DexRouter deployment`);
    console.log(`${"=".repeat(64)}`);
    console.log(`  Chains (${chains.length}): ${chains.join(", ")}`);
    console.log(`  Env:           ${env}`);
    console.log(`  Broadcast:     ${broadcast ? "Yes" : "No (simulation only)"}`);
    console.log(`  Dry run:       ${dryRun ? "Yes" : "No"}`);
    console.log(`  Concurrency:   ${jobs}`);
    console.log(`  Worktree base: ${wtBase}`);
    console.log(`  Logs:          ${logDir}`);
    if (dirty) {
      console.log(
        `\n  ⚠️  Working tree has uncommitted changes — worktrees deploy committed HEAD, ` +
          `NOT your local edits. Commit first if those edits should ship.`
      );
    }
    if (broadcast && env === "prod") {
      console.log(
        `\n  ⚠️  prod broadcast: this deploys NEW non-proxy implementations. Going live still ` +
          `requires the TokenApproveProxy.addProxy whitelist step via the Boss system.`
      );
    }

    // ---- Worktree lifecycle helpers --------------------------------------------------
    function git(args, opts = {}) {
      return execFileSync("git", args, { cwd: PROJECT_ROOT, encoding: "utf8", ...opts });
    }

    function setupWorktree(chain) {
      const wt = path.join(wtBase, chain);
      // Idempotent: the worktree path is no longer timestamped, so clear any stale
      // registration/dir left by a previous (e.g. interrupted) run before re-adding.
      removeWorktree(wt);
      // Detached worktree at HEAD: independent working dir, shared .git.
      git(["worktree", "add", "--detach", "--force", wt, "HEAD"], { stdio: "pipe" });

      // node_modules: symlink (never copy — too large).
      fs.symlinkSync(path.join(PROJECT_ROOT, "node_modules"), path.join(wt, "node_modules"), "dir");

      // lib/forge-std: a fresh worktree leaves the submodule mountpoint empty; replace
      // with a symlink to the main checkout's populated copy.
      const wtForgeStd = path.join(wt, "lib", "forge-std");
      fs.rmSync(wtForgeStd, { recursive: true, force: true });
      fs.mkdirSync(path.dirname(wtForgeStd), { recursive: true });
      fs.symlinkSync(path.join(PROJECT_ROOT, "lib", "forge-std"), wtForgeStd, "dir");

      // .env: copy (contains RPC URLs + PRIVATE_KEY the child hardhat config needs).
      fs.copyFileSync(path.join(PROJECT_ROOT, ".env"), path.join(wt, ".env"));

      return wt;
    }

    function removeWorktree(wt) {
      try {
        git(["worktree", "remove", "--force", wt], { stdio: "pipe" });
      } catch (_) {
        // Fall back to manual cleanup + prune if git refuses (e.g. symlink quirks).
        try {
          fs.rmSync(wt, { recursive: true, force: true });
        } catch (_) {}
        try {
          git(["worktree", "prune"], { stdio: "pipe" });
        } catch (_) {}
      }
    }

    // ---- Run one chain's deploy in its worktree --------------------------------------
    function runChain(chain) {
      return new Promise((resolve) => {
        const started = Date.now();
        const logPath = path.join(logDir, `${chain}.log`);
        let wt;
        try {
          wt = setupWorktree(chain);
        } catch (e) {
          resolve({ chain, ok: false, durationMs: 0, logPath, error: `worktree setup failed: ${e.message}` });
          return;
        }

        const args = ["hardhat", "deploy-and-verify", "--network", chain, "--env", env];
        if (broadcast) args.push("--broadcast");
        if (dryRun) args.push("--dry-run");

        const log = fs.createWriteStream(logPath, { flags: "a" });
        log.write(`$ npx ${args.join(" ")}\n(cwd: ${wt})\n\n`);
        console.log(`  ▶️  [${chain}] start  → ${logPath}`);

        const child = spawn("npx", args, {
          cwd: wt,
          env: { ...process.env, HARDHAT_NETWORK: chain },
        });
        child.stdout.on("data", (d) => log.write(d));
        child.stderr.on("data", (d) => log.write(d));

        const finish = (ok, error) => {
          log.end();
          const durationMs = Date.now() - started;

          // On a real broadcast success, copy the recorded addresses file back to main.
          let recordedBack = false;
          if (ok && broadcast && !dryRun) {
            try {
              const rel = path.relative(PROJECT_ROOT, deployedPath(chain, env));
              const src = path.join(wt, rel);
              const dst = path.join(PROJECT_ROOT, rel);
              if (fs.existsSync(src)) {
                fs.copyFileSync(src, dst);
                recordedBack = true;
              }
            } catch (e) {
              error = `deploy ok but copy-back of addresses failed: ${e.message}`;
              ok = false;
            }
          }

          if (!keepWorktrees) removeWorktree(wt);
          const icon = ok ? "✅" : "❌";
          console.log(
            `  ${icon} [${chain}] ${ok ? "done" : "FAILED"} (${(durationMs / 1000).toFixed(1)}s)` +
              (recordedBack ? " · addresses recorded" : "") +
              (error ? ` · ${error}` : "")
          );
          resolve({ chain, ok, durationMs, logPath, error, recordedBack, wt: keepWorktrees ? wt : undefined });
        };

        child.on("error", (e) => finish(false, `spawn failed: ${e.message}`));
        child.on("close", (code) => finish(code === 0, code === 0 ? undefined : `exit code ${code}`));
      });
    }

    // ---- Bounded-concurrency pool ----------------------------------------------------
    const results = [];
    let cursor = 0;
    async function worker() {
      while (cursor < chains.length) {
        const chain = chains[cursor++];
        results.push(await runChain(chain));
      }
    }
    await Promise.all(Array.from({ length: jobs }, () => worker()));

    // Best-effort prune of the shared worktree base dir.
    if (!keepWorktrees) {
      try {
        fs.rmSync(wtBase, { recursive: true, force: true });
      } catch (_) {}
      try {
        git(["worktree", "prune"], { stdio: "pipe" });
      } catch (_) {}
    }

    // ---- Summary ---------------------------------------------------------------------
    results.sort((a, b) => chains.indexOf(a.chain) - chains.indexOf(b.chain));
    const ok = results.filter((r) => r.ok);
    const failed = results.filter((r) => !r.ok);

    console.log(`\n${"=".repeat(64)}`);
    console.log(`📊 Summary  (${ok.length}/${results.length} ok)`);
    console.log(`${"=".repeat(64)}`);
    for (const r of results) {
      const icon = r.ok ? "✅" : "❌";
      const dur = `${(r.durationMs / 1000).toFixed(1)}s`.padStart(7);
      console.log(`  ${icon} ${r.chain.padEnd(12)} ${dur}  ${r.error ? "— " + r.error : ""}`);
    }
    console.log(`\n  Logs: ${logDir}`);
    if (keepWorktrees) {
      console.log(`  Worktrees kept under: ${wtBase}`);
    }

    if (broadcast && !dryRun && ok.length > 0) {
      console.log(`\nNext steps for the ${ok.length} successful chain(s):`);
      if (env === "prod") {
        console.log(`  • Add each new DexRouter impl to TokenApproveProxy whitelist (addProxy) via Boss.`);
      } else {
        console.log(`  • Mount each new impl on the existing proxy (ProxyAdmin.upgrade) via Boss.`);
      }
      console.log(`  • Review the updated scripts/deployed/<chain>/${env === "stg" ? "stg" : "base"}.js files.`);
    }

    if (failed.length > 0) {
      throw new Error(
        `${failed.length} chain(s) failed: ${failed.map((r) => r.chain).join(", ")}. ` +
          `See per-chain logs in ${logDir}.`
      );
    }
  });
