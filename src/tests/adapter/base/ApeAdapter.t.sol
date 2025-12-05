// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.17;

import {ApeAdapter} from "@dex/adapter/ApeAdapter.sol";
import {AbstractAdapterTest} from "../common/AbstractAdapterTest.t.sol";

/**
 * @title AgniFinanceAdapterTest
 * @dev Test for AgniFinance adapter (UniswapV3-style DEX on Mantle)
 * @dev Tests token swaps on AgniFinance pools
 * @dev Uses "mantle" network identifier from foundry.toml
 */
contract ApeAdapterTest is AbstractAdapterTest {
    // Token addresses on xlayer network
    address constant WOKB = 0xe538905cf8410324e03A5A23C1c177a474D59b2b;
    address constant USDT = 0x1E4a5963aBFD975d8c9021ce480b42188849D41d;

    // Jace addresses
    address constant JACE_WOKB_POOL = 0x285ffecE603E7e33EE9D6DaD0F38f7E98506C0A6;
    address constant JACE = 0x4344Ca7bDccb707616f45Aab5Cb843D1D366D483;

    // Slerf addresses
    address constant USDT_WOKB_POOL = 0xfbB29f00ee1e078304D9a8DCfC4170C85c523e13;

    /**
     * @dev Create AgniFinance adapter
     */
    function createCustomAdapter(
        string memory
    ) internal override returns (address) {
        return address(new ApeAdapter());
    }

    /**
     * @dev Define test cases for AgniFinance swaps
     */
    function getSwapTestCases()
        internal
        pure
        override
        returns (SwapTestCase[][] memory)
    {
        SwapTestCase[][] memory cases = new SwapTestCase[][](2);
        cases[0] = getJaceSwapTestCases();
        cases[1] = getSlerfSwapTestCases();

        return cases;
    }

    function getJaceSwapTestCases()
        internal
        pure
        returns (SwapTestCase[] memory)
    {
        SwapTestCase[] memory cases = new SwapTestCase[](2);

        // Test 1: JACE to WOKB
        // https://www.oklink.com/x-layer/tx/0x56f0bdeb1ee79cbde56b201b33a5d47820d1952a5139e2ef7e30fc436da1a8d7
        cases[0] = SwapTestCase({
            networkId: "xlayer", // Uses Mantle network from foundry.toml
            forkBlock: 38272486 - 1, // Block before the transaction
            fromToken: JACE,
            toToken: WOKB,
            pool: JACE_WOKB_POOL,
            amount: 585.81978969 * 10 ** 18, // 585.81978969 JACE
            expectedOutput: 485451477594412,
            sellBase: true,
            expectRevert: false,
            description: "JACE to WOKB on XLayer",
            moreInfo: "",
            fromTokenPreTo: JACE_WOKB_POOL
        });

        // Test 2: WOKB to JACE
        cases[1] = SwapTestCase({
            networkId: "xlayer",
            forkBlock: 38272486 - 1,
            fromToken: WOKB,
            toToken: JACE,
            pool: JACE_WOKB_POOL,
            amount: 0.01 * 10 ** 18, 
            expectedOutput: 0,
            sellBase: false, // WOKB is quote token
            expectRevert: false,
            description: "WOKB to JACE on XLayer",
            moreInfo: "",
            fromTokenPreTo: JACE_WOKB_POOL
        });

        return cases;
    }

    function getSlerfSwapTestCases()
        internal
        pure
        returns (SwapTestCase[] memory)
    {
        SwapTestCase[] memory cases = new SwapTestCase[](2);

        // Test 1: Slerf to WOKB
        cases[0] = SwapTestCase({
            networkId: "xlayer",
            forkBlock: 0,
            fromToken: USDT,
            toToken: WOKB,
            pool: USDT_WOKB_POOL,
            amount: 0.01 * 10 ** 6,
            expectedOutput: 0,
            sellBase: true,
            expectRevert: false,
            description: "USDT to WOKB on XLayer",
            moreInfo: "",
            fromTokenPreTo: USDT_WOKB_POOL
        });

        // Test 2: WOKB to USDT
        // https://www.oklink.com/x-layer/tx/0x5bc6eb04cbffa7d3dc2ad12f754e3b1feb216a73af3d419a0625c1fff8db508e
        cases[1] = SwapTestCase({
            networkId: "xlayer",
            forkBlock: 36761533 - 1,
            fromToken: WOKB,
            toToken: USDT,
            pool: USDT_WOKB_POOL,
            amount: 1030613824062463,
            expectedOutput: 198352,
            sellBase: false,
            expectRevert: false,
            description: "WOKB to USDT on XLayer",
            moreInfo: "",
            fromTokenPreTo: USDT_WOKB_POOL
        });

        return cases;
    }
}
