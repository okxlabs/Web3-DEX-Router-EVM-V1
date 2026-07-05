/**
 * Sourcify v2 verification — a direct-API alternative to forge's built-in sourcify verifier.
 *
 * WHY this exists (not just `forge verify-contract --verifier sourcify`):
 *   - Some explorers (Cronos) sit behind Cloudflare, whose WAF deterministically blocks the
 *     large standard-json verification POST (403 challenge on any body once real source pushes
 *     it past ~90 KB — content + size, not size alone; browser headers/multipart don't help).
 *     Sourcify is a different host (sourcify.dev), so it sidesteps the CF block entirely, and
 *     explorers that ingest Sourcify matches (Cronos among them) then show the source.
 *   - forge's sourcify path targets the legacy Sourcify API and does an etherscan-style ABI
 *     pre-check that misfires on some setups. This talks to the current v2 API directly.
 *
 * Library linking: DexRouter bakes its 5 router-library addresses into the on-chain bytecode.
 * Sourcify auto-detects those from the placeholder positions and back-fills them, so the
 * standard-json needs no explicit `libraries` — `forge --show-standard-json-input` output
 * (even with empty settings.libraries) exact-matches. Verified 6/6 on Cronos (2026-07).
 */
const { execSync } = require('child_process');
const path = require('path');

const PROJECT_ROOT = path.join(__dirname, '..', '..');
const COMPILER_VERSION = 'v0.8.17+commit.8df45f5f';
const POLL_INTERVAL_MS = 3000;
const POLL_MAX_ATTEMPTS = 40; // ~2 min

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

/** Is this address already verified on Sourcify for the chain? Returns the match string or null. */
async function sourcifyMatch(serverUrl, chainId, address) {
  try {
    const r = await fetch(`${serverUrl}/v2/contract/${chainId}/${address}`).then((x) => x.json());
    return r && r.match ? r.match : null;
  } catch {
    return null;
  }
}

/**
 * Verify one contract on Sourcify v2. Shell-free (no CF-blocked host involved) — returns the
 * same { success, output } shape executeCommand uses so the caller can treat it uniformly.
 * @param {string} serverUrl - Sourcify server (e.g. https://sourcify.dev/server)
 * @param {number|string} chainId
 * @param {string} address
 * @param {string} contractIdentifier - e.g. "contracts/8/DexRouter.sol:DexRouter"
 * @returns {Promise<{success: boolean, output: string}>}
 */
async function verifyViaSourcify(serverUrl, chainId, address, contractIdentifier) {
  const existing = await sourcifyMatch(serverUrl, chainId, address);
  if (existing) return { success: true, output: `already verified on Sourcify (${existing})` };

  let stdJson;
  try {
    const raw = execSync(
      `forge verify-contract ${address} ${contractIdentifier} --show-standard-json-input`,
      { cwd: PROJECT_ROOT, encoding: 'utf8', maxBuffer: 256 * 1024 * 1024 }
    );
    stdJson = JSON.parse(raw);
  } catch (e) {
    return { success: false, output: `failed to build standard-json: ${e.message}` };
  }

  let verificationId;
  try {
    const sub = await fetch(`${serverUrl}/v2/verify/${chainId}/${address}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ stdJsonInput: stdJson, compilerVersion: COMPILER_VERSION, contractIdentifier }),
    });
    const subJson = await sub.json();
    // Some Sourcify errors mean "nothing to do" rather than a real failure.
    if (subJson.customCode === 'already_verified' || /already.*verified/i.test(subJson.message || '')) {
      return { success: true, output: 'already verified on Sourcify' };
    }
    if (!subJson.verificationId) {
      return { success: false, output: `submit rejected: HTTP ${sub.status} ${JSON.stringify(subJson).slice(0, 300)}` };
    }
    verificationId = subJson.verificationId;
  } catch (e) {
    return { success: false, output: `submit failed: ${e.message}` };
  }

  for (let i = 0; i < POLL_MAX_ATTEMPTS; i++) {
    await sleep(POLL_INTERVAL_MS);
    let job;
    try {
      job = await fetch(`${serverUrl}/v2/verify/${verificationId}`).then((x) => x.json());
    } catch {
      continue; // transient — keep polling
    }
    if (!job.isJobCompleted) continue;
    const c = job.contract || {};
    const match = c.match || c.runtimeMatch || c.creationMatch;
    if (match) return { success: true, output: `Sourcify ${match}` };
    const err = (job.error && (job.error.message || job.error.customCode)) || 'no match (bytecode differs)';
    return { success: false, output: `Sourcify verification failed: ${err}` };
  }
  return { success: false, output: 'Sourcify verification timed out (still pending)' };
}

module.exports = { verifyViaSourcify, sourcifyMatch, SOURCIFY_COMPILER_VERSION: COMPILER_VERSION };
