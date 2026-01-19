// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

import {GmxAdapter2} from "@dex/adapter/GmxAdapter2.sol";
import {AbstractAdapterTest} from "../common/AbstractAdapterTest.t.sol";

/**
 * @title GmxAdapter2Test
 * @dev Test for GMX V2 adapter on Avalanche
 * @dev Tests token swaps through GMX vault
 * @dev Uses "avax" network identifier from foundry.toml
 */
contract GmxAdapter2Test is AbstractAdapterTest {
    /**
     * @dev Create GmxAdapter2 adapter
     */
    function createCustomAdapter(string memory /* networkId */) internal override returns (address) {
        return address(new GmxAdapter2());
    }

    /**
     * @dev Define test cases for GMX swaps
     */
    function getSwapTestCases()
        internal
        pure
        override
        returns (SwapTestCase[][] memory)
    {
        SwapTestCase[][] memory cases = new SwapTestCase[][](3);
        cases[0] = getGmxV2TestCases();
        cases[1] = getBmxTestCases();
        cases[2] = getNavigatorCryptoPoolTestCases();
        
        return cases;
    }
    function getNavigatorCryptoPoolTestCases() internal pure returns (SwapTestCase[] memory) {
        SwapTestCase[] memory cases = new SwapTestCase[](1);

        address WSONIC = 0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38;
        address LBTC = 0xecAc9C5F704e954931349Da37F60E39f515c11c1;
        address VAULT = 0xe9263682E837eFabb145f8C632B9d2c518D90652;
        // https://sonicscan.org/tx/0xbc3f352ec9c04541c90a4e976184b18310f704f07598123ff7c316b192891b7f
        cases[0] = SwapTestCase({
            networkId: "sonic",
            forkBlock: 47040356,
            fromToken: WSONIC,
            toToken: LBTC,
            pool: VAULT,
            amount: 1045.7224308028324 * 10 ** 18,
            expectedOutput: 272511,
            sellBase: true,
            expectRevert: false,
            description: "WSONIC to LBTC on Navigator Crypto Pool",
            moreInfo: abi.encode(WSONIC, LBTC),
            fromTokenPreTo: address(0)
        });

        return cases;
    }

    /**
     * @dev Define test cases for GMX V2 using Avalanche network
     */
    function getGmxV2TestCases() internal pure returns (SwapTestCase[] memory) {
        // Token addresses on Avalanche
        address WAVAX = 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7;
        address USDC_e = 0xA7D7079b0FEaD91F3e65f86E8915Cb59c1a4C664;
        address USDC = 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E;
        
        // GMX vault address on Avalanche
        address GMX_VAULT = 0x9ab2De34A33fB459b538c43f251eB825645e8595;
        
        SwapTestCase[] memory cases = new SwapTestCase[](2);
        
        // Test 1: WAVAX to USDC.e
        // Based on the original test case from GmxAdapter2.t.sol
        cases[0] = SwapTestCase({
            networkId: "avax", // Uses AVAX network from foundry.toml
            forkBlock: 41269697, // From original test - requires archive node
            fromToken: WAVAX,
            toToken: USDC_e,
            pool: GMX_VAULT,
            amount: 1 ether,
            expectedOutput: 34855635, // Dynamic - GMX pricing varies
            sellBase: true,
            expectRevert: false,
            description: "WAVAX to USDC.e via GMX on AVAX",
            moreInfo: abi.encode(WAVAX, USDC_e),
            fromTokenPreTo: address(0)
        });
        
        // Test 2: USDC.e to USDC
        // Second swap from the original test sequence
        cases[1] = SwapTestCase({
            networkId: "avax",
            forkBlock: 41269697, // Same block as first test
            fromToken: USDC_e,
            toToken: USDC,
            pool: GMX_VAULT,
            amount: 30 * 10**6, // 30 USDC.e (6 decimals)
            expectedOutput: 29994000, // 29.994 USDC (6 decimals)
            sellBase: true,
            expectRevert: false,
            description: "USDC.e to USDC via GMX on AVAX",
            moreInfo: abi.encode(USDC_e, USDC),
            fromTokenPreTo: address(0)
        });
        
        return cases;
    }

    function getBmxTestCases() internal pure returns (SwapTestCase[] memory) {
        // Token addresses on Base
        address WELL = 0xA88594D404727625A9437C3f886C7643872296AE;
        address USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
        
        // BMX vault address on Base
        address BMX_VAULT = 0xec8d8D4b215727f3476FF0ab41c406FA99b4272C;
        
        SwapTestCase[] memory cases = new SwapTestCase[](1);
        
        // Test 1: WELL to USDC
        // https://basescan.org/tx/0x9cbcea0e789ffdafec1715cc979310a9d7c529db6d8743c97a79f7a9978d22fa
        cases[0] = SwapTestCase({
            networkId: "base", // Uses Base network from foundry.toml
            forkBlock: 34054006 - 1, // Base chain block - adjust as needed
            fromToken: WELL,
            toToken: USDC,
            pool: BMX_VAULT,
            amount: 35.538577479802864018 * 10 ** 18, // 35.538577479802864018 WELL tokens (18 decimals)
            expectedOutput: 1.195769 * 10 ** 6, // 1.195769 USDC (6 decimals)
            sellBase: true,
            expectRevert: false,
            description: "WELL to USDC via BMX on Base",
            moreInfo: abi.encode(WELL, USDC),
            fromTokenPreTo: address(0)
        });
        
        return cases;
    }
}
