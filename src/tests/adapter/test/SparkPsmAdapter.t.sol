// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {AbstractAdapterTest} from "../common/AbstractAdapterTest.t.sol";
import {SparkPsmAdapter} from "@dex/adapter/SparkPsmAdapter.sol";

contract SparkPsmAdapterTest is AbstractAdapterTest {

    // Mapping of network IDs to their Spark PSM addresses
    mapping(string => address) internal sparkPsmAddresses;

    function createCustomAdapter(
        string memory networkId
    ) internal override returns (address) {
        // Spark PSM addresses per network
        sparkPsmAddresses["arb"] = 0x2B05F8e1cACC6974fD79A673a341Fe1f58d27266; // Arbitrum PSM3 (same address)
        sparkPsmAddresses["op"] = 0xe0F9978b907853F354d79188A3dEfbD41978af62; // Optimism PSM3 (same address)
        sparkPsmAddresses["base"] = 0x1601843c5E9bC251A3272907010AFa41Fa18347E; // Base PSM3 (same address)

        address psmAddress = sparkPsmAddresses[networkId];
        require(psmAddress != address(0), "Unsupported network for Spark PSM");
        
        return address(new SparkPsmAdapter(psmAddress));
    }

    function getSwapTestCases()
        internal
        override
        pure
        returns (SwapTestCase[][] memory)
    {
        SwapTestCase[][] memory cases = new SwapTestCase[][](1);
        cases[0] = getSparkPsmTestCases();

        return cases;
    }

    function getSparkPsmTestCases() internal pure returns (SwapTestCase[] memory) {

        address USDC = 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85;
        address sUSDC = 0xb5B2dc7fd34C249F4be7fB1fCea07950784229e0;
        //https://optimistic.etherscan.io/tx/0x11c55d6d103caa4ab465f536037ef167c669f6648356156a375ff35b21a99930
        SwapTestCase[] memory cases = new SwapTestCase[](1);
        cases[0] = SwapTestCase({
            networkId: "op",
            forkBlock: 141083875 - 1,
            fromToken: USDC,
            toToken: sUSDC,
            pool: address(0),
            amount: 443.679223 * 10 ** 6,
            expectedOutput: 415.737795 * 10 ** 18,
            sellBase: false,
            expectRevert: false,
            description: "USDC to sUSDC on Optimism Spark PSM",
            moreInfo: abi.encode(USDC, sUSDC),
            fromTokenPreTo: address(0)
        });

        return cases;
    }
}
