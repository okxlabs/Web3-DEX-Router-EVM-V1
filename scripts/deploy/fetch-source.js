/**
 * fetch-source — pull the VERIFIED source code of a deployed contract on ANY supported
 * chain, trying the best explorer provider for that chain.
 *
 * Per-chain constants (_WETH/_APPROVE_PROXY/_PERMIT2/_FF_FACTORY) are compile-time
 * `constant`s with no getters, so verified source is the only way to read what was
 * actually deployed. This unifies the heterogeneous explorers behind one call.
 *
 * Providers (tried in the order configured per chain in CHAIN_PROVIDERS):
 *   - etherscanV2     api.etherscan.io/v2 multichain (one ETHERSCAN_API_KEY, ?chainid=)
 *   - oklink          OKLink verify-contract-info (Ok-Access-Key only; XLAYERSCAN_API_KEY)
 *   - etherscanCompat any Etherscan/Blockscout-compatible getsourcecode endpoint (keyless
 *                     or with a per-chain key) — covers zkSync's API, Blockscout instances
 *   - sourcify        Sourcify server (full/partial match) — covers monad's instance
 *
 * Keys are read straight from .env (tolerating `KEY = "val"` spacing) so they never appear
 * in a shell command.
 *
 * Library:  const { fetchSource } = require('./fetch-source'); await fetchSource(chain, addr)
 *           -> { ok, via, contractName, compiler, sourceCode, reason }
 * CLI:      node scripts/deploy/fetch-source.js <chain|all> [address] [--env prod|stg] [--save <dir>]
 *           (in `all` mode, address defaults to each chain's base.newImpl)
 */
const fs = require("fs");
const path = require("path");
const https = require("https");
const { CHAINS, resolveChain } = require("./verify_via_foundry");
const { loadDeployed, normalizeEnv } = require("./deployedEnv");

// ---- env key parsing (tolerates `KEY = "val"` and `KEY="val"`) -----------------------
const ENV_RAW = fs.readFileSync(path.join(__dirname, "..", "..", ".env"), "utf8");
const envKey = (name) => ((ENV_RAW.match(new RegExp("^\\s*" + name + "\\s*=\\s*\"?([^\"\\n]+)\"?", "m")) || [])[1] || "").trim();
const ETHERSCAN_KEY = envKey("ETHERSCAN_API_KEY");
const OKLINK_KEY = envKey("XLAYERSCAN_API_KEY");

// ---- low-level GET (follows one redirect) --------------------------------------------
function httpGet(url, headers, redirectsLeft = 1) {
  return new Promise((resolve) => {
    const req = https.get(url, { headers: headers || {}, timeout: 15000 }, (res) => {
      if ([301, 302, 307, 308].includes(res.statusCode) && res.headers.location && redirectsLeft > 0) {
        res.resume();
        return resolve(httpGet(res.headers.location, headers, redirectsLeft - 1));
      }
      let d = ""; res.on("data", (c) => (d += c)); res.on("end", () => resolve({ body: d, status: res.statusCode }));
    });
    req.on("error", (e) => resolve({ body: "", status: 0, err: e.message }));
    req.on("timeout", () => { req.destroy(); resolve({ body: "", status: 0, err: "timeout" }); });
  });
}
const parse = (s) => { try { return JSON.parse(s); } catch { return null; } };

