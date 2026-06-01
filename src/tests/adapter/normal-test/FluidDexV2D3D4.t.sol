// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

import {FluidDexV2D3D4Adapter} from "@dex/adapter/FluidDexV2D3D4Adapter.sol";
import {IFluidDexV2Router} from "@dex/interfaces/IFluidDexV2Router.sol";
import {AbstractAdapterTest} from "../common/AbstractAdapterTest.t.sol";

contract FluidDexV2D3D4AdapterTest is AbstractAdapterTest {
    /**
     * @dev Create FluidDexV2D3D4Adapter
     */
    function createCustomAdapter(
        string memory /* networkId */
    ) internal override returns (address) {
        return address(
            new FluidDexV2D3D4Adapter(
                0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270, // WPOL
                0x713fD04a47Db41AB5684AEC2A2063d5278A53616 // FluidDexV2Router
            )
        );
    }

    /**
     * @dev Define test cases for FluidDexV2D3D4Adapter swaps
     */
    function getSwapTestCases()
        internal
        override
        pure
        returns (SwapTestCase[][] memory)
    {
        SwapTestCase[][] memory cases = new SwapTestCase[][](1);
        cases[0] = getFluidDexV2D3D4TestCases();

        return cases;
    }

    /**
     * @dev Define test cases for FluidDexV2D3D4Adapter swaps
     */
    function getFluidDexV2D3D4TestCases()
        internal
        pure
        returns (SwapTestCase[] memory)
    {
        // Token addresses on Polygon network
        address NativeToken = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
        address WNativeToken = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
        address USDC = 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359;
        address USDT0 = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;

        // Pools
        IFluidDexV2Router.DexKey memory d3USDCUSDT0 = IFluidDexV2Router.DexKey({
            token0: USDC,
            token1: USDT0,
            fee: 100,
            tickSpacing: 1,
            controller: address(0)
        });
        IFluidDexV2Router.DexKey memory d4USDCUSDT0 = IFluidDexV2Router.DexKey({
            token0: USDC,
            token1: USDT0,
            fee: 100,
            tickSpacing: 1,
            controller: address(0)
        });
        IFluidDexV2Router.DexKey memory d3USDCNativeToken = IFluidDexV2Router.DexKey({
            token0: USDC,
            token1: NativeToken,
            fee: 500,
            tickSpacing: 10,
            controller: address(0)
        });
        IFluidDexV2Router.DexKey memory d4USDCNativeToken = IFluidDexV2Router.DexKey({
            token0: USDC,
            token1: NativeToken,
            fee: 500,
            tickSpacing: 10,
            controller: address(0)
        });

        SwapTestCase[] memory cases = new SwapTestCase[](6);

        // Test1: USDC to USDT0 by D3 pool
        // tx: https://polygonscan.com/tx/0x37a8dd3ea253dba568cdd2901c0b0197d311884349a21c67570b73a63083528a
        cases[0] = SwapTestCase({
            networkId: "polygon",
            forkBlock: 79892383 - 1,
            fromToken: USDC,
            toToken: USDT0,
            pool: address(0),
            amount: 10000000,
            expectedOutput: 10007854,
            sellBase: true,
            expectRevert: false,
            description: "USDC to USDT0 by D3 pool on Polygon FluidDexV2D3D4",
            moreInfo: abi.encode(3, d3USDCUSDT0, true, "0x"),
            fromTokenPreTo: address(0)
        });

        // Test2: USDT0 to USDC by D4 pool
        // tx: https://polygonscan.com/tx/0x7ac0d7d32b632a04d7265e0035d8d20e98737c6adb8fea1e7a034806f67e8cab
        cases[1] = SwapTestCase({
            networkId: "polygon",
            forkBlock: 79892448 - 1,
            fromToken: USDT0,
            toToken: USDC,
            pool: address(0),
            amount: 10000000,
            expectedOutput: 9999082,
            sellBase: true,
            expectRevert: false,
            description: "USDT0 to USDC by D4 pool on Polygon FluidDexV2D3D4",
            moreInfo: abi.encode(4, d4USDCUSDT0, false, "0x"),
            fromTokenPreTo: address(0)
        });

        // Test3: NativeToken to USDC by D3 pool
        cases[2] = SwapTestCase({
            networkId: "polygon",
            forkBlock: 79892455,
            fromToken: WNativeToken,
            toToken: USDC,
            pool: address(0),
            amount: 10 * 10 ** 18,
            expectedOutput: 0,
            sellBase: true,
            expectRevert: false,
            description: "NativeToken to USDC by D3 pool on Polygon FluidDexV2D3D4",
            moreInfo: abi.encode(3, d3USDCNativeToken, false, "0x"),
            fromTokenPreTo: address(0)
        });

        // Test4: NativeToken to USDC by D4 pool
        cases[3] = SwapTestCase({
            networkId: "polygon",
            forkBlock: 79892455,
            fromToken: WNativeToken,
            toToken: USDC,
            pool: address(0),
            amount: 10 * 10 ** 18,
            expectedOutput: 0,
            sellBase: true,
            expectRevert: false,
            description: "NativeToken to USDC by D4 pool on Polygon FluidDexV2D3D4",
            moreInfo: abi.encode(4, d4USDCNativeToken, false, "0x"),
            fromTokenPreTo: address(0)
        });

        // Test5: USDC to NativeToken by D3 pool
        // tx: https://polygonscan.com/tx/0xeae3f85daa86e9746dcf4123737ab72185f3657ca1f8f045f2a0dbe1de64027a
        cases[4] = SwapTestCase({
            networkId: "polygon",
            forkBlock: 79892450 - 1,
            fromToken: USDC,
            toToken: WNativeToken,
            pool: address(0),
            amount: 10000000,
            expectedOutput: 0,
            sellBase: true,
            expectRevert: false,
            description: "USDC to NativeToken by D3 pool on Polygon FluidDexV2D3D4",
            moreInfo: abi.encode(3, d3USDCNativeToken, true, ""),
            fromTokenPreTo: address(0)
        });

        // Test6: USDC to NativeToken by D4 pool
        // tx: https://polygonscan.com/tx/0x52454e79bb86a713bc511471b55204bc58c74207ff3d075a6a57b86262555573
        cases[5] = SwapTestCase({
            networkId: "polygon",
            forkBlock: 79892453 - 1,
            fromToken: USDC,
            toToken: WNativeToken,
            pool: address(0),
            amount: 10000000,
            expectedOutput: 0,
            sellBase: true,
            expectRevert: false,
            description: "USDC to NativeToken by D4 pool on Polygon FluidDexV2D3D4",
            moreInfo: abi.encode(4, d4USDCNativeToken, true, "0x"),
            fromTokenPreTo: address(0)
        });

        return cases;
    }
}