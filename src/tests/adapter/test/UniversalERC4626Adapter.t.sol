// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

import {UniversalERC4626Adapter} from "@dex/adapter/TemplateAdapter/UniversalERC4626Adapter.sol";
import {AbstractAdapterTest} from "../common/AbstractAdapterTest.t.sol";

/// @title UniversalERC4626AdapterTest
/// @notice Adapter tests for UniversalERC4626Adapter
/// @dev Uses the AbstractAdapterTest harness with ERC4626 vaults from Ethereum mainnet
contract UniversalERC4626AdapterTest is AbstractAdapterTest {
    // ERC4626 Vault addresses on Ethereum mainnet
    address constant sUSDS = 0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD;
    address constant USDS = 0xdC035D45d973E3EC169d2276DDab16f1e407384F;
    address constant sGYD = 0xeA50f402653c41cAdbaFD1f788341dB7B7F37816;
    address constant GYD = 0xe07F9D810a48ab5c3c914BA3cA53AF14E4491e8A;
    address constant scrvUSD = 0x0655977FEb2f289A4aB78af67BAB0d17aAb84367;
    address constant crvUSD = 0xf939E0A03FB07F59A73314E73794Be0E57ac1b4E;
    address constant USX = 0x0000000000000000000000000000000000000000;
    /**
     * @dev Create UniversalERC4626Adapter for the specified network
     * @param networkId The network identifier (e.g. "eth")
     */
    function createCustomAdapter(
        string memory networkId
    ) internal override returns (address) {
        // Silence unused variable warning
        networkId;
        return address(new UniversalERC4626Adapter());
    }

    /**
     * @dev Define test cases for ERC4626 swaps
     */
    function getSwapTestCases()
        internal
        pure
        override
        returns (SwapTestCase[][] memory)
    {
        SwapTestCase[][] memory cases = new SwapTestCase[][](3);
        cases[0] = getSUSDSTestCases();
        cases[1] = getSGYDTestCases();
        cases[2] = getSCRVUSDTestCases();
        return cases;
    }

    /**
     * @dev Test cases for sUSDS vault (USDS <-> sUSDS)
     * sUSDS is an ERC4626 vault for USDS stablecoin
     */
    function getSUSDSTestCases() internal pure returns (SwapTestCase[] memory) {
        SwapTestCase[] memory cases = new SwapTestCase[](2);

        // Test 1: USDS -> sUSDS (deposit)
        cases[0] = SwapTestCase({
            networkId: "eth",
            forkBlock: 0, // latest
            fromToken: USDS,
            toToken: sUSDS,
            pool: sUSDS, // ERC4626 vault is the pool
            amount: 1 * 10 ** 18, // 1 USDS
            expectedOutput: 0, // dynamic based on exchange rate
            sellBase: true, // asset -> shares
            expectRevert: false,
            description: "USDS to sUSDS deposit",
            moreInfo: abi.encode(USDS, sUSDS),
            fromTokenPreTo: address(0)
        });

        // Test 2: sUSDS -> USDS (redeem)
        cases[1] = SwapTestCase({
            networkId: "eth",
            forkBlock: 0, // latest
            fromToken: sUSDS,
            toToken: USDS,
            pool: sUSDS, // ERC4626 vault is the pool
            amount: 1 * 10 ** 18, // 1 sUSDS share
            expectedOutput: 0, // dynamic based on exchange rate
            sellBase: false, // shares -> asset (sellQuote)
            expectRevert: false,
            description: "sUSDS to USDS redeem",
            moreInfo: abi.encode(sUSDS, USDS),
            fromTokenPreTo: address(0)
        });

        return cases;
    }

    /**
     * @dev Test cases for sGYD vault (GYD <-> sGYD)
     * sGYD is an ERC4626 vault for GYD stablecoin
     */
    function getSGYDTestCases() internal pure returns (SwapTestCase[] memory) {
        SwapTestCase[] memory cases = new SwapTestCase[](2);

        // Test 1: GYD -> sGYD (deposit)
        cases[0] = SwapTestCase({
            networkId: "eth",
            forkBlock: 0, // latest
            fromToken: GYD,
            toToken: sGYD,
            pool: sGYD, // ERC4626 vault is the pool
            amount: 1 * 10 ** 18, // 1 GYD
            expectedOutput: 0, // dynamic based on exchange rate
            sellBase: true, // asset -> shares
            expectRevert: false,
            description: "GYD to sGYD deposit",
            moreInfo: abi.encode(GYD, sGYD),
            fromTokenPreTo: address(0)
        });

        // Test 2: sGYD -> GYD (redeem)
        cases[1] = SwapTestCase({
            networkId: "eth",
            forkBlock: 0, // latest
            fromToken: sGYD,
            toToken: GYD,
            pool: sGYD, // ERC4626 vault is the pool
            amount: 1 * 10 ** 18, // 1 sGYD share
            expectedOutput: 0, // dynamic based on exchange rate
            sellBase: false, // shares -> asset (sellQuote)
            expectRevert: false,
            description: "sGYD to GYD redeem",
            moreInfo: abi.encode(sGYD, GYD),
            fromTokenPreTo: address(0)
        });

        return cases;
    }

    /**
     * @dev Test cases for scrvUSD vault (crvUSD <-> scrvUSD)
     * scrvUSD is an ERC4626 vault for crvUSD stablecoin (Curve)
     */
    function getSCRVUSDTestCases()
        internal
        pure
        returns (SwapTestCase[] memory)
    {
        SwapTestCase[] memory cases = new SwapTestCase[](2);

        // Test 1: crvUSD -> scrvUSD (deposit)
        cases[0] = SwapTestCase({
            networkId: "eth",
            forkBlock: 0, // latest
            fromToken: crvUSD,
            toToken: scrvUSD,
            pool: scrvUSD, // ERC4626 vault is the pool
            amount: 1 * 10 ** 18, // 1 crvUSD
            expectedOutput: 0, // dynamic based on exchange rate
            sellBase: true, // asset -> shares
            expectRevert: false,
            description: "crvUSD to scrvUSD deposit",
            moreInfo: abi.encode(crvUSD, scrvUSD),
            fromTokenPreTo: address(0)
        });

        // Test 2: scrvUSD -> crvUSD (redeem)
        cases[1] = SwapTestCase({
            networkId: "eth",
            forkBlock: 0, // latest
            fromToken: scrvUSD,
            toToken: crvUSD,
            pool: scrvUSD, // ERC4626 vault is the pool
            amount: 1 * 10 ** 18, // 1 scrvUSD share
            expectedOutput: 0, // dynamic based on exchange rate
            sellBase: false, // shares -> asset (sellQuote)
            expectRevert: false,
            description: "scrvUSD to crvUSD redeem",
            moreInfo: abi.encode(scrvUSD, crvUSD),
            fromTokenPreTo: address(0)
        });

        return cases;
    }
}
