// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

import {TraderJoeV2PAdapter} from "@dex/adapter/TraderJoeV2PAdapter.sol";
import {AbstractAdapterTest} from "../common/AbstractAdapterTest.t.sol";

/**
 * @title TraderJoeV2PAdapterTest
 * @dev Test for TraderJoeV2PAdapter (V2.1 & V2.2)
 */
contract TraderJoeV2PAdapterTest is AbstractAdapterTest {
    /**
     * @dev Create TraderJoeV2P adapter
     */
    function createCustomAdapter(string memory /* networkId */) internal override returns (address) {
        return address(new TraderJoeV2PAdapter());
    }

    function getSwapTestCases()
        internal
        pure
        override
        returns (SwapTestCase[][] memory)
    {
        SwapTestCase[][] memory cases = new SwapTestCase[][](1);
        cases[0] = getMonadTestCases();

        return cases;
    }

    function getMonadTestCases() internal pure returns (SwapTestCase[] memory) {
        address USDC = 0x754704Bc059F8C67012fEd69BC8A327a5aafb603;
        address AUSD = 0x00000000eFE302BEAA2b3e6e1b18d08D69a9012a;

        address USDC_AUSD_POOL = 0x465A0B350bb6a7eFF750729f1D866d67F0b53980;

        SwapTestCase[] memory cases = new SwapTestCase[](1);
        // https://monadvision.com/tx/0xae21e027273dc3a3efecfd8130fe25c476e2e66f7b4258cd3dc366d969e680e5
        cases[0] = SwapTestCase({
            networkId: "monad",
            forkBlock: 40859638 - 1,
            fromToken: USDC,
            toToken: AUSD,
            pool: USDC_AUSD_POOL,
            amount: 417210000,
            expectedOutput: 417272580,
            sellBase: true,
            expectRevert: false,
            description: "USDC to AUSD on Monad",
            moreInfo: abi.encode(USDC),
            fromTokenPreTo: USDC_AUSD_POOL
        });

        return cases;
    }
}

