// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {AbstractAdapterTest} from "../common/AbstractAdapterTest.t.sol";
import {VenusAdapter} from "@dex/adapter/VenusAdapter.sol";
import {IERC20} from "@dex/interfaces/IERC20.sol";
import "forge-std/console2.sol";

contract VenusAdapterTest is AbstractAdapterTest {
    // BSC addresses
    address internal constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    
    // BSC Venus tokens
    address internal constant vUSDT = 0xfD5840Cd36d94D7229439859C0112a4185BC0255;
    address internal constant vUSDC = 0xecA88125a5ADbe82614ffC12D0DB554E2e2867C8;
    address internal constant vBNB = 0xA07c5b74C9B40447a954e1466938b865b6BBea36;
    
    // BSC Underlying tokens
    address internal constant USDT = 0x55d398326f99059fF775485246999027B3197955;
    address internal constant USDC = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;
    address internal constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    // ARB Venus tokens
    address internal constant vUSDC_ARB = 0x7D8609f8da70fF9027E9bc5229Af4F6727662707;
    
    // ARB Underlying tokens
    address internal constant USDC_ARB = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

    // ETH Venus tokens
    address internal constant vUSDC_ETH = 0x17C07e0c232f2f80DfDbd7a95b942D893A4C5ACb;
    
    // ETH Underlying tokens
    address internal constant USDC_ETH = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    function createCustomAdapter(
        string memory networkId
    ) internal override returns (address) {
        // BSC needs WBNB for native token wrapping, ARB doesn't need WETH
        if (keccak256(bytes(networkId)) == keccak256(bytes("bsc"))) {
            return address(new VenusAdapter(WBNB, vBNB));
        }
        return address(new VenusAdapter(address(0), address(0)));
    }

    function getSwapTestCases()
        internal
        override
        view
        returns (SwapTestCase[][] memory)
    {
        SwapTestCase[][] memory cases = new SwapTestCase[][](1);
        cases[0] = getTestCases();
        return cases;
    }

    function getTestCases()
        internal
        view
        returns (SwapTestCase[] memory)
    {
        SwapTestCase[] memory cases = new SwapTestCase[](9);

        // Test Case 1: USDC -> vUSDC (Mint)
        // https://bscscan.com/tx/0x2a1363b65426a39e2fd348c3fbedddb35967b051cdd67e3c5ebb7f9205357a71
        cases[0] = SwapTestCase({
            networkId: "bsc",
            forkBlock: 74222161,
            fromToken: USDC,
            toToken: vUSDC,
            pool: vUSDC,
            amount: 2 * 10 ** 18,
            expectedOutput: 7631287680,
            sellBase: false,
            expectRevert: false,
            description: "USDC to vUSDC (Mint) on Venus BSC",
            moreInfo: "",
            fromTokenPreTo: address(0)
        });

        // Test Case 2: vUSDC -> USDC (Redeem)
        // https://bscscan.com/tx/0xfb796239992988b4415ffe9d3eaedfcdc88b254452abe317ba5530d4bdd7bfe9
        cases[1] = SwapTestCase({
            networkId: "bsc",
            forkBlock: 74222740,
            fromToken: vUSDC,
            toToken: USDC,
            pool: vUSDC,
            amount: 11446926800,
            expectedOutput: 2999999999950910472, // ~ 3 USDC
            sellBase: true,
            expectRevert: false,
            description: "vUSDC to USDC (Redeem) on Venus BSC",
            moreInfo: "",
            fromTokenPreTo: address(0)
        });

        // Test Case 3: vBNB -> BNB (Redeem)
        // Based on mint tx: https://bscscan.com/tx/0x0d550daf7420031ab8f3c94d8be834862ca3524916662ae47d6e685e12e4aeb8
        cases[2] = SwapTestCase({
            networkId: "bsc",
            forkBlock: 74220998,
            fromToken: vBNB,
            toToken: WBNB,  // Test framework checks WBNB balance
            pool: vBNB,
            amount: 4014839,  // 0.04014839 vBNB (8 decimals)
            expectedOutput: 999999770086297,  // ~0.001 BNB wrapped to WBNB
            sellBase: true,
            expectRevert: false,
            description: "vBNB to BNB (Redeem) on Venus BSC",
            moreInfo: "",
            fromTokenPreTo: address(0)
        });

        // Test Case 4: BNB -> vBNB (Mint)
        // https://bscscan.com/tx/0x0d550daf7420031ab8f3c94d8be834862ca3524916662ae47d6e685e12e4aeb8
        cases[3] = SwapTestCase({
            networkId: "bsc",
            forkBlock: 74220997,  // Block before the mint tx
            fromToken: WBNB,  // Test framework uses WBNB, adapter unwraps to BNB
            toToken: vBNB,
            pool: vBNB,
            amount: 1000000000000000,  // 0.001 BNB (18 decimals)
            expectedOutput: 4014839,  // ~0.04014839 vBNB (8 decimals)
            sellBase: false,
            expectRevert: false,
            description: "BNB to vBNB (Mint) on Venus BSC",
            moreInfo: "",
            fromTokenPreTo: address(0)
        });

        // Test Case 5: USDC -> vUSDC (Mint) on ARB
        // https://arbiscan.io/tx/0x430ca13f75962415743ac1935b4159ac7517a54862aa14ddc532024edd5d7159
        cases[4] = SwapTestCase({
            networkId: "arb",
            forkBlock: 418396378,
            fromToken: USDC_ARB,
            toToken: vUSDC_ARB,
            pool: vUSDC_ARB,
            amount: 1000000,  // 1 USDC (6 decimals)
            expectedOutput: 91851390,  // Dynamic (~0.9185139 vUSDC at 8 decimals)
            sellBase: false,
            expectRevert: false,
            description: "USDC to vUSDC (Mint) on Venus ARB",
            moreInfo: "",
            fromTokenPreTo: address(0)
        });

        // Test Case 6: vUSDC -> USDC (Redeem) on ARB
        // https://arbiscan.io/tx/0xa54721e1540885c3e0b01e909cb34986a557f4fa4a64cc7c969f5ae1664cd3fa
        cases[5] = SwapTestCase({
            networkId: "arb",
            forkBlock: 418405485,
            fromToken: vUSDC_ARB,
            toToken: USDC_ARB,
            pool: vUSDC_ARB,
            amount: 91851183,  // 0.91851183 vUSDC (8 decimals)
            expectedOutput: 1000000,  // (1 USDC at 6 decimals)
            sellBase: true,
            expectRevert: false,
            description: "vUSDC to USDC (Redeem) on Venus ARB",
            moreInfo: "",
            fromTokenPreTo: address(0)
        });

        // Test Case 7: USDC -> vUSDC (Mint) on ETH
        // https://etherscan.io/tx/0x2861fea1b195715ea548fc3f148ed13c4d4fb2dcd8226e014d5881cde0cc7d2d
        cases[6] = SwapTestCase({
            networkId: "eth",
            forkBlock: 24173675,
            fromToken: USDC_ETH,
            toToken: vUSDC_ETH,
            pool: vUSDC_ETH,
            amount: 500000,  // 0.5 USDC (6 decimals)
            expectedOutput: 45433340,  // Dynamic (~45433340 vUSDC at 8 decimals)
            sellBase: false,
            expectRevert: false,
            description: "USDC to vUSDC (Mint) on Venus ETH",
            moreInfo: "",
            fromTokenPreTo: address(0)
        });

        // Test Case 8: vUSDC -> USDC (Redeem) on ETH
        // https://etherscan.io/tx/0x82da8c11347e7450c8d1f949abb58dec9c0084e68464cefa0fe554b356339b64
        cases[7] = SwapTestCase({
            networkId: "eth",
            forkBlock: 24173677,
            fromToken: vUSDC_ETH,
            toToken: USDC_ETH,
            pool: vUSDC_ETH,
            amount: 45433340,  // 0.4543334 vUSDC (8 decimals)
            expectedOutput: 500000,  // Dynamic (~0.5 USDC at 6 decimals)
            sellBase: true,
            expectRevert: false,
            description: "vUSDC to USDC (Redeem) on Venus ETH",
            moreInfo: "",
            fromTokenPreTo: address(0)
        });

        // Test Case 9: Non-vToken pool should revert
        // Passing USDC (not a vToken) as pool should fail isVToken() check
        cases[8] = SwapTestCase({
            networkId: "bsc",
            forkBlock: 0,
            fromToken: USDC,
            toToken: vUSDC,
            pool: USDC,  // USDC is NOT a vToken - should revert
            amount: 1 * 10 ** 18,
            expectedOutput: 0,
            sellBase: false,
            expectRevert: true,  // Expect revert because USDC.isVToken() will fail
            description: "Non-vToken pool should revert (USDC passed as pool)",
            moreInfo: "",
            fromTokenPreTo: address(0)
        });

        return cases;
    }
}

