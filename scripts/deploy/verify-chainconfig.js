/**
 * verify-chainconfig — check that a chain's ChainConfig addresses are not just
 * well-formed but actually CORRECT (point to the right contracts on-chain).
 *
 * Background: the per-chain constants (_WETH / _APPROVE_PROXY / _PERMIT2 / _FF_FACTORY)
 * are read from scripts/deployed/<chain>/<env>.js and baked into ChainConfig.sol as
 * compile-time `constant`s (no getters). chainConfigGen.validateValues() only checks
 * their SHAPE (non-zero, 20 bytes). A typo'd-but-valid address therefore compiles in
 * silently and can't be eth_call'd back. This module adds the missing identity layer.
 *
 * Two layers, returning structured { errors, warnings, onchainSkipped }:
 *   - offline (always): chainId double-source agreement, EIP-55 checksum, permit2
 *     canonical, WETH cross-chain reuse.
 *   - on-chain (when an RPC is reachable; otherwise skipped with a loud warning):
 *     code presence, TokenApproveProxy.tokenApprove() == base.tokenApprove (the fund
 *     gate), WETH decimals/symbol, Permit2 DOMAIN_SEPARATOR, provider chainId match.
 *
 * Enforcement is decided by the caller. The deploy gate (tasks/deploy-and-verify.js)
 * treats `errors` as fatal and `warnings`/`onchainSkipped` as non-blocking.
 */
const { ethers } = require("ethers");
const { loadDeployed } = require("./deployedEnv");
const { CHAINS } = require("./verify_via_foundry");

// Permit2 is deployed at the same deterministic address on virtually every chain.
const CANONICAL_PERMIT2 = "0x000000000022D473030F116dDEE9F6B43aC78BA3";
// Standard OP-stack predeploy WETH — legitimately identical across all OP-stack chains,
// so sharing it is expected, not a copy-paste error.
const OP_STACK_WETH = "0x4200000000000000000000000000000000000006";
const ZERO_ADDR = "0x0000000000000000000000000000000000000000";

const ADDR_RE = /^0x[0-9a-fA-F]{40}$/;
const FF_FACTORY_RE = /^0xff[0-9a-fA-F]{62}$/;

const eqAddr = (a, b) => !!a && !!b && a.toLowerCase() === b.toLowerCase();
const isZero = (a) => !a || /^0x0+$/.test(a);

// Strip env/network suffixes so eth and eth_dev collapse to the same logical chain
// (they SHOULD share a WETH; that is not a misconfig).
const baseName = (n) => n.replace(/_(dev|test|testnet|sepolia|goerli|mumbai)$/i, "").toLowerCase();

function withTimeout(promise, ms, label) {
  let t;
  const timeout = new Promise((_, rej) => { t = setTimeout(() => rej(new Error(`${label} timed out after ${ms}ms`)), ms); });
  return Promise.race([promise, timeout]).finally(() => clearTimeout(t));
}

// Condense ethers' very verbose call errors to one short reason. Prefers the JSON-RPC
// error message embedded in the response body when present.
function shortErr(e) {
  const body = e && e.error && e.error.body;
  if (typeof body === "string") {
    const m = body.match(/"message"\s*:\s*"([^"]+)"/);
    if (m) return m[1];
  }
  return (e && (e.reason || e.code)) || (e && e.message ? String(e.message).slice(0, 120) : String(e));
}

// A call that throws means the node could not give us an answer (method unavailable,
// gas-limit, timeout, transport error) OR the target reverted. Either way we could not
// *confirm* identity, so it degrades to a warning — never a hard block. Only a call that
// SUCCEEDS and returns a contradicting value is a hard error.
function isProviderRefusal(e) {
  const s = `${(e && e.code) || ""} ${shortErr(e)}`.toLowerCase();
  return /server_error|timeout|network|does not exist|not available|exceeds provider limit|bad response|missing revert data|-3260[0-9]/.test(s);
}

/**
 * @param {string} chain  resolved chain name (key in CHAINS / scripts/deployed)
 * @param {string} env    'prod' | 'stg'
 * @param {{rpcUrl?: string|null, timeoutMs?: number}} [opts]
 * @returns {Promise<{chain:string, env:string, errors:string[], warnings:string[], onchainSkipped:boolean}>}
 */
