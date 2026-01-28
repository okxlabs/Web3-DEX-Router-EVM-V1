// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.17;

import {DnyFeeAdapter} from "@dex/adapter/DnyFeeAdapter.sol";
import {AbstractAdapterTest} from "../common/AbstractAdapterTest.t.sol";

/// @title DnyFeeAdapter
/// @notice Adapter tests for DnyFeeAdapter
/// @dev Uses the new AbstractAdapterTest harness to minimise boilerplate.
contract DnyFeeAdapterTest is AbstractAdapterTest {
    /**
     * @dev Create DnyFeeAdapter
     */
    function createCustomAdapter(
        string memory /* networkId */
    ) internal override returns (address) {
        return address(new DnyFeeAdapter());
    }

    /**
     * @dev Define test cases for DnyFeeAdapter swaps
     */
    function getSwapTestCases()
        internal
        override
        pure
        returns (SwapTestCase[][] memory)
    {
        SwapTestCase[][] memory cases = new SwapTestCase[][](5);
        cases[0] = getRocketForkUniV2TestCases();
        cases[1] = getLFGTestCases();
        cases[2] = getOKIETestCases(); // Skip OKIE tests
        cases[3] = getMonadTestCases();
        cases[4] = getDFSwapTestCases();

        return cases;
    }

    function getRocketForkUniV2TestCases()
        internal
        pure
        returns (SwapTestCase[] memory)
    {
        // Token addresses on Base network
        address WETH = 0x4200000000000000000000000000000000000006;
        address RCKT = 0x6653dD4B92a0e5Bf8ae570A98906d9D6fD2eEc09;
        address axlUSDC = 0xEB466342C4d449BC9f53A865D5Cb90586f405215;

        // Pool addresses
        address RCKTaxlUSDC = 0x1a7975836BD4f1a53e5251F41b6DA5FF5FD105f5;
        address axlUSDCWETH = 0x86cd8533b0166BDcF5d366A3Bb0c3465E56D3ad5;

        SwapTestCase[] memory cases = new SwapTestCase[](2);

        // Test 1: RCKT to axlUSDC
        // tx: https://basescan.org/tx/0x58d6b6e915bec61d737c3c4311cd4aedc9e5434f8e9804a0d1614b5314fef9c5
        // fee: 3/1000 (30)
        cases[0] = SwapTestCase({
            networkId: "base",
            forkBlock: 3781130,
            fromToken: RCKT,
            toToken: axlUSDC,
            pool: RCKTaxlUSDC,
            amount: 2 * 10 ** 18, // 2 RCKT
            expectedOutput: 0, // dynamic
            sellBase: true,
            expectRevert: false,
            description: "RCKT to axlUSDC on Base RocketForkUniV2",
            moreInfo: abi.encode(uint256(30)), // 3/1000 fee
            fromTokenPreTo: RCKTaxlUSDC // Transfer tokens to pool first
        });

        // Test 2: axlUSDC to WETH
        // tx: https://basescan.org/tx/0x5c9777c05d10055f8315944bae54f3ebf3733df315c4f74f7354182742acbc8d
        // fee: 3/1000 (30)
        cases[1] = SwapTestCase({
            networkId: "base",
            forkBlock: 3802311,
            fromToken: axlUSDC,
            toToken: WETH,
            pool: axlUSDCWETH,
            amount: 0.1 * 10 ** 6, // 0.1 axlUSDC
            expectedOutput: 0, // dynamic
            sellBase: false, // axlUSDC is quote token
            expectRevert: false,
            description: "axlUSDC to WETH on Base RocketForkUniV2",
            moreInfo: abi.encode(uint256(30)), // 3/1000 fee
            fromTokenPreTo: axlUSDCWETH // Transfer tokens to pool first
        });

        return cases;
    }

    function getLFGTestCases()
        internal
        pure
        returns (SwapTestCase[] memory)
    {

        SwapTestCase[] memory cases = new SwapTestCase[](2);

        address USDC = 0x74b7F16337b8972027F6196A17a631aC6dE26d22; // 6 dec
        address USDT = 0x1E4a5963aBFD975d8c9021ce480b42188849D41d; // 6 dec
        address LFG_LP = 0xA64DE09fDe4e98b1a9a105ebC1F933F1851B1168;

        // tx: https://web3.okx.com/explorer/x-layer/tx/0x8761af72402bf9c9f10183575814d09ffdb45a96fb85f8b5d42cb88bb981b0e4
        cases[0] = SwapTestCase({
            networkId: "xlayer",
            forkBlock: 31645200,
            fromToken: USDC,
            toToken: USDT,
            pool: LFG_LP,
            amount: 21.837674 * 10 ** 6, 
            expectedOutput: 21.807808 * 10 ** 6,
            sellBase: false,
            expectRevert: false,
            description: "USDC to USDT on LFG",
            moreInfo: abi.encode(uint256(30)), // 3/1000 fee
            fromTokenPreTo: LFG_LP // Transfer tokens to pool first
        });

        // expect revert because fee is less than 3/1000
        cases[1] = SwapTestCase({
            networkId: "xlayer",
            forkBlock: 31645200,
            fromToken: USDC,
            toToken: USDT,
            pool: LFG_LP,
            amount: 21.837674 * 10 ** 6, 
            expectedOutput: 21.807808 * 10 ** 6,
            sellBase: false,
            expectRevert: true,
            description: "USDC to USDT on LFG",
            moreInfo: abi.encode(uint256(29)), // 2.9/1000 fee
            fromTokenPreTo: LFG_LP // Transfer tokens to pool first
        });
    }

    function getOKIETestCases()
        internal
        pure
        returns (SwapTestCase[] memory)
    {
        SwapTestCase[] memory cases = new SwapTestCase[](2);

        address WOKB = 0xe538905cf8410324e03A5A23C1c177a474D59b2b; // WOKB
        address OKIECAT = 0x2dF6295e1F79751f39594554F1FD93a838430c71; // OKIE CAT
        address OKIE_LP = 0xf69466eA2Bb7A5Fbb82214f75ABAeF40442F8578; // OKIE LP

        // tx: https://web3.okx.com/explorer/x-layer/tx/0x22ec3d456d29079e78d0974b52f65ae2b250f0e87a9a7d7685687bb02f0c8297
        cases[0] = SwapTestCase({
            networkId: "xlayer",
            forkBlock: 31663032-1,
            fromToken: OKIECAT,
            toToken: WOKB,
            pool: OKIE_LP,
            amount: 2690411813480424849798337,  
            expectedOutput: 995059091108356848,
            sellBase: true,
            expectRevert: false,
            description: "OKIECAT to WOKB on OKIE",
            moreInfo: abi.encode(uint256(25)), // 2.5/1000 fee
            fromTokenPreTo: OKIE_LP // Transfer tokens to pool first
        });

        // expect revert because fee is less than 2.5/1000
        cases[1] = SwapTestCase({
            networkId: "xlayer",
            forkBlock: 31663032-1,
            fromToken: OKIECAT,
            toToken: WOKB,
            pool: OKIE_LP,
            amount: 2690411813480424849798337,  
            expectedOutput: 995059091108356848,
            sellBase: true,
            expectRevert: true,
            description: "OKIECAT to WOKB on OKIE",
            moreInfo: abi.encode(uint256(24)), // 2.4/1000 fee
            fromTokenPreTo: OKIE_LP // Transfer tokens to pool first
        });

        return cases;
    }

    function getMonadTestCases()
        internal
        pure
        returns (SwapTestCase[] memory)
    {
        SwapTestCase[] memory cases = new SwapTestCase[](1);

        // Token addresses on Monad network
        address WMON = 0x3bd359C1119dA7Da1D913D1C4D2B7c461115433A; // Wrapped MON
        address USDC = 0x754704Bc059F8C67012fEd69BC8A327a5aafb603; // USDC

        // Pool address
        address WMON_USDC_POOL = 0x3fE12728ea1B89E4Bac6e59A9130b61A27D032F8;

        // Test: WMON to USDC
        // Note: Monad has higher cold state access costs (8,100 gas vs 2,100 on Ethereum)
        cases[0] = SwapTestCase({
            networkId: "monad",
            forkBlock: 0, // Set to specific block when testing
            fromToken: WMON,
            toToken: USDC,
            pool: WMON_USDC_POOL,
            amount: 1 * 10 ** 18, // 1 WMON
            expectedOutput: 0, // dynamic
            sellBase: true, // WMON is token0 (base)
            expectRevert: false,
            description: "WMON to USDC on Monad",
            moreInfo: abi.encode(uint256(30)), // 3/1000 fee (adjust based on actual pool fee)
            fromTokenPreTo: WMON_USDC_POOL // Transfer tokens to pool first
        });

        return cases;
    }

    function getDFSwapTestCases()
        internal
        pure
        returns (SwapTestCase[] memory)
    {
        SwapTestCase[] memory cases = new SwapTestCase[](2);

        // DFSwap addresses on X Layer
        address WOKB = 0xe538905cf8410324e03A5A23C1c177a474D59b2b;
        address USDT0 = 0x779Ded0c9e1022225f8E0630b35a9b54bE713736;
        address WOKB_USDT0_POOL = 0xb6fd17297544076228ae0f7f43975CD564d47551;

        // Test: WOKB to USDT0 on DFSwap
        // https://www.oklink.com/x-layer/tx/0x42e21f6a803933c5fcc46b33f83aa9cd75fab74e103b639ff5f83f3a2401c989
        cases[0] = SwapTestCase({
            networkId: "xlayer",
            forkBlock: 38648250 - 1, // Block before the transaction
            fromToken: WOKB,
            toToken: USDT0,
            pool: WOKB_USDT0_POOL,
            amount: 261760427944461727, // amount1In from transaction
            expectedOutput: 49923723, // amount0Out from transaction
            sellBase: false, // WOKB is token1 (quote), USDT0 is token0 (base)
            expectRevert: false,
            description: "WOKB to USDT0 on DFSwap",
            moreInfo: abi.encode(uint256(30)), // 3/1000 fee
            fromTokenPreTo: WOKB_USDT0_POOL
        });

        cases[1] = SwapTestCase({
            networkId: "xlayer",
            forkBlock: 38648250 - 1, // Block before the transaction
            fromToken: USDT0,
            toToken: WOKB,
            pool: WOKB_USDT0_POOL,
            amount: 49923723, // amount0In from transaction
            expectedOutput: 0, // amount0Out from transaction
            sellBase: true, // USDT0 is token1 (quote), WOKB is token0 (base)
            expectRevert: false,
            description: "USDT0 to WOKB on DFSwap",
            moreInfo: abi.encode(uint256(30)), // 3/1000 fee
            fromTokenPreTo: WOKB_USDT0_POOL
        });

        return cases;
    }
}