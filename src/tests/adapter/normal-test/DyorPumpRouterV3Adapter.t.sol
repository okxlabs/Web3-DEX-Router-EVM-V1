// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

import {DyorPumpRouterV3Adapter} from "contracts/8/adapter/DyorPumpRouterV3Adapter.sol";
import {AbstractAdapterTest} from "../common/AbstractAdapterTest.t.sol";

/**
 * @title DyorPumpRouterV3AdapterTest
 * @dev Test for DyorPumpRouterV3Adapter
 */
contract DyorPumpRouterV3AdapterTest is AbstractAdapterTest {
    /**
     * @dev Create BakeryAdapter
     */
    mapping(string => address) internal routers;
    mapping(string => address) internal weth;
    function createCustomAdapter(
        string memory networkId
    ) internal override returns (address) {
        routers["xlayer"] = 0xDf7143e86c919cb440e6e972bafe0ebD1bb26F56;
        weth["xlayer"] = 0xe538905cf8410324e03A5A23C1c177a474D59b2b;
        return address(new DyorPumpRouterV3Adapter(routers[networkId], weth[networkId]));
    }

    /**
     * @dev Define test cases for BakeryAdapter
     */
    function getSwapTestCases()
        internal
        pure
        override
        returns (SwapTestCase[][] memory)
    {
        SwapTestCase[][] memory cases = new SwapTestCase[][](1);
        cases[0] = getDyorfunTestCases();

        return cases;
    }

    function getDyorfunTestCases()
        internal
        pure
        returns (SwapTestCase[] memory)
    {
        SwapTestCase[] memory cases = new SwapTestCase[](1);

        address wokb = 0xe538905cf8410324e03A5A23C1c177a474D59b2b;
        address fftq = 0x2c557300CdC5a4a5665920096A986f055a1EAA18;
        address fftq_wokb_pool = fftq;
        address[] memory path = new address[](2);
        path[0] = wokb;
        path[1] = fftq;
        bytes memory moreInfo = abi.encode(0.303 * 10 ** 18, 0, path);
        // Test 1: Sell base (OKB -> fftq)
        cases[0] = SwapTestCase({
            networkId: "xlayer",
            forkBlock: 43475334, // Example block, update as needed
            fromToken: wokb,
            toToken: fftq,
            pool: fftq_wokb_pool,
            amount: 0.303 * 10 ** 18, // 0.3 WOKB
            expectedOutput: 0,
            sellBase: true,
            expectRevert: false,
            description: "WOKB to fftq on XLayer via DyorPumpRouterV3Adapter",
            moreInfo: moreInfo,
            fromTokenPreTo: address(0)
        });

        // Test 2: quote base (fftq -> OKB)
        // use src/tests/adapter/special/DyorPumpRouterV3Adapter.t.sol

        return cases;
    }
}