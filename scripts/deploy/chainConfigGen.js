const fs = require('fs');
const path = require('path');

// Generated, gitignored file that holds the current deploy target's per-chain constants.
// Constants.sol imports it and re-exports the symbols transitively.
const CHAIN_CONFIG_PATH = path.join(__dirname, '..', '..', 'contracts', '8', 'libraries', 'ChainConfig.sol');

const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';
const ZERO_FF_FACTORY = '0x0000000000000000000000000000000000000000000000000000000000000000';

const ADDR_RE = /^0x[0-9a-fA-F]{40}$/;
const FF_FACTORY_RE = /^0xff[0-9a-fA-F]{62}$/; // 0xff + 20-byte addr + 11-byte padding (32 bytes)

// Ethereum mainnet defaults — used to seed ChainConfig.sol when absent (e.g. fresh checkout)
// so plain `forge build` / `hardhat compile` work without running a deploy first.
const DEFAULT_VALUES = {
  chainId: 1,
  gasLimit: 100000,
  weth: '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2',
  approveProxy: '0x70cBb871E8f30Fc8Ce23609E9E0Ea87B6b222F58',
  permit2: '0x000000000022D473030F116dDEE9F6B43aC78BA3',
  ffFactory: '0xff1F98431c8aD98523631AE4a59f267346ea31F9840000000000000000000000',
};

function isZeroAddress(a) {
  return /^0x0+$/.test(a);
}

function checkRequiredAddr(errs, label, val) {
  if (!val) { errs.push(`${label} is required but missing/empty`); return; }
  if (!ADDR_RE.test(val)) { errs.push(`${label} is not a valid 20-byte address: ${val}`); return; }
  if (isZeroAddress(val)) { errs.push(`${label} must not be the zero address`); }
}

function checkOptionalAddr(errs, label, val) {
  if (!val || isZeroAddress(val)) return; // empty / zero is allowed for optional values
  if (!ADDR_RE.test(val)) errs.push(`${label} is not a valid 20-byte address: ${val}`);
}

/**
 * Validate per-chain values. Throws with a combined message on any problem, so a
 * misconfigured chain fails LOUDLY before generating / deploying — never silently
 * compiles a wrong/zero constant into the bytecode.
 * @param {object} v
 * @param {string} [chain] - chain name, for the error message
 */
function validateValues(v, chain) {
  const where = chain ? ` for chain "${chain}"` : '';
  const errs = [];

  if (!Number.isInteger(v.chainId) || v.chainId <= 0) {
    errs.push(`chainId must be a positive integer (got ${JSON.stringify(v.chainId)})`);
  }
  const gl = Number(v.gasLimit);
  if (!Number.isInteger(gl) || gl <= 0) {
    errs.push(`NATIVE_TOKEN_TRANSFER_GAS_LIMIT must be a positive integer (got ${JSON.stringify(v.gasLimit)})`);
  }

  // Required, must be a real (non-zero) address — a zero here would break the router.
  checkRequiredAddr(errs, '_WETH (wNativeToken)', v.weth);
  checkRequiredAddr(errs, '_APPROVE_PROXY (tokenApproveProxy)', v.approveProxy);

  // Optional — a chain may legitimately have no Permit2 / no Uniswap V3 factory.
  // Zero is allowed (callers should log it), but a malformed non-zero value is rejected.
  checkOptionalAddr(errs, '_PERMIT2 (permit2)', v.permit2);
  if (v.ffFactory && v.ffFactory !== ZERO_FF_FACTORY && !FF_FACTORY_RE.test(v.ffFactory)) {
    errs.push(`_FF_FACTORY must be 32 bytes starting with 0xff: ${v.ffFactory}`);
  }

  if (errs.length) {
    throw new Error(`Invalid ChainConfig values${where}:\n  - ${errs.join('\n  - ')}`);
  }
}

/**
 * Render ChainConfig.sol source from a validated set of per-chain values.
 * @param {{chainId:number, gasLimit:number|string, weth?:string, approveProxy?:string, permit2?:string, ffFactory?:string}} v
 * @param {string} [chain]
 * @returns {string}
 */
function generateSource(v, chain) {
  validateValues(v, chain);

  const weth = v.weth;
  const approveProxy = v.approveProxy;
  const permit2 = v.permit2 || ZERO_ADDRESS;
  const ffFactory = v.ffFactory || ZERO_FF_FACTORY;

  return `/// SPDX-License-Identifier: MIT
// AUTO-GENERATED — DO NOT EDIT BY HAND. This file is gitignored.
// Per-chain constants for the current deploy target. Regenerated per deploy by
// scripts/deploy/gen-chainconfig.js, or seeded with defaults by scripts/deploy/ensure-chainconfig.js.
pragma solidity ^0.8.0;

// Target chain this config was generated for. DeployDexRouter.s.sol asserts
// block.chainid == _EXPECTED_CHAIN_ID to prevent deploying with the wrong chain's config.
uint256 constant _EXPECTED_CHAIN_ID = ${v.chainId};

uint256 constant NATIVE_TOKEN_TRANSFER_GAS_LIMIT = ${v.gasLimit};
address constant _WETH = ${weth};
address constant _APPROVE_PROXY = ${approveProxy};
address constant _PERMIT2 = ${permit2};
// Uniswap V3 CREATE2 prefix: 0xff ++ factory(20 bytes) ++ 11-byte zero padding.
bytes32 constant _FF_FACTORY = ${ffFactory};
`;
}

/**
 * Validate and write ChainConfig.sol from the given values.
 * @param {object} values - see generateSource
 * @param {string} [chain]
 */
function writeChainConfig(values, chain) {
  fs.writeFileSync(CHAIN_CONFIG_PATH, generateSource(values, chain));
}

module.exports = {
  CHAIN_CONFIG_PATH,
  ZERO_ADDRESS,
  ZERO_FF_FACTORY,
  DEFAULT_VALUES,
  validateValues,
  generateSource,
  writeChainConfig,
};
