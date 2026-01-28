// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

import {TesseraAdapter} from "contracts/8/adapter/TesseraAdapter.sol";
import {AbstractAdapterTest} from "../common/AbstractAdapterTest.t.sol";

/// @title TesseraAdapterTest
contract TesseraAdapterTest is AbstractAdapterTest {
    address private constant TESSERA_SWAP = 0x55555522005BcAE1c2424D474BfD5ed477749E3e;

    address private constant BSC_POOL_WBNB_USDT = 0xf524C1Bc1C64A2C99bc7eccf19EDe9a1d89d5a7C;
    address private constant BSC_POOL_BROCCOLI_USDT = 0xfcB771FfEA207F32fb8b4c105A284EAc7d975A32;

    address private constant BSC_WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address private constant BSC_USDT = 0x55d398326f99059fF775485246999027B3197955;
    address private constant BSC_BROCCOLI = 0x6d5AD1592ed9D6D1dF9b93c793AB759573Ed6714;

    function createCustomAdapter(string memory networkId) internal override returns (address adapter) {
        networkId; // silence unused warning
        return address(new TesseraAdapter(TESSERA_SWAP));
    }

    function getSwapTestCases() internal pure override returns (SwapTestCase[][] memory cases) {
        SwapTestCase[][] memory cases = new SwapTestCase[][](1);
        cases[0] = getBscTesseraTestCases();
        return cases;
    }

    function getBscTesseraTestCases() internal pure returns (SwapTestCase[] memory cases) {
        cases = new SwapTestCase[](3);
        cases[0] = _bscWbnbToUsdt();
        cases[1] = _bscUsdtToWbnb();
        cases[2] = _bscBroccoliToUsdt();
    }

    function _bscWbnbToUsdt() internal pure returns (SwapTestCase memory) {
        return SwapTestCase({
            networkId: "bsc",
            forkBlock: 0,
            fromToken: BSC_WBNB,
            toToken: BSC_USDT,
            pool: BSC_POOL_WBNB_USDT,
            amount: 0.01 ether,
            expectedOutput: 0,
            sellBase: true,
            expectRevert: false,
            description: "bsc wbnb->usdt",
            moreInfo: abi.encode(BSC_WBNB, BSC_USDT),
            fromTokenPreTo: address(0)
        });
    }

    // https://bscscan.com/tx/0xd3b2df008477d2f8612c3a575d9ebfbee97482c147e55415874b34007966c5d6#eventlog
    function _bscUsdtToWbnb() internal pure returns (SwapTestCase memory) {
        return SwapTestCase({
            networkId: "bsc",
            forkBlock: 74935356,
            fromToken: BSC_USDT,
            toToken: BSC_WBNB,
            pool: BSC_POOL_WBNB_USDT,
            amount: 53470967590697923085,
            expectedOutput: 0,
            sellBase: false,
            expectRevert: false,
            description: "bsc usdt->wbnb",
            moreInfo: abi.encode(BSC_USDT, BSC_WBNB),
            fromTokenPreTo: address(0)
        });
    }

    // https://bscscan.com/tx/0x774151848c88cb038190bfdc12bdee5adac4de294afd24c741085eda8a5e2e8f#eventlog
    function _bscBroccoliToUsdt() internal pure returns (SwapTestCase memory) {
        return SwapTestCase({
            networkId: "bsc",
            forkBlock: 74612188,
            fromToken: BSC_BROCCOLI,
            toToken: BSC_USDT,
            pool: BSC_POOL_BROCCOLI_USDT,
            amount: 1748932835196135319375,
            expectedOutput: 51919871714235761624,
            sellBase: true,
            expectRevert: false,
            description: "bsc broccoli->usdt",
            moreInfo: abi.encode(BSC_BROCCOLI, BSC_USDT),
            fromTokenPreTo: address(0)
        });
    }
}