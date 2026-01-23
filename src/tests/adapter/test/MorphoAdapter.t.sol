// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.17;

import {UniversalERC4626Adapter} from "@dex/adapter/TemplateAdapter/UniversalERC4626Adapter.sol";
import {AbstractAdapterTest} from "../common/AbstractAdapterTest.t.sol";

/// @title MorphoAdapterTest
/// @notice Adapter tests for Morpho vaults using UniversalERC4626Adapter
/// @dev Morpho MetaMorpho vaults are ERC4626 compliant
contract MorphoAdapterTest is AbstractAdapterTest {
    // Ethereum
    address constant WETH_ETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant VAULT_ETH = 0xBEEf050ecd6a16c4e7bfFbB52Ebba7846C4b8cD4;

    // Base
    address constant gtUSDCp_BASE = 0xeE8F4eC5672F09119b96Ab6fB59C27E1b7e44b61;
    address constant USDC_BASE = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    // Arbitrum
    address constant VAULT_ARB = 0x4B6F1C9E5d470b97181786b26da0d0945A7cf027;
    address constant USDC_ARB = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

    // Optimism
    address constant VAULT_OP = 0x48921e52f70CEC7D3425Cf5103Caace27Fc0b2Fe;
    address constant USDC_OP = 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85;

    function createCustomAdapter(
        string memory networkId
    ) internal override returns (address) {
        networkId;
        return address(new UniversalERC4626Adapter());
    }

    function getSwapTestCases()
        internal
        pure
        override
        returns (SwapTestCase[][] memory)
    {
        SwapTestCase[][] memory cases = new SwapTestCase[][](1);
        cases[0] = getTestCases();
        return cases;
    }

    function getTestCases() internal pure returns (SwapTestCase[] memory) {
        SwapTestCase[] memory cases = new SwapTestCase[](8);

        // https://basescan.org/tx/0xb4f4ad77130523d2c51935774414d4d304c0366d10c34bd08da0a4b9356879bd
        cases[0] = SwapTestCase({
            networkId: "base",
            forkBlock: 41010288,
            fromToken: USDC_BASE,
            toToken: gtUSDCp_BASE,
            pool: gtUSDCp_BASE,
            amount: 200000,
            expectedOutput: 184877026685354544,
            sellBase: true,
            expectRevert: false,
            description: "USDC to gtUSDCp deposit on Morpho Base",
            moreInfo: bytes(""),
            fromTokenPreTo: address(0)
        });

        // https://basescan.org/tx/0x99a40e0509a40161cdf19c76ed13e06ea9cb23fe60fdc06357f96eb84ff1a117
        cases[1] = SwapTestCase({
            networkId: "base",
            forkBlock: 41010432,
            fromToken: gtUSDCp_BASE,
            toToken: USDC_BASE,
            pool: gtUSDCp_BASE,
            amount: 184877026685354544,
            expectedOutput: 200000,
            sellBase: false,
            expectRevert: false,
            description: "gtUSDCp to USDC redeem on Morpho Base",
            moreInfo: bytes(""),
            fromTokenPreTo: address(0)
        });


        // https://etherscan.io/tx/0x6ad23866c893434f17a047768ca33a3b5a103e8c22c691f9ab8eedfaa3ef5e1f
        cases[2] = SwapTestCase({
            networkId: "eth",
            forkBlock: 24267594,
            fromToken: WETH_ETH,
            toToken: VAULT_ETH,
            pool: VAULT_ETH,
            amount: 1000000000000000,
            expectedOutput: 963359629024694,
            sellBase: true,
            expectRevert: false,
            description: "WETH to Vault deposit on Morpho ETH",
            moreInfo: bytes(""),
            fromTokenPreTo: address(0)
        });

        // https://etherscan.io/tx/0x8e6439bc158c1a8589519bcb21ce77f55db9af47a22f6bac52218d63e3d288dc
        cases[3] = SwapTestCase({
            networkId: "eth",
            forkBlock: 24267688,
            fromToken: VAULT_ETH,
            toToken: WETH_ETH,
            pool: VAULT_ETH,
            amount: 963359629024694,
            expectedOutput: 1000000650401003,
            sellBase: false,
            expectRevert: false,
            description: "Vault to WETH redeem on Morpho ETH",
            moreInfo: bytes(""),
            fromTokenPreTo: address(0)
        });

        // https://optimistic.etherscan.io/tx/0x42fa357a4d30044898eb2051984d50b69ecf239c657e0656c27e0b2a27a65057
        cases[4] = SwapTestCase({
            networkId: "op",
            forkBlock: 146606954,
            fromToken: USDC_OP,
            toToken: VAULT_OP,
            pool: VAULT_OP,
            amount: 1000000,
            expectedOutput: 997244030723769231,
            sellBase: true,
            expectRevert: false,
            description: "USDC to Vault deposit on Morpho OP",
            moreInfo: bytes(""),
            fromTokenPreTo: address(0)
        });

        // https://optimistic.etherscan.io/tx/0x6d9ee5fe03f9bfb798127a32403c01f641294549dd36c6a9d7c8e550cd5f7a21
        cases[5] = SwapTestCase({
            networkId: "op",
            forkBlock: 146606987,
            fromToken: VAULT_OP,
            toToken: USDC_OP,
            pool: VAULT_OP,
            amount: 997244030723769231,
            expectedOutput: 1000000,
            sellBase: false,
            expectRevert: false,
            description: "Vault to USDC redeem on Morpho OP",
            moreInfo: bytes(""),
            fromTokenPreTo: address(0)
        });

        // https://arbiscan.io/tx/0xed306d14d43c4e2d17491246341b5f219166839bd9b4b0e50d6006a52ca29667
        cases[6] = SwapTestCase({
            networkId: "arb",
            forkBlock: 422938796,
            fromToken: USDC_ARB,
            toToken: VAULT_ARB,
            pool: VAULT_ARB,
            amount: 5000000,
            expectedOutput: 4870906375202556295,
            sellBase: true,
            expectRevert: false,
            description: "USDC to Vault deposit on Morpho Arb",
            moreInfo: bytes(""),
            fromTokenPreTo: address(0)
        });

        // https://arbiscan.io/tx/0x5a49ff464ca1aea2105ee4c22e862b543547d6ebc012f9f4a8914b5d6ae42942
        cases[7] = SwapTestCase({
            networkId: "arb",
            forkBlock: 422938913,
            fromToken: VAULT_ARB,
            toToken: USDC_ARB,
            pool: VAULT_ARB,
            amount: 4870906375202556295,
            expectedOutput: 5000000,
            sellBase: false,
            expectRevert: false,
            description: "Vault to USDC redeem on Morpho Arb",
            moreInfo: bytes(""),
            fromTokenPreTo: address(0)
        });

        return cases;
    }
}
