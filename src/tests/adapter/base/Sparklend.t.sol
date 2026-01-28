// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {AbstractAdapterTest} from "../common/AbstractAdapterTest.t.sol";
import {AaveV3Adapter} from "@dex/adapter/AaveV3Adapter.sol";
import {IERC20} from "@dex/interfaces/IERC20.sol";

/**
 * @title SparklendTest
 * @dev Tests AaveV3Adapter with Sparklend on Ethereum mainnet
 * @dev Sparklend uses the same Aave V3 interface
 */
contract SparklendTest is AbstractAdapterTest {
    // Sparklend Pool on Ethereum mainnet
    address internal constant SPARK_POOL = 0xC13e21B648A5Ee794902342038FF3aDAB66BE987;

    // ETH Token addresses
    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant SP_WETH = 0x59cD1C87501baa753d0B5B5Ab5D8416A45cD71DB; // Spark WETH aToken
    
    // USDC addresses
    address internal constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant SP_USDC = 0x377C3bd93f2a2984E1E7bE6A5C22c525eD4A4815; // Spark USDC spToken

    function createCustomAdapter(
        string memory
    ) internal override returns (address) {
        return address(new AaveV3Adapter(SPARK_POOL));
    }

    function getSwapTestCases()
        internal
        override
        pure
        returns (SwapTestCase[][] memory)
    {
        SwapTestCase[][] memory cases = new SwapTestCase[][](1);
        cases[0] = getTestCases();
        return cases;
    }

    function getTestCases()
        internal
        pure
        returns (SwapTestCase[] memory)
    {
        SwapTestCase[] memory cases = new SwapTestCase[](4);

        // Test Case 0: Supply WETH (WETH -> spWETH)
        // https://etherscan.io/tx/0x16a44929d863ed8d8890bf8bb85ac79df42e762a4977517373229fd4296d2330
        cases[0] = SwapTestCase({
            networkId: "eth",
            forkBlock: 24244299,
            fromToken: WETH,
            toToken: SP_WETH,
            pool: SPARK_POOL,
            amount: 1000000000000000,
            expectedOutput: 1000000000000000,
            sellBase: true,
            expectRevert: false,
            description: "WETH to spWETH (Supply) on Sparklend ETH",
            moreInfo: abi.encode(WETH, SP_WETH, true),
            fromTokenPreTo: address(0)
        });

        // Test Case 1: Supply USDC (USDC -> spUSDC)
        // https://etherscan.io/tx/0x80c3722b6d591a5f229a98786779f63f24e2b5c8b1c6740e651c162e94642da0
        cases[1] = SwapTestCase({
            networkId: "eth",
            forkBlock: 24244305,
            fromToken: USDC,
            toToken: SP_USDC,
            pool: SPARK_POOL,
            amount: 500000,
            expectedOutput: 499999,
            sellBase: true,
            expectRevert: false,
            description: "USDC to spUSDC (Supply) on Sparklend ETH",
            moreInfo: abi.encode(USDC, SP_USDC, true),
            fromTokenPreTo: address(0)
        });

        // Test Case 2: Withdraw WETH (spWETH -> WETH)
        // https://etherscan.io/tx/0xcabef8ca203c214a8e72035c2be62bad7d5f9a121d33d6b3d992d09f4d1dcfe2
        cases[2] = SwapTestCase({
            networkId: "eth",
            forkBlock: 24267050 - 1,    // -1 for aaveTokens
            fromToken: SP_WETH,
            toToken: WETH,
            pool: SPARK_POOL,
            amount: 3824927707690, // spWETH burned
            expectedOutput: 3824927707690, // WETH received
            sellBase: false,
            expectRevert: false,
            description: "spWETH to WETH (Withdraw) on Sparklend ETH",
            moreInfo: abi.encode(SP_WETH, WETH, false),
            fromTokenPreTo: address(0)
        });

        // Test Case 3: Withdraw USDC (spUSDC -> USDC)
        // https://etherscan.io/tx/0x89001790049e3ade277f096fdcb0b5cd8309efe185ba0d25e44dbd99a870c624
        // Fork at block BEFORE the tx (24244329) so wealthy holder still has spUSDC
        cases[3] = SwapTestCase({
            networkId: "eth",
            forkBlock: 24244330 - 1,    // -1 for aaveTokens
            fromToken: SP_USDC,
            toToken: USDC,
            pool: SPARK_POOL,
            amount: 500000, // spUSDC to burn (6 decimals scaled)
            expectedOutput: 500000, // USDC received (6 decimals)
            sellBase: false,
            expectRevert: false,
            description: "spUSDC to USDC (Withdraw) on Sparklend ETH",
            moreInfo: abi.encode(SP_USDC, USDC, false),
            fromTokenPreTo: address(0)
        });

        return cases;
    }
}