// ---- providers: each returns {contractName, compiler, sourceCode} or null ------------
async function pEtherscanV2(chainId, addr) {
  if (!ETHERSCAN_KEY) return { skip: "no ETHERSCAN_API_KEY" };
  const { body } = await httpGet(`https://api.etherscan.io/v2/api?chainid=${chainId}&module=contract&action=getsourcecode&address=${addr}&apikey=${ETHERSCAN_KEY}`);
  const j = parse(body); const r = j && j.result && j.result[0];
  if (r && r.SourceCode) return { contractName: r.ContractName, compiler: r.CompilerVersion, sourceCode: r.SourceCode };
  return { reason: `etherscanV2:${(j && j.message) || "no-source"}` };
}
async function pOklink(short, addr) {
  if (!OKLINK_KEY) return { skip: "no OKLink key" };
  const { body } = await httpGet(`https://www.oklink.com/api/v5/explorer/contract/verify-contract-info?chainShortName=${short}&contractAddress=${addr}`, { "Ok-Access-Key": OKLINK_KEY });
  const j = parse(body); const it = j && j.data && j.data[0];
  if (it && it.sourceCode) return { contractName: it.contractName, compiler: it.compilerVersion, sourceCode: it.sourceCode };
  return { reason: `oklink:${(j && (j.msg || j.code)) || "no-source"}` };
}
async function pEtherscanCompat(baseUrl, addr, key) {
  const sep = baseUrl.includes("?") ? "&" : "?";
  const { body, err } = await httpGet(`${baseUrl}${sep}module=contract&action=getsourcecode&address=${addr}${key ? "&apikey=" + key : ""}`);
  if (err) return { reason: `compat:${err}` };
  const j = parse(body); const r = j && j.result && j.result[0];
  if (r && (r.SourceCode || r.sourceCode)) return { contractName: r.ContractName, compiler: r.CompilerVersion, sourceCode: r.SourceCode || r.sourceCode };
  return { reason: `compat:${(j && j.message) || "no-source"}` };
}
async function pSourcify(server, chainId, addr) {
  const s = server.replace(/\/$/, "");
  let { body, err } = await httpGet(`${s}/v2/contract/${chainId}/${addr}?fields=sources,compilation`);
  let j = parse(body);
  if (j && j.sources) return { contractName: (j.compilation && j.compilation.name) || "?", compiler: (j.compilation && j.compilation.compilerVersion) || "?", sourceCode: JSON.stringify(j.sources) };
  ({ body, err } = await httpGet(`${s}/files/any/${chainId}/${addr}`)); // legacy API
  j = parse(body);
  if (j && (j.files || j.status === "full" || j.status === "partial")) return { contractName: "?", compiler: "?", sourceCode: JSON.stringify(j.files || j) };
  return { reason: `sourcify:${err || "no-source"}` };
}
// Blockscout's native v2 API (different shape from the etherscan-compat shim). Keyless.
async function pBlockscoutV2(host, addr) {
  const { body, err } = await httpGet(`https://${host}/api/v2/smart-contracts/${addr}`);
  if (err) return { reason: `bsv2:${err}` };
  const j = parse(body);
  if (j && j.source_code) {
    let src = j.source_code;
    if (Array.isArray(j.additional_sources)) src += "\n" + j.additional_sources.map((s) => s.source_code).join("\n");
    return { contractName: j.name, compiler: j.compiler_version, sourceCode: src };
  }
  return { reason: `bsv2:${(j && j.message) || "no-source"}` };
}

// ---- per-chain provider order --------------------------------------------------------
// Chains absent here default to [etherscanV2] (works for all etherscan-v2 multichain chains).
const CHAIN_PROVIDERS = {
  manta: ["oklink:manta"], ftm: ["oklink:ftm"], polyzkevm: ["oklink:polygon_zkevm"],
  xlayer: ["oklink:xlayer"], ethw: ["oklink:ethw", "compat:https://www.oklink.com/api"],
  zksyncEra: ["compat:https://block-explorer-api.mainnet.zksync.io/api"],
  monad: ["sourcify:https://sourcify-api-monad.blockvision.org"],
  // Blockscout / native explorers (keyless Etherscan-compatible getsourcecode). These hosts
  // may be unreachable from a restricted network; they work where egress is open.
  scroll: ["etherscanV2", "compat:https://blockscout.scroll.io/api"],
  mode: ["bsv2:explorer.mode.network", "compat:https://explorer.mode.network/api"],
  zeta: ["bsv2:zetachain.blockscout.com", "compat:https://zetachain.blockscout.com/api"],
  metis: ["bsv2:andromeda-explorer.metis.io", "bsv2:metis.routescan.io"],
  merlin: ["bsv2:scan.merlinchain.io", "compat:https://scan.merlinchain.io/api"],
  conflux: ["compat:https://evmapi.confluxscan.org/api", "compat:https://evm.confluxscan.org/api"],
  cro: ["etherscanV2", "bsv2:explorer.cronos.org"],
  iotex: ["bsv2:iotexscan.io", "compat:https://iotexscan.io/api"],
  pharos: ["bsv2:pharosscan.xyz", "compat:https://pharosscan.xyz/api"],
};

