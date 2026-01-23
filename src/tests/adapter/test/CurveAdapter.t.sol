// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

import {CurveAdapter} from "@dex/adapter/CurveAdapter.sol";
import {AbstractAdapterTest} from "../common/AbstractAdapterTest.t.sol";

/// @title CurveAdapter Multi-Chain Test
/// @notice Adapter tests for CurveAdapter on multiple networks
/// @dev Uses the new AbstractAdapterTest harness to minimise boilerplate.
contract CurveAdapterTest is AbstractAdapterTest {
    // Mapping of network IDs to their wrapped tokens
    mapping(string => address) internal WETH_ADDRESSES;
    
    /**
     * @dev Create CurveAdapter for the specified network
     * @param networkId The network identifier (e.g. "xlayer", "eth", "bsc")
     */
    function createCustomAdapter(
        string memory networkId
    ) internal override returns (address) {
        // Wrapped token addresses per network
        WETH_ADDRESSES["xlayer"] = 0xe538905cf8410324e03A5A23C1c177a474D59b2b; // XLAYER_WOKB
        WETH_ADDRESSES["eth"] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // ETH_WETH
        WETH_ADDRESSES["bsc"] = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c; // BSC_WBNB
        WETH_ADDRESSES["polygon"] = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270; // POLYGON_WMATIC
        WETH_ADDRESSES["arbitrum"] = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1; // ARBITRUM_WETH
        WETH_ADDRESSES["base"] = 0x4200000000000000000000000000000000000006; // BASE_WETH
        WETH_ADDRESSES["linea"] = 0xe5D7C2a44FfDDf6b295A15c148167daaAf5Cf34f; // LINEA_WETH
        WETH_ADDRESSES["mantle"] = 0x78c1b0C915c4FAA5FffA6CAbf0219DA63d7f4cb8; // MANTLE_WMNT
        
        address weth = WETH_ADDRESSES[networkId];
        require(weth != address(0), "Unsupported network for CurveAdapter");
        
        return address(new CurveAdapter(weth));
    }

    /**
     * @dev Define test cases for CurveAdapter swaps
     */
    function getSwapTestCases()
        internal
        override
        pure
        returns (SwapTestCase[][] memory)
    {
        SwapTestCase[][] memory cases = new SwapTestCase[][](2);
        cases[0] = getCurveAdapterTestCases();

        return cases;
    }

    function getCurveAdapterTestCases()
        internal
        pure
        returns (SwapTestCase[] memory)
    {
        // Token addresses on Xlayer network
        address USDC = 0x74b7F16337b8972027F6196A17a631aC6dE26d22;
        address USDT = 0x1E4a5963aBFD975d8c9021ce480b42188849D41d;

        // Pool addresses
        address USDCUSDT_2pool = 0xD1b30BA128573fcd7D141C8A987961b40e047BB6;

        SwapTestCase[] memory cases = new SwapTestCase[](2);

        // Test 1: USDC to USDT
        // tx: https://www.oklink.com/zh-hans/x-layer/tx/0x855db68d7b37e9ec98054cae1939dbb762feddf7b22dd8abfff2404c0691ce40
        cases[0] = SwapTestCase({
            networkId: "xlayer",
            forkBlock: 30480017,
            fromToken: USDC,
            toToken: USDT,
            pool: USDCUSDT_2pool,
            amount: 34999800104,
            expectedOutput: 34991444965,
            sellBase: true,
            expectRevert: false,
            description: "USDC to USDT on Xlayer CurveAdapter",
            moreInfo: abi.encode(USDC, USDT, int128(0), int128(1), false),
            fromTokenPreTo: address(0) // no need to transfer tokens to pool first
        });

        // Test 2: USDT to USDC
        // tx: https://www.oklink.com/zh-hans/x-layer/tx/0x2e1de3f191e8c2b3328f86d1fdd03fb90d7e0c3a5d89bda1656abe31f17f0046
        cases[1] = SwapTestCase({
            networkId: "xlayer",
            forkBlock: 30356279,
            fromToken: USDT,
            toToken: USDC,
            pool: USDCUSDT_2pool,
            amount: 264711216,
            expectedOutput: 264711117,
            sellBase: true,
            expectRevert: false,
            description: "USDT to USDC on Xlayer CurveAdapter",
            moreInfo: abi.encode(USDT, USDC, int128(1), int128(0), false),
            fromTokenPreTo: address(0) // no need to transfer tokens to pool first
        });

        return cases;
    }
} 