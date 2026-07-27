/**
 * TVM compile helpers for the TRON deploy flow.
 *
 * TRON contracts are compiled with the official TRON Solidity compiler fork
 * (tronprotocol/solidity), NOT vanilla solc: the fork removed the `ether`/`gwei`
 * unit denominations and its version line has no 0.8.17 (…0.8.11 → 0.8.18 → 0.8.20+).
 * 0.8.18 is pinned here: nearest to the repo's 0.8.17 with no breaking language
 * changes, and it predates the 0.8.20 Shanghai default (PUSH0) that TVM may lack.
 *
 * The wasm (soljson) build is used instead of a native binary so the compiler runs
 * inside the node process — no downloaded-executable hurdles.
 *
 * The compile input is a `forge flatten` single file passed through cleanForTronSolc()
 * — the same transform set validated against the v1.0.8 TRON deployment:
 *   1. deduplicate SPDX license identifiers (flatten concatenates one per source)
 *   2. drop `pragma abicoder v2;` lines (tron-solc rejects them)
 *   3. rewrite the forge-merged pragma (e.g. `=0.8.17 >=0.8.17 ^0.8.0`) to ^0.8.0
 *      (no 0.8.17 tron-solc exists to satisfy an exact-version pragma)
 *   4. `1 ether` -> `10 ** 18` (unit denominations removed from tron-solc)
 */
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const PROJECT_ROOT = path.join(__dirname, '..', '..', '..');

const TRON_SOLC_VERSION = 'v0.8.18+commit.f18bedfe';
const TRON_SOLC_URL =
  `https://raw.githubusercontent.com/tronprotocol/solc-bin/main/wasm/soljson-${encodeURIComponent(TRON_SOLC_VERSION)}.js`;
// gitignored cache — survives checkouts, re-downloaded when absent
const TRON_SOLC_PATH = path.join(PROJECT_ROOT, 'cache', 'tron-solc', `soljson-${TRON_SOLC_VERSION}.js`);

/** Apply the TVM source transforms to a flattened solidity source string. */
function cleanForTronSolc(source) {
  const lines = source.split('\n');
  let spdxSeen = false;
  let cleaned = lines
    .filter((l) => {
      if (/SPDX-License-Identifier/.test(l)) {
        if (spdxSeen) return false;
        spdxSeen = true;
        return true;
      }
      if (/^\s*pragma\s+abicoder\s+v2\s*;/.test(l)) return false;
      return true;
    })
    .join('\n');
  cleaned = cleaned.replace(/^pragma solidity .*$/m, 'pragma solidity ^0.8.0;');
  cleaned = cleaned.replace(/\b1 ether\b/g, '10 ** 18');

  const leftover = cleaned.match(/\b[0-9_]+ (ether|gwei)\b/g);
  if (leftover) {
    throw new Error(
      `cleanForTronSolc: unhandled unit denominations remain (tron-solc rejects them): ${[...new Set(leftover)].join(', ')}`
    );
  }
  return cleaned;
}

/** Download the tron-solc soljson build into the cache if absent; return its path. */
function ensureTronSolc() {
  if (fs.existsSync(TRON_SOLC_PATH)) return TRON_SOLC_PATH;
  fs.mkdirSync(path.dirname(TRON_SOLC_PATH), { recursive: true });
  console.log(`Downloading tron-solc ${TRON_SOLC_VERSION} (wasm) ...`);
  execSync(`curl -sL --fail -o "${TRON_SOLC_PATH}" "${TRON_SOLC_URL}"`, { stdio: 'inherit' });
  const size = fs.statSync(TRON_SOLC_PATH).size;
  if (size < 1_000_000) {
    fs.rmSync(TRON_SOLC_PATH);
    throw new Error(`tron-solc download looks truncated (${size} bytes) — retry or fetch manually from ${TRON_SOLC_URL}`);
  }
  console.log(`  cached at ${path.relative(PROJECT_ROOT, TRON_SOLC_PATH)} (${(size / 1e6).toFixed(1)} MB)`);
  return TRON_SOLC_PATH;
}

/**
 * Compile a single (flattened, cleaned) source with tron-solc.
 * @param {string} sourceName - key for the standard-json sources map (also the artifact key)
 * @param {string} source - cleaned solidity source
 * @returns {{contracts: Object, errors: Array}} contracts = standard-json output for sourceName
 */
function compileWithTronSolc(sourceName, source) {
  const soljson = require(ensureTronSolc());
  const compile = soljson.cwrap('solidity_compile', 'string', ['string', 'number', 'number']);
  const input = {
    language: 'Solidity',
    sources: { [sourceName]: { content: source } },
    settings: {
      optimizer: { enabled: true, runs: 200 }, // must match foundry.toml for byte-comparable output
      outputSelection: { '*': { '*': ['abi', 'evm.bytecode.object', 'evm.bytecode.linkReferences'] } },
    },
  };
  const out = JSON.parse(compile(JSON.stringify(input), 0, 0));
  const errors = (out.errors || []).filter((e) => e.severity === 'error');
  return { contracts: (out.contracts && out.contracts[sourceName]) || {}, errors };
}

/** forge flatten a contract into outPath and return the raw flattened source. */
function forgeFlatten(contractPath, outPath) {
  fs.mkdirSync(path.dirname(outPath), { recursive: true });
  execSync(`forge flatten ${contractPath} -o "${outPath}"`, { cwd: PROJECT_ROOT, stdio: 'pipe' });
  return fs.readFileSync(outPath, 'utf8');
}

module.exports = {
  TRON_SOLC_VERSION,
  TRON_SOLC_PATH,
  cleanForTronSolc,
  ensureTronSolc,
  compileWithTronSolc,
  forgeFlatten,
};
