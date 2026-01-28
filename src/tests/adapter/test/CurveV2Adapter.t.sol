// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {AbstractAdapterTest} from "../common/AbstractAdapterTest.t.sol";
import {CurveV2Adapter} from "@dex/adapter/CurveV2Adapter.sol";

contract CurveV2AdapterTest is AbstractAdapterTest {

    // Mapping of network IDs to their wrapped tokens
    mapping(string => address) internal WETH_ADDRESSES;

    function createCustomAdapter(
        string memory networkId
    ) internal override returns (address) {
        // Wrapped token addresses per network
        WETH_ADDRESSES["eth"] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // Ethereum WETH
        WETH_ADDRESSES["arb"] = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1; // Arbitrum WETH
        WETH_ADDRESSES["op"] = 0x4200000000000000000000000000000000000006; // Optimism WETH
        WETH_ADDRESSES["base"] = 0x4200000000000000000000000000000000000006; // Base WETH
        WETH_ADDRESSES["bsc"] = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c; // BSC WBNB
        WETH_ADDRESSES["polygon"] = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270; // Polygon WMATIC
        WETH_ADDRESSES["linea"] = 0xe5D7C2a44FfDDf6b295A15c148167daaAf5Cf34f; // Linea WETH
        WETH_ADDRESSES["mantle"] = 0x78c1b0C915c4FAA5FffA6CAbf0219DA63d7f4cb8; // Mantle WMNT
        WETH_ADDRESSES["xlayer"] = 0xe538905cf8410324e03A5A23C1c177a474D59b2b; // XLayer WOKB

        address weth = WETH_ADDRESSES[networkId];
        require(weth != address(0), "Unsupported network for Curve V2");
        
        return address(new CurveV2Adapter(weth));
    }

    function getSwapTestCases()
        internal
        override
        pure
        returns (SwapTestCase[][] memory)
    {
        SwapTestCase[][] memory cases = new SwapTestCase[][](2);
        cases[0] = getCurveV2TestCases();
        cases[1] = getOkieStableSwapTestCases();

        return cases;
    }

    function getOkieStableSwapTestCases() internal pure returns (SwapTestCase[] memory) {
        SwapTestCase[] memory cases = new SwapTestCase[](1);

        address USDT0 = 0x779Ded0c9e1022225f8E0630b35a9b54bE713736;
        address USDT = 0x1E4a5963aBFD975d8c9021ce480b42188849D41d;
        address USDT0_USDT_2pool = 0x28238e5d9E6624DfEe9367317a7288a91D51B9f0;
        // tx: https://www.oklink.com/zh-hans/x-layer/tx/0x855db68d7b37e9ec98054cae1939dbb762feddf7b22dd8abfff2404c0691ce40
        cases[0] = SwapTestCase({
            networkId: "xlayer",
            forkBlock: 35926150 - 1,
            fromToken: USDT0,
            toToken: USDT,
            pool: USDT0_USDT_2pool,
            amount: 199890000,
            expectedOutput: 200096366,
            sellBase: true,
            expectRevert: false,
            description: "USDT0 to USDT on Xlayer CurveV2Adapter",
            moreInfo: abi.encode(USDT0, USDT, int128(1), int128(0), false),
            fromTokenPreTo: address(0)
        });

        return cases;
    }

    /**
     * @dev Test cases for Ethereum Curve V2 swaps
     * Transaction link: https://etherscan.io/tx/0x2fe33ab853e69e2998f6fe8da7621bad23f5f3db8534b1f220913f6940bba758
     * Transaction: CRV to crvUSD swap on Curve V2 pool
     * From TokenExchange event: sold_id=1 (CRV), bought_id=0 (crvUSD)
     */
    function getCurveV2TestCases() internal pure returns (SwapTestCase[] memory) {
        SwapTestCase[] memory cases = new SwapTestCase[](1);

        // Token addresses
        address CRV = 0xD533a949740bb3306d119CC777fa900bA034cd52; // Curve DAO Token
        address crvUSD = 0xf939E0A03FB07F59A73314E73794Be0E57ac1b4E; // Curve.Fi USD Stablecoin
        address POOL = 0xafca625321Df8D6A068bDD8F1585d489D2acF11b; // Curve V2 Pool

        // Transaction: CRV to crvUSD swap
        // Input: 0.135206669309128642 CRV (135206669309128642)
        // Output: 0.116901388463382035 crvUSD (116901388463382035)
        // From exchange function: i=1 (CRV), j=0 (crvUSD)
        // From TokenExchange event: sold_id=1, bought_id=0
        // Since sold_id=1 (non-base token) and bought_id=0 (base token), sellBase=false
        cases[0] = SwapTestCase({
            networkId: "eth",
            forkBlock: 22930847 - 1,
            fromToken: CRV,
            toToken: crvUSD,
            pool: POOL,
            amount: 135206669309128642, // 0.135206669309128642 CRV
            expectedOutput: 116906512903513457, // 0.116901388463382035 crvUSD
            sellBase: false, // Selling index 1 (CRV), buying index 0 (crvUSD), so not selling base token
            expectRevert: false,
            description: "CRV to crvUSD on Ethereum Curve V2",
            moreInfo: abi.encode(CRV, crvUSD, int128(1), int128(0), false),
            fromTokenPreTo: address(0)
        });

        return cases;
    }
}
