// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.17;

import {UniV4Adapter} from "@dex/adapter/UniV4Adapter.sol";
import {AbstractAdapterTest} from "../common/AbstractAdapterTest.t.sol";

/// @title UniV4AdapterTest
/// @notice Adapter tests for UniV4Adapter (single hop swaps)
/// @dev Uses the AbstractAdapterTest harness to minimise boilerplate.
contract UniV4AdapterTest is AbstractAdapterTest {

    // Mapping of network IDs to their pool managers and wrapped tokens
    mapping(string => address) internal poolManagers;
    mapping(string => address) internal wrappedTokens;
    
    /**
     * @dev Create UniV4Adapter for the specified network
     * @param networkId The network identifier (e.g. "eth", "bsc", "base")
     */
    function createCustomAdapter(string memory networkId) internal override returns (address) {
        // Pool manager addresses per network
        poolManagers["eth"] = 0x000000000004444c5dc75cB358380D2e3dE08A90;
        poolManagers["base"] = 0x498581fF718922c3f8e6A244956aF099B2652b2b;
        poolManagers["unichain"] = 0x1F98400000000000000000000000000000000004;
        
        // Wrapped token addresses per network
        wrappedTokens["eth"] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH
        wrappedTokens["bsc"] = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c; // WBNB
        wrappedTokens["base"] = 0x4200000000000000000000000000000000000006; // WETH
        wrappedTokens["unichain"] = 0x4200000000000000000000000000000000000006; // WETH

        address poolManager = poolManagers[networkId];
        address wrappedToken = wrappedTokens[networkId];
        require(poolManager != address(0), "Unsupported network");
        require(wrappedToken != address(0), "Unsupported network");
        
        return address(
            new UniV4Adapter(
                poolManager,
                wrappedToken
            )
        );
    }

    /**
     * @dev Define test cases for UniV4 single hop swaps
     */
    function getSwapTestCases()
        internal
        pure
        override
        returns (SwapTestCase[][] memory)
    {
        SwapTestCase[][] memory cases = new SwapTestCase[][](1);
        cases[0] = getBaseTestCases();

        return cases;
    }

    function getBaseTestCases()
        internal
        pure
        returns (SwapTestCase[] memory)
    {
        // Token addresses on Base network
        address FeeToken = 0x1A85b97F8b0E1CEE4D5500E093F5970a2aeB3fB8; // Fee-on-transfer token
        address USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

        // Pool manager address on Base
        address POOL_MANAGER = 0x498581fF718922c3f8e6A244956aF099B2652b2b;

        SwapTestCase[] memory cases = new SwapTestCase[](1);

        // Test: Fee-on-transfer token to USDC on Base
        cases[0] = SwapTestCase({
            networkId: "base",
            forkBlock: 38611960,
            fromToken: FeeToken,
            toToken: USDC,
            pool: POOL_MANAGER,
            amount: 915523991890652198646, // ~915 FeeToken
            expectedOutput: 0, // dynamic
            sellBase: true,
            expectRevert: false,
            description: "Fee-on-transfer token to USDC on Base UniV4",
            moreInfo: abi.encode(FeeToken, USDC, uint24(50000), int24(1000)),
            fromTokenPreTo: address(0)
        });

        return cases;
    }
}

