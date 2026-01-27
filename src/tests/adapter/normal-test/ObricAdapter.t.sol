// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

import {ObricAdapter} from "contracts/8/adapter/ObricAdapter.sol";
import {AbstractAdapterTest} from "../common/AbstractAdapterTest.t.sol";

/// @title ObricAdapterTest
/// @notice Adapter tests for ObricAdapter (Base)
/// @dev Uses "base" network identifier from foundry.toml
contract ObricAdapterTest is AbstractAdapterTest {
    /// @notice Create custom adapter instance for a given networkId
    function createCustomAdapter(string memory networkId) internal override returns (address adapter) {
        networkId; // silence unused warning
        return address(new ObricAdapter());
    }

    /// @notice Define swap test cases
    function getSwapTestCases() internal pure override returns (SwapTestCase[][] memory) {
        SwapTestCase[][] memory cases = new SwapTestCase[][](1);
        cases[0] = getBaseObricTestCases();
        return cases;
    }

    /// @notice Base network Obric test cases
    function getBaseObricTestCases() internal pure returns (SwapTestCase[] memory) {
        // Base token addresses
        address weth = 0x4200000000000000000000000000000000000006;
        address usdc = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

        // Obric pool used in integration test
        address pool = 0xcDfeE22ac1a69842f4e6068f64dB49B6B45b6A78;

        SwapTestCase[] memory cases = new SwapTestCase[](2);

        // Case 1: WETH -> USDC
        cases[0] = SwapTestCase({
            networkId: "base",
            forkBlock: 0, // latest
            fromToken: weth,
            toToken: usdc,
            pool: pool,
            amount: 0.001 ether,
            expectedOutput: 0, // dynamic
            sellBase: true,
            expectRevert: false,
            description: "WETH to USDC on Base (Obric)",
            moreInfo: abi.encode(weth, usdc),
            fromTokenPreTo: address(0)
        });

        // Case 2: USDC -> WETH
        cases[1] = SwapTestCase({
            networkId: "base",
            forkBlock: 0, // latest
            fromToken: usdc,
            toToken: weth,
            pool: pool,
            amount: 0.1 * 10 ** 6, // 0.1 USDC (6 decimals)
            expectedOutput: 0, // dynamic
            sellBase: false,
            expectRevert: false,
            description: "USDC to WETH on Base (Obric)",
            moreInfo: abi.encode(usdc, weth),
            fromTokenPreTo: address(0)
        });

        return cases;
    }
}
