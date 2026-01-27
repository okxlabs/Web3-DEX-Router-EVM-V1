// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

import {PancakeStableSwapTwoAdapter} from "@dex/adapter/PancakeStableSwapTwoAdapter.sol";
import {AbstractAdapterTest} from "../common/AbstractAdapterTest.t.sol";

/**
 * @title UniversalUniswapV2AdapterTest
 * @dev Simple test for UniversalUniswapV2Adapter
 * @dev UniversalUniswapV2Adapter uses 0.2% fee (998/1000)
 * @dev Uses "bsc" network identifier from foundry.toml
 */
contract PancakeStableSwapTwoAdapterTest is AbstractAdapterTest {
    // Mapping of network IDs to their native wrapped tokens
    mapping(string => address) internal nativeWrappedTokens;
    
    /**
     * @dev Create PancakeStableSwapTwo adapter for the specified network
     * @param networkId The network identifier (e.g. "xlayer", "bsc")
     */
    function createCustomAdapter(string memory networkId) internal override returns (address) {
        // Native wrapped token addresses per network
        nativeWrappedTokens["xlayer"] = 0xe538905cf8410324e03A5A23C1c177a474D59b2b; // XLAYER_WOKB
        nativeWrappedTokens["bsc"] = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c; // BSC_WBNB
        // Add more networks as needed

        address nativeWrappedToken = nativeWrappedTokens[networkId];
        require(nativeWrappedToken != address(0), "Unsupported network for PancakeStableSwapTwoAdapter");
        
        return address(new PancakeStableSwapTwoAdapter(nativeWrappedToken));
    }

    function getSwapTestCases()
        internal
        pure
        override
        returns (SwapTestCase[][] memory)
    {
        SwapTestCase[][] memory cases = new SwapTestCase[][](1);
        cases[0] = getOkieStableSwapTestCases();

        return cases;
    }

    function getOkieStableSwapTestCases() internal pure returns (SwapTestCase[] memory) {

        address USDT = 0x1E4a5963aBFD975d8c9021ce480b42188849D41d;
        address USDC = 0x74b7F16337b8972027F6196A17a631aC6dE26d22;

        address pool = 0xE6E352BcC4ab14b1e567042a22A79491a8bC3bdc;
        SwapTestCase[] memory cases = new SwapTestCase[](2);

        // https://www.oklink.com/x-layer/tx/0x519a408e193a2e4c4090dc2c61e0e5f8c8714f769dceebba2e25bb13e668076e
        // USDT to USDC
        cases[0] = SwapTestCase({
            networkId: "xlayer",
            forkBlock: 44957468 - 1,
            fromToken: USDT,
            toToken: USDC,
            pool: pool,
            amount: 105275668,
            expectedOutput: 105223238,
            sellBase: true,
            expectRevert: false,
            description: "USDT to USDC on XLayer",
            moreInfo: abi.encode(USDT, USDC, 0, 1),
            fromTokenPreTo: address(0)
        });

        cases[1] = SwapTestCase({
            networkId: "xlayer",
            forkBlock: 0,
            fromToken: USDC,
            toToken: USDT,
            pool: pool,
            amount: 105223238,
            expectedOutput: 0,
            sellBase: false,
            expectRevert: false,
            description: "USDC to USDT on XLayer",
            moreInfo: abi.encode(USDC, USDT, 1, 0),
            fromTokenPreTo: address(0)
        });
        return cases;
    }
} 