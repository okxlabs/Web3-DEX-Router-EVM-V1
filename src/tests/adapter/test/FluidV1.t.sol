// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

import {FluidAdapter} from "@dex/adapter/FluidAdapter.sol";
import {AbstractAdapterTest} from "../common/AbstractAdapterTest.t.sol";

/// @title FluidV1Test
/// @notice Adapter tests for FluidV1
/// @dev Uses the new AbstractAdapterTest harness to minimise boilerplate.
contract FluidV1Test is AbstractAdapterTest {
    /**
     * @dev Create FluidV1Adapter
     */
    function createCustomAdapter(
        string memory /* networkId */
    ) internal override returns (address) {
        return address(new FluidAdapter(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c)); // WBNB on BSC
    }

    /**
     * @dev Define test cases for FluidV1Adapter swaps
     */
    function getSwapTestCases()
        internal
        override
        pure
        returns (SwapTestCase[][] memory)
    {
        SwapTestCase[][] memory cases = new SwapTestCase[][](1);
        cases[0] = getFluidV1TestCases();
        return cases;
    }

    /**
     * @dev Define test cases for FluidV1Adapter swaps
     */
    function getFluidV1TestCases()
        internal
        pure
        returns (SwapTestCase[] memory)
    {
        SwapTestCase[] memory cases = new SwapTestCase[](1);

        address USDC = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;
        address USDT = 0x55d398326f99059fF775485246999027B3197955;
        address FluidV1_USDC_USDT = 0x0B1a513ee24972DAEf112bC777a5610d4325C9e7;

        // Test 1: USDC to USDT
        // tx: https://bscscan.com/tx/0x0ac25c3b97b12c035f16c4a3910f4447aeee0a53ad9cfddee16041302a8390ee
        cases[0] = SwapTestCase({
            networkId: "bsc",
            forkBlock: 76794741 - 1,
            fromToken: USDC,
            toToken: USDT,
            pool: FluidV1_USDC_USDT,
            amount: 3000000000000000000, // 3 USDC
            expectedOutput: 2999466969070000000, // 2.999 USDT
            sellBase: true,
            expectRevert: false,
            description: "USDC to USDT on BSC FluidV1",
            moreInfo: abi.encode(USDC, USDT),
            fromTokenPreTo: address(0)
        });
        return cases;
    }
}