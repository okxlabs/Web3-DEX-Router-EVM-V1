// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../common/TrimAndCommissionTestBase.t.sol";
import "@dex/interfaces/IPermit2.sol";

/*
 * Unxswap method test cases - Complete cross-combination testing.
 * All swap cases use 2 pools.
 *
 * Test Dimensions:
 * 1. Transfer Modes (5): Legacy / Direct / Permit2Signature / Permit2Allowance / ByInvest
 *    - Only applies to ERC20 fromToken; ETH input doesn't use transferMode
 * 2. Swap Types (3): ERC20->ERC20->ERC20 / ERC20->ERC20->ETH / ETH->ERC20->ERC20
 * 3. Commission (5): None / 8 fromToken ToC / 8 fromToken ToB / 8 toToken ToC / 8 toToken ToB
 * 4. Trim (2): None / 2 trim (trim + charge)
 *
 * Total: 5 modes * 2 ERC20-input types * 5 comm * 2 trim + 1 * 1 ETH-input type * 5 comm * 2 trim = 110 cases
 */

contract UnxswapTransferModeTest is TrimAndCommissionTestBase {
    // fromToken commission requires extra amount (swap amount + commission amount)
    uint256 constant twoEther = 2 * 10 ** 18;
    uint256 constant TWO_USDT_AMOUNT = 2000 * 10 ** 6;

    // ============================================================================
    // WETH -> USDT -> USDC (ERC20 -> ERC20 -> ERC20)
    // ============================================================================

    // -------------------- Legacy Mode --------------------
    // noTrim
    function test_unxswapTo_WETH2USDT2USDC_legacy_noTrim_noComm() tokenLogAndCheck3(WETH, USDC, oneEther, false, false, false, 0, _MODE_LEGACY) public {
        _execSwap(_generateWETH2USDT2USDCUnxswapToData(_MODE_LEGACY));
    }
    function test_unxswapTo_WETH2USDT2USDC_legacy_noTrim_8fromCommToC() tokenLogAndCheck3(WETH, USDC, twoEther, false, false, true, 8, _MODE_LEGACY) public {
        _execSwapWithComm(_generateWETH2USDT2USDCUnxswapToData(_MODE_LEGACY), _generateMultipleCommissionData(true, WETH, false, 8));
    }
    function test_unxswapTo_WETH2USDT2USDC_legacy_noTrim_8fromCommToB() tokenLogAndCheck3(WETH, USDC, twoEther, false, false, true, 8, _MODE_LEGACY) public {
        _execSwapWithComm(_generateWETH2USDT2USDCUnxswapToData(_MODE_LEGACY), _generateMultipleCommissionData(true, WETH, true, 8));
    }
    function test_unxswapTo_WETH2USDT2USDC_legacy_noTrim_8toCommToC() tokenLogAndCheck3(WETH, USDC, oneEther, false, false, false, 8, _MODE_LEGACY) public {
        _execSwapWithComm(_generateWETH2USDT2USDCUnxswapToData(_MODE_LEGACY), _generateMultipleCommissionData(false, USDC, false, 8));
    }
    function test_unxswapTo_WETH2USDT2USDC_legacy_noTrim_8toCommToB() tokenLogAndCheck3(WETH, USDC, oneEther, false, false, false, 8, _MODE_LEGACY) public {
        _execSwapWithComm(_generateWETH2USDT2USDCUnxswapToData(_MODE_LEGACY), _generateMultipleCommissionData(false, USDC, true, 8));
    }
    // 2trim
    function test_unxswapTo_WETH2USDT2USDC_legacy_2trim_noComm() tokenLogAndCheck3(WETH, USDC, oneEther, true, true, false, 0, _MODE_LEGACY) public {
        _execSwapWithTrim(_generateWETH2USDT2USDCUnxswapToData(_MODE_LEGACY), _generate2TrimData());
    }
    function test_unxswapTo_WETH2USDT2USDC_legacy_2trim_8fromCommToC() tokenLogAndCheck3(WETH, USDC, twoEther, true, true, true, 8, _MODE_LEGACY) public {
        _execSwapWithTrimComm(_generateWETH2USDT2USDCUnxswapToData(_MODE_LEGACY), _generate2TrimData(), _generateMultipleCommissionData(true, WETH, false, 8));
    }
    function test_unxswapTo_WETH2USDT2USDC_legacy_2trim_8fromCommToB() tokenLogAndCheck3(WETH, USDC, twoEther, true, true, true, 8, _MODE_LEGACY) public {
        _execSwapWithTrimComm(_generateWETH2USDT2USDCUnxswapToData(_MODE_LEGACY), _generate2TrimData(), _generateMultipleCommissionData(true, WETH, true, 8));
    }
    function test_unxswapTo_WETH2USDT2USDC_legacy_2trim_8toCommToC() tokenLogAndCheck3(WETH, USDC, oneEther, true, true, false, 8, _MODE_LEGACY) public {
        _execSwapWithTrimComm(_generateWETH2USDT2USDCUnxswapToData(_MODE_LEGACY), _generate2TrimData(), _generateMultipleCommissionData(false, USDC, false, 8));
    }
    function test_unxswapTo_WETH2USDT2USDC_legacy_2trim_8toCommToB() tokenLogAndCheck3(WETH, USDC, oneEther, true, true, false, 8, _MODE_LEGACY) public {
        _execSwapWithTrimComm(_generateWETH2USDT2USDCUnxswapToData(_MODE_LEGACY), _generate2TrimData(), _generateMultipleCommissionData(false, USDC, true, 8));
    }

    // -------------------- Direct Mode --------------------
    // noTrim
    function test_unxswapTo_WETH2USDT2USDC_direct_noTrim_noComm() tokenLogAndCheck3(WETH, USDC, oneEther, false, false, false, 0, _MODE_DIRECT) public {
        _execSwap(_generateWETH2USDT2USDCUnxswapToData(_MODE_DIRECT));
    }
    function test_unxswapTo_WETH2USDT2USDC_direct_noTrim_8fromCommToC() tokenLogAndCheck3(WETH, USDC, twoEther, false, false, true, 8, _MODE_DIRECT) public {
        _execSwapWithComm(_generateWETH2USDT2USDCUnxswapToData(_MODE_DIRECT), _generateMultipleCommissionData(true, WETH, false, 8));
    }
    function test_unxswapTo_WETH2USDT2USDC_direct_noTrim_8fromCommToB() tokenLogAndCheck3(WETH, USDC, twoEther, false, false, true, 8, _MODE_DIRECT) public {
        _execSwapWithComm(_generateWETH2USDT2USDCUnxswapToData(_MODE_DIRECT), _generateMultipleCommissionData(true, WETH, true, 8));
    }
    function test_unxswapTo_WETH2USDT2USDC_direct_noTrim_8toCommToC() tokenLogAndCheck3(WETH, USDC, oneEther, false, false, false, 8, _MODE_DIRECT) public {
        _execSwapWithComm(_generateWETH2USDT2USDCUnxswapToData(_MODE_DIRECT), _generateMultipleCommissionData(false, USDC, false, 8));
    }
    function test_unxswapTo_WETH2USDT2USDC_direct_noTrim_8toCommToB() tokenLogAndCheck3(WETH, USDC, oneEther, false, false, false, 8, _MODE_DIRECT) public {
        _execSwapWithComm(_generateWETH2USDT2USDCUnxswapToData(_MODE_DIRECT), _generateMultipleCommissionData(false, USDC, true, 8));
    }
    // 2trim
    function test_unxswapTo_WETH2USDT2USDC_direct_2trim_noComm() tokenLogAndCheck3(WETH, USDC, oneEther, true, true, false, 0, _MODE_DIRECT) public {
        _execSwapWithTrim(_generateWETH2USDT2USDCUnxswapToData(_MODE_DIRECT), _generate2TrimData());
    }
    function test_unxswapTo_WETH2USDT2USDC_direct_2trim_8fromCommToC() tokenLogAndCheck3(WETH, USDC, twoEther, true, true, true, 8, _MODE_DIRECT) public {
        _execSwapWithTrimComm(_generateWETH2USDT2USDCUnxswapToData(_MODE_DIRECT), _generate2TrimData(), _generateMultipleCommissionData(true, WETH, false, 8));
    }
    function test_unxswapTo_WETH2USDT2USDC_direct_2trim_8fromCommToB() tokenLogAndCheck3(WETH, USDC, twoEther, true, true, true, 8, _MODE_DIRECT) public {
        _execSwapWithTrimComm(_generateWETH2USDT2USDCUnxswapToData(_MODE_DIRECT), _generate2TrimData(), _generateMultipleCommissionData(true, WETH, true, 8));
    }
    function test_unxswapTo_WETH2USDT2USDC_direct_2trim_8toCommToC() tokenLogAndCheck3(WETH, USDC, oneEther, true, true, false, 8, _MODE_DIRECT) public {
        _execSwapWithTrimComm(_generateWETH2USDT2USDCUnxswapToData(_MODE_DIRECT), _generate2TrimData(), _generateMultipleCommissionData(false, USDC, false, 8));
    }
    function test_unxswapTo_WETH2USDT2USDC_direct_2trim_8toCommToB() tokenLogAndCheck3(WETH, USDC, oneEther, true, true, false, 8, _MODE_DIRECT) public {
        _execSwapWithTrimComm(_generateWETH2USDT2USDCUnxswapToData(_MODE_DIRECT), _generate2TrimData(), _generateMultipleCommissionData(false, USDC, true, 8));
    }

    // -------------------- Permit2 Signature Mode --------------------
    // noTrim
    function test_unxswapTo_WETH2USDT2USDC_permit2Sig_noTrim_noComm() tokenLogAndCheck3(WETH, USDC, oneEther, false, false, false, 0, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2Sig(_generateWETH2USDT2USDCUnxswapToData(_MODE_PERMIT2_SIGNATURE), WETH, oneEther);
    }
    function test_unxswapTo_WETH2USDT2USDC_permit2Sig_noTrim_8fromCommToC() tokenLogAndCheck3(WETH, USDC, twoEther, false, false, true, 8, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigFromCommToC(_generateWETH2USDT2USDCUnxswapToData(_MODE_PERMIT2_SIGNATURE), WETH, oneEther, 8, _generateMultipleCommissionData(true, WETH, false, 8));
    }
    function test_unxswapTo_WETH2USDT2USDC_permit2Sig_noTrim_8fromCommToB() tokenLogAndCheck3(WETH, USDC, twoEther, false, false, true, 8, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigComm(_generateWETH2USDT2USDCUnxswapToData(_MODE_PERMIT2_SIGNATURE), WETH, twoEther, _generateMultipleCommissionData(true, WETH, true, 8));
    }
    function test_unxswapTo_WETH2USDT2USDC_permit2Sig_noTrim_8toCommToC() tokenLogAndCheck3(WETH, USDC, oneEther, false, false, false, 8, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigComm(_generateWETH2USDT2USDCUnxswapToData(_MODE_PERMIT2_SIGNATURE), WETH, oneEther, _generateMultipleCommissionData(false, USDC, false, 8));
    }
    function test_unxswapTo_WETH2USDT2USDC_permit2Sig_noTrim_8toCommToB() tokenLogAndCheck3(WETH, USDC, oneEther, false, false, false, 8, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigComm(_generateWETH2USDT2USDCUnxswapToData(_MODE_PERMIT2_SIGNATURE), WETH, oneEther, _generateMultipleCommissionData(false, USDC, true, 8));
    }
    // 2trim
    function test_unxswapTo_WETH2USDT2USDC_permit2Sig_2trim_noComm() tokenLogAndCheck3(WETH, USDC, oneEther, true, true, false, 0, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigTrim(_generateWETH2USDT2USDCUnxswapToData(_MODE_PERMIT2_SIGNATURE), WETH, oneEther, _generate2TrimData());
    }
    function test_unxswapTo_WETH2USDT2USDC_permit2Sig_2trim_8fromCommToC() tokenLogAndCheck3(WETH, USDC, twoEther, true, true, true, 8, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigTrimFromCommToC(_generateWETH2USDT2USDCUnxswapToData(_MODE_PERMIT2_SIGNATURE), WETH, oneEther, 8, _generate2TrimData(), _generateMultipleCommissionData(true, WETH, false, 8));
    }
    function test_unxswapTo_WETH2USDT2USDC_permit2Sig_2trim_8fromCommToB() tokenLogAndCheck3(WETH, USDC, twoEther, true, true, true, 8, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigTrimComm(_generateWETH2USDT2USDCUnxswapToData(_MODE_PERMIT2_SIGNATURE), WETH, twoEther, _generate2TrimData(), _generateMultipleCommissionData(true, WETH, true, 8));
    }
    function test_unxswapTo_WETH2USDT2USDC_permit2Sig_2trim_8toCommToC() tokenLogAndCheck3(WETH, USDC, oneEther, true, true, false, 8, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigTrimComm(_generateWETH2USDT2USDCUnxswapToData(_MODE_PERMIT2_SIGNATURE), WETH, oneEther, _generate2TrimData(), _generateMultipleCommissionData(false, USDC, false, 8));
    }
    function test_unxswapTo_WETH2USDT2USDC_permit2Sig_2trim_8toCommToB() tokenLogAndCheck3(WETH, USDC, oneEther, true, true, false, 8, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigTrimComm(_generateWETH2USDT2USDCUnxswapToData(_MODE_PERMIT2_SIGNATURE), WETH, oneEther, _generate2TrimData(), _generateMultipleCommissionData(false, USDC, true, 8));
    }

    // -------------------- Permit2 Allowance Mode --------------------
    // noTrim
    function test_unxswapTo_WETH2USDT2USDC_permit2Allow_noTrim_noComm() tokenLogAndCheck3(WETH, USDC, oneEther, false, false, false, 0, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwap(_generateWETH2USDT2USDCUnxswapToData(_MODE_PERMIT2_ALLOWANCE));
    }
    function test_unxswapTo_WETH2USDT2USDC_permit2Allow_noTrim_8fromCommToC() tokenLogAndCheck3(WETH, USDC, twoEther, false, false, true, 8, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithComm(_generateWETH2USDT2USDCUnxswapToData(_MODE_PERMIT2_ALLOWANCE), _generateMultipleCommissionData(true, WETH, false, 8));
    }
    function test_unxswapTo_WETH2USDT2USDC_permit2Allow_noTrim_8fromCommToB() tokenLogAndCheck3(WETH, USDC, twoEther, false, false, true, 8, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithComm(_generateWETH2USDT2USDCUnxswapToData(_MODE_PERMIT2_ALLOWANCE), _generateMultipleCommissionData(true, WETH, true, 8));
    }
    function test_unxswapTo_WETH2USDT2USDC_permit2Allow_noTrim_8toCommToC() tokenLogAndCheck3(WETH, USDC, oneEther, false, false, false, 8, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithComm(_generateWETH2USDT2USDCUnxswapToData(_MODE_PERMIT2_ALLOWANCE), _generateMultipleCommissionData(false, USDC, false, 8));
    }
    function test_unxswapTo_WETH2USDT2USDC_permit2Allow_noTrim_8toCommToB() tokenLogAndCheck3(WETH, USDC, oneEther, false, false, false, 8, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithComm(_generateWETH2USDT2USDCUnxswapToData(_MODE_PERMIT2_ALLOWANCE), _generateMultipleCommissionData(false, USDC, true, 8));
    }
    // 2trim
    function test_unxswapTo_WETH2USDT2USDC_permit2Allow_2trim_noComm() tokenLogAndCheck3(WETH, USDC, oneEther, true, true, false, 0, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithTrim(_generateWETH2USDT2USDCUnxswapToData(_MODE_PERMIT2_ALLOWANCE), _generate2TrimData());
    }
    function test_unxswapTo_WETH2USDT2USDC_permit2Allow_2trim_8fromCommToC() tokenLogAndCheck3(WETH, USDC, twoEther, true, true, true, 8, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithTrimComm(_generateWETH2USDT2USDCUnxswapToData(_MODE_PERMIT2_ALLOWANCE), _generate2TrimData(), _generateMultipleCommissionData(true, WETH, false, 8));
    }
    function test_unxswapTo_WETH2USDT2USDC_permit2Allow_2trim_8fromCommToB() tokenLogAndCheck3(WETH, USDC, twoEther, true, true, true, 8, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithTrimComm(_generateWETH2USDT2USDCUnxswapToData(_MODE_PERMIT2_ALLOWANCE), _generate2TrimData(), _generateMultipleCommissionData(true, WETH, true, 8));
    }
    function test_unxswapTo_WETH2USDT2USDC_permit2Allow_2trim_8toCommToC() tokenLogAndCheck3(WETH, USDC, oneEther, true, true, false, 8, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithTrimComm(_generateWETH2USDT2USDCUnxswapToData(_MODE_PERMIT2_ALLOWANCE), _generate2TrimData(), _generateMultipleCommissionData(false, USDC, false, 8));
    }
    function test_unxswapTo_WETH2USDT2USDC_permit2Allow_2trim_8toCommToB() tokenLogAndCheck3(WETH, USDC, oneEther, true, true, false, 8, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithTrimComm(_generateWETH2USDT2USDCUnxswapToData(_MODE_PERMIT2_ALLOWANCE), _generate2TrimData(), _generateMultipleCommissionData(false, USDC, true, 8));
    }

    // -------------------- By Invest Mode --------------------
    // noTrim
    function test_unxswapTo_WETH2USDT2USDC_byInvest_noTrim_noComm() tokenLogAndCheck3(WETH, USDC, oneEther, false, false, false, 0, _MODE_BY_INVEST) public {
        IERC20(WETH).transfer(address(dexRouter), oneEther);
        _execSwap(_generateWETH2USDT2USDCUnxswapToData(_MODE_BY_INVEST));
    }
    // 2trim
    function test_unxswapTo_WETH2USDT2USDC_byInvest_2trim_noComm() tokenLogAndCheck3(WETH, USDC, oneEther, true, true, false, 0, _MODE_BY_INVEST) public {
        IERC20(WETH).transfer(address(dexRouter), oneEther);
        _execSwapWithTrim(_generateWETH2USDT2USDCUnxswapToData(_MODE_BY_INVEST), _generate2TrimData());
    }

    // ============================================================================
    // USDT -> USDC -> ETH (ERC20 -> ERC20 -> ETH)
    // ============================================================================
    uint256 constant USDT_AMOUNT = 1000 * 10 ** 6;

    // -------------------- Legacy Mode --------------------
    // noTrim
    function test_unxswapTo_USDT2USDC2ETH_legacy_noTrim_noComm() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, false, false, false, 0, _MODE_LEGACY) public {
        _execSwap(_generateUSDT2USDC2ETHUnxswapToData(_MODE_LEGACY));
    }
    function test_unxswapTo_USDT2USDC2ETH_legacy_noTrim_8fromCommToC() tokenLogAndCheck3(USDT, ETH, TWO_USDT_AMOUNT, false, false, true, 8, _MODE_LEGACY) public {
        _execSwapWithComm(_generateUSDT2USDC2ETHUnxswapToData(_MODE_LEGACY), _generateMultipleCommissionData(true, USDT, false, 8));
    }
    function test_unxswapTo_USDT2USDC2ETH_legacy_noTrim_8fromCommToB() tokenLogAndCheck3(USDT, ETH, TWO_USDT_AMOUNT, false, false, true, 8, _MODE_LEGACY) public {
        _execSwapWithComm(_generateUSDT2USDC2ETHUnxswapToData(_MODE_LEGACY), _generateMultipleCommissionData(true, USDT, true, 8));
    }
    function test_unxswapTo_USDT2USDC2ETH_legacy_noTrim_8toCommToC() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, false, false, false, 8, _MODE_LEGACY) public {
        _execSwapWithComm(_generateUSDT2USDC2ETHUnxswapToData(_MODE_LEGACY), _generateMultipleCommissionData(false, ETH, false, 8));
    }
    function test_unxswapTo_USDT2USDC2ETH_legacy_noTrim_8toCommToB() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, false, false, false, 8, _MODE_LEGACY) public {
        _execSwapWithComm(_generateUSDT2USDC2ETHUnxswapToData(_MODE_LEGACY), _generateMultipleCommissionData(false, ETH, true, 8));
    }
    // 2trim
    function test_unxswapTo_USDT2USDC2ETH_legacy_2trim_noComm() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, true, true, false, 0, _MODE_LEGACY) public {
        _execSwapWithTrim(_generateUSDT2USDC2ETHUnxswapToData(_MODE_LEGACY), _generate2TrimData());
    }
    function test_unxswapTo_USDT2USDC2ETH_legacy_2trim_8fromCommToC() tokenLogAndCheck3(USDT, ETH, TWO_USDT_AMOUNT, true, true, true, 8, _MODE_LEGACY) public {
        _execSwapWithTrimComm(_generateUSDT2USDC2ETHUnxswapToData(_MODE_LEGACY), _generate2TrimData(), _generateMultipleCommissionData(true, USDT, false, 8));
    }
    function test_unxswapTo_USDT2USDC2ETH_legacy_2trim_8fromCommToB() tokenLogAndCheck3(USDT, ETH, TWO_USDT_AMOUNT, true, true, true, 8, _MODE_LEGACY) public {
        _execSwapWithTrimComm(_generateUSDT2USDC2ETHUnxswapToData(_MODE_LEGACY), _generate2TrimData(), _generateMultipleCommissionData(true, USDT, true, 8));
    }
    function test_unxswapTo_USDT2USDC2ETH_legacy_2trim_8toCommToC() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, true, true, false, 8, _MODE_LEGACY) public {
        _execSwapWithTrimComm(_generateUSDT2USDC2ETHUnxswapToData(_MODE_LEGACY), _generate2TrimData(), _generateMultipleCommissionData(false, ETH, false, 8));
    }
    function test_unxswapTo_USDT2USDC2ETH_legacy_2trim_8toCommToB() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, true, true, false, 8, _MODE_LEGACY) public {
        _execSwapWithTrimComm(_generateUSDT2USDC2ETHUnxswapToData(_MODE_LEGACY), _generate2TrimData(), _generateMultipleCommissionData(false, ETH, true, 8));
    }

    // -------------------- Direct Mode --------------------
    // noTrim
    function test_unxswapTo_USDT2USDC2ETH_direct_noTrim_noComm() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, false, false, false, 0, _MODE_DIRECT) public {
        _execSwap(_generateUSDT2USDC2ETHUnxswapToData(_MODE_DIRECT));
    }
    function test_unxswapTo_USDT2USDC2ETH_direct_noTrim_8fromCommToC() tokenLogAndCheck3(USDT, ETH, TWO_USDT_AMOUNT, false, false, true, 8, _MODE_DIRECT) public {
        _execSwapWithComm(_generateUSDT2USDC2ETHUnxswapToData(_MODE_DIRECT), _generateMultipleCommissionData(true, USDT, false, 8));
    }
    function test_unxswapTo_USDT2USDC2ETH_direct_noTrim_8fromCommToB() tokenLogAndCheck3(USDT, ETH, TWO_USDT_AMOUNT, false, false, true, 8, _MODE_DIRECT) public {
        _execSwapWithComm(_generateUSDT2USDC2ETHUnxswapToData(_MODE_DIRECT), _generateMultipleCommissionData(true, USDT, true, 8));
    }
    function test_unxswapTo_USDT2USDC2ETH_direct_noTrim_8toCommToC() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, false, false, false, 8, _MODE_DIRECT) public {
        _execSwapWithComm(_generateUSDT2USDC2ETHUnxswapToData(_MODE_DIRECT), _generateMultipleCommissionData(false, ETH, false, 8));
    }
    function test_unxswapTo_USDT2USDC2ETH_direct_noTrim_8toCommToB() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, false, false, false, 8, _MODE_DIRECT) public {
        _execSwapWithComm(_generateUSDT2USDC2ETHUnxswapToData(_MODE_DIRECT), _generateMultipleCommissionData(false, ETH, true, 8));
    }
    // 2trim
    function test_unxswapTo_USDT2USDC2ETH_direct_2trim_noComm() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, true, true, false, 0, _MODE_DIRECT) public {
        _execSwapWithTrim(_generateUSDT2USDC2ETHUnxswapToData(_MODE_DIRECT), _generate2TrimData());
    }
    function test_unxswapTo_USDT2USDC2ETH_direct_2trim_8fromCommToC() tokenLogAndCheck3(USDT, ETH, TWO_USDT_AMOUNT, true, true, true, 8, _MODE_DIRECT) public {
        _execSwapWithTrimComm(_generateUSDT2USDC2ETHUnxswapToData(_MODE_DIRECT), _generate2TrimData(), _generateMultipleCommissionData(true, USDT, false, 8));
    }
    function test_unxswapTo_USDT2USDC2ETH_direct_2trim_8fromCommToB() tokenLogAndCheck3(USDT, ETH, TWO_USDT_AMOUNT, true, true, true, 8, _MODE_DIRECT) public {
        _execSwapWithTrimComm(_generateUSDT2USDC2ETHUnxswapToData(_MODE_DIRECT), _generate2TrimData(), _generateMultipleCommissionData(true, USDT, true, 8));
    }
    function test_unxswapTo_USDT2USDC2ETH_direct_2trim_8toCommToC() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, true, true, false, 8, _MODE_DIRECT) public {
        _execSwapWithTrimComm(_generateUSDT2USDC2ETHUnxswapToData(_MODE_DIRECT), _generate2TrimData(), _generateMultipleCommissionData(false, ETH, false, 8));
    }
    function test_unxswapTo_USDT2USDC2ETH_direct_2trim_8toCommToB() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, true, true, false, 8, _MODE_DIRECT) public {
        _execSwapWithTrimComm(_generateUSDT2USDC2ETHUnxswapToData(_MODE_DIRECT), _generate2TrimData(), _generateMultipleCommissionData(false, ETH, true, 8));
    }

    // -------------------- Permit2 Signature Mode --------------------
    // noTrim
    function test_unxswapTo_USDT2USDC2ETH_permit2Sig_noTrim_noComm() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, false, false, false, 0, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2Sig(_generateUSDT2USDC2ETHUnxswapToData(_MODE_PERMIT2_SIGNATURE), USDT, USDT_AMOUNT);
    }
    function test_unxswapTo_USDT2USDC2ETH_permit2Sig_noTrim_8fromCommToC() tokenLogAndCheck3(USDT, ETH, TWO_USDT_AMOUNT, false, false, true, 8, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigFromCommToC(_generateUSDT2USDC2ETHUnxswapToData(_MODE_PERMIT2_SIGNATURE), USDT, USDT_AMOUNT, 8, _generateMultipleCommissionData(true, USDT, false, 8));
    }
    function test_unxswapTo_USDT2USDC2ETH_permit2Sig_noTrim_8fromCommToB() tokenLogAndCheck3(USDT, ETH, TWO_USDT_AMOUNT, false, false, true, 8, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigComm(_generateUSDT2USDC2ETHUnxswapToData(_MODE_PERMIT2_SIGNATURE), USDT, TWO_USDT_AMOUNT, _generateMultipleCommissionData(true, USDT, true, 8));
    }
    function test_unxswapTo_USDT2USDC2ETH_permit2Sig_noTrim_8toCommToC() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, false, false, false, 8, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigComm(_generateUSDT2USDC2ETHUnxswapToData(_MODE_PERMIT2_SIGNATURE), USDT, USDT_AMOUNT, _generateMultipleCommissionData(false, ETH, false, 8));
    }
    function test_unxswapTo_USDT2USDC2ETH_permit2Sig_noTrim_8toCommToB() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, false, false, false, 8, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigComm(_generateUSDT2USDC2ETHUnxswapToData(_MODE_PERMIT2_SIGNATURE), USDT, USDT_AMOUNT, _generateMultipleCommissionData(false, ETH, true, 8));
    }
    // 2trim
    function test_unxswapTo_USDT2USDC2ETH_permit2Sig_2trim_noComm() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, true, true, false, 0, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigTrim(_generateUSDT2USDC2ETHUnxswapToData(_MODE_PERMIT2_SIGNATURE), USDT, USDT_AMOUNT, _generate2TrimData());
    }
    function test_unxswapTo_USDT2USDC2ETH_permit2Sig_2trim_8fromCommToC() tokenLogAndCheck3(USDT, ETH, TWO_USDT_AMOUNT, true, true, true, 8, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigTrimFromCommToC(_generateUSDT2USDC2ETHUnxswapToData(_MODE_PERMIT2_SIGNATURE), USDT, USDT_AMOUNT, 8, _generate2TrimData(), _generateMultipleCommissionData(true, USDT, false, 8));
    }
    function test_unxswapTo_USDT2USDC2ETH_permit2Sig_2trim_8fromCommToB() tokenLogAndCheck3(USDT, ETH, TWO_USDT_AMOUNT, true, true, true, 8, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigTrimComm(_generateUSDT2USDC2ETHUnxswapToData(_MODE_PERMIT2_SIGNATURE), USDT, TWO_USDT_AMOUNT, _generate2TrimData(), _generateMultipleCommissionData(true, USDT, true, 8));
    }
    function test_unxswapTo_USDT2USDC2ETH_permit2Sig_2trim_8toCommToC() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, true, true, false, 8, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigTrimComm(_generateUSDT2USDC2ETHUnxswapToData(_MODE_PERMIT2_SIGNATURE), USDT, USDT_AMOUNT, _generate2TrimData(), _generateMultipleCommissionData(false, ETH, false, 8));
    }
    function test_unxswapTo_USDT2USDC2ETH_permit2Sig_2trim_8toCommToB() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, true, true, false, 8, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigTrimComm(_generateUSDT2USDC2ETHUnxswapToData(_MODE_PERMIT2_SIGNATURE), USDT, USDT_AMOUNT, _generate2TrimData(), _generateMultipleCommissionData(false, ETH, true, 8));
    }

    // -------------------- Permit2 Allowance Mode --------------------
    // noTrim
    function test_unxswapTo_USDT2USDC2ETH_permit2Allow_noTrim_noComm() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, false, false, false, 0, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwap(_generateUSDT2USDC2ETHUnxswapToData(_MODE_PERMIT2_ALLOWANCE));
    }
    function test_unxswapTo_USDT2USDC2ETH_permit2Allow_noTrim_8fromCommToC() tokenLogAndCheck3(USDT, ETH, TWO_USDT_AMOUNT, false, false, true, 8, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithComm(_generateUSDT2USDC2ETHUnxswapToData(_MODE_PERMIT2_ALLOWANCE), _generateMultipleCommissionData(true, USDT, false, 8));
    }
    function test_unxswapTo_USDT2USDC2ETH_permit2Allow_noTrim_8fromCommToB() tokenLogAndCheck3(USDT, ETH, TWO_USDT_AMOUNT, false, false, true, 8, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithComm(_generateUSDT2USDC2ETHUnxswapToData(_MODE_PERMIT2_ALLOWANCE), _generateMultipleCommissionData(true, USDT, true, 8));
    }
    function test_unxswapTo_USDT2USDC2ETH_permit2Allow_noTrim_8toCommToC() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, false, false, false, 8, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithComm(_generateUSDT2USDC2ETHUnxswapToData(_MODE_PERMIT2_ALLOWANCE), _generateMultipleCommissionData(false, ETH, false, 8));
    }
    function test_unxswapTo_USDT2USDC2ETH_permit2Allow_noTrim_8toCommToB() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, false, false, false, 8, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithComm(_generateUSDT2USDC2ETHUnxswapToData(_MODE_PERMIT2_ALLOWANCE), _generateMultipleCommissionData(false, ETH, true, 8));
    }
    // 2trim
    function test_unxswapTo_USDT2USDC2ETH_permit2Allow_2trim_noComm() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, true, true, false, 0, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithTrim(_generateUSDT2USDC2ETHUnxswapToData(_MODE_PERMIT2_ALLOWANCE), _generate2TrimData());
    }
    function test_unxswapTo_USDT2USDC2ETH_permit2Allow_2trim_8fromCommToC() tokenLogAndCheck3(USDT, ETH, TWO_USDT_AMOUNT, true, true, true, 8, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithTrimComm(_generateUSDT2USDC2ETHUnxswapToData(_MODE_PERMIT2_ALLOWANCE), _generate2TrimData(), _generateMultipleCommissionData(true, USDT, false, 8));
    }
    function test_unxswapTo_USDT2USDC2ETH_permit2Allow_2trim_8fromCommToB() tokenLogAndCheck3(USDT, ETH, TWO_USDT_AMOUNT, true, true, true, 8, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithTrimComm(_generateUSDT2USDC2ETHUnxswapToData(_MODE_PERMIT2_ALLOWANCE), _generate2TrimData(), _generateMultipleCommissionData(true, USDT, true, 8));
    }
    function test_unxswapTo_USDT2USDC2ETH_permit2Allow_2trim_8toCommToC() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, true, true, false, 8, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithTrimComm(_generateUSDT2USDC2ETHUnxswapToData(_MODE_PERMIT2_ALLOWANCE), _generate2TrimData(), _generateMultipleCommissionData(false, ETH, false, 8));
    }
    function test_unxswapTo_USDT2USDC2ETH_permit2Allow_2trim_8toCommToB() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, true, true, false, 8, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithTrimComm(_generateUSDT2USDC2ETHUnxswapToData(_MODE_PERMIT2_ALLOWANCE), _generate2TrimData(), _generateMultipleCommissionData(false, ETH, true, 8));
    }

    // -------------------- By Invest Mode --------------------
    // noTrim
    function test_unxswapTo_USDT2USDC2ETH_byInvest_noTrim_noComm() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, false, false, false, 0, _MODE_BY_INVEST) public {
        SafeERC20.safeTransfer(IERC20(USDT), address(dexRouter), USDT_AMOUNT);
        _execSwap(_generateUSDT2USDC2ETHUnxswapToData(_MODE_BY_INVEST));
    }
    // 2trim
    function test_unxswapTo_USDT2USDC2ETH_byInvest_2trim_noComm() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, true, true, false, 0, _MODE_BY_INVEST) public {
        SafeERC20.safeTransfer(IERC20(USDT), address(dexRouter), USDT_AMOUNT);
        _execSwapWithTrim(_generateUSDT2USDC2ETHUnxswapToData(_MODE_BY_INVEST), _generate2TrimData());
    }

    // ============================================================================
    // ETH -> USDT -> USDC (ETH -> ERC20 -> ERC20)
    // Note: ETH input doesn't use transferMode (transferMode is for ERC20 only)
    // ============================================================================

    // noTrim
    function test_unxswapTo_ETH2USDT2USDC_noTrim_noComm() tokenLogAndCheck3(ETH, USDC, oneEther, false, false, false, 0, _MODE_LEGACY) public {
        _execSwapWithValue(_generateETH2USDT2USDCUnxswapToData(), oneEther);
    }
    function test_unxswapTo_ETH2USDT2USDC_noTrim_8fromCommToC() tokenLogAndCheck3(ETH, USDC, twoEther, false, false, true, 8, _MODE_LEGACY) public {
        _execSwapWithValueComm(_generateETH2USDT2USDCUnxswapToData(), twoEther, _generateMultipleCommissionData(true, ETH, false, 8));
    }
    function test_unxswapTo_ETH2USDT2USDC_noTrim_8fromCommToB() tokenLogAndCheck3(ETH, USDC, twoEther, false, false, true, 8, _MODE_LEGACY) public {
        _execSwapWithValueComm(_generateETH2USDT2USDCUnxswapToData(), twoEther, _generateMultipleCommissionData(true, ETH, true, 8));
    }
    function test_unxswapTo_ETH2USDT2USDC_noTrim_8toCommToC() tokenLogAndCheck3(ETH, USDC, oneEther, false, false, false, 8, _MODE_LEGACY) public {
        _execSwapWithValueComm(_generateETH2USDT2USDCUnxswapToData(), oneEther, _generateMultipleCommissionData(false, USDC, false, 8));
    }
    function test_unxswapTo_ETH2USDT2USDC_noTrim_8toCommToB() tokenLogAndCheck3(ETH, USDC, oneEther, false, false, false, 8, _MODE_LEGACY) public {
        _execSwapWithValueComm(_generateETH2USDT2USDCUnxswapToData(), oneEther, _generateMultipleCommissionData(false, USDC, true, 8));
    }
    // 2trim
    function test_unxswapTo_ETH2USDT2USDC_2trim_noComm() tokenLogAndCheck3(ETH, USDC, oneEther, true, true, false, 0, _MODE_LEGACY) public {
        _execSwapWithValueTrim(_generateETH2USDT2USDCUnxswapToData(), oneEther, _generate2TrimData());
    }
    function test_unxswapTo_ETH2USDT2USDC_2trim_8fromCommToC() tokenLogAndCheck3(ETH, USDC, twoEther, true, true, true, 8, _MODE_LEGACY) public {
        _execSwapWithValueTrimComm(_generateETH2USDT2USDCUnxswapToData(), twoEther, _generate2TrimData(), _generateMultipleCommissionData(true, ETH, false, 8));
    }
    function test_unxswapTo_ETH2USDT2USDC_2trim_8fromCommToB() tokenLogAndCheck3(ETH, USDC, twoEther, true, true, true, 8, _MODE_LEGACY) public {
        _execSwapWithValueTrimComm(_generateETH2USDT2USDCUnxswapToData(), twoEther, _generate2TrimData(), _generateMultipleCommissionData(true, ETH, true, 8));
    }
    function test_unxswapTo_ETH2USDT2USDC_2trim_8toCommToC() tokenLogAndCheck3(ETH, USDC, oneEther, true, true, false, 8, _MODE_LEGACY) public {
        _execSwapWithValueTrimComm(_generateETH2USDT2USDCUnxswapToData(), oneEther, _generate2TrimData(), _generateMultipleCommissionData(false, USDC, false, 8));
    }
    function test_unxswapTo_ETH2USDT2USDC_2trim_8toCommToB() tokenLogAndCheck3(ETH, USDC, oneEther, true, true, false, 8, _MODE_LEGACY) public {
        _execSwapWithValueTrimComm(_generateETH2USDT2USDCUnxswapToData(), oneEther, _generate2TrimData(), _generateMultipleCommissionData(false, USDC, true, 8));
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

    /// @notice WETH -> USDT -> USDC two-pool swap
    function _generateWETH2USDT2USDCUnxswapToData(uint256 transferMode) internal view returns (bytes memory) {
        // WETH -> USDT: token0 -> token1 (reversed=false), USDT -> USDC: token1 -> token0 (reversed=true)
        bytes32[] memory pools = _generatePoolsDefault(WETH_USDT_UNIV2, USDC_USDT_UNIV2, false, true, false, transferMode);
        return abi.encodeWithSelector(DexRouter.unxswapTo.selector, uint256(uint160(WETH)), oneEther, 0, arnaud, pools);
    }

    /// @notice ETH -> USDT -> USDC two-pool swap (ETH auto-wrapped to WETH)
    /// @dev ETH input doesn't use transferMode (transferMode is for ERC20 fromToken only)
    function _generateETH2USDT2USDCUnxswapToData() internal view returns (bytes memory) {
        // srcToken high bits store orderId (123), low bits are 0 for ETH
        // transferMode=0 (Legacy) since ETH input doesn't use transfer mode
        bytes32[] memory pools = _generatePoolsDefault(WETH_USDT_UNIV2, USDC_USDT_UNIV2, false, true, false, _MODE_LEGACY);
        return abi.encodeWithSelector(DexRouter.unxswapTo.selector, 123 << 160, oneEther, 0, arnaud, pools);
    }

    /// @notice USDT -> USDC -> ETH two-pool swap (WETH unwrapped to ETH at the end)
    function _generateUSDT2USDC2ETHUnxswapToData(uint256 transferMode) internal view returns (bytes memory) {
        // USDT -> USDC: token1 -> token0 (reversed=true), USDC -> WETH: token0 -> token1 (reversed=false), unwrap=true
        bytes32[] memory pools = _generatePoolsDefault(USDC_USDT_UNIV2, USDC_WETH_UNIV2, true, false, true, transferMode);
        return abi.encodeWithSelector(DexRouter.unxswapTo.selector, uint256(uint160(USDT)), USDT_AMOUNT, 0, arnaud, pools);
    }

    /// @notice Generate pools with default UniV2 fee rate (997_000_000)
    function _generatePoolsDefault(
        address pool1, address pool2, bool pool1Reversed, bool pool2Reversed, bool unwrapWeth, uint256 transferMode
    ) internal pure returns (bytes32[] memory) {
        return _generatePools(pool1, pool2, pool1Reversed, pool2Reversed, unwrapWeth, transferMode, 997_000_000, 997_000_000);
    }

    /// @notice Generate a two-pool swap route array
    /// @dev Pool encoding: [1 byte flags][7 bytes reserved][4 bytes fee numerator][20 bytes pool address]
    ///      Flags: bit7=REVERSE, bit6=WETH_UNWRAP, bit5=IS_TOKEN1_TAX, bit4=IS_TOKEN0_TAX, bit3-1=TRANSFER_MODE
    function _generatePools(
        address pool1, address pool2, bool pool1Reversed, bool pool2Reversed,
        bool unwrapWeth, uint256 transferMode, uint32 numerator1, uint32 numerator2
    ) internal pure returns (bytes32[] memory pools) {
        pools = new bytes32[](2);
        
        // First pool: includes transfer mode
        uint8 pool1Flags = uint8(transferMode >> 248);
        if (pool1Reversed) pool1Flags |= 0x80;
        pools[0] = bytes32(abi.encodePacked(pool1Flags, uint56(0), numerator1, pool1));
        
        // Second pool: may include unwrap flag
        uint8 pool2Flags = 0;
        if (pool2Reversed) pool2Flags |= 0x80;
        if (unwrapWeth) pool2Flags |= 0x40;
        pools[1] = bytes32(abi.encodePacked(pool2Flags, uint56(0), numerator2, pool2));
        
        return pools;
    }
}