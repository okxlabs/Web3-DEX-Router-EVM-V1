const fs = require("fs");
const path = require("path");

const DEPLOYED_DIR = path.join(__dirname, "..", "deployed");

// Environment is orthogonal to chain. A deploy target = (chain, env).
// The chain provides chainId / rpc / verifier; the env only selects which address set.
// prod keeps the historical base.js name; stg is a sibling stg.js in the same chain dir.
const ENV_FILE = { prod: "base.js", stg: "stg.js" };

function normalizeEnv(env) {
  const e = (env || "prod").toLowerCase();
  if (!ENV_FILE[e]) throw new Error(`Unknown env "${env}". Use: ${Object.keys(ENV_FILE).join(" | ")}`);
  return e;
}

// Resolve deployed/<chain> case-insensitively (e.g. zksyncEra -> zkSyncEra).
function resolveChainDir(chain) {
  const hit = fs.existsSync(DEPLOYED_DIR)
    ? fs.readdirSync(DEPLOYED_DIR).find((d) => d.toLowerCase() === chain.toLowerCase())
    : null;
  return path.join(DEPLOYED_DIR, hit || chain);
}

function deployedPath(chain, env) {
  return path.join(resolveChainDir(chain), ENV_FILE[normalizeEnv(env)]);
}

// Load the addresses object for (chain, env), or null if absent. Cache-busted for fresh reads.
function loadDeployed(chain, env) {
  const p = deployedPath(chain, env);
  if (!fs.existsSync(p)) return null;
  delete require.cache[require.resolve(p)];
  return require(p);
}

module.exports = { DEPLOYED_DIR, ENV_FILE, normalizeEnv, resolveChainDir, deployedPath, loadDeployed };
