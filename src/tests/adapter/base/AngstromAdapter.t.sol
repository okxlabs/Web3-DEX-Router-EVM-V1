// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.17;

import {AngstromAdapter} from "@dex/adapter/AngstromAdapter.sol";
import {AbstractAdapterTest} from "../common/AbstractAdapterTest.t.sol";
import {Currency} from "@dex/types/Currency.sol";
import {IAngstromAdapter} from "@dex/interfaces/IAngstromAdapter.sol";
/// @title AngstromAdapterTest
/// @notice Adapter tests for AngstromAdapter
/// @dev Uses the new AbstractAdapterTest harness to minimise boilerplate.
contract AngstromAdapterTest is AbstractAdapterTest {

    // Mapping of network IDs to their pool managers and wrapped tokens
    mapping(string => address) internal poolManagers;
    mapping(string => address) internal wrappedTokens;
    
    /**
     * @dev Create UniV4AdapterV2 adapter for the specified network
     * @param networkId The network identifier (e.g. "eth", "bsc")
     */
    function createCustomAdapter(string memory networkId) internal override returns (address) {
        // Pool manager addresses per network
        poolManagers["eth"] = 0x000000000004444c5dc75cB358380D2e3dE08A90;
        poolManagers["bsc"] = 0x000000000004444c5dc75cB358380D2e3dE08A90;
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
            new AngstromAdapter(
                poolManager,
                wrappedToken
            )
        );
    }

    /**
     * @dev Define test cases for UniV4 multihop swaps
     */
    function getSwapTestCases()
        internal
        pure
        override
        returns (SwapTestCase[][] memory)
    {
        SwapTestCase[][] memory cases = new SwapTestCase[][](1);
        cases[0] = getAngstromTestCases();

        return cases;
    }

    function getAngstromTestCases() 
        internal
        pure
        returns (SwapTestCase[] memory)
    {
        address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        address angstromHook = 0x0000000aa232009084Bd71A5797d089AA4Edfad4;
        SwapTestCase[] memory cases = new SwapTestCase[](2);
        
        // Create attestation bundle
        IAngstromAdapter.Attestation[] memory attestations = new IAngstromAdapter.Attestation[](3);
        attestations[0] = IAngstromAdapter.Attestation({
            blockNumber: 23672782,
            unlockData: hex"1234abcd5678ef014c8d1e2f3a5b7c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b"
        });
        attestations[1] = IAngstromAdapter.Attestation({
            blockNumber: 23672783,
            unlockData: hex"1234abcd5678ef014c8d1e2f3a5b7c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b"
        });
        attestations[2] = IAngstromAdapter.Attestation({
            blockNumber: 23672783,
            unlockData: hex"1234abcd5678ef014c8d1e2f3a5b7c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b"
        });
        // Encode attestations to hookData
        bytes memory hookData = abi.encode(attestations);
        
        // Test 1: USDC -> WETH
        AngstromAdapter.PathKey[] memory pathKeys = new AngstromAdapter.PathKey[](1);
        pathKeys[0] = AngstromAdapter.PathKey({
            inputCurrency: Currency.wrap(usdc),
            intermediateCurrency: Currency.wrap(weth),        
            fee: 8388608,
            tickSpacing: 10,
            hook: angstromHook,
            hookData: hookData
        });
        cases[0] = SwapTestCase({
            networkId: "eth", // Uses eth network from foundry.toml
            forkBlock: 23672783, // Block from the actual transaction
            fromToken: usdc,
            toToken: weth,
            pool: angstromHook, // actually hook address
            amount: 1 * 10 ** 6,
            expectedOutput: 0,
            sellBase: true,
            expectRevert: false,
            description: "USDC to WETH COIN",
            moreInfo: abi.encode(pathKeys),
            fromTokenPreTo: address(0)
        });

        // Test 2: WETH -> USDC (reverse direction)
        AngstromAdapter.PathKey[] memory pathKeys2 = new AngstromAdapter.PathKey[](1);
        pathKeys2[0] = AngstromAdapter.PathKey({
            inputCurrency: Currency.wrap(weth),
            intermediateCurrency: Currency.wrap(usdc),        
            fee: 8388608,
            tickSpacing: 10,
            hook: angstromHook,
            hookData: hookData
        });
        cases[1] = SwapTestCase({
            networkId: "eth", // Uses eth network from foundry.toml
            forkBlock: 23672783, // Block from the actual transaction
            fromToken: weth,
            toToken: usdc,
            pool: angstromHook, // actually hook address
            amount: 0.001 ether, // 0.001 WETH
            expectedOutput: 0,
            sellBase: true,
            expectRevert: false,
            description: "WETH to USDC COIN",
            moreInfo: abi.encode(pathKeys2),
            fromTokenPreTo: address(0)
        });

        return cases;
    }
} 