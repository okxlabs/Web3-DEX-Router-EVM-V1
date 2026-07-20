/**
 * HyperEVM "big blocks" toggle for the deployer account.
 *
 * WHY: HyperEVM has a dual-block architecture — small blocks (~1s cadence, 2-3M gas
 * limit) and big blocks (~1min cadence, 30M gas limit). Which one an account's txs
 * land in is an ACCOUNT-LEVEL flag on HyperCore (the L1), toggled by submitting a
 * signed `evmUserModify` action to the HyperCore exchange API. Our DexRouter deploy
 * txs are ~3-4M gas each, so they physically cannot fit in a small block: without
 * this toggle every broadcast fails with `-32603: exceeds block gas limit`.
 *
 * This module signs and submits that action with the same PRIVATE_KEY the deploy
 * uses. It is wired into `deploy-and-verify` (see tasks/deploy-and-verify.js): for
 * chains flagged `bigBlocks: true` in deploy.config.js, the pipeline enables big
 * blocks right before the forge broadcast and ALWAYS restores small blocks after
 * (finally-block), so callers never need to know block modes exist.
 *
 * Signing scheme (mirrors the official hyperliquid-python-sdk `sign_l1_action`):
 *   1. msgpack(action) ++ nonce_be64 ++ 0x00        (no vault address)
 *   2. connectionId = keccak256(bytes from step 1)
 *   3. EIP-712 sign the "phantom agent" {source: 'a' (mainnet), connectionId}
 *      under domain {name: 'Exchange', version: '1', chainId: 1337, verifyingContract: 0x0}
 * The action shape is fixed, so the msgpack encoding is hand-rolled below (two-entry
 * fixmap of fixstrs + bool) instead of pulling in a msgpack dependency.
 *
 * Manual recovery CLI (e.g. if a crash skipped the restore):
 *   node scripts/deploy/hyperliquidBigBlocks.js big|small
 */

const { ethers } = require('ethers');

const EXCHANGE_URL = 'https://api.hyperliquid.xyz/exchange';

/** msgpack-encode {type: 'evmUserModify', usingBigBlocks: <bool>} (fixed shape). */
function packEvmUserModify(usingBigBlocks) {
  const fixstr = (s) => Buffer.concat([Buffer.from([0xa0 | s.length]), Buffer.from(s, 'utf8')]);
  return Buffer.concat([
    Buffer.from([0x82]), // fixmap, 2 entries (key order must match the action JSON below)
    fixstr('type'),
    fixstr('evmUserModify'),
    fixstr('usingBigBlocks'),
    Buffer.from([usingBigBlocks ? 0xc3 : 0xc2]),
  ]);
}

/**
 * Toggle the deployer account's big-blocks flag on HyperCore mainnet.
 * @param {string} privateKey - deployer key (from env; never logged)
 * @param {boolean} usingBigBlocks
 * @returns {Promise<object>} exchange API response (throws on status !== 'ok')
 */
async function setUsingBigBlocks(privateKey, usingBigBlocks) {
  if (!privateKey) {
    throw new Error('PRIVATE_KEY is not set — cannot sign the evmUserModify action');
  }
  const wallet = new ethers.Wallet(privateKey);
  const action = { type: 'evmUserModify', usingBigBlocks };
  const nonce = Date.now();

  const nonceBuf = Buffer.alloc(8);
  nonceBuf.writeBigUInt64BE(BigInt(nonce));
  const connectionId = ethers.utils.keccak256(
    Buffer.concat([packEvmUserModify(usingBigBlocks), nonceBuf, Buffer.from([0x00])])
  );

  const signature = ethers.utils.splitSignature(
    await wallet._signTypedData(
      { name: 'Exchange', version: '1', chainId: 1337, verifyingContract: ethers.constants.AddressZero },
      { Agent: [{ name: 'source', type: 'string' }, { name: 'connectionId', type: 'bytes32' }] },
      { source: 'a', connectionId } // source 'a' = mainnet
    )
  );

  const payload = {
    action,
    nonce,
    signature: { r: signature.r, s: signature.s, v: signature.v },
    vaultAddress: null,
  };
  const res = await ethers.utils.fetchJson({ url: EXCHANGE_URL, timeout: 30000 }, JSON.stringify(payload));
  if (!res || res.status !== 'ok') {
    throw new Error(`evmUserModify(usingBigBlocks=${usingBigBlocks}) rejected: ${JSON.stringify(res)}`);
  }
  return res;
}

module.exports = { setUsingBigBlocks };

// Manual CLI: node scripts/deploy/hyperliquidBigBlocks.js big|small
if (require.main === module) {
  require('dotenv').config();
  const size = process.argv[2];
  if (size !== 'big' && size !== 'small') {
    console.error('Usage: node scripts/deploy/hyperliquidBigBlocks.js <big|small>');
    process.exit(1);
  }
  setUsingBigBlocks(process.env.PRIVATE_KEY, size === 'big')
    .then(() => console.log(`✅ deployer now targets ${size} blocks`))
    .catch((e) => { console.error(`❌ ${e.message}`); process.exit(1); });
}
