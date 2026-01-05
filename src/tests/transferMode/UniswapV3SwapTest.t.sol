// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../common/TrimAndCommissionTestBase.t.sol";
import "@dex/interfaces/IPermit2.sol";

/*
 * UniswapV3Swap method test cases - Complete cross-combination testing.
 * All swap cases use 2 pools.
 *
 * Test Dimensions:
 * 1. Transfer Modes (5): Legacy / Direct / Permit2Signature / Permit2Allowance / ByInvest
 *    - Only applies to ERC20 fromToken; ETH input only allows Legacy mode
 * 2. Swap Types (3): ERC20->ERC20->ERC20 / ERC20->ERC20->ETH / ETH->ERC20->ERC20
 * 3. Commission (5): None / 8 fromToken ToC / 8 fromToken ToB / 8 toToken ToC / 8 toToken ToB
 *    - ByInvest mode doesn't allow commission
 * 4. Trim (2): None / 2 trim (trim + charge)
 *
 * Total: 4 modes * 2 ERC20-input * 5 comm * 2 trim + 2 * 2 trim (ByInvest noComm) + 1 * 5 comm * 2 trim (ETH) = 94 cases
 */

contract UniswapV3SwapTest is TrimAndCommissionTestBase {
    // fromToken commission requires extra amount (swap amount + commission amount)
    uint256 constant twoEther = 2 * 10 ** 18;
    uint256 constant USDT_AMOUNT = 1000 * 10 ** 6;
    uint256 constant TWO_USDT_AMOUNT = 2000 * 10 ** 6;

    // ============================================================================
    // WETH -> USDT -> USDC (ERC20 -> ERC20 -> ERC20)
    // ============================================================================

    // -------------------- Legacy Mode --------------------
    // noTrim
    function test_uniswapV3SwapTo_WETH2USDT2USDC_legacy_noTrim_noComm() tokenLogAndCheck3(WETH, USDC, oneEther, false, false, false, 0, _MODE_LEGACY) public {
        _execSwap(_generateWETH2USDT2USDCUniswapV3Data(_MODE_LEGACY));
    }
    function test_uniswapV3SwapTo_WETH2USDT2USDC_legacy_noTrim_8fromCommToC() tokenLogAndCheck3(WETH, USDC, twoEther, false, false, true, 8, _MODE_LEGACY) public {
        _execSwapWithComm(_generateWETH2USDT2USDCUniswapV3Data(_MODE_LEGACY), _generateMultipleCommissionData(true, WETH, false, 8));
    }
    function test_uniswapV3SwapTo_WETH2USDT2USDC_legacy_noTrim_8fromCommToB() tokenLogAndCheck3(WETH, USDC, twoEther, false, false, true, 8, _MODE_LEGACY) public {
        _execSwapWithComm(_generateWETH2USDT2USDCUniswapV3Data(_MODE_LEGACY), _generateMultipleCommissionData(true, WETH, true, 8));
    }
    function test_uniswapV3SwapTo_WETH2USDT2USDC_legacy_noTrim_8toCommToC() tokenLogAndCheck3(WETH, USDC, oneEther, false, false, false, 8, _MODE_LEGACY) public {
        _execSwapWithComm(_generateWETH2USDT2USDCUniswapV3Data(_MODE_LEGACY), _generateMultipleCommissionData(false, USDC, false, 8));
    }
    function test_uniswapV3SwapTo_WETH2USDT2USDC_legacy_noTrim_8toCommToB() tokenLogAndCheck3(WETH, USDC, oneEther, false, false, false, 8, _MODE_LEGACY) public {
        _execSwapWithComm(_generateWETH2USDT2USDCUniswapV3Data(_MODE_LEGACY), _generateMultipleCommissionData(false, USDC, true, 8));
    }
    // 2trim
    function test_uniswapV3SwapTo_WETH2USDT2USDC_legacy_2trim_noComm() tokenLogAndCheck3(WETH, USDC, oneEther, true, true, false, 0, _MODE_LEGACY) public {
        _execSwapWithTrim(_generateWETH2USDT2USDCUniswapV3Data(_MODE_LEGACY), _generate2TrimData());
    }
    function test_uniswapV3SwapTo_WETH2USDT2USDC_legacy_2trim_8fromCommToC() tokenLogAndCheck3(WETH, USDC, twoEther, true, true, true, 8, _MODE_LEGACY) public {
        _execSwapWithTrimComm(_generateWETH2USDT2USDCUniswapV3Data(_MODE_LEGACY), _generate2TrimData(), _generateMultipleCommissionData(true, WETH, false, 8));
    }
    function test_uniswapV3SwapTo_WETH2USDT2USDC_legacy_2trim_8fromCommToB() tokenLogAndCheck3(WETH, USDC, twoEther, true, true, true, 8, _MODE_LEGACY) public {
        _execSwapWithTrimComm(_generateWETH2USDT2USDCUniswapV3Data(_MODE_LEGACY), _generate2TrimData(), _generateMultipleCommissionData(true, WETH, true, 8));
    }
    function test_uniswapV3SwapTo_WETH2USDT2USDC_legacy_2trim_8toCommToC() tokenLogAndCheck3(WETH, USDC, oneEther, true, true, false, 8, _MODE_LEGACY) public {
        _execSwapWithTrimComm(_generateWETH2USDT2USDCUniswapV3Data(_MODE_LEGACY), _generate2TrimData(), _generateMultipleCommissionData(false, USDC, false, 8));
    }
    function test_uniswapV3SwapTo_WETH2USDT2USDC_legacy_2trim_8toCommToB() tokenLogAndCheck3(WETH, USDC, oneEther, true, true, false, 8, _MODE_LEGACY) public {
        _execSwapWithTrimComm(_generateWETH2USDT2USDCUniswapV3Data(_MODE_LEGACY), _generate2TrimData(), _generateMultipleCommissionData(false, USDC, true, 8));
    }

    // -------------------- Direct Mode --------------------
    // noTrim
    function test_uniswapV3SwapTo_WETH2USDT2USDC_direct_noTrim_noComm() tokenLogAndCheck3(WETH, USDC, oneEther, false, false, false, 0, _MODE_DIRECT) public {
        _execSwap(_generateWETH2USDT2USDCUniswapV3Data(_MODE_DIRECT));
    }
    function test_uniswapV3SwapTo_WETH2USDT2USDC_direct_noTrim_8fromCommToC() tokenLogAndCheck3(WETH, USDC, twoEther, false, false, true, 8, _MODE_DIRECT) public {
        _execSwapWithComm(_generateWETH2USDT2USDCUniswapV3Data(_MODE_DIRECT), _generateMultipleCommissionData(true, WETH, false, 8));
    }
    function test_uniswapV3SwapTo_WETH2USDT2USDC_direct_noTrim_8fromCommToB() tokenLogAndCheck3(WETH, USDC, twoEther, false, false, true, 8, _MODE_DIRECT) public {
        _execSwapWithComm(_generateWETH2USDT2USDCUniswapV3Data(_MODE_DIRECT), _generateMultipleCommissionData(true, WETH, true, 8));
    }
    function test_uniswapV3SwapTo_WETH2USDT2USDC_direct_noTrim_8toCommToC() tokenLogAndCheck3(WETH, USDC, oneEther, false, false, false, 8, _MODE_DIRECT) public {
        _execSwapWithComm(_generateWETH2USDT2USDCUniswapV3Data(_MODE_DIRECT), _generateMultipleCommissionData(false, USDC, false, 8));
    }
    function test_uniswapV3SwapTo_WETH2USDT2USDC_direct_noTrim_8toCommToB() tokenLogAndCheck3(WETH, USDC, oneEther, false, false, false, 8, _MODE_DIRECT) public {
        _execSwapWithComm(_generateWETH2USDT2USDCUniswapV3Data(_MODE_DIRECT), _generateMultipleCommissionData(false, USDC, true, 8));
    }
    // 2trim
    function test_uniswapV3SwapTo_WETH2USDT2USDC_direct_2trim_noComm() tokenLogAndCheck3(WETH, USDC, oneEther, true, true, false, 0, _MODE_DIRECT) public {
        _execSwapWithTrim(_generateWETH2USDT2USDCUniswapV3Data(_MODE_DIRECT), _generate2TrimData());
    }
    function test_uniswapV3SwapTo_WETH2USDT2USDC_direct_2trim_8fromCommToC() tokenLogAndCheck3(WETH, USDC, twoEther, true, true, true, 8, _MODE_DIRECT) public {
        _execSwapWithTrimComm(_generateWETH2USDT2USDCUniswapV3Data(_MODE_DIRECT), _generate2TrimData(), _generateMultipleCommissionData(true, WETH, false, 8));
    }
    function test_uniswapV3SwapTo_WETH2USDT2USDC_direct_2trim_8fromCommToB() tokenLogAndCheck3(WETH, USDC, twoEther, true, true, true, 8, _MODE_DIRECT) public {
        _execSwapWithTrimComm(_generateWETH2USDT2USDCUniswapV3Data(_MODE_DIRECT), _generate2TrimData(), _generateMultipleCommissionData(true, WETH, true, 8));
    }
    function test_uniswapV3SwapTo_WETH2USDT2USDC_direct_2trim_8toCommToC() tokenLogAndCheck3(WETH, USDC, oneEther, true, true, false, 8, _MODE_DIRECT) public {
        _execSwapWithTrimComm(_generateWETH2USDT2USDCUniswapV3Data(_MODE_DIRECT), _generate2TrimData(), _generateMultipleCommissionData(false, USDC, false, 8));
    }
    function test_uniswapV3SwapTo_WETH2USDT2USDC_direct_2trim_8toCommToB() tokenLogAndCheck3(WETH, USDC, oneEther, true, true, false, 8, _MODE_DIRECT) public {
        _execSwapWithTrimComm(_generateWETH2USDT2USDCUniswapV3Data(_MODE_DIRECT), _generate2TrimData(), _generateMultipleCommissionData(false, USDC, true, 8));
    }

    // -------------------- Permit2 Signature Mode --------------------
    // noTrim
    function test_uniswapV3SwapTo_WETH2USDT2USDC_permit2Sig_noTrim_noComm() tokenLogAndCheck3(WETH, USDC, oneEther, false, false, false, 0, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2Sig(_generateWETH2USDT2USDCUniswapV3Data(_MODE_PERMIT2_SIGNATURE), WETH, oneEther);
    }
    function test_uniswapV3SwapTo_WETH2USDT2USDC_permit2Sig_noTrim_8fromCommToC() tokenLogAndCheck3(WETH, USDC, twoEther, false, false, true, 8, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigFromCommToC(_generateWETH2USDT2USDCUniswapV3Data(_MODE_PERMIT2_SIGNATURE), WETH, oneEther, 8, _generateMultipleCommissionData(true, WETH, false, 8));
    }
    function test_uniswapV3SwapTo_WETH2USDT2USDC_permit2Sig_noTrim_8fromCommToB() tokenLogAndCheck3(WETH, USDC, twoEther, false, false, true, 8, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigComm(_generateWETH2USDT2USDCUniswapV3Data(_MODE_PERMIT2_SIGNATURE), WETH, twoEther, _generateMultipleCommissionData(true, WETH, true, 8));
    }
    function test_uniswapV3SwapTo_WETH2USDT2USDC_permit2Sig_noTrim_8toCommToC() tokenLogAndCheck3(WETH, USDC, oneEther, false, false, false, 8, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigComm(_generateWETH2USDT2USDCUniswapV3Data(_MODE_PERMIT2_SIGNATURE), WETH, oneEther, _generateMultipleCommissionData(false, USDC, false, 8));
    }
    function test_uniswapV3SwapTo_WETH2USDT2USDC_permit2Sig_noTrim_8toCommToB() tokenLogAndCheck3(WETH, USDC, oneEther, false, false, false, 8, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigComm(_generateWETH2USDT2USDCUniswapV3Data(_MODE_PERMIT2_SIGNATURE), WETH, oneEther, _generateMultipleCommissionData(false, USDC, true, 8));
    }
    // 2trim
    function test_uniswapV3SwapTo_WETH2USDT2USDC_permit2Sig_2trim_noComm() tokenLogAndCheck3(WETH, USDC, oneEther, true, true, false, 0, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigTrim(_generateWETH2USDT2USDCUniswapV3Data(_MODE_PERMIT2_SIGNATURE), WETH, oneEther, _generate2TrimData());
    }
    function test_uniswapV3SwapTo_WETH2USDT2USDC_permit2Sig_2trim_8fromCommToC() tokenLogAndCheck3(WETH, USDC, twoEther, true, true, true, 8, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigTrimFromCommToC(_generateWETH2USDT2USDCUniswapV3Data(_MODE_PERMIT2_SIGNATURE), WETH, oneEther, 8, _generate2TrimData(), _generateMultipleCommissionData(true, WETH, false, 8));
    }
    function test_uniswapV3SwapTo_WETH2USDT2USDC_permit2Sig_2trim_8fromCommToB() tokenLogAndCheck3(WETH, USDC, twoEther, true, true, true, 8, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigTrimComm(_generateWETH2USDT2USDCUniswapV3Data(_MODE_PERMIT2_SIGNATURE), WETH, twoEther, _generate2TrimData(), _generateMultipleCommissionData(true, WETH, true, 8));
    }
    function test_uniswapV3SwapTo_WETH2USDT2USDC_permit2Sig_2trim_8toCommToC() tokenLogAndCheck3(WETH, USDC, oneEther, true, true, false, 8, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigTrimComm(_generateWETH2USDT2USDCUniswapV3Data(_MODE_PERMIT2_SIGNATURE), WETH, oneEther, _generate2TrimData(), _generateMultipleCommissionData(false, USDC, false, 8));
    }
    function test_uniswapV3SwapTo_WETH2USDT2USDC_permit2Sig_2trim_8toCommToB() tokenLogAndCheck3(WETH, USDC, oneEther, true, true, false, 8, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigTrimComm(_generateWETH2USDT2USDCUniswapV3Data(_MODE_PERMIT2_SIGNATURE), WETH, oneEther, _generate2TrimData(), _generateMultipleCommissionData(false, USDC, true, 8));
    }

    // -------------------- Permit2 Allowance Mode --------------------
    // noTrim
    function test_uniswapV3SwapTo_WETH2USDT2USDC_permit2Allow_noTrim_noComm() tokenLogAndCheck3(WETH, USDC, oneEther, false, false, false, 0, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwap(_generateWETH2USDT2USDCUniswapV3Data(_MODE_PERMIT2_ALLOWANCE));
    }
    function test_uniswapV3SwapTo_WETH2USDT2USDC_permit2Allow_noTrim_8fromCommToC() tokenLogAndCheck3(WETH, USDC, twoEther, false, false, true, 8, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithComm(_generateWETH2USDT2USDCUniswapV3Data(_MODE_PERMIT2_ALLOWANCE), _generateMultipleCommissionData(true, WETH, false, 8));
    }
    function test_uniswapV3SwapTo_WETH2USDT2USDC_permit2Allow_noTrim_8fromCommToB() tokenLogAndCheck3(WETH, USDC, twoEther, false, false, true, 8, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithComm(_generateWETH2USDT2USDCUniswapV3Data(_MODE_PERMIT2_ALLOWANCE), _generateMultipleCommissionData(true, WETH, true, 8));
    }
    function test_uniswapV3SwapTo_WETH2USDT2USDC_permit2Allow_noTrim_8toCommToC() tokenLogAndCheck3(WETH, USDC, oneEther, false, false, false, 8, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithComm(_generateWETH2USDT2USDCUniswapV3Data(_MODE_PERMIT2_ALLOWANCE), _generateMultipleCommissionData(false, USDC, false, 8));
    }
    function test_uniswapV3SwapTo_WETH2USDT2USDC_permit2Allow_noTrim_8toCommToB() tokenLogAndCheck3(WETH, USDC, oneEther, false, false, false, 8, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithComm(_generateWETH2USDT2USDCUniswapV3Data(_MODE_PERMIT2_ALLOWANCE), _generateMultipleCommissionData(false, USDC, true, 8));
    }
    // 2trim
    function test_uniswapV3SwapTo_WETH2USDT2USDC_permit2Allow_2trim_noComm() tokenLogAndCheck3(WETH, USDC, oneEther, true, true, false, 0, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithTrim(_generateWETH2USDT2USDCUniswapV3Data(_MODE_PERMIT2_ALLOWANCE), _generate2TrimData());
    }
    function test_uniswapV3SwapTo_WETH2USDT2USDC_permit2Allow_2trim_8fromCommToC() tokenLogAndCheck3(WETH, USDC, twoEther, true, true, true, 8, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithTrimComm(_generateWETH2USDT2USDCUniswapV3Data(_MODE_PERMIT2_ALLOWANCE), _generate2TrimData(), _generateMultipleCommissionData(true, WETH, false, 8));
    }
    function test_uniswapV3SwapTo_WETH2USDT2USDC_permit2Allow_2trim_8fromCommToB() tokenLogAndCheck3(WETH, USDC, twoEther, true, true, true, 8, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithTrimComm(_generateWETH2USDT2USDCUniswapV3Data(_MODE_PERMIT2_ALLOWANCE), _generate2TrimData(), _generateMultipleCommissionData(true, WETH, true, 8));
    }
    function test_uniswapV3SwapTo_WETH2USDT2USDC_permit2Allow_2trim_8toCommToC() tokenLogAndCheck3(WETH, USDC, oneEther, true, true, false, 8, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithTrimComm(_generateWETH2USDT2USDCUniswapV3Data(_MODE_PERMIT2_ALLOWANCE), _generate2TrimData(), _generateMultipleCommissionData(false, USDC, false, 8));
    }
    function test_uniswapV3SwapTo_WETH2USDT2USDC_permit2Allow_2trim_8toCommToB() tokenLogAndCheck3(WETH, USDC, oneEther, true, true, false, 8, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithTrimComm(_generateWETH2USDT2USDCUniswapV3Data(_MODE_PERMIT2_ALLOWANCE), _generate2TrimData(), _generateMultipleCommissionData(false, USDC, true, 8));
    }

    // -------------------- By Invest Mode (no commission allowed) --------------------
    // noTrim
    function test_uniswapV3SwapTo_WETH2USDT2USDC_byInvest_noTrim_noComm() tokenLogAndCheck3(WETH, USDC, oneEther, false, false, false, 0, _MODE_BY_INVEST) public {
        IERC20(WETH).transfer(address(dexRouter), oneEther);
        _execSwap(_generateWETH2USDT2USDCUniswapV3Data(_MODE_BY_INVEST));
    }
    // 2trim
    function test_uniswapV3SwapTo_WETH2USDT2USDC_byInvest_2trim_noComm() tokenLogAndCheck3(WETH, USDC, oneEther, true, true, false, 0, _MODE_BY_INVEST) public {
        IERC20(WETH).transfer(address(dexRouter), oneEther);
        _execSwapWithTrim(_generateWETH2USDT2USDCUniswapV3Data(_MODE_BY_INVEST), _generate2TrimData());
    }

    // ============================================================================
    // USDT -> USDC -> ETH (ERC20 -> ERC20 -> ETH)
    // ============================================================================

    // -------------------- Legacy Mode --------------------
    // noTrim
    function test_uniswapV3SwapTo_USDT2USDC2ETH_legacy_noTrim_noComm() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, false, false, false, 0, _MODE_LEGACY) public {
        _execSwap(_generateUSDT2USDC2ETHUniswapV3Data(_MODE_LEGACY));
    }
    function test_uniswapV3SwapTo_USDT2USDC2ETH_legacy_noTrim_8fromCommToC() tokenLogAndCheck3(USDT, ETH, TWO_USDT_AMOUNT, false, false, true, 8, _MODE_LEGACY) public {
        _execSwapWithComm(_generateUSDT2USDC2ETHUniswapV3Data(_MODE_LEGACY), _generateMultipleCommissionData(true, USDT, false, 8));
    }
    function test_uniswapV3SwapTo_USDT2USDC2ETH_legacy_noTrim_8fromCommToB() tokenLogAndCheck3(USDT, ETH, TWO_USDT_AMOUNT, false, false, true, 8, _MODE_LEGACY) public {
        _execSwapWithComm(_generateUSDT2USDC2ETHUniswapV3Data(_MODE_LEGACY), _generateMultipleCommissionData(true, USDT, true, 8));
    }
    function test_uniswapV3SwapTo_USDT2USDC2ETH_legacy_noTrim_8toCommToC() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, false, false, false, 8, _MODE_LEGACY) public {
        _execSwapWithComm(_generateUSDT2USDC2ETHUniswapV3Data(_MODE_LEGACY), _generateMultipleCommissionData(false, ETH, false, 8));
    }
    function test_uniswapV3SwapTo_USDT2USDC2ETH_legacy_noTrim_8toCommToB() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, false, false, false, 8, _MODE_LEGACY) public {
        _execSwapWithComm(_generateUSDT2USDC2ETHUniswapV3Data(_MODE_LEGACY), _generateMultipleCommissionData(false, ETH, true, 8));
    }
    // 2trim
    function test_uniswapV3SwapTo_USDT2USDC2ETH_legacy_2trim_noComm() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, true, true, false, 0, _MODE_LEGACY) public {
        _execSwapWithTrim(_generateUSDT2USDC2ETHUniswapV3Data(_MODE_LEGACY), _generate2TrimData());
    }
    function test_uniswapV3SwapTo_USDT2USDC2ETH_legacy_2trim_8fromCommToC() tokenLogAndCheck3(USDT, ETH, TWO_USDT_AMOUNT, true, true, true, 8, _MODE_LEGACY) public {
        _execSwapWithTrimComm(_generateUSDT2USDC2ETHUniswapV3Data(_MODE_LEGACY), _generate2TrimData(), _generateMultipleCommissionData(true, USDT, false, 8));
    }
    function test_uniswapV3SwapTo_USDT2USDC2ETH_legacy_2trim_8fromCommToB() tokenLogAndCheck3(USDT, ETH, TWO_USDT_AMOUNT, true, true, true, 8, _MODE_LEGACY) public {
        _execSwapWithTrimComm(_generateUSDT2USDC2ETHUniswapV3Data(_MODE_LEGACY), _generate2TrimData(), _generateMultipleCommissionData(true, USDT, true, 8));
    }
    function test_uniswapV3SwapTo_USDT2USDC2ETH_legacy_2trim_8toCommToC() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, true, true, false, 8, _MODE_LEGACY) public {
        _execSwapWithTrimComm(_generateUSDT2USDC2ETHUniswapV3Data(_MODE_LEGACY), _generate2TrimData(), _generateMultipleCommissionData(false, ETH, false, 8));
    }
    function test_uniswapV3SwapTo_USDT2USDC2ETH_legacy_2trim_8toCommToB() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, true, true, false, 8, _MODE_LEGACY) public {
        _execSwapWithTrimComm(_generateUSDT2USDC2ETHUniswapV3Data(_MODE_LEGACY), _generate2TrimData(), _generateMultipleCommissionData(false, ETH, true, 8));
    }

    // -------------------- Direct Mode --------------------
    // noTrim
    function test_uniswapV3SwapTo_USDT2USDC2ETH_direct_noTrim_noComm() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, false, false, false, 0, _MODE_DIRECT) public {
        _execSwap(_generateUSDT2USDC2ETHUniswapV3Data(_MODE_DIRECT));
    }
    function test_uniswapV3SwapTo_USDT2USDC2ETH_direct_noTrim_8fromCommToC() tokenLogAndCheck3(USDT, ETH, TWO_USDT_AMOUNT, false, false, true, 8, _MODE_DIRECT) public {
        _execSwapWithComm(_generateUSDT2USDC2ETHUniswapV3Data(_MODE_DIRECT), _generateMultipleCommissionData(true, USDT, false, 8));
    }
    function test_uniswapV3SwapTo_USDT2USDC2ETH_direct_noTrim_8fromCommToB() tokenLogAndCheck3(USDT, ETH, TWO_USDT_AMOUNT, false, false, true, 8, _MODE_DIRECT) public {
        _execSwapWithComm(_generateUSDT2USDC2ETHUniswapV3Data(_MODE_DIRECT), _generateMultipleCommissionData(true, USDT, true, 8));
    }
    function test_uniswapV3SwapTo_USDT2USDC2ETH_direct_noTrim_8toCommToC() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, false, false, false, 8, _MODE_DIRECT) public {
        _execSwapWithComm(_generateUSDT2USDC2ETHUniswapV3Data(_MODE_DIRECT), _generateMultipleCommissionData(false, ETH, false, 8));
    }
    function test_uniswapV3SwapTo_USDT2USDC2ETH_direct_noTrim_8toCommToB() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, false, false, false, 8, _MODE_DIRECT) public {
        _execSwapWithComm(_generateUSDT2USDC2ETHUniswapV3Data(_MODE_DIRECT), _generateMultipleCommissionData(false, ETH, true, 8));
    }
    // 2trim
    function test_uniswapV3SwapTo_USDT2USDC2ETH_direct_2trim_noComm() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, true, true, false, 0, _MODE_DIRECT) public {
        _execSwapWithTrim(_generateUSDT2USDC2ETHUniswapV3Data(_MODE_DIRECT), _generate2TrimData());
    }
    function test_uniswapV3SwapTo_USDT2USDC2ETH_direct_2trim_8fromCommToC() tokenLogAndCheck3(USDT, ETH, TWO_USDT_AMOUNT, true, true, true, 8, _MODE_DIRECT) public {
        _execSwapWithTrimComm(_generateUSDT2USDC2ETHUniswapV3Data(_MODE_DIRECT), _generate2TrimData(), _generateMultipleCommissionData(true, USDT, false, 8));
    }
    function test_uniswapV3SwapTo_USDT2USDC2ETH_direct_2trim_8fromCommToB() tokenLogAndCheck3(USDT, ETH, TWO_USDT_AMOUNT, true, true, true, 8, _MODE_DIRECT) public {
        _execSwapWithTrimComm(_generateUSDT2USDC2ETHUniswapV3Data(_MODE_DIRECT), _generate2TrimData(), _generateMultipleCommissionData(true, USDT, true, 8));
    }
    function test_uniswapV3SwapTo_USDT2USDC2ETH_direct_2trim_8toCommToC() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, true, true, false, 8, _MODE_DIRECT) public {
        _execSwapWithTrimComm(_generateUSDT2USDC2ETHUniswapV3Data(_MODE_DIRECT), _generate2TrimData(), _generateMultipleCommissionData(false, ETH, false, 8));
    }
    function test_uniswapV3SwapTo_USDT2USDC2ETH_direct_2trim_8toCommToB() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, true, true, false, 8, _MODE_DIRECT) public {
        _execSwapWithTrimComm(_generateUSDT2USDC2ETHUniswapV3Data(_MODE_DIRECT), _generate2TrimData(), _generateMultipleCommissionData(false, ETH, true, 8));
    }

    // -------------------- Permit2 Signature Mode --------------------
    // noTrim
    function test_uniswapV3SwapTo_USDT2USDC2ETH_permit2Sig_noTrim_noComm() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, false, false, false, 0, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2Sig(_generateUSDT2USDC2ETHUniswapV3Data(_MODE_PERMIT2_SIGNATURE), USDT, USDT_AMOUNT);
    }
    function test_uniswapV3SwapTo_USDT2USDC2ETH_permit2Sig_noTrim_8fromCommToC() tokenLogAndCheck3(USDT, ETH, TWO_USDT_AMOUNT, false, false, true, 8, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigFromCommToC(_generateUSDT2USDC2ETHUniswapV3Data(_MODE_PERMIT2_SIGNATURE), USDT, USDT_AMOUNT, 8, _generateMultipleCommissionData(true, USDT, false, 8));
    }
    function test_uniswapV3SwapTo_USDT2USDC2ETH_permit2Sig_noTrim_8fromCommToB() tokenLogAndCheck3(USDT, ETH, TWO_USDT_AMOUNT, false, false, true, 8, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigComm(_generateUSDT2USDC2ETHUniswapV3Data(_MODE_PERMIT2_SIGNATURE), USDT, TWO_USDT_AMOUNT, _generateMultipleCommissionData(true, USDT, true, 8));
    }
    function test_uniswapV3SwapTo_USDT2USDC2ETH_permit2Sig_noTrim_8toCommToC() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, false, false, false, 8, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigComm(_generateUSDT2USDC2ETHUniswapV3Data(_MODE_PERMIT2_SIGNATURE), USDT, USDT_AMOUNT, _generateMultipleCommissionData(false, ETH, false, 8));
    }
    function test_uniswapV3SwapTo_USDT2USDC2ETH_permit2Sig_noTrim_8toCommToB() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, false, false, false, 8, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigComm(_generateUSDT2USDC2ETHUniswapV3Data(_MODE_PERMIT2_SIGNATURE), USDT, USDT_AMOUNT, _generateMultipleCommissionData(false, ETH, true, 8));
    }
    // 2trim
    function test_uniswapV3SwapTo_USDT2USDC2ETH_permit2Sig_2trim_noComm() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, true, true, false, 0, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigTrim(_generateUSDT2USDC2ETHUniswapV3Data(_MODE_PERMIT2_SIGNATURE), USDT, USDT_AMOUNT, _generate2TrimData());
    }
    function test_uniswapV3SwapTo_USDT2USDC2ETH_permit2Sig_2trim_8fromCommToC() tokenLogAndCheck3(USDT, ETH, TWO_USDT_AMOUNT, true, true, true, 8, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigTrimFromCommToC(_generateUSDT2USDC2ETHUniswapV3Data(_MODE_PERMIT2_SIGNATURE), USDT, USDT_AMOUNT, 8, _generate2TrimData(), _generateMultipleCommissionData(true, USDT, false, 8));
    }
    function test_uniswapV3SwapTo_USDT2USDC2ETH_permit2Sig_2trim_8fromCommToB() tokenLogAndCheck3(USDT, ETH, TWO_USDT_AMOUNT, true, true, true, 8, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigTrimComm(_generateUSDT2USDC2ETHUniswapV3Data(_MODE_PERMIT2_SIGNATURE), USDT, TWO_USDT_AMOUNT, _generate2TrimData(), _generateMultipleCommissionData(true, USDT, true, 8));
    }
    function test_uniswapV3SwapTo_USDT2USDC2ETH_permit2Sig_2trim_8toCommToC() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, true, true, false, 8, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigTrimComm(_generateUSDT2USDC2ETHUniswapV3Data(_MODE_PERMIT2_SIGNATURE), USDT, USDT_AMOUNT, _generate2TrimData(), _generateMultipleCommissionData(false, ETH, false, 8));
    }
    function test_uniswapV3SwapTo_USDT2USDC2ETH_permit2Sig_2trim_8toCommToB() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, true, true, false, 8, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigTrimComm(_generateUSDT2USDC2ETHUniswapV3Data(_MODE_PERMIT2_SIGNATURE), USDT, USDT_AMOUNT, _generate2TrimData(), _generateMultipleCommissionData(false, ETH, true, 8));
    }

    // -------------------- Permit2 Allowance Mode --------------------
    // noTrim
    function test_uniswapV3SwapTo_USDT2USDC2ETH_permit2Allow_noTrim_noComm() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, false, false, false, 0, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwap(_generateUSDT2USDC2ETHUniswapV3Data(_MODE_PERMIT2_ALLOWANCE));
    }
    function test_uniswapV3SwapTo_USDT2USDC2ETH_permit2Allow_noTrim_8fromCommToC() tokenLogAndCheck3(USDT, ETH, TWO_USDT_AMOUNT, false, false, true, 8, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithComm(_generateUSDT2USDC2ETHUniswapV3Data(_MODE_PERMIT2_ALLOWANCE), _generateMultipleCommissionData(true, USDT, false, 8));
    }
    function test_uniswapV3SwapTo_USDT2USDC2ETH_permit2Allow_noTrim_8fromCommToB() tokenLogAndCheck3(USDT, ETH, TWO_USDT_AMOUNT, false, false, true, 8, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithComm(_generateUSDT2USDC2ETHUniswapV3Data(_MODE_PERMIT2_ALLOWANCE), _generateMultipleCommissionData(true, USDT, true, 8));
    }
    function test_uniswapV3SwapTo_USDT2USDC2ETH_permit2Allow_noTrim_8toCommToC() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, false, false, false, 8, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithComm(_generateUSDT2USDC2ETHUniswapV3Data(_MODE_PERMIT2_ALLOWANCE), _generateMultipleCommissionData(false, ETH, false, 8));
    }
    function test_uniswapV3SwapTo_USDT2USDC2ETH_permit2Allow_noTrim_8toCommToB() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, false, false, false, 8, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithComm(_generateUSDT2USDC2ETHUniswapV3Data(_MODE_PERMIT2_ALLOWANCE), _generateMultipleCommissionData(false, ETH, true, 8));
    }
    // 2trim
    function test_uniswapV3SwapTo_USDT2USDC2ETH_permit2Allow_2trim_noComm() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, true, true, false, 0, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithTrim(_generateUSDT2USDC2ETHUniswapV3Data(_MODE_PERMIT2_ALLOWANCE), _generate2TrimData());
    }
    function test_uniswapV3SwapTo_USDT2USDC2ETH_permit2Allow_2trim_8fromCommToC() tokenLogAndCheck3(USDT, ETH, TWO_USDT_AMOUNT, true, true, true, 8, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithTrimComm(_generateUSDT2USDC2ETHUniswapV3Data(_MODE_PERMIT2_ALLOWANCE), _generate2TrimData(), _generateMultipleCommissionData(true, USDT, false, 8));
    }
    function test_uniswapV3SwapTo_USDT2USDC2ETH_permit2Allow_2trim_8fromCommToB() tokenLogAndCheck3(USDT, ETH, TWO_USDT_AMOUNT, true, true, true, 8, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithTrimComm(_generateUSDT2USDC2ETHUniswapV3Data(_MODE_PERMIT2_ALLOWANCE), _generate2TrimData(), _generateMultipleCommissionData(true, USDT, true, 8));
    }
    function test_uniswapV3SwapTo_USDT2USDC2ETH_permit2Allow_2trim_8toCommToC() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, true, true, false, 8, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithTrimComm(_generateUSDT2USDC2ETHUniswapV3Data(_MODE_PERMIT2_ALLOWANCE), _generate2TrimData(), _generateMultipleCommissionData(false, ETH, false, 8));
    }
    function test_uniswapV3SwapTo_USDT2USDC2ETH_permit2Allow_2trim_8toCommToB() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, true, true, false, 8, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithTrimComm(_generateUSDT2USDC2ETHUniswapV3Data(_MODE_PERMIT2_ALLOWANCE), _generate2TrimData(), _generateMultipleCommissionData(false, ETH, true, 8));
    }

    // -------------------- By Invest Mode (no commission allowed) --------------------
    // noTrim
    function test_uniswapV3SwapTo_USDT2USDC2ETH_byInvest_noTrim_noComm() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, false, false, false, 0, _MODE_BY_INVEST) public {
        SafeERC20.safeTransfer(IERC20(USDT), address(dexRouter), USDT_AMOUNT);
        _execSwap(_generateUSDT2USDC2ETHUniswapV3Data(_MODE_BY_INVEST));
    }
    // 2trim
    function test_uniswapV3SwapTo_USDT2USDC2ETH_byInvest_2trim_noComm() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, true, true, false, 0, _MODE_BY_INVEST) public {
        SafeERC20.safeTransfer(IERC20(USDT), address(dexRouter), USDT_AMOUNT);
        _execSwapWithTrim(_generateUSDT2USDC2ETHUniswapV3Data(_MODE_BY_INVEST), _generate2TrimData());
    }

    // ============================================================================
    // ETH -> USDT -> USDC (ETH -> ERC20 -> ERC20)
    // Note: ETH input only allows Legacy mode (no transferMode encoding)
    // ============================================================================

    // noTrim
    function test_uniswapV3SwapTo_ETH2USDT2USDC_noTrim_noComm() tokenLogAndCheck3(ETH, USDC, oneEther, false, false, false, 0, _MODE_LEGACY) public {
        _execSwapWithValue(_generateETH2USDT2USDCUniswapV3Data(), oneEther);
    }
    function test_uniswapV3SwapTo_ETH2USDT2USDC_noTrim_8fromCommToC() tokenLogAndCheck3(ETH, USDC, twoEther, false, false, true, 8, _MODE_LEGACY) public {
        _execSwapWithValueComm(_generateETH2USDT2USDCUniswapV3Data(), twoEther, _generateMultipleCommissionData(true, ETH, false, 8));
    }
    function test_uniswapV3SwapTo_ETH2USDT2USDC_noTrim_8fromCommToB() tokenLogAndCheck3(ETH, USDC, twoEther, false, false, true, 8, _MODE_LEGACY) public {
        _execSwapWithValueComm(_generateETH2USDT2USDCUniswapV3Data(), twoEther, _generateMultipleCommissionData(true, ETH, true, 8));
    }
    function test_uniswapV3SwapTo_ETH2USDT2USDC_noTrim_8toCommToC() tokenLogAndCheck3(ETH, USDC, oneEther, false, false, false, 8, _MODE_LEGACY) public {
        _execSwapWithValueComm(_generateETH2USDT2USDCUniswapV3Data(), oneEther, _generateMultipleCommissionData(false, USDC, false, 8));
    }
    function test_uniswapV3SwapTo_ETH2USDT2USDC_noTrim_8toCommToB() tokenLogAndCheck3(ETH, USDC, oneEther, false, false, false, 8, _MODE_LEGACY) public {
        _execSwapWithValueComm(_generateETH2USDT2USDCUniswapV3Data(), oneEther, _generateMultipleCommissionData(false, USDC, true, 8));
    }
    // 2trim
    function test_uniswapV3SwapTo_ETH2USDT2USDC_2trim_noComm() tokenLogAndCheck3(ETH, USDC, oneEther, true, true, false, 0, _MODE_LEGACY) public {
        _execSwapWithValueTrim(_generateETH2USDT2USDCUniswapV3Data(), oneEther, _generate2TrimData());
    }
    function test_uniswapV3SwapTo_ETH2USDT2USDC_2trim_8fromCommToC() tokenLogAndCheck3(ETH, USDC, twoEther, true, true, true, 8, _MODE_LEGACY) public {
        _execSwapWithValueTrimComm(_generateETH2USDT2USDCUniswapV3Data(), twoEther, _generate2TrimData(), _generateMultipleCommissionData(true, ETH, false, 8));
    }
    function test_uniswapV3SwapTo_ETH2USDT2USDC_2trim_8fromCommToB() tokenLogAndCheck3(ETH, USDC, twoEther, true, true, true, 8, _MODE_LEGACY) public {
        _execSwapWithValueTrimComm(_generateETH2USDT2USDCUniswapV3Data(), twoEther, _generate2TrimData(), _generateMultipleCommissionData(true, ETH, true, 8));
    }
    function test_uniswapV3SwapTo_ETH2USDT2USDC_2trim_8toCommToC() tokenLogAndCheck3(ETH, USDC, oneEther, true, true, false, 8, _MODE_LEGACY) public {
        _execSwapWithValueTrimComm(_generateETH2USDT2USDCUniswapV3Data(), oneEther, _generate2TrimData(), _generateMultipleCommissionData(false, USDC, false, 8));
    }
    function test_uniswapV3SwapTo_ETH2USDT2USDC_2trim_8toCommToB() tokenLogAndCheck3(ETH, USDC, oneEther, true, true, false, 8, _MODE_LEGACY) public {
        _execSwapWithValueTrimComm(_generateETH2USDT2USDCUniswapV3Data(), oneEther, _generate2TrimData(), _generateMultipleCommissionData(false, USDC, true, 8));
    }


    // ============================================================================
    // Internal Execution Helpers - Simplify test case implementation
    // ============================================================================

    // Basic swap execution
    function _execSwap(bytes memory swapData) internal {
        (bool success, ) = address(dexRouter).call(swapData);
        require(success, "swap failed");
    }

    // Swap with ETH value
    function _execSwapWithValue(bytes memory swapData, uint256 value) internal {
        (bool success, ) = address(dexRouter).call{value: value}(swapData);
        require(success, "swap failed");
    }

    // Swap + commission
    function _execSwapWithComm(bytes memory swapData, bytes memory commData) internal {
        (bool success, ) = address(dexRouter).call(bytes.concat(swapData, commData));
        require(success, "swap failed");
    }

    // Swap + trim
    function _execSwapWithTrim(bytes memory swapData, bytes memory trimData) internal {
        (bool success, ) = address(dexRouter).call(bytes.concat(swapData, trimData));
        require(success, "swap failed");
    }

    // Swap + trim + commission
    function _execSwapWithTrimComm(bytes memory swapData, bytes memory trimData, bytes memory commData) internal {
        (bool success, ) = address(dexRouter).call(bytes.concat(swapData, trimData, commData));
        require(success, "swap failed");
    }

    // Swap with value + commission
    function _execSwapWithValueComm(bytes memory swapData, uint256 value, bytes memory commData) internal {
        (bool success, ) = address(dexRouter).call{value: value}(bytes.concat(swapData, commData));
        require(success, "swap failed");
    }

    // Swap with value + trim
    function _execSwapWithValueTrim(bytes memory swapData, uint256 value, bytes memory trimData) internal {
        (bool success, ) = address(dexRouter).call{value: value}(bytes.concat(swapData, trimData));
        require(success, "swap failed");
    }

    // Swap with value + trim + commission
    function _execSwapWithValueTrimComm(bytes memory swapData, uint256 value, bytes memory trimData, bytes memory commData) internal {
        (bool success, ) = address(dexRouter).call{value: value}(bytes.concat(swapData, trimData, commData));
        require(success, "swap failed");
    }

    // Permit2 signature swap
    function _execSwapWithPermit2Sig(bytes memory swapData, address token, uint256 amount) internal {
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        bytes memory permit2Info = _generatePermit2Info(token, amounts);
        (bool success, ) = address(dexRouter).call(bytes.concat(swapData, permit2Info));
        require(success, "swap failed");
    }

    // Permit2 signature + commission
    function _execSwapWithPermit2SigComm(bytes memory swapData, address token, uint256 amount, bytes memory commData) internal {
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        bytes memory permit2Info = _generatePermit2Info(token, amounts);
        (bool success, ) = address(dexRouter).call(bytes.concat(swapData, permit2Info, commData));
        require(success, "swap failed");
    }

    // Permit2 signature + trim
    function _execSwapWithPermit2SigTrim(bytes memory swapData, address token, uint256 amount, bytes memory trimData) internal {
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        bytes memory permit2Info = _generatePermit2Info(token, amounts);
        (bool success, ) = address(dexRouter).call(bytes.concat(swapData, permit2Info, trimData));
        require(success, "swap failed");
    }

    // Permit2 signature + trim + commission
    function _execSwapWithPermit2SigTrimComm(bytes memory swapData, address token, uint256 amount, bytes memory trimData, bytes memory commData) internal {
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        bytes memory permit2Info = _generatePermit2Info(token, amounts);
        (bool success, ) = address(dexRouter).call(bytes.concat(swapData, permit2Info, trimData, commData));
        require(success, "swap failed");
    }

    // Permit2 signature + fromToken ToC commission (requires multiple amounts in permit2 signature)
    // ToC mode transfers commission via permit2, so need to sign swap amount + each commission amount
    function _execSwapWithPermit2SigFromCommToC(bytes memory swapData, address token, uint256 swapAmount, uint256 commCount, bytes memory commData) internal {
        uint256[] memory amounts = new uint256[](commCount + 1);
        amounts[0] = swapAmount;
        uint256 commAmountEach = swapAmount / 10; // 10% per commission, enough for test
        for (uint256 i = 0; i < commCount; i++) {
            amounts[i + 1] = commAmountEach;
        }
        bytes memory permit2Info = _generatePermit2Info(token, amounts);
        (bool success, ) = address(dexRouter).call(bytes.concat(swapData, permit2Info, commData));
        require(success, "swap failed");
    }

    // Permit2 signature + trim + fromToken ToC commission
    function _execSwapWithPermit2SigTrimFromCommToC(bytes memory swapData, address token, uint256 swapAmount, uint256 commCount, bytes memory trimData, bytes memory commData) internal {
        uint256[] memory amounts = new uint256[](commCount + 1);
        amounts[0] = swapAmount;
        uint256 commAmountEach = swapAmount / 10; // 10% per commission, enough for test
        for (uint256 i = 0; i < commCount; i++) {
            amounts[i + 1] = commAmountEach;
        }
        bytes memory permit2Info = _generatePermit2Info(token, amounts);
        (bool success, ) = address(dexRouter).call(bytes.concat(swapData, permit2Info, trimData, commData));
        require(success, "swap failed");
    }

    // ============================================================================
    // Swap Data Generation Functions
    // ============================================================================

    /// @notice WETH -> USDT -> USDC two-pool swap via UniswapV3
    /// @dev Pool token order (token0 < token1 sorted by address):
    ///      - WETH_USDT_UNIV3: token0=WETH, token1=USDT
    ///      - USDC_USDT_UNIV3: token0=USDC, token1=USDT
    function _generateWETH2USDT2USDCUniswapV3Data(uint256 transferMode) internal view returns (bytes memory) {
        uint256 receiver = uint256(uint160(arnaud)); // receiver address in low bits
        uint256 amount = oneEther;
        uint256 minReturn = 0;
        
        // WETH -> USDT: token0 -> token1, oneForZero=false (zeroForOne)
        // USDT -> USDC: token1 -> token0, oneForZero=true
        uint256[] memory pools = _generateV3PoolsDefault(
            WETH_USDT_UNIV3,    // pool1
            USDC_USDT_UNIV3,    // pool2
            false,               // pool1OneForZero: WETH(token0) -> USDT(token1), so zeroForOne
            true,                // pool2OneForZero: USDT(token1) -> USDC(token0), so oneForZero
            false,               // unwrapWeth: output is USDC, no unwrap needed
            transferMode         // transferMode
        );
        
        return abi.encodeWithSelector(
            DexRouter.uniswapV3SwapTo.selector, receiver, amount, minReturn, pools
        );
    }

    /// @notice ETH -> USDT -> USDC two-pool swap via UniswapV3 (ETH auto-wrapped to WETH)
    /// @dev ETH input only allows Legacy mode (no transferMode encoding)
    function _generateETH2USDT2USDCUniswapV3Data() internal view returns (bytes memory) {
        // receiver high bits store orderId, low bits are receiver address
        uint256 receiver = 123 << 160 | uint256(uint160(arnaud)); // orderId=123
        uint256 amount = oneEther;
        uint256 minReturn = 0;
        
        // ETH is auto-wrapped to WETH, then follows the same path
        // WETH -> USDT: token0 -> token1, oneForZero=false (zeroForOne)
        // USDT -> USDC: token1 -> token0, oneForZero=true
        // transferMode=0 (Legacy) since ETH input doesn't use transfer mode
        uint256[] memory pools = _generateV3PoolsDefault(
            WETH_USDT_UNIV3,    // pool1
            USDC_USDT_UNIV3,    // pool2
            false,               // pool1OneForZero: WETH(token0) -> USDT(token1), so zeroForOne
            true,                // pool2OneForZero: USDT(token1) -> USDC(token0), so oneForZero
            false,               // unwrapWeth: output is USDC, no unwrap needed
            _MODE_LEGACY         // transferMode: ETH input only allows Legacy
        );
        
        return abi.encodeWithSelector(
            DexRouter.uniswapV3SwapTo.selector, receiver, amount, minReturn, pools
        );
    }

    /// @notice USDT -> USDC -> ETH two-pool swap via UniswapV3 (WETH unwrapped to ETH at the end)
    /// @dev Pool token order:
    ///      - USDC_USDT_UNIV3: token0=USDC, token1=USDT
    ///      - USDC_WETH_UNIV3: token0=USDC, token1=WETH
    function _generateUSDT2USDC2ETHUniswapV3Data(uint256 transferMode) internal view returns (bytes memory) {
        uint256 receiver = uint256(uint160(arnaud));
        uint256 amount = USDT_AMOUNT; // USDT has 6 decimals
        uint256 minReturn = 0;
        
        // USDT -> USDC: token1 -> token0, oneForZero=true
        // USDC -> WETH: token0 -> token1, oneForZero=false (zeroForOne), then unwrap to ETH
        uint256[] memory pools = _generateV3PoolsDefault(
            USDC_USDT_UNIV3,    // pool1
            USDC_WETH_UNIV3,    // pool2
            true,                // pool1OneForZero: USDT(token1) -> USDC(token0), so oneForZero
            false,               // pool2OneForZero: USDC(token0) -> WETH(token1), so zeroForOne
            true,                // unwrapWeth: output WETH needs to be converted to ETH
            transferMode         // transferMode
        );
        
        return abi.encodeWithSelector(
            DexRouter.uniswapV3SwapTo.selector, receiver, amount, minReturn, pools
        );
    }

    /// @notice Generate a two-pool UniswapV3 swap route array
    /// @param pool1 First pool address
    /// @param pool2 Second pool address
    /// @param pool1OneForZero Whether first pool swaps token1->token0 (true) or token0->token1 (false)
    /// @param pool2OneForZero Whether second pool swaps token1->token0 (true) or token0->token1 (false)
    /// @param unwrapWeth Whether to convert WETH to ETH at the end (only applies to last pool)
    /// @param transferMode Transfer mode (only applies to first pool)
    /// @return pools Encoded pools array (uint256[])
    /// @dev UniswapV3 pool encoding (uint256):
    ///      - bit255: ONE_FOR_ZERO_MASK (1<<255) - swap direction, 0=token0->token1, 1=token1->token0
    ///      - bit253: WETH_UNWRAP_MASK (1<<253) - last pool only, unwrap WETH to ETH
    ///      - bit251-249: TRANSFER_MODE - first pool only, transfer mode
    ///      - bit159-0: ADDRESS_MASK - pool address
    function _generateV3Pools(
        address pool1,
        address pool2,
        bool pool1OneForZero,
        bool pool2OneForZero,
        bool unwrapWeth,
        uint256 transferMode
    ) internal pure returns (uint256[] memory pools) {
        pools = new uint256[](2);
        
        // ========== First pool ==========
        // bit255: ONE_FOR_ZERO_MASK (1<<255), bit253: WETH_UNWRAP_MASK (1<<253)
        // bit251-249: TRANSFER_MODE
        uint256 pool1Value = uint256(uint160(pool1));
        if (pool1OneForZero) {
            pool1Value |= (1 << 255); // Set ONE_FOR_ZERO_MASK
        }
        pool1Value |= transferMode; // Add transfer mode
        
        pools[0] = pool1Value;
        
        // ========== Second pool ==========
        uint256 pool2Value = uint256(uint160(pool2));
        if (pool2OneForZero) {
            pool2Value |= (1 << 255); // Set ONE_FOR_ZERO_MASK
        }
        if (unwrapWeth) {
            pool2Value |= (1 << 253); // Set WETH_UNWRAP_MASK, convert WETH to ETH at the end
        }
        
        pools[1] = pool2Value;
        
        return pools;
    }
    
    /// @notice Simplified V3 pools generation method
    function _generateV3PoolsDefault(
        address pool1,
        address pool2,
        bool pool1OneForZero,
        bool pool2OneForZero,
        bool unwrapWeth,
        uint256 transferMode
    ) internal pure returns (uint256[] memory) {
        return _generateV3Pools(
            pool1,
            pool2,
            pool1OneForZero,
            pool2OneForZero,
            unwrapWeth,
            transferMode
        );
    }
}
