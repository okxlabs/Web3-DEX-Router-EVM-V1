// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.17;

import {AlienBaseV3Adapter} from "@dex/adapter/AlienBaseV3Adapter.sol";
import {AbstractAdapterTest} from "../common/AbstractAdapterTest.t.sol";

/**
 * @title AlienBaseV3AdapterTest
 * @dev Test for AlienBase V3 adapter (Uniswap V3 style DEX on Base)
 * @dev Tests token swaps on AlienBase V3 pools
 * @dev Uses "base" network identifier from foundry.toml
 */
contract AlienBaseV3AdapterTest is AbstractAdapterTest {
    // Token addresses on Base network
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    // Pool address
    address constant WETH_USDC_POOL =
        0xB27f110571c96B8271d91ad42D33A391A75E6030;

    /**
     * @dev Create AlienBaseV3 adapter
     */
    function createCustomAdapter(
        string memory
    ) internal override returns (address) {
        return address(new AlienBaseV3Adapter(payable(WETH)));
    }

    /**
     * @dev Define test cases for AlienBase V3 swaps
     */
    function getSwapTestCases()
        internal
        pure
        override
        returns (SwapTestCase[][] memory)
    {
        SwapTestCase[][] memory cases = new SwapTestCase[][](1);
        cases[0] = new SwapTestCase[](2);

        // Test 1: WETH to USDC
        cases[0][0] = SwapTestCase({
            networkId: "base",
            forkBlock: 21693942,
            fromToken: WETH,
            toToken: USDC,
            pool: WETH_USDC_POOL,
            amount: 0.046502901914085561 * 10 ** 18, // ~0.046502 WETH
            expectedOutput: 121.605458 * 10 ** 6, // actual output is 121.788068 USDC, but we can't get the exact output because of the rounding error
            sellBase: false, // WETH is quote in this context
            expectRevert: false,
            description: "WETH to USDC on Base",
            moreInfo: abi.encode(uint160(0), abi.encode(WETH, USDC, uint24(0))),
            fromTokenPreTo: address(0)
        });

        // Test 2: USDC to WETH (based on original test)
        cases[0][1] = SwapTestCase({
            networkId: "base", // Uses Base network from foundry.toml
            forkBlock: 21693941, // Block from original test
            fromToken: USDC,
            toToken: WETH,
            pool: WETH_USDC_POOL,
            amount: 121788068, // 121.788068 USDC (6 decimals)
            expectedOutput: 0, // Dynamic
            sellBase: true, // USDC is base in this context
            expectRevert: false,
            description: "USDC to WETH on Base",
            moreInfo: abi.encode(uint160(0), abi.encode(USDC, WETH, uint24(0))),
            fromTokenPreTo: address(0)
        });

        return cases;
    }
}
