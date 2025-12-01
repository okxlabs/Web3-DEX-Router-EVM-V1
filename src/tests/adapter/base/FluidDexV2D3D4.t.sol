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
                0xe16aD4692B2505d21959f22Ff32D18d808D35759 // FluidDexV2Router
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
        address[][] memory paths = new address[][](6);
        IFluidDexV2Router.SwapInConfig[][] memory swapInConfigs = new IFluidDexV2Router.SwapInConfig[][](6);

        // Test1: USDC to USDT0 by D3 pool
        // tx: https://polygonscan.com/tx/0x94c968f8a8f6967d50d1b7a4fe1ed44aa796fdd44311ea1ab13af61fa567af3e
        paths[0] = new address[](2);
        paths[0][0] = USDC;
        paths[0][1] = USDT0;
        swapInConfigs[0] = new IFluidDexV2Router.SwapInConfig[](1);
        swapInConfigs[0][0] = IFluidDexV2Router.SwapInConfig({
            dexType: 3,
            dexKey: d3USDCUSDT0,   
            amountOutMin: 0,
            controllerData: ""
        });  
        cases[0] = SwapTestCase({
            networkId: "polygon",
            forkBlock: 79153756 - 1,
            fromToken: USDC,
            toToken: USDT0,
            pool: address(0),
            amount: 10000000,
            expectedOutput: 9955621,
            sellBase: true,
            expectRevert: false,
            description: "USDC to USDT0 by D3 pool on Polygon FluidDexV2D3D4",
            moreInfo: abi.encode(paths[0], swapInConfigs[0]),
            fromTokenPreTo: address(0)
        });

        // Test2: USDC to USDT0 by D4 pool
        // tx: https://polygonscan.com/tx/0x30d14aef9d8af59d6a3dc65f96d1781cd1a6de54c1afd6a315369aa60d8a7d08
        paths[1] = new address[](2);
        paths[1][0] = USDC;
        paths[1][1] = USDT0;
        swapInConfigs[1] = new IFluidDexV2Router.SwapInConfig[](1);
        swapInConfigs[1][0] = IFluidDexV2Router.SwapInConfig({
            dexType: 4,
            dexKey: d4USDCUSDT0,
            amountOutMin: 0,
            controllerData: ""
        });
        cases[1] = SwapTestCase({
            networkId: "polygon",
            forkBlock: 79153759 - 1,
            fromToken: USDC,
            toToken: USDT0,
            pool: address(0),
            amount: 10000000,
            expectedOutput: 9922468,
            sellBase: true,
            expectRevert: false,
            description: "USDC to USDT0 by D4 pool on Polygon FluidDexV2D3D4",
            moreInfo: abi.encode(paths[1], swapInConfigs[1]),
            fromTokenPreTo: address(0)
        });

        // Test3: NativeToken to USDC by D3 pool
        // tx: https://polygonscan.com/tx/0xff52f9d2ee6e1bf9b565d9ace163407e1eded1b060cfe5f983fdaf03639ded46
        paths[2] = new address[](2);
        paths[2][0] = NativeToken;
        swapInConfigs[2] = new IFluidDexV2Router.SwapInConfig[](1);
        paths[2][1] = USDC;
        swapInConfigs[2][0] = IFluidDexV2Router.SwapInConfig({
            dexType: 3,
            dexKey: d3USDCNativeToken,
            amountOutMin: 0,
            controllerData: ""
        });
        cases[2] = SwapTestCase({
            networkId: "polygon",
            forkBlock: 79153763 - 1,
            fromToken: WNativeToken,
            toToken: USDC,
            pool: address(0),
            amount: 10 * 10 ** 18,
            expectedOutput: 50842827,
            sellBase: true,
            expectRevert: false,
            description: "NativeToken to USDC by D3 pool on Polygon FluidDexV2D3D4",
            moreInfo: abi.encode(paths[2], swapInConfigs[2]),
            fromTokenPreTo: address(0)
        });

        // Test4: NativeToken to USDC by D4 pool
        // tx: https://polygonscan.com/tx/0x01abc8dd2f40394375f9afdce25607ebe5e411a89c0644d676c1b24423b2582d
        paths[3] = new address[](2);
        paths[3][0] = NativeToken;
        paths[3][1] = USDC;
        swapInConfigs[3] = new IFluidDexV2Router.SwapInConfig[](1);
        swapInConfigs[3][0] = IFluidDexV2Router.SwapInConfig({
            dexType: 4,
            dexKey: d4USDCNativeToken,
            amountOutMin: 0,
            controllerData: ""
        });
        cases[3] = SwapTestCase({
            networkId: "polygon",
            forkBlock: 79153765 - 1,
            fromToken: WNativeToken,
            toToken: USDC,
            pool: address(0),
            amount: 10 * 10 ** 18,
            expectedOutput: 50799556,
            sellBase: true,
            expectRevert: false,
            description: "NativeToken to USDC by D4 pool on Polygon FluidDexV2D3D4",
            moreInfo: abi.encode(paths[3], swapInConfigs[3]),
            fromTokenPreTo: address(0)
        });

        // Test5: USDC to NativeToken by D3 pool
        paths[4] = new address[](2);
        paths[4][0] = USDC;
        paths[4][1] = NativeToken;
        swapInConfigs[4] = new IFluidDexV2Router.SwapInConfig[](1);
        swapInConfigs[4][0] = IFluidDexV2Router.SwapInConfig({
            dexType: 3,
            dexKey: d3USDCNativeToken,
            amountOutMin: 0,
            controllerData: ""
        });
        cases[4] = SwapTestCase({
            networkId: "polygon",
            forkBlock: 79153765,
            fromToken: USDC,
            toToken: WNativeToken,
            pool: address(0),
            amount: 10000000,
            expectedOutput: 0,
            sellBase: true,
            expectRevert: false,
            description: "USDC to NativeToken by D3 pool on Polygon FluidDexV2D3D4",
            moreInfo: abi.encode(paths[4], swapInConfigs[4]),
            fromTokenPreTo: address(0)
        });

        // Test6: USDC to NativeToken by D4 pool
        paths[5] = new address[](2);
        paths[5][0] = USDC;
        paths[5][1] = NativeToken;
        swapInConfigs[5] = new IFluidDexV2Router.SwapInConfig[](1);
        swapInConfigs[5][0] = IFluidDexV2Router.SwapInConfig({
            dexType: 4,
            dexKey: d4USDCNativeToken,
            amountOutMin: 0,
            controllerData: ""
        });
        cases[5] = SwapTestCase({
            networkId: "polygon",
            forkBlock: 79153765,
            fromToken: USDC,
            toToken: WNativeToken,
            pool: address(0),
            amount: 10000000,
            expectedOutput: 0,
            sellBase: true,
            expectRevert: false,
            description: "USDC to NativeToken by D4 pool on Polygon FluidDexV2D3D4",
            moreInfo: abi.encode(paths[5], swapInConfigs[5]),
            fromTokenPreTo: address(0)
        });

        return cases;
    }
}