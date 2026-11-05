/// SPDX-License-Identifier: MIT
// Public Ethereum example configuration for building DexRouter v1.0.10.
// Replace these values with the target chain's verified addresses before deployment.
pragma solidity ^0.8.0;

// Example chain ID; deployment tooling should verify block.chainid against it.
uint256 constant _EXPECTED_CHAIN_ID = 1;

uint256 constant NATIVE_TOKEN_TRANSFER_GAS_LIMIT = 100000;
address constant _WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address constant _APPROVE_PROXY = 0x70cBb871E8f30Fc8Ce23609E9E0Ea87B6b222F58;
address constant _PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
// Uniswap V3 CREATE2 prefix: 0xff ++ factory(20 bytes) ++ 11-byte zero padding.
bytes32 constant _FF_FACTORY = 0xff1F98431c8aD98523631AE4a59f267346ea31F9840000000000000000000000;
// Supply the target owner explicitly in the deployment transaction.
address constant _OWNER = address(0);
