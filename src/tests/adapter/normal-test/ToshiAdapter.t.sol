// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

import {ToshiAdapter} from "contracts/8/adapter/ToshiAdapter.sol";
import {AbstractAdapterTest} from "../common/AbstractAdapterTest.t.sol";

/**
 * @title ToshiAdapterTest
 * @dev Test for ToshiAdapter on Base network
 * @dev Uses "base" network identifier from foundry.toml
 */
contract ToshiAdapterTest is AbstractAdapterTest {
    /**
     * @dev Create ToshiAdapter
     */
    function createCustomAdapter(
        string memory
    ) internal override returns (address) {
        // Base WETH address
        address baseWETH = 0x4200000000000000000000000000000000000006;
        return address(new ToshiAdapter(baseWETH));
    }

    /**
     * @dev Define test cases for ToshiAdapter
     */
    function getSwapTestCases()
        internal
        pure
        override
        returns (SwapTestCase[][] memory)
    {
        SwapTestCase[][] memory cases = new SwapTestCase[][](1);
        cases[0] = getToshiTestCases();

        return cases;
    }

    function getToshiTestCases()
        internal
        pure
        returns (SwapTestCase[] memory)
    {
        SwapTestCase[] memory cases = new SwapTestCase[](2);

        // Base WETH address (used as input token)
        address baseWETH = 0x4200000000000000000000000000000000000006;
        // Output token from the transaction
        address outputToken = 0x37D1886D078D120d51281ac19121dC8721494e52;
        // Token from sell transaction (TizCoin)
        address tizToken = 0x935b06bdA8D6532Da6CFBfF2A9B06E9179328453;
        // Toshi pool address
        address toshiPool = 0x1ea172Fb88C24DFC21Ff6Fa38762511C123bA948;

        // Test case 1: WETH to ERC20 swap (buy operation)
        // https://basescan.org/tx/0xee294ed2c6deaac7479ffccd585ac7bb40f7364e4fd1f95436fea2e0cfa63870
        cases[0] = SwapTestCase({
            networkId: "base", // Uses Base network from foundry.toml
            forkBlock: 34352746 - 1, // Block number from the sell transaction
            fromToken: baseWETH,
            toToken: outputToken,
            pool: toshiPool,
            amount: 10000000000000, // 0.00001 ETH (10,000,000,000,000 wei)
            expectedOutput: 4266035750061719726760, // Expected output from the transaction
            sellBase: true,
            expectRevert: false,
            description: "WETH to ERC20 on Base via ToshiAdapter (Buy)",
            moreInfo: abi.encode(baseWETH, outputToken),
            fromTokenPreTo: address(0)
        });

        // Test case 2: ERC20 to ETH swap (sell operation) - simulating the actual BaseScan transaction
        // https://basescan.org/tx/0xa587baf8d7125e6a08240a765d08e3410255012fa52ce8c8e81e89b7874e734c
        cases[1] = SwapTestCase({
            networkId: "base", // Uses Base network from foundry.toml
            forkBlock: 34356414 - 1, // Block number from the actual transaction
            fromToken: tizToken, // TizCoin (TZ$)
            toToken: baseWETH, // ETH output
            pool: toshiPool,
            amount: 18114352919465595234577620, // Amount from the actual transaction
            expectedOutput: 9132025426582113, // ETH amount from actual transaction (0.009132025426582113 ETH)
            sellBase: false,
            expectRevert: false,
            description: "TizCoin to ETH on Base via ToshiAdapter (Sell)",
            moreInfo: abi.encode(tizToken, address(0)),
            fromTokenPreTo: toshiPool
        });

        return cases;
    }
}