async function runProvider(spec, chain, addr) {
  if (spec === "etherscanV2") return pEtherscanV2(CHAINS[chain].chainId, addr);
  if (spec.startsWith("oklink:")) return pOklink(spec.slice(7), addr);
  if (spec.startsWith("compat:")) return pEtherscanCompat(spec.slice(7), addr);
  if (spec.startsWith("bsv2:")) return pBlockscoutV2(spec.slice(5), addr);
  if (spec.startsWith("sourcify:")) return pSourcify(spec.slice(9), CHAINS[chain].chainId, addr);
  return { reason: "unknown provider " + spec };
}

/**
 * @param {string} chain  chain name / alias
 * @param {string} [address]  contract address; defaults to base.newImpl for (chain, env)
 * @param {{env?:string}} [opts]
 * @returns {Promise<{ok:boolean, chain:string, address:string, via?:string, contractName?:string, compiler?:string, sourceCode?:string, reason?:string}>}
 */
async function fetchSource(chain, address, opts = {}) {
  const c = resolveChain(chain);
  if (!c) return { ok: false, chain, reason: `unknown chain "${chain}"` };
  const env = normalizeEnv(opts.env);
  const addr = address || (loadDeployed(c, env) || {}).newImpl;
  if (!addr) return { ok: false, chain: c, reason: "no address (pass one or set base.newImpl)" };
  const specs = CHAIN_PROVIDERS[c] || ["etherscanV2"];
  const reasons = [];
  for (const spec of specs) {
    const r = await runProvider(spec, c, addr);
    if (r && r.sourceCode) return { ok: true, chain: c, address: addr, via: spec, contractName: r.contractName, compiler: r.compiler, sourceCode: r.sourceCode };
    reasons.push(r && (r.reason || r.skip) || "?");
  }
  return { ok: false, chain: c, address: addr, reason: reasons.join(" | ") };
}

module.exports = { fetchSource, CHAIN_PROVIDERS };

// ---- CLI -----------------------------------------------------------------------------
if (require.main === module) {
  (async () => {
    const args = process.argv.slice(2);
    const env = (args.includes("--env") ? args[args.indexOf("--env") + 1] : "prod");
    const saveDir = args.includes("--save") ? args[args.indexOf("--save") + 1] : null;
    const positional = args.filter((a, i) => !a.startsWith("--") && args[i - 1] !== "--env" && args[i - 1] !== "--save");
    const which = positional[0];
    if (!which) { console.error("Usage: node scripts/deploy/fetch-source.js <chain|all> [address] [--env prod|stg] [--save <dir>]"); process.exit(1); }
    const list = which.toLowerCase() === "all" ? Object.keys(CHAINS).filter((c) => loadDeployed(c, env)) : [which];
    let ok = 0;
    for (const chain of list) {
      const r = await fetchSource(chain, list.length === 1 ? positional[1] : undefined, { env });
      if (r.ok) {
        ok++;
        console.log(`✅ ${r.chain.padEnd(12)} ${String(r.via).padEnd(22)} ${r.contractName || "?"} (${(r.sourceCode || "").length} bytes)`);
        if (saveDir) {
          fs.mkdirSync(saveDir, { recursive: true });
          fs.writeFileSync(path.join(saveDir, `${r.chain}_${r.address}.txt`), r.sourceCode);
        }
      } else {
        console.log(`❌ ${String(r.chain).padEnd(12)} ${r.reason}`);
      }
    }
    console.log(`\n${ok}/${list.length} fetched${saveDir ? ` (saved to ${saveDir})` : ""}`);
  })();
}
