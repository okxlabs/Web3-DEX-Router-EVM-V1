/// SPDX-License-Identifier: MIT
// AUTO-GENERATED — DO NOT EDIT BY HAND. This file is gitignored.
// Per-chain constants for the current deploy target. Regenerated per deploy by
// scripts/deploy/gen-chainconfig.js, or seeded with defaults by scripts/deploy/ensure-chainconfig.js.
pragma solidity ^0.8.0;

// Target chain this config was generated for. DeployDexRouter.s.sol asserts
// block.chainid == _EXPECTED_CHAIN_ID to prevent deploying with the wrong chain's config.
uint256 constant _EXPECTED_CHAIN_ID = 1;

uint256 constant NATIVE_TOKEN_TRANSFER_GAS_LIMIT = 100000;
address constant _WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address constant _APPROVE_PROXY = 0x70cBb871E8f30Fc8Ce23609E9E0Ea87B6b222F58;
address constant _PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
// Uniswap V3 CREATE2 prefix: 0xff ++ factory(20 bytes) ++ 11-byte zero padding.
bytes32 constant _FF_FACTORY = 0xff1F98431c8aD98523631AE4a59f267346ea31F9840000000000000000000000;
// DexRouter owner (constructor arg in DeployDexRouter.s.sol). Per-chain, REQUIRED in
// deployed/<chain>/base.js owner (no default). NOT baked into any value/routing path.
address constant _OWNER = 0xAcE2B3E7c752d5deBca72210141d464371b3B9b1;
