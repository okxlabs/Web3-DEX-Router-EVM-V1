pragma solidity 0.8.17;

import {AbstractAdapterTest} from "../common/AbstractAdapterTest.t.sol";
import {SavingsPoolAdapter} from "@dex/adapter/SavingsPoolAdapter.sol";

contract SavingsPoolAdapterTest is AbstractAdapterTest {
    // ETH Token addresses - PYUSD
    address internal constant PYUSD = 0x6c3ea9036406852006290770BEdFcAbA0e23A0e8;
    address internal constant SP_PYUSD = 0x80128DbB9f07b93DDE62A6daeadb69ED14a7D354; // Spark PYUSD vault
    
    // ETH Token addresses - USDS
    address internal constant USDS = 0xdC035D45d973E3EC169d2276DDab16f1e407384F;
    address internal constant S_USDS = 0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD; // sUSDS vault (Spark)
    address internal constant ST_USDS = 0x99CD4Ec3f88A45940936F469E4bB72A2A701EEB9; // stUSDS vault (Sky)

    // Base Token addresses - USDC
    address internal constant USDC_BASE = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913; // Circle USDC on Base
    address internal constant S_USDC_BASE = 0x3128a0F7f0ea68E7B7c9B00AFa7E41045828e858; // Spark sUSDC on Base

    // Arbitrum Token addresses - USDC
    address internal constant USDC_ARB = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831; // Circle USDC on Arbitrum
    address internal constant S_USDC_ARB = 0x940098b108fB7D0a7E374f6eDED7760787464609; // Spark sUSDC on Arbitrum

    // Optimism Token addresses - USDC
    address internal constant USDC_OP = 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85; // Circle USDC on Optimism
    address internal constant S_USDC_OP = 0xCF9326e24EBfFBEF22ce1050007A43A3c0B6DB55; // Spark sUSDC on Optimism

    function createCustomAdapter(
        string memory
    ) internal override returns (address) {
        return address(new SavingsPoolAdapter());
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
        SwapTestCase[] memory cases = new SwapTestCase[](11);

        // Test Case 0: Deposit PYUSD -> spPYUSD (sellBase)
        // PYUSD has 6 decimals
        cases[0] = SwapTestCase({
            networkId: "eth",
            forkBlock: 24245863,
            fromToken: PYUSD,
            toToken: SP_PYUSD,
            pool: SP_PYUSD, // pool is the savings token itself
            amount: 1000000,
            expectedOutput: 996589,
            sellBase: true,
            expectRevert: false,
            description: "PYUSD to spPYUSD (Deposit) on Spark ETH",
            moreInfo: bytes(""),
            fromTokenPreTo: address(0)
        });

        // Test Case 1: Withdraw spPYUSD -> PYUSD (sellQuote)
        // https://etherscan.io/tx/0xafd44c95403616549d9fcb1d887292f7ad31b1dde54d95fb0c9ef5989947ad86
        cases[1] = SwapTestCase({
            networkId: "eth",
            forkBlock: 24246007, // Block before tx (24246008 - 1)
            fromToken: SP_PYUSD,
            toToken: PYUSD,
            pool: SP_PYUSD,
            amount: 996589, // spPYUSD shares
            expectedOutput: 1000001, // PYUSD assets received
            sellBase: false,
            expectRevert: false,
            description: "spPYUSD to PYUSD (Withdraw) on Spark ETH",
            moreInfo: bytes(""),
            fromTokenPreTo: address(0)
        });

        // Test Case 2: Deposit USDS -> sUSDS (sellBase)
        // https://etherscan.io/tx/0x19d562395aedc5f3d92fd7b559ce7e49e74483c9b5ae489b6b5bbc8782540615
        cases[2] = SwapTestCase({
            networkId: "eth",
            forkBlock: 24245863, // TODO: update to block before tx
            fromToken: USDS,
            toToken: S_USDS,
            pool: S_USDS,
            amount: 1000000000000000000, // TODO: update to actual tx amount (18 decimals)
            expectedOutput: 0, // TODO: update to actual tx output
            sellBase: true,
            expectRevert: false,
            description: "USDS to sUSDS (Deposit) on Spark ETH",
            moreInfo: bytes(""),
            fromTokenPreTo: address(0)
        });

        // Test Case 3: Withdraw sUSDS -> USDS (sellQuote)
        // https://etherscan.io/tx/0x39c1e7472c7a582a52192e4548bdab6cecf17088e97fbe913d2f3f15734748a6
        
        cases[3] = SwapTestCase({
            networkId: "eth",
            forkBlock: 24245798,
            fromToken: S_USDS,
            toToken: USDS,
            pool: S_USDS,
            amount: 923242360427600262, // sUSDS shares (18 decimals)
            expectedOutput: 1000000790981209751, // USDS assets received (18 decimals)
            sellBase: false,
            expectRevert: false,
            description: "sUSDS to USDS (Withdraw) on Spark ETH",
            moreInfo: bytes(""),
            fromTokenPreTo: address(0)
        });

        // Test Case 4: Withdraw stUSDS -> USDS (sellQuote) via Sky stUSDS
        // https://etherscan.io/tx/0xa92ffc2e532cb023219fe4f8c7249575d1922b451e8da8089de47d911c516b96
        cases[4] = SwapTestCase({
            networkId: "eth",
            forkBlock: 24245921,
            fromToken: ST_USDS,
            toToken: USDS,
            pool: ST_USDS,
            amount: 2036356194829051, // stUSDS shares (18 decimals)
            expectedOutput: 2090475985613330, // USDS assets received (18 decimals)
            sellBase: false,
            expectRevert: false,
            description: "stUSDS to USDS (Withdraw) on Sky ETH",
            moreInfo: bytes(""),
            fromTokenPreTo: address(0)
        });

        // Test Case 5: Withdraw sUSDC -> USDC on Base (sellQuote)
        // https://basescan.org/tx/0x84b81c00278af6b344259ce0ca0b9585f010fb6b725ed246461c0aecbe15aa73
        cases[5] = SwapTestCase({
            networkId: "base",
            forkBlock: 41000585,
            fromToken: S_USDC_BASE,
            toToken: USDC_BASE,
            pool: S_USDC_BASE,
            amount: 173085294115728653, // sUSDC shares (18 decimals)
            expectedOutput: 187532, // USDC assets received (6 decimals)
            sellBase: false,
            expectRevert: false,
            description: "sUSDC to USDC (Withdraw) on Spark Base",
            moreInfo: bytes(""),
            fromTokenPreTo: address(0)
        });

        // Test Case 6: Deposit USDC -> sUSDC on Base (sellBase)
        // https://basescan.org/tx/0x6e903df44dd036aa8f18397544e8ede2dccce4e6355c4d0c0af5df80806ed82e
        cases[6] = SwapTestCase({
            networkId: "base",
            forkBlock: 41000585, // TODO: update to correct block
            fromToken: USDC_BASE,
            toToken: S_USDC_BASE,
            pool: S_USDC_BASE,
            amount: 100000, // USDC assets (6 decimals) - TODO: update
            expectedOutput: 92296000000000000, // sUSDC shares - TODO: update
            sellBase: true,
            expectRevert: false,
            description: "USDC to sUSDC (Deposit) on Spark Base",
            moreInfo: bytes(""),
            fromTokenPreTo: address(0)
        });

        // Test Case 7: Deposit USDC -> sUSDC on Arbitrum (sellBase)
        // https://arbiscan.io/tx/0xc817724faafe167bfd23c04330fcb307e15db0e747cfee97a28e76f6d92cc685
        cases[7] = SwapTestCase({
            networkId: "arb",
            forkBlock: 422856266,
            fromToken: USDC_ARB,
            toToken: S_USDC_ARB,
            pool: S_USDC_ARB,
            amount: 1000000, // USDC assets (6 decimals)
            expectedOutput: 922963000000000000, // sUSDC shares (18 decimals)
            sellBase: true,
            expectRevert: false,
            description: "USDC to sUSDC (Deposit) on Spark Arbitrum",
            moreInfo: bytes(""),
            fromTokenPreTo: address(0)
        });

        // Test Case 8: Withdraw sUSDC -> USDC on Arbitrum (sellQuote)
        // https://arbiscan.io/tx/0xb2ada0c2222caf01990db38054a7bb9130f2be32a52e0d96f8f70adb1a94322e
        cases[8] = SwapTestCase({
            networkId: "arb",
            forkBlock: 422856337,
            fromToken: S_USDC_ARB,
            toToken: USDC_ARB,
            pool: S_USDC_ARB,
            amount: 922963000000000000, // sUSDC shares (18 decimals)
            expectedOutput: 999999, // USDC assets received (6 decimals)
            sellBase: false,
            expectRevert: false,
            description: "sUSDC to USDC (Withdraw) on Spark Arbitrum",
            moreInfo: bytes(""),
            fromTokenPreTo: address(0)
        });

        // Test Case 9: Deposit USDC -> sUSDC on Optimism (sellBase)
        // https://optimistic.etherscan.io/tx/0xa788fcd7decdf7d13b4de9268bf82a4275cf3c0769eb82972bec36a682a5cce3
        cases[9] = SwapTestCase({
            networkId: "op",
            forkBlock: 146596233,
            fromToken: USDC_OP,
            toToken: S_USDC_OP,
            pool: S_USDC_OP,
            amount: 1000000, // USDC assets (6 decimals)
            expectedOutput: 922963000000000000, // sUSDC shares (18 decimals)
            sellBase: true,
            expectRevert: false,
            description: "USDC to sUSDC (Deposit) on Spark Optimism",
            moreInfo: bytes(""),
            fromTokenPreTo: address(0)
        });

        // Test Case 10: Withdraw sUSDC -> USDC on Optimism (sellQuote)
        // https://optimistic.etherscan.io/tx/0xe8fba7a84bc233839d44aa7917676eb3073d20d1f21cf5040a742554f134d38d
        cases[10] = SwapTestCase({
            networkId: "op",
            forkBlock: 146596233, // TODO: update to correct block
            fromToken: S_USDC_OP,
            toToken: USDC_OP,
            pool: S_USDC_OP,
            amount: 922963000000000000, // sUSDC shares (18 decimals) - TODO: update
            expectedOutput: 999999, // USDC assets received (6 decimals) - TODO: update
            sellBase: false,
            expectRevert: false,
            description: "sUSDC to USDC (Withdraw) on Spark Optimism",
            moreInfo: bytes(""),
            fromTokenPreTo: address(0)
        });

        return cases;
    }
}
