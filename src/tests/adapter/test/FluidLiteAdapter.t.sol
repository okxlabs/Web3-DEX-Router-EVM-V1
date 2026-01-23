// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

import {FluidLiteAdapter} from "@dex/adapter/FluidLiteAdapter.sol";
import {IFluidDexLite} from "@dex/interfaces/IFluidDexLite.sol";
import {AbstractAdapterTest} from "../common/AbstractAdapterTest.t.sol";

/// @title FluidLiteAdapterTest
/// @notice Adapter tests for FluidLiteAdapter
/// @dev Uses the new AbstractAdapterTest harness to minimise boilerplate.
contract FluidLiteAdapterTest is AbstractAdapterTest {
    /**
     * @dev Create FluidLiteAdapter
     */
    function createCustomAdapter(
        string memory /* networkId */
    ) internal override returns (address) {
        return address(
            new FluidLiteAdapter(
                0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, // WETH
                0xBbcb91440523216e2b87052A99F69c604A7b6e00 // FluidDexLite
            )
        );
    }

    /**
     * @dev Define test cases for FluidLiteAdapter swaps
     */
    function getSwapTestCases()
        internal
        override
        pure
        returns (SwapTestCase[][] memory)
    {
        SwapTestCase[][] memory cases = new SwapTestCase[][](1);
        cases[0] = getFluidLiteTestCases();

        return cases;
    }

    /**
     * @dev Define test cases for FluidLiteAdapter swaps, FluidDexLite only supports USDC/USDT pair for now
     */
    function getFluidLiteTestCases()
        internal
        pure
        returns (SwapTestCase[] memory)
    {
        // Token addresses on ETH network
        address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // token0
        address USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7; // token1

        // Pool address
        address FluidDexLite = 0xBbcb91440523216e2b87052A99F69c604A7b6e00;

        SwapTestCase[] memory cases = new SwapTestCase[](2);

        // Test 1: USDC to USDT
        // tx: https://etherscan.io/tx/0xf0694745f7e58efff933f281ec97783177980891db8389e6288467a3c8a7b3b9
        cases[0] = SwapTestCase({
            networkId: "eth",
            forkBlock: 23087442,
            fromToken: USDC,
            toToken: USDT,
            pool: FluidDexLite,
            amount: 2449030408,
            expectedOutput: 2448515860,
            sellBase: true,
            expectRevert: false,
            description: "USDC to USDT on ETH FluidDexLite",
            moreInfo: abi.encode(IFluidDexLite.DexKey({token0: USDC, token1: USDT, salt: 0}), true),
            fromTokenPreTo: address(0)
        });

        // Test 2: USDT to USDC
        // tx: https://etherscan.io/tx/0x53f41ce1506c3fa7af0dd3a1f3371a7ef9b78ea9faa50b95db77b30b28087f56
        cases[1] = SwapTestCase({
            networkId: "eth",
            forkBlock: 23087402,
            fromToken: USDT,
            toToken: USDC,
            pool: FluidDexLite,
            amount: 10000000,
            expectedOutput: 10001987,
            sellBase: true,
            expectRevert: false,
            description: "USDT to USDC on ETH FluidDexLite",
            moreInfo: abi.encode(IFluidDexLite.DexKey({token0: USDC, token1: USDT, salt: 0}), false),
            fromTokenPreTo: address(0)
        });

        return cases;
    }
}