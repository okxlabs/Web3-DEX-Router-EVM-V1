// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {AbstractAdapterTest} from "../common/AbstractAdapterTest.t.sol";
import {DODOV2Adapter} from "@dex/adapter/DODOV2Adapter.sol";

contract DODOV2AdapterTest is AbstractAdapterTest {

    function createCustomAdapter(
        string memory /* networkId */
    ) internal override returns (address) {
        return address(new DODOV2Adapter());
    }

    function getSwapTestCases()
        internal
        override
        pure
        returns (SwapTestCase[][] memory)
    {
        SwapTestCase[][] memory cases = new SwapTestCase[][](1);
        cases[0] = getAbracadabraTestCases();

        return cases;
    }

    function getAbracadabraTestCases() internal pure returns (SwapTestCase[] memory) {

        address MIM = 0xFEa7a6a0B346362BF88A9e4A88416B77a57D6c2A;
        address USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
        address USDC_MIM_POOL = 0x8279699D397ED22b1014fE4D08fFD7Da7B3374C0;
        //https://arbiscan.io/tx/0x21bde7b7a6b189fe06be92f9c50b4a8c1bdb923c08ed3c88b5f9aafc3bbd45ed
        SwapTestCase[] memory cases = new SwapTestCase[](1);
        cases[0] = SwapTestCase({
            networkId: "arb",
            forkBlock: 379068773 - 1,
            fromToken: MIM,
            toToken: USDC,
            pool: USDC_MIM_POOL,
            amount: 50.650178 * 10 ** 18,
            expectedOutput: 50.648678 * 10 ** 6,
            sellBase: true,
            expectRevert: false,
            description: "MIM to USDC on Abracadabra",
            moreInfo: abi.encode(),
            fromTokenPreTo: USDC_MIM_POOL
        });

        return cases;
    }
}
