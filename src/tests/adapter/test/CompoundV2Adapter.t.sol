// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

import {CompoundAdapter} from "@dex/adapter/CompoundV2Adapter.sol";
import {AbstractAdapterTest} from "../common/AbstractAdapterTest.t.sol";

/**
 * @title CompoundV2AdapterTest
 * @dev Test for Compound V2 adapter
 * @dev Tests mint (deposit) and redeem (withdraw) operations
 * @dev Uses "eth" network identifier from foundry.toml
 */
contract CompoundV2AdapterTest is AbstractAdapterTest {
    // Mapping of network IDs to their wrapped tokens
    mapping(string => address) internal WETH;

    /**
     * @dev Create CompoundV2 adapter
     */
    function createCustomAdapter(string memory networkId) internal override returns (address) {
        WETH["eth"] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        WETH["linea"] = 0xe5D7C2a44FfDDf6b295A15c148167daaAf5Cf34f;
        address weth = WETH[networkId];
        return address(new CompoundAdapter(weth));
    }

    /**
     * @dev Define test cases for Compound V2 operations
     */
    function getSwapTestCases()
        internal
        pure
        override
        returns (SwapTestCase[][] memory)
    {
        SwapTestCase[][] memory cases = new SwapTestCase[][](2);
        cases[0] = getCompoundV2TestCases();
        cases[1] = getMendiTestCases();
        
        return cases;
    }

    /**
     * @dev Define test cases for Compound V2 mint and redeem operations
     */
    function getCompoundV2TestCases() internal pure returns (SwapTestCase[] memory) {
        SwapTestCase[] memory cases = new SwapTestCase[](4);


        // Token addresses on Ethereum mainnet
        address CETH = 0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5; // cETH
        address WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH
        address DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F; // DAI
        address CDAI = 0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643; // cDAI
        address USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7; // USDT
        address CUSDT = 0xf650C3d88D12dB855b8bf7D11Be6C55A4e07dCC9; // cUSDT
        address ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
        
        // Test 1: ETH to cETH (Mint)
        // Based on the original test case from CompoundAdapter.t.sol
        cases[0] = SwapTestCase({
            networkId: "eth", // Uses ETH network from foundry.toml
            forkBlock: 19000000, // Historical block for stability
            fromToken: WETH, // Using WETH instead of ETH for consistency
            toToken: CETH,
            pool: address(0), // Not used in Compound adapter
            amount: 10 ether,
            expectedOutput: 0, // Dynamic - cToken rates vary
            sellBase: true,
            expectRevert: false,
            description: "ETH to cETH mint via Compound V2",
            moreInfo: abi.encode(ETH_ADDRESS, CETH, true), // (fromToken, toToken, isMint)
            fromTokenPreTo: address(0)
        });
        
        // Test 2: cETH to ETH (Redeem)
        cases[1] = SwapTestCase({
            networkId: "eth",
            forkBlock: 19000000,
            fromToken: CETH,
            toToken: WETH, // Will be converted from ETH_ADDRESS internally
            pool: address(0),
            amount: 500000000, // ~500 cETH (8 decimals)
            expectedOutput: 0, // Dynamic
            sellBase: true,
            expectRevert: false,
            description: "cETH to ETH redeem via Compound V2",
            moreInfo: abi.encode(CETH, ETH_ADDRESS, false), // (fromToken, toToken, isMint)
            fromTokenPreTo: address(0)
        });
        
        // Test 3: DAI to cDAI (Mint)
        cases[2] = SwapTestCase({
            networkId: "eth",
            forkBlock: 19000000,
            fromToken: DAI,
            toToken: CDAI,
            pool: address(0),
            amount: 1000 * 10**18, // 1000 DAI
            expectedOutput: 0, // Dynamic
            sellBase: true,
            expectRevert: false,
            description: "DAI to cDAI mint via Compound V2",
            moreInfo: abi.encode(DAI, CDAI, true),
            fromTokenPreTo: address(0)
        });
        
        // Test 4: cDAI to DAI (Redeem)
        cases[3] = SwapTestCase({
            networkId: "eth",
            forkBlock: 19000000,
            fromToken: CDAI,
            toToken: DAI,
            pool: address(0),
            amount: 50000 * 10**8, // 50000 cDAI (8 decimals)
            expectedOutput: 0, // Dynamic
            sellBase: true,
            expectRevert: false,
            description: "cDAI to DAI redeem via Compound V2",
            moreInfo: abi.encode(CDAI, DAI, false),
            fromTokenPreTo: address(0)
        });
        
        return cases;
    }

    function getMendiTestCases() internal pure returns (SwapTestCase[] memory) {
        SwapTestCase[] memory cases = new SwapTestCase[](1);
        // Token addresses on Linea
        address WETH = 0xe5D7C2a44FfDDf6b295A15c148167daaAf5Cf34f; // WETH
        address meWETH = 0xAd7f33984bed10518012013D4aB0458D37FEE6F3; // meWETH
        address meWETH_WETH_POOL = 0xAd7f33984bed10518012013D4aB0458D37FEE6F3; // meWETH_WETH_POOL
        //https://lineascan.build/tx/0x2e0350475cf4f55e33f3cee0c05e86312226792687e38f7eebeee1e0e65aa99f
        cases[0] = SwapTestCase({
            networkId: "linea",
            forkBlock: 21893946,
            fromToken: meWETH,
            toToken: WETH,
            pool: meWETH_WETH_POOL,
            amount: 0.52512768 * 10 ** 8, // 0.52512768 meWETH (18 decimals)
            expectedOutput: 0.01121091841618736 * 10 ** 18, // 0.01121091841618736 WETH (18 decimals)
            sellBase: false,
            expectRevert: false,
            description: "meWETH to WETH via Mendi on Linea",
            moreInfo: abi.encode(meWETH, WETH, false),
            fromTokenPreTo: address(0)
        });

        return cases;
    }
}