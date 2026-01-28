// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

import {EkuboAdapter, PoolKey, Config} from "@dex/adapter/EkuboAdapter.sol";
import {AbstractAdapterTest} from "../common/AbstractAdapterTest.t.sol";
import {IERC20} from "@dex/interfaces/IERC20.sol";

/// @title EkuboAdapter
/// @notice Adapter tests for EkuboAdapter
/// @dev Uses the new AbstractAdapterTest harness to minimise boilerplate.
contract EkuboAdapterTest is AbstractAdapterTest {
    /// @dev The minimum value that can be returned from #getSqrtRatioAtTick. Equivalent to getSqrtRatioAtTick(MIN_TICK)
    uint160 internal constant MIN_SQRT_RATIO = 4295128739;
    /// @dev The maximum value that can be returned from #getSqrtRatioAtTick. Equivalent to getSqrtRatioAtTick(MAX_TICK)
    uint160 internal constant MAX_SQRT_RATIO =
        1461446703485210103287273052203988822378723970342;

    // Mapping of network IDs to their native wrapped tokens
    mapping(string => address) internal nativeWrappedTokens;
    
    /**
     * @dev Create UniversalUniswapV3 adapter for the specified network
     * @param networkId The network identifier (e.g. "bsc", "mantle")
     */
    function createCustomAdapter(string memory networkId) internal override returns (address) {
        // Native wrapped token addresses per network
        nativeWrappedTokens["eth"] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // ETH_WETH
        address EKUBO_CORE = 0xe0e0e08A6A4b9Dc7bD67BCB7aadE5cF48157d444;

        address nativeWrappedToken = nativeWrappedTokens[networkId];
        require(nativeWrappedToken != address(0), "Unsupported network");
        
        return address(
            new EkuboAdapter(
                payable(nativeWrappedToken),
                EKUBO_CORE
            )
        );
    }

    /**
     * @dev Define test cases for Thena V3 swaps
     */
    function getSwapTestCases()
        internal
        pure
        override
        returns (SwapTestCase[][] memory)
    {
        SwapTestCase[][] memory cases = new SwapTestCase[][](1);
        cases[0] = getEkuboTestCases();

        return cases;
    }

    function getEkuboTestCases()
        internal
        pure
        returns (SwapTestCase[] memory)
    {
        address USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7; 
        address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        address WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
        address WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        address WSOL = 0xD31a59c85aE9D8edEFeC411D448f90841571b89c;

        SwapTestCase[] memory cases = new SwapTestCase[](4);

        // Test 1: USDT to USDC
        // https://app.blocksec.com/explorer/tx/eth/0xb712c8cb4f2ca39a7d3073829ae5d17b1c8693e5da411fe773f7a644737592fe
        cases[0] = SwapTestCase({
            networkId: "eth",
            forkBlock: 23095382, // latest head
            fromToken: USDT,
            toToken: USDC,
            pool: address(0),
            amount: 1203897925, // 1203.897925 USDT (USDT has 6 decimals)
            expectedOutput: 1204204511, // 1204.204511 USDC (USDC has 6 decimals)
            sellBase: true,
            expectRevert: false,
            description: "USDT to USDC on Ekubo",
            moreInfo: abi.encode(PoolKey({
                token0: USDC,
                token1: USDT,
                config: Config.wrap(0x0000000000000000000000000000000000000000000053e2d6238da300000032)
            }), true),
            fromTokenPreTo: address(0)
        });

        // Test 2: ETH to WBTC
        // https://app.blocksec.com/explorer/tx/eth/0x3d81711e9655911d8b7fd47cb7f6d99e90eed1808f29ef1b7628335ea69df847
        cases[1] = SwapTestCase({
            networkId: "eth",
            forkBlock: 23095721, // latest
            fromToken: WETH,
            toToken: WBTC,
            pool: address(0),
            amount: 311791097858752512, // 0.311791097858752512 ETH
            expectedOutput: 1043202, // 0.01043202 WBTC
            sellBase: true,
            expectRevert: false,
            description: "ETH to WBTC on Ekubo",
            moreInfo: abi.encode(PoolKey({
                token0: address(0),
                token1: WBTC,
                config: Config.wrap(0x00000000000000000000000000000000000000000020c49ba5e353f7000003e8)
            }), false),
            fromTokenPreTo: address(0)
        });

        // Test 3: USDC to ETH
        // https://app.blocksec.com/explorer/tx/eth/0x6c1a77074a3f801c12d206da84658b556cab69ee3cdd0f1b154b7b9ae4350976
        cases[2] = SwapTestCase({
            networkId: "eth",
            forkBlock: 23095791, // latest
            fromToken: USDC,
            toToken: WETH,
            pool: address(0),
            amount: 3251523319, // 3251.523319 USDC (USDC has 6 decimals)
            expectedOutput: 833537516942508585, // 0.833537516942508585 ETH
            sellBase: true,
            expectRevert: false,
            description: "USDC to ETH on Ekubo",
            moreInfo: abi.encode(PoolKey({
                token0: address(0),
                token1: USDC,
                config: Config.wrap(0x0000000000000000000000000000000000000000000d1b71758e21960000137e)
            }), true),
            fromTokenPreTo: address(0)
        });

        cases[3] = SwapTestCase({
            networkId: "eth",
            forkBlock: 23225708,
            fromToken: WSOL,
            toToken: USDC,
            pool: address(0),
            amount: 3690,
            expectedOutput: 732,
            sellBase: false,
            expectRevert: false,
            description: "WSOL to USDC on Ekubo (sellQuote)",
            moreInfo: abi.encode(PoolKey({
                token0: USDC,
                token1: WSOL,
                config: Config.wrap(0x0000000000000000000000000000000000000000004189374bc6a7f00000137c)
            }), true),
            fromTokenPreTo: address(0)
        });

        return cases;
    }
}