async function verifyChainConfig(chain, env, opts = {}) {
  const { rpcUrl = null, timeoutMs = 10000 } = opts;
  const errors = [];
  const warnings = [];
  let onchainSkipped = false;

  const base = loadDeployed(chain, env);
  if (!base) {
    errors.push(`no deployed addresses for ${chain}/${env} (expected scripts/deployed/${chain}/${env === "stg" ? "stg" : "base"}.js)`);
    return { chain, env, errors, warnings, onchainSkipped };
  }

  // The exact values gen-chainconfig.js bakes into ChainConfig.sol:
  const expectedChainId = CHAINS[chain] && CHAINS[chain].chainId;
  const weth = base.wNativeToken;
  const approveProxy = base.tokenApproveProxy;
  const tokenApprove = base.tokenApprove;
  const permit2 = base.permit2 || ZERO_ADDR;
  const ffFactory = base._FF_FACTORY || "";
  const ffEmbedded = FF_FACTORY_RE.test(ffFactory) ? "0x" + ffFactory.slice(4, 44) : null;

  // ---------------------------------------------------------------- offline layer
  // chainId double-source agreement (CHAINS vs base._CACHED_CHAIN_ID).
  if (!Number.isInteger(expectedChainId) || expectedChainId <= 0) {
    errors.push(`CHAINS.${chain}.chainId is missing/invalid (${JSON.stringify(expectedChainId)})`);
  } else if (base._CACHED_CHAIN_ID == null) {
    warnings.push(`base.js has no _CACHED_CHAIN_ID — cannot cross-check against CHAINS.${chain}.chainId (${expectedChainId})`);
  } else if (Number(base._CACHED_CHAIN_ID) !== Number(expectedChainId)) {
    errors.push(`chainId mismatch: CHAINS=${expectedChainId} but base._CACHED_CHAIN_ID=${base._CACHED_CHAIN_ID}`);
  }

  // EIP-55 checksum on every configured address (getAddress throws on a bad checksum
  // or malformed value; all-lower/all-upper is accepted as un-checksummed).
  const addrFields = [
    ["wNativeToken (_WETH)", weth, true],
    ["tokenApproveProxy (_APPROVE_PROXY)", approveProxy, true],
    ["tokenApprove", tokenApprove, false],
    ["permit2 (_PERMIT2)", isZero(permit2) ? null : permit2, false],
    ["_FF_FACTORY factory", ffEmbedded, false],
  ];
  for (const [label, val, required] of addrFields) {
    if (val == null || val === "") { if (required) errors.push(`${label} is required but missing`); continue; }
    try { ethers.utils.getAddress(val); }
    catch { errors.push(`${label} is not a valid / well-checksummed address: ${val}`); }
  }
  if (ffFactory && ffFactory !== "" && !FF_FACTORY_RE.test(ffFactory)) {
    errors.push(`_FF_FACTORY must be 32 bytes starting with 0xff: ${ffFactory}`);
  }

  // permit2 canonical (warning — a chain may legitimately have a non-canonical deploy).
  if (!isZero(permit2) && !eqAddr(permit2, CANONICAL_PERMIT2)) {
    warnings.push(`permit2 ${permit2} is NOT the canonical Permit2 (${CANONICAL_PERMIT2}) — confirm this chain really has a different deploy`);
  }

  // WETH reused by another (different) chain — usually a copy-paste error.
  if (ADDR_RE.test(weth || "") && !eqAddr(weth, OP_STACK_WETH)) {
    const sharers = Object.keys(CHAINS)
      .filter((c) => c !== chain && baseName(c) !== baseName(chain))
      .filter((c) => { const b = loadDeployed(c, env); return b && eqAddr(b.wNativeToken, weth); });
    if (sharers.length) warnings.push(`wNativeToken ${weth} is also used by: ${sharers.join(", ")} — verify it is the correct WETH for ${chain}`);
  }

  // ---------------------------------------------------------------- on-chain layer
  if (!rpcUrl) {
    onchainSkipped = true;
    warnings.push(`no RPC url for ${chain} — on-chain identity checks skipped`);
    return { chain, env, errors, warnings, onchainSkipped };
  }

  const provider = new ethers.providers.JsonRpcProvider({ url: rpcUrl, timeout: timeoutMs });
  // Reachability probe + provider/chain identity.
  try {
    const net = await withTimeout(provider.getNetwork(), timeoutMs, "getNetwork");
    if (expectedChainId && Number(net.chainId) !== Number(expectedChainId)) {
      errors.push(`RPC reports chainId ${net.chainId} but ${chain} expects ${expectedChainId} — wrong RPC for this chain`);
    }
  } catch (e) {
    onchainSkipped = true;
    warnings.push(`RPC unreachable for ${chain} (${shortErr(e)}) — on-chain identity checks skipped`);
    return { chain, env, errors, warnings, onchainSkipped };
  }

  // getCode that SUCCEEDS and returns empty is definitive (no contract) → error.
  // getCode that THROWS means the node refused → warning (could not verify).
  const checkCode = async (label, addr, requiredMsg) => {
    try {
      const code = await withTimeout(provider.getCode(addr), timeoutMs, `getCode(${addr})`);
      if (!code || code === "0x") errors.push(`${label} ${addr} ${requiredMsg}`);
    } catch (e) {
      warnings.push(`could not fetch code for ${label} ${addr} (${shortErr(e)}) — unverified`);
    }
  };
  for (const [label, addr] of [["_WETH", weth], ["_APPROVE_PROXY", approveProxy]]) {
    if (ADDR_RE.test(addr || "")) await checkCode(label, addr, "has no code on-chain (not a contract)");
  }
  for (const [label, addr] of [["_PERMIT2", isZero(permit2) ? null : permit2], ["_FF_FACTORY factory", ffEmbedded]]) {
    if (addr) await checkCode(label, addr, "is configured but has no code on-chain");
  }

  // Fund-gate cross-check: the configured TokenApproveProxy must report the configured
  // TokenApprove. A SUCCESSFUL call returning a different address is a hard error (wrong
  // contract). A call that the node refuses degrades to a warning (identity unverified).
  if (ADDR_RE.test(approveProxy || "")) {
    try {
      const proxy = new ethers.Contract(approveProxy, ["function tokenApprove() view returns (address)"], provider);
      const onchainTA = await withTimeout(proxy.tokenApprove(), timeoutMs, "tokenApprove()");
      if (!ADDR_RE.test(tokenApprove || "")) {
        warnings.push(`base.tokenApprove is missing — cannot cross-check; proxy.tokenApprove()=${onchainTA}`);
      } else if (!eqAddr(onchainTA, tokenApprove)) {
        errors.push(`_APPROVE_PROXY identity mismatch: ${approveProxy}.tokenApprove()=${onchainTA} but base.tokenApprove=${tokenApprove}`);
      }
    } catch (e) {
      const msg = `_APPROVE_PROXY ${approveProxy}.tokenApprove() unverified (${shortErr(e)})`;
      if (isProviderRefusal(e)) warnings.push(`${msg} — RPC refused the call`);
      else warnings.push(`${msg} — reverted; may not be a TokenApproveProxy (confirm manually)`);
    }
  }

  // WETH sanity: ERC20 decimals should be 18; symbol should be readable.
  if (ADDR_RE.test(weth || "")) {
    const werc = new ethers.Contract(weth, [
      "function decimals() view returns (uint8)",
      "function symbol() view returns (string)",
    ], provider);
    try {
      const dec = await withTimeout(werc.decimals(), timeoutMs, "decimals()");
      if (Number(dec) !== 18) warnings.push(`_WETH ${weth} decimals()=${dec} (expected 18) — confirm this is the wrapped native token`);
    } catch (e) { warnings.push(`_WETH ${weth} decimals() unverified (${shortErr(e)})`); }
    try { await withTimeout(werc.symbol(), timeoutMs, "symbol()"); }
    catch (e) { warnings.push(`_WETH ${weth} symbol() unverified (${shortErr(e)})`); }
  }

  // Permit2 identity: a real Permit2 exposes DOMAIN_SEPARATOR().
  if (!isZero(permit2)) {
    try {
      const p2 = new ethers.Contract(permit2, ["function DOMAIN_SEPARATOR() view returns (bytes32)"], provider);
      await withTimeout(p2.DOMAIN_SEPARATOR(), timeoutMs, "DOMAIN_SEPARATOR()");
    } catch (e) { warnings.push(`_PERMIT2 ${permit2} DOMAIN_SEPARATOR() unverified (${shortErr(e)})`); }
  }

  return { chain, env, errors, warnings, onchainSkipped };
}

module.exports = { verifyChainConfig, CANONICAL_PERMIT2 };
