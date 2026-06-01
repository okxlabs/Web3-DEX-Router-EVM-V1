// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.17;

import {AgniFinanceAdapter} from "@dex/adapter/AgniFinanceAdapter.sol";
import {AbstractAdapterTest} from "../common/AbstractAdapterTest.t.sol";

/**
 * @title AgniFinanceAdapterTest
 * @dev Test for AgniFinance adapter (UniswapV3-style DEX on Mantle)
 * @dev Tests token swaps on AgniFinance pools
 * @dev Uses "mantle" network identifier from foundry.toml
 */
contract AgniFinanceAdapterTest is AbstractAdapterTest {
    // Token addresses on Mantle network
    address constant WMNT = 0x78c1b0C915c4FAA5FffA6CAbf0219DA63d7f4cb8;
    address constant WETH = 0xdEAddEaDdeadDEadDEADDEAddEADDEAddead1111;
    address constant USDT = 0x201EBa5CC46D216Ce6DC03F6a759e8E766e956aE;

    // Pool addresses
    address constant WMNT_USDT = 0xD08C50F7E69e9aeb2867DefF4A8053d9A855e26A;
    address constant WETH_USDT = 0x628f7131CF43e88EBe3921Ae78C4bA0C31872bd4;

    /**
     * @dev Create AgniFinance adapter
     */
    function createCustomAdapter(
        string memory
    ) internal override returns (address) {
        return address(new AgniFinanceAdapter(payable(WMNT)));
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
        SwapTestCase[][] memory cases = new SwapTestCase[][](1);
        cases[0] = new SwapTestCase[](4);

        // Test 1: WMNT to USDT
        // //https://explorer.mantle.xyz/tx/0x49e745b9582d202b744a140c3a7e6aa8cd4a2bb2a282609b413696ddd899eebe
        cases[0][0] = SwapTestCase({
            networkId: "mantle", // Uses Mantle network from foundry.toml
            forkBlock: 62825725, // Block before the transaction
            fromToken: WMNT,
            toToken: USDT,
            pool: WMNT_USDT,
            amount: 0.415 * 10 ** 18, // 0.415 WMNT
            expectedOutput: 0.504974 * 10 ** 6,
            sellBase: true,
            expectRevert: false,
            description: "WMNT to USDT on Mantle",
            moreInfo: abi.encode(uint160(0), abi.encode(WMNT, USDT)),
            fromTokenPreTo: address(0)
        });

        // Test 2: USDT to WMNT
        cases[0][1] = SwapTestCase({
            networkId: "mantle",
            forkBlock: 62825725,
            fromToken: USDT,
            toToken: WMNT,
            pool: WMNT_USDT,
            amount: 1000000, // 1 USDT (6 decimals)
            expectedOutput: 0,
            sellBase: false, // USDT is quote token
            expectRevert: false,
            description: "USDT to WMNT on Mantle",
            moreInfo: abi.encode(uint160(0), abi.encode(USDT, WMNT)),
            fromTokenPreTo: address(0)
        });

        // Test 3: WETH to USDT
        cases[0][2] = SwapTestCase({
            networkId: "mantle",
            forkBlock: 62825725,
            fromToken: WETH,
            toToken: USDT,
            pool: WETH_USDT,
            amount: 1 ether, // 1 WETH
            expectedOutput: 0,
            sellBase: true,
            expectRevert: false,
            description: "WETH to USDT on Mantle",
            moreInfo: abi.encode(uint160(0), abi.encode(WETH, USDT)),
            fromTokenPreTo: address(0)
        });

        // Test 4: USDT to WETH
        cases[0][3] = SwapTestCase({
            networkId: "mantle",
            forkBlock: 62825725,
            fromToken: USDT,
            toToken: WETH,
            pool: WETH_USDT,
            amount: 3000 * 10 ** 6, // 3000 USDT
            expectedOutput: 0,
            sellBase: false,
            expectRevert: false,
            description: "USDT to WETH on Mantle",
            moreInfo: abi.encode(uint160(0), abi.encode(USDT, WETH)),
            fromTokenPreTo: address(0)
        });

        return cases;
    }
}
