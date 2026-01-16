// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../common/TrimAndCommissionTestBase.t.sol";
import "@dex/interfaces/permit2/IPermit2.sol";

/*
 * UniswapV3SwapExactOut method test cases - Complete cross-combination testing.
 * All swap cases use 2 pools (two-hop swap).
 *
 * Test Dimensions:
 * 1. Transfer Modes (4): Legacy / Direct / Permit2Signature / Permit2Allowance
 *    - ExactOut does NOT support NoTransfer and ByInvest modes
 *    - Only applies to ERC20 fromToken; ETH input doesn't use transferMode
 * 2. Swap Types (3): ERC20->ERC20->ERC20 / ERC20->ERC20->ETH / ETH->ERC20->ERC20
 * 3. Commission (9): None / 2 fromToken ToC / 2 fromToken ToB / 2 toToken ToC / 2 toToken ToB
 *                    / 8 fromToken ToC / 8 fromToken ToB / 8 toToken ToC / 8 toToken ToB
 * 4. Trim: NOT supported for ExactOut
 *
 * Total: 4 modes * 2 ERC20-input types * 9 comm + 1 * 1 ETH-input type * 9 comm = 81 cases
 */

contract UnxswapV3ExactOutTransferModeTest is TrimAndCommissionTestBase {
    // ExactOut: specify output amount, calculate required input
    uint256 constant USDC_OUT = 1000 * 10 ** 6;     // target output: 1000 USDC
    uint256 constant ETH_OUT = 5 * 10 ** 17;        // target output: 0.5 ETH
    uint256 constant MAX_WETH_IN = 2 * 10 ** 18;    // max input: 2 WETH (for slippage)
    uint256 constant MAX_USDT_IN = 3000 * 10 ** 6;  // max input: 3000 USDT (for slippage)
    uint256 constant MAX_ETH_IN = 2 * 10 ** 18;     // max input: 2 ETH (for slippage)

    // ============================================================================
    // WETH -> USDT -> USDC (ERC20 -> ERC20 -> ERC20, ExactOut)
    // ============================================================================

    // -------------------- Legacy Mode --------------------
    // noComm
    function test_v3ExactOut_WETH2USDT2USDC_legacy_noComm() tokenLogAndCheck3(WETH, USDC, MAX_WETH_IN, false, false, false, 0, _MODE_LEGACY) public {
        _execSwap(_genWETH2USDT2USDCExactOutData(_MODE_LEGACY));
    }
    // 2 fromToken commission
    function test_v3ExactOut_WETH2USDT2USDC_legacy_2fromCommToC() tokenLogAndCheck3(WETH, USDC, MAX_WETH_IN, false, false, true, 2, _MODE_LEGACY) public {
        _execSwapWithComm(_genWETH2USDT2USDCExactOutData(_MODE_LEGACY), _generateMultipleCommissionData(true, WETH, false, 2));
    }
    function test_v3ExactOut_WETH2USDT2USDC_legacy_2fromCommToB() tokenLogAndCheck3(WETH, USDC, MAX_WETH_IN, false, false, true, 2, _MODE_LEGACY) public {
        _execSwapWithComm(_genWETH2USDT2USDCExactOutData(_MODE_LEGACY), _generateMultipleCommissionData(true, WETH, true, 2));
    }
    // 2 toToken commission
    function test_v3ExactOut_WETH2USDT2USDC_legacy_2toCommToC() tokenLogAndCheck3(WETH, USDC, MAX_WETH_IN, false, false, false, 2, _MODE_LEGACY) public {
        _execSwapWithComm(_genWETH2USDT2USDCExactOutData(_MODE_LEGACY), _generateMultipleCommissionData(false, USDC, false, 2));
    }
    function test_v3ExactOut_WETH2USDT2USDC_legacy_2toCommToB() tokenLogAndCheck3(WETH, USDC, MAX_WETH_IN, false, false, false, 2, _MODE_LEGACY) public {
        _execSwapWithComm(_genWETH2USDT2USDCExactOutData(_MODE_LEGACY), _generateMultipleCommissionData(false, USDC, true, 2));
    }
    // 8 fromToken commission
    function test_v3ExactOut_WETH2USDT2USDC_legacy_8fromCommToC() tokenLogAndCheck3(WETH, USDC, MAX_WETH_IN, false, false, true, 8, _MODE_LEGACY) public {
        _execSwapWithComm(_genWETH2USDT2USDCExactOutData(_MODE_LEGACY), _generateMultipleCommissionData(true, WETH, false, 8));
    }
    function test_v3ExactOut_WETH2USDT2USDC_legacy_8fromCommToB() tokenLogAndCheck3(WETH, USDC, MAX_WETH_IN, false, false, true, 8, _MODE_LEGACY) public {
        _execSwapWithComm(_genWETH2USDT2USDCExactOutData(_MODE_LEGACY), _generateMultipleCommissionData(true, WETH, true, 8));
    }
    // 8 toToken commission
    function test_v3ExactOut_WETH2USDT2USDC_legacy_8toCommToC() tokenLogAndCheck3(WETH, USDC, MAX_WETH_IN, false, false, false, 8, _MODE_LEGACY) public {
        _execSwapWithComm(_genWETH2USDT2USDCExactOutData(_MODE_LEGACY), _generateMultipleCommissionData(false, USDC, false, 8));
    }
    function test_v3ExactOut_WETH2USDT2USDC_legacy_8toCommToB() tokenLogAndCheck3(WETH, USDC, MAX_WETH_IN, false, false, false, 8, _MODE_LEGACY) public {
        _execSwapWithComm(_genWETH2USDT2USDCExactOutData(_MODE_LEGACY), _generateMultipleCommissionData(false, USDC, true, 8));
    }

    // -------------------- Direct Mode --------------------
    // noComm
    function test_v3ExactOut_WETH2USDT2USDC_direct_noComm() tokenLogAndCheck3(WETH, USDC, MAX_WETH_IN, false, false, false, 0, _MODE_DIRECT) public {
        _execSwap(_genWETH2USDT2USDCExactOutData(_MODE_DIRECT));
    }
    // 2 fromToken commission
    function test_v3ExactOut_WETH2USDT2USDC_direct_2fromCommToC() tokenLogAndCheck3(WETH, USDC, MAX_WETH_IN, false, false, true, 2, _MODE_DIRECT) public {
        _execSwapWithComm(_genWETH2USDT2USDCExactOutData(_MODE_DIRECT), _generateMultipleCommissionData(true, WETH, false, 2));
    }
    function test_v3ExactOut_WETH2USDT2USDC_direct_2fromCommToB() tokenLogAndCheck3(WETH, USDC, MAX_WETH_IN, false, false, true, 2, _MODE_DIRECT) public {
        _execSwapWithComm(_genWETH2USDT2USDCExactOutData(_MODE_DIRECT), _generateMultipleCommissionData(true, WETH, true, 2));
    }
    // 2 toToken commission
    function test_v3ExactOut_WETH2USDT2USDC_direct_2toCommToC() tokenLogAndCheck3(WETH, USDC, MAX_WETH_IN, false, false, false, 2, _MODE_DIRECT) public {
        _execSwapWithComm(_genWETH2USDT2USDCExactOutData(_MODE_DIRECT), _generateMultipleCommissionData(false, USDC, false, 2));
    }
    function test_v3ExactOut_WETH2USDT2USDC_direct_2toCommToB() tokenLogAndCheck3(WETH, USDC, MAX_WETH_IN, false, false, false, 2, _MODE_DIRECT) public {
        _execSwapWithComm(_genWETH2USDT2USDCExactOutData(_MODE_DIRECT), _generateMultipleCommissionData(false, USDC, true, 2));
    }
    // 8 fromToken commission
    function test_v3ExactOut_WETH2USDT2USDC_direct_8fromCommToC() tokenLogAndCheck3(WETH, USDC, MAX_WETH_IN, false, false, true, 8, _MODE_DIRECT) public {
        _execSwapWithComm(_genWETH2USDT2USDCExactOutData(_MODE_DIRECT), _generateMultipleCommissionData(true, WETH, false, 8));
    }
    function test_v3ExactOut_WETH2USDT2USDC_direct_8fromCommToB() tokenLogAndCheck3(WETH, USDC, MAX_WETH_IN, false, false, true, 8, _MODE_DIRECT) public {
        _execSwapWithComm(_genWETH2USDT2USDCExactOutData(_MODE_DIRECT), _generateMultipleCommissionData(true, WETH, true, 8));
    }
    // 8 toToken commission
    function test_v3ExactOut_WETH2USDT2USDC_direct_8toCommToC() tokenLogAndCheck3(WETH, USDC, MAX_WETH_IN, false, false, false, 8, _MODE_DIRECT) public {
        _execSwapWithComm(_genWETH2USDT2USDCExactOutData(_MODE_DIRECT), _generateMultipleCommissionData(false, USDC, false, 8));
    }
    function test_v3ExactOut_WETH2USDT2USDC_direct_8toCommToB() tokenLogAndCheck3(WETH, USDC, MAX_WETH_IN, false, false, false, 8, _MODE_DIRECT) public {
        _execSwapWithComm(_genWETH2USDT2USDCExactOutData(_MODE_DIRECT), _generateMultipleCommissionData(false, USDC, true, 8));
    }

    // -------------------- Permit2 Signature Mode --------------------
    // noComm
    function test_v3ExactOut_WETH2USDT2USDC_permit2Sig_noComm() tokenLogAndCheck3(WETH, USDC, MAX_WETH_IN, false, false, false, 0, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2Sig(_genWETH2USDT2USDCExactOutData(_MODE_PERMIT2_SIGNATURE), WETH, MAX_WETH_IN);
    }
    // 2 fromToken commission
    function test_v3ExactOut_WETH2USDT2USDC_permit2Sig_2fromCommToC() tokenLogAndCheck3(WETH, USDC, MAX_WETH_IN, false, false, true, 2, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigFromCommToC(_genWETH2USDT2USDCExactOutData(_MODE_PERMIT2_SIGNATURE), WETH, MAX_WETH_IN, 2, _generateMultipleCommissionData(true, WETH, false, 2));
    }
    function test_v3ExactOut_WETH2USDT2USDC_permit2Sig_2fromCommToB() tokenLogAndCheck3(WETH, USDC, MAX_WETH_IN, false, false, true, 2, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigComm(_genWETH2USDT2USDCExactOutData(_MODE_PERMIT2_SIGNATURE), WETH, MAX_WETH_IN, _generateMultipleCommissionData(true, WETH, true, 2));
    }
    // 2 toToken commission
    function test_v3ExactOut_WETH2USDT2USDC_permit2Sig_2toCommToC() tokenLogAndCheck3(WETH, USDC, MAX_WETH_IN, false, false, false, 2, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigComm(_genWETH2USDT2USDCExactOutData(_MODE_PERMIT2_SIGNATURE), WETH, MAX_WETH_IN, _generateMultipleCommissionData(false, USDC, false, 2));
    }
    function test_v3ExactOut_WETH2USDT2USDC_permit2Sig_2toCommToB() tokenLogAndCheck3(WETH, USDC, MAX_WETH_IN, false, false, false, 2, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigComm(_genWETH2USDT2USDCExactOutData(_MODE_PERMIT2_SIGNATURE), WETH, MAX_WETH_IN, _generateMultipleCommissionData(false, USDC, true, 2));
    }
    // 8 fromToken commission
    function test_v3ExactOut_WETH2USDT2USDC_permit2Sig_8fromCommToC() tokenLogAndCheck3(WETH, USDC, MAX_WETH_IN, false, false, true, 8, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigFromCommToC(_genWETH2USDT2USDCExactOutData(_MODE_PERMIT2_SIGNATURE), WETH, MAX_WETH_IN, 8, _generateMultipleCommissionData(true, WETH, false, 8));
    }
    function test_v3ExactOut_WETH2USDT2USDC_permit2Sig_8fromCommToB() tokenLogAndCheck3(WETH, USDC, MAX_WETH_IN, false, false, true, 8, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigComm(_genWETH2USDT2USDCExactOutData(_MODE_PERMIT2_SIGNATURE), WETH, MAX_WETH_IN, _generateMultipleCommissionData(true, WETH, true, 8));
    }
    // 8 toToken commission
    function test_v3ExactOut_WETH2USDT2USDC_permit2Sig_8toCommToC() tokenLogAndCheck3(WETH, USDC, MAX_WETH_IN, false, false, false, 8, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigComm(_genWETH2USDT2USDCExactOutData(_MODE_PERMIT2_SIGNATURE), WETH, MAX_WETH_IN, _generateMultipleCommissionData(false, USDC, false, 8));
    }
    function test_v3ExactOut_WETH2USDT2USDC_permit2Sig_8toCommToB() tokenLogAndCheck3(WETH, USDC, MAX_WETH_IN, false, false, false, 8, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigComm(_genWETH2USDT2USDCExactOutData(_MODE_PERMIT2_SIGNATURE), WETH, MAX_WETH_IN, _generateMultipleCommissionData(false, USDC, true, 8));
    }

    // -------------------- Permit2 Allowance Mode --------------------
    // noComm
    function test_v3ExactOut_WETH2USDT2USDC_permit2Allow_noComm() tokenLogAndCheck3(WETH, USDC, MAX_WETH_IN, false, false, false, 0, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwap(_genWETH2USDT2USDCExactOutData(_MODE_PERMIT2_ALLOWANCE));
    }
    // 2 fromToken commission
    function test_v3ExactOut_WETH2USDT2USDC_permit2Allow_2fromCommToC() tokenLogAndCheck3(WETH, USDC, MAX_WETH_IN, false, false, true, 2, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithComm(_genWETH2USDT2USDCExactOutData(_MODE_PERMIT2_ALLOWANCE), _generateMultipleCommissionData(true, WETH, false, 2));
    }
    function test_v3ExactOut_WETH2USDT2USDC_permit2Allow_2fromCommToB() tokenLogAndCheck3(WETH, USDC, MAX_WETH_IN, false, false, true, 2, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithComm(_genWETH2USDT2USDCExactOutData(_MODE_PERMIT2_ALLOWANCE), _generateMultipleCommissionData(true, WETH, true, 2));
    }
    // 2 toToken commission
    function test_v3ExactOut_WETH2USDT2USDC_permit2Allow_2toCommToC() tokenLogAndCheck3(WETH, USDC, MAX_WETH_IN, false, false, false, 2, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithComm(_genWETH2USDT2USDCExactOutData(_MODE_PERMIT2_ALLOWANCE), _generateMultipleCommissionData(false, USDC, false, 2));
    }
    function test_v3ExactOut_WETH2USDT2USDC_permit2Allow_2toCommToB() tokenLogAndCheck3(WETH, USDC, MAX_WETH_IN, false, false, false, 2, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithComm(_genWETH2USDT2USDCExactOutData(_MODE_PERMIT2_ALLOWANCE), _generateMultipleCommissionData(false, USDC, true, 2));
    }
    // 8 fromToken commission
    function test_v3ExactOut_WETH2USDT2USDC_permit2Allow_8fromCommToC() tokenLogAndCheck3(WETH, USDC, MAX_WETH_IN, false, false, true, 8, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithComm(_genWETH2USDT2USDCExactOutData(_MODE_PERMIT2_ALLOWANCE), _generateMultipleCommissionData(true, WETH, false, 8));
    }
    function test_v3ExactOut_WETH2USDT2USDC_permit2Allow_8fromCommToB() tokenLogAndCheck3(WETH, USDC, MAX_WETH_IN, false, false, true, 8, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithComm(_genWETH2USDT2USDCExactOutData(_MODE_PERMIT2_ALLOWANCE), _generateMultipleCommissionData(true, WETH, true, 8));
    }
    // 8 toToken commission
    function test_v3ExactOut_WETH2USDT2USDC_permit2Allow_8toCommToC() tokenLogAndCheck3(WETH, USDC, MAX_WETH_IN, false, false, false, 8, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithComm(_genWETH2USDT2USDCExactOutData(_MODE_PERMIT2_ALLOWANCE), _generateMultipleCommissionData(false, USDC, false, 8));
    }
    function test_v3ExactOut_WETH2USDT2USDC_permit2Allow_8toCommToB() tokenLogAndCheck3(WETH, USDC, MAX_WETH_IN, false, false, false, 8, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithComm(_genWETH2USDT2USDCExactOutData(_MODE_PERMIT2_ALLOWANCE), _generateMultipleCommissionData(false, USDC, true, 8));
    }

    // ============================================================================
    // USDT -> USDC -> ETH (ERC20 -> ERC20 -> ETH, ExactOut)
    // ============================================================================

    // -------------------- Legacy Mode --------------------
    // noComm
    function test_v3ExactOut_USDT2USDC2ETH_legacy_noComm() tokenLogAndCheck3(USDT, ETH, MAX_USDT_IN, false, false, false, 0, _MODE_LEGACY) public {
        _execSwap(_genUSDT2USDC2ETHExactOutData(_MODE_LEGACY));
    }
    // 2 fromToken commission
    function test_v3ExactOut_USDT2USDC2ETH_legacy_2fromCommToC() tokenLogAndCheck3(USDT, ETH, MAX_USDT_IN, false, false, true, 2, _MODE_LEGACY) public {
        _execSwapWithComm(_genUSDT2USDC2ETHExactOutData(_MODE_LEGACY), _generateMultipleCommissionData(true, USDT, false, 2));
    }
    function test_v3ExactOut_USDT2USDC2ETH_legacy_2fromCommToB() tokenLogAndCheck3(USDT, ETH, MAX_USDT_IN, false, false, true, 2, _MODE_LEGACY) public {
        _execSwapWithComm(_genUSDT2USDC2ETHExactOutData(_MODE_LEGACY), _generateMultipleCommissionData(true, USDT, true, 2));
    }
    // 2 toToken commission
    function test_v3ExactOut_USDT2USDC2ETH_legacy_2toCommToC() tokenLogAndCheck3(USDT, ETH, MAX_USDT_IN, false, false, false, 2, _MODE_LEGACY) public {
        _execSwapWithComm(_genUSDT2USDC2ETHExactOutData(_MODE_LEGACY), _generateMultipleCommissionData(false, ETH, false, 2));
    }
    function test_v3ExactOut_USDT2USDC2ETH_legacy_2toCommToB() tokenLogAndCheck3(USDT, ETH, MAX_USDT_IN, false, false, false, 2, _MODE_LEGACY) public {
        _execSwapWithComm(_genUSDT2USDC2ETHExactOutData(_MODE_LEGACY), _generateMultipleCommissionData(false, ETH, true, 2));
    }
    // 8 fromToken commission
    function test_v3ExactOut_USDT2USDC2ETH_legacy_8fromCommToC() tokenLogAndCheck3(USDT, ETH, MAX_USDT_IN, false, false, true, 8, _MODE_LEGACY) public {
        _execSwapWithComm(_genUSDT2USDC2ETHExactOutData(_MODE_LEGACY), _generateMultipleCommissionData(true, USDT, false, 8));
    }
    function test_v3ExactOut_USDT2USDC2ETH_legacy_8fromCommToB() tokenLogAndCheck3(USDT, ETH, MAX_USDT_IN, false, false, true, 8, _MODE_LEGACY) public {
        _execSwapWithComm(_genUSDT2USDC2ETHExactOutData(_MODE_LEGACY), _generateMultipleCommissionData(true, USDT, true, 8));
    }
    // 8 toToken commission
    function test_v3ExactOut_USDT2USDC2ETH_legacy_8toCommToC() tokenLogAndCheck3(USDT, ETH, MAX_USDT_IN, false, false, false, 8, _MODE_LEGACY) public {
        _execSwapWithComm(_genUSDT2USDC2ETHExactOutData(_MODE_LEGACY), _generateMultipleCommissionData(false, ETH, false, 8));
    }
    function test_v3ExactOut_USDT2USDC2ETH_legacy_8toCommToB() tokenLogAndCheck3(USDT, ETH, MAX_USDT_IN, false, false, false, 8, _MODE_LEGACY) public {
        _execSwapWithComm(_genUSDT2USDC2ETHExactOutData(_MODE_LEGACY), _generateMultipleCommissionData(false, ETH, true, 8));
    }

    // -------------------- Direct Mode --------------------
    // noComm
    function test_v3ExactOut_USDT2USDC2ETH_direct_noComm() tokenLogAndCheck3(USDT, ETH, MAX_USDT_IN, false, false, false, 0, _MODE_DIRECT) public {
        _execSwap(_genUSDT2USDC2ETHExactOutData(_MODE_DIRECT));
    }
    // 2 fromToken commission
    function test_v3ExactOut_USDT2USDC2ETH_direct_2fromCommToC() tokenLogAndCheck3(USDT, ETH, MAX_USDT_IN, false, false, true, 2, _MODE_DIRECT) public {
        _execSwapWithComm(_genUSDT2USDC2ETHExactOutData(_MODE_DIRECT), _generateMultipleCommissionData(true, USDT, false, 2));
    }
    function test_v3ExactOut_USDT2USDC2ETH_direct_2fromCommToB() tokenLogAndCheck3(USDT, ETH, MAX_USDT_IN, false, false, true, 2, _MODE_DIRECT) public {
        _execSwapWithComm(_genUSDT2USDC2ETHExactOutData(_MODE_DIRECT), _generateMultipleCommissionData(true, USDT, true, 2));
    }
    // 2 toToken commission
    function test_v3ExactOut_USDT2USDC2ETH_direct_2toCommToC() tokenLogAndCheck3(USDT, ETH, MAX_USDT_IN, false, false, false, 2, _MODE_DIRECT) public {
        _execSwapWithComm(_genUSDT2USDC2ETHExactOutData(_MODE_DIRECT), _generateMultipleCommissionData(false, ETH, false, 2));
    }
    function test_v3ExactOut_USDT2USDC2ETH_direct_2toCommToB() tokenLogAndCheck3(USDT, ETH, MAX_USDT_IN, false, false, false, 2, _MODE_DIRECT) public {
        _execSwapWithComm(_genUSDT2USDC2ETHExactOutData(_MODE_DIRECT), _generateMultipleCommissionData(false, ETH, true, 2));
    }
    // 8 fromToken commission
    function test_v3ExactOut_USDT2USDC2ETH_direct_8fromCommToC() tokenLogAndCheck3(USDT, ETH, MAX_USDT_IN, false, false, true, 8, _MODE_DIRECT) public {
        _execSwapWithComm(_genUSDT2USDC2ETHExactOutData(_MODE_DIRECT), _generateMultipleCommissionData(true, USDT, false, 8));
    }
    function test_v3ExactOut_USDT2USDC2ETH_direct_8fromCommToB() tokenLogAndCheck3(USDT, ETH, MAX_USDT_IN, false, false, true, 8, _MODE_DIRECT) public {
        _execSwapWithComm(_genUSDT2USDC2ETHExactOutData(_MODE_DIRECT), _generateMultipleCommissionData(true, USDT, true, 8));
    }
    // 8 toToken commission
    function test_v3ExactOut_USDT2USDC2ETH_direct_8toCommToC() tokenLogAndCheck3(USDT, ETH, MAX_USDT_IN, false, false, false, 8, _MODE_DIRECT) public {
        _execSwapWithComm(_genUSDT2USDC2ETHExactOutData(_MODE_DIRECT), _generateMultipleCommissionData(false, ETH, false, 8));
    }
    function test_v3ExactOut_USDT2USDC2ETH_direct_8toCommToB() tokenLogAndCheck3(USDT, ETH, MAX_USDT_IN, false, false, false, 8, _MODE_DIRECT) public {
        _execSwapWithComm(_genUSDT2USDC2ETHExactOutData(_MODE_DIRECT), _generateMultipleCommissionData(false, ETH, true, 8));
    }

    // -------------------- Permit2 Signature Mode --------------------
    // noComm
    function test_v3ExactOut_USDT2USDC2ETH_permit2Sig_noComm() tokenLogAndCheck3(USDT, ETH, MAX_USDT_IN, false, false, false, 0, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2Sig(_genUSDT2USDC2ETHExactOutData(_MODE_PERMIT2_SIGNATURE), USDT, MAX_USDT_IN);
    }
    // 2 fromToken commission
    function test_v3ExactOut_USDT2USDC2ETH_permit2Sig_2fromCommToC() tokenLogAndCheck3(USDT, ETH, MAX_USDT_IN, false, false, true, 2, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigFromCommToC(_genUSDT2USDC2ETHExactOutData(_MODE_PERMIT2_SIGNATURE), USDT, MAX_USDT_IN, 2, _generateMultipleCommissionData(true, USDT, false, 2));
    }
    function test_v3ExactOut_USDT2USDC2ETH_permit2Sig_2fromCommToB() tokenLogAndCheck3(USDT, ETH, MAX_USDT_IN, false, false, true, 2, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigComm(_genUSDT2USDC2ETHExactOutData(_MODE_PERMIT2_SIGNATURE), USDT, MAX_USDT_IN, _generateMultipleCommissionData(true, USDT, true, 2));
    }
    // 2 toToken commission
    function test_v3ExactOut_USDT2USDC2ETH_permit2Sig_2toCommToC() tokenLogAndCheck3(USDT, ETH, MAX_USDT_IN, false, false, false, 2, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigComm(_genUSDT2USDC2ETHExactOutData(_MODE_PERMIT2_SIGNATURE), USDT, MAX_USDT_IN, _generateMultipleCommissionData(false, ETH, false, 2));
    }
    function test_v3ExactOut_USDT2USDC2ETH_permit2Sig_2toCommToB() tokenLogAndCheck3(USDT, ETH, MAX_USDT_IN, false, false, false, 2, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigComm(_genUSDT2USDC2ETHExactOutData(_MODE_PERMIT2_SIGNATURE), USDT, MAX_USDT_IN, _generateMultipleCommissionData(false, ETH, true, 2));
    }
    // 8 fromToken commission
    function test_v3ExactOut_USDT2USDC2ETH_permit2Sig_8fromCommToC() tokenLogAndCheck3(USDT, ETH, MAX_USDT_IN, false, false, true, 8, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigFromCommToC(_genUSDT2USDC2ETHExactOutData(_MODE_PERMIT2_SIGNATURE), USDT, MAX_USDT_IN, 8, _generateMultipleCommissionData(true, USDT, false, 8));
    }
    function test_v3ExactOut_USDT2USDC2ETH_permit2Sig_8fromCommToB() tokenLogAndCheck3(USDT, ETH, MAX_USDT_IN, false, false, true, 8, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigComm(_genUSDT2USDC2ETHExactOutData(_MODE_PERMIT2_SIGNATURE), USDT, MAX_USDT_IN, _generateMultipleCommissionData(true, USDT, true, 8));
    }
    // 8 toToken commission
    function test_v3ExactOut_USDT2USDC2ETH_permit2Sig_8toCommToC() tokenLogAndCheck3(USDT, ETH, MAX_USDT_IN, false, false, false, 8, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigComm(_genUSDT2USDC2ETHExactOutData(_MODE_PERMIT2_SIGNATURE), USDT, MAX_USDT_IN, _generateMultipleCommissionData(false, ETH, false, 8));
    }
    function test_v3ExactOut_USDT2USDC2ETH_permit2Sig_8toCommToB() tokenLogAndCheck3(USDT, ETH, MAX_USDT_IN, false, false, false, 8, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigComm(_genUSDT2USDC2ETHExactOutData(_MODE_PERMIT2_SIGNATURE), USDT, MAX_USDT_IN, _generateMultipleCommissionData(false, ETH, true, 8));
    }

    // -------------------- Permit2 Allowance Mode --------------------
    // noComm
    function test_v3ExactOut_USDT2USDC2ETH_permit2Allow_noComm() tokenLogAndCheck3(USDT, ETH, MAX_USDT_IN, false, false, false, 0, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwap(_genUSDT2USDC2ETHExactOutData(_MODE_PERMIT2_ALLOWANCE));
    }
    // 2 fromToken commission
    function test_v3ExactOut_USDT2USDC2ETH_permit2Allow_2fromCommToC() tokenLogAndCheck3(USDT, ETH, MAX_USDT_IN, false, false, true, 2, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithComm(_genUSDT2USDC2ETHExactOutData(_MODE_PERMIT2_ALLOWANCE), _generateMultipleCommissionData(true, USDT, false, 2));
    }
    function test_v3ExactOut_USDT2USDC2ETH_permit2Allow_2fromCommToB() tokenLogAndCheck3(USDT, ETH, MAX_USDT_IN, false, false, true, 2, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithComm(_genUSDT2USDC2ETHExactOutData(_MODE_PERMIT2_ALLOWANCE), _generateMultipleCommissionData(true, USDT, true, 2));
    }
    // 2 toToken commission
    function test_v3ExactOut_USDT2USDC2ETH_permit2Allow_2toCommToC() tokenLogAndCheck3(USDT, ETH, MAX_USDT_IN, false, false, false, 2, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithComm(_genUSDT2USDC2ETHExactOutData(_MODE_PERMIT2_ALLOWANCE), _generateMultipleCommissionData(false, ETH, false, 2));
    }
    function test_v3ExactOut_USDT2USDC2ETH_permit2Allow_2toCommToB() tokenLogAndCheck3(USDT, ETH, MAX_USDT_IN, false, false, false, 2, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithComm(_genUSDT2USDC2ETHExactOutData(_MODE_PERMIT2_ALLOWANCE), _generateMultipleCommissionData(false, ETH, true, 2));
    }
    // 8 fromToken commission
    function test_v3ExactOut_USDT2USDC2ETH_permit2Allow_8fromCommToC() tokenLogAndCheck3(USDT, ETH, MAX_USDT_IN, false, false, true, 8, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithComm(_genUSDT2USDC2ETHExactOutData(_MODE_PERMIT2_ALLOWANCE), _generateMultipleCommissionData(true, USDT, false, 8));
    }
    function test_v3ExactOut_USDT2USDC2ETH_permit2Allow_8fromCommToB() tokenLogAndCheck3(USDT, ETH, MAX_USDT_IN, false, false, true, 8, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithComm(_genUSDT2USDC2ETHExactOutData(_MODE_PERMIT2_ALLOWANCE), _generateMultipleCommissionData(true, USDT, true, 8));
    }
    // 8 toToken commission
    function test_v3ExactOut_USDT2USDC2ETH_permit2Allow_8toCommToC() tokenLogAndCheck3(USDT, ETH, MAX_USDT_IN, false, false, false, 8, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithComm(_genUSDT2USDC2ETHExactOutData(_MODE_PERMIT2_ALLOWANCE), _generateMultipleCommissionData(false, ETH, false, 8));
    }
    function test_v3ExactOut_USDT2USDC2ETH_permit2Allow_8toCommToB() tokenLogAndCheck3(USDT, ETH, MAX_USDT_IN, false, false, false, 8, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithComm(_genUSDT2USDC2ETHExactOutData(_MODE_PERMIT2_ALLOWANCE), _generateMultipleCommissionData(false, ETH, true, 8));
    }

    // ============================================================================
    // ETH -> USDT -> USDC (ETH -> ERC20 -> ERC20, ExactOut)
    // Note: ETH input doesn't use transferMode (transferMode is for ERC20 only)
    // ============================================================================
    
    // noComm
    function test_v3ExactOut_ETH2USDT2USDC_noComm() tokenLogAndCheck3(ETH, USDC, MAX_ETH_IN, false, false, false, 0, _MODE_LEGACY) public {
        _execSwapWithValue(_genETH2USDT2USDCExactOutData(), MAX_ETH_IN);
    }
    // 2 fromToken commission
    function test_v3ExactOut_ETH2USDT2USDC_2fromCommToC() tokenLogAndCheck3(ETH, USDC, MAX_ETH_IN, false, false, true, 2, _MODE_LEGACY) public {
        _execSwapWithValueComm(_genETH2USDT2USDCExactOutData(), MAX_ETH_IN, _generateMultipleCommissionData(true, ETH, false, 2));
    }
    function test_v3ExactOut_ETH2USDT2USDC_2fromCommToB() tokenLogAndCheck3(ETH, USDC, MAX_ETH_IN, false, false, true, 2, _MODE_LEGACY) public {
        _execSwapWithValueComm(_genETH2USDT2USDCExactOutData(), MAX_ETH_IN, _generateMultipleCommissionData(true, ETH, true, 2));
    }
    // 2 toToken commission
    function test_v3ExactOut_ETH2USDT2USDC_2toCommToC() tokenLogAndCheck3(ETH, USDC, MAX_ETH_IN, false, false, false, 2, _MODE_LEGACY) public {
        _execSwapWithValueComm(_genETH2USDT2USDCExactOutData(), MAX_ETH_IN, _generateMultipleCommissionData(false, USDC, false, 2));
    }
    function test_v3ExactOut_ETH2USDT2USDC_2toCommToB() tokenLogAndCheck3(ETH, USDC, MAX_ETH_IN, false, false, false, 2, _MODE_LEGACY) public {
        _execSwapWithValueComm(_genETH2USDT2USDCExactOutData(), MAX_ETH_IN, _generateMultipleCommissionData(false, USDC, true, 2));
    }
    // 8 fromToken commission
    function test_v3ExactOut_ETH2USDT2USDC_8fromCommToC() tokenLogAndCheck3(ETH, USDC, MAX_ETH_IN, false, false, true, 8, _MODE_LEGACY) public {
        _execSwapWithValueComm(_genETH2USDT2USDCExactOutData(), MAX_ETH_IN, _generateMultipleCommissionData(true, ETH, false, 8));
    }
    function test_v3ExactOut_ETH2USDT2USDC_8fromCommToB() tokenLogAndCheck3(ETH, USDC, MAX_ETH_IN, false, false, true, 8, _MODE_LEGACY) public {
        _execSwapWithValueComm(_genETH2USDT2USDCExactOutData(), MAX_ETH_IN, _generateMultipleCommissionData(true, ETH, true, 8));
    }
    // 8 toToken commission
    function test_v3ExactOut_ETH2USDT2USDC_8toCommToC() tokenLogAndCheck3(ETH, USDC, MAX_ETH_IN, false, false, false, 8, _MODE_LEGACY) public {
        _execSwapWithValueComm(_genETH2USDT2USDCExactOutData(), MAX_ETH_IN, _generateMultipleCommissionData(false, USDC, false, 8));
    }
    function test_v3ExactOut_ETH2USDT2USDC_8toCommToB() tokenLogAndCheck3(ETH, USDC, MAX_ETH_IN, false, false, false, 8, _MODE_LEGACY) public {
        _execSwapWithValueComm(_genETH2USDT2USDCExactOutData(), MAX_ETH_IN, _generateMultipleCommissionData(false, USDC, true, 8));
    }

    // ============================================================================
    // Internal Execution Helpers
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

    // Swap with value + commission
    function _execSwapWithValueComm(bytes memory swapData, uint256 value, bytes memory commData) internal {
        (bool success, ) = address(dexRouter).call{value: value}(bytes.concat(swapData, commData));
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

    // Permit2 signature + fromToken ToC commission (requires multiple amounts in permit2 signature)
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

    // ============================================================================
    // Swap Data Generation Functions
    // ============================================================================

    /// @notice WETH -> USDT -> USDC two-pool V3 exactOut swap
    /// @dev V3 ExactOut: specify output amount (USDC_OUT), calculate required input
    function _genWETH2USDT2USDCExactOutData(uint256 transferMode) internal view returns (bytes memory) {
        uint256 receiver = uint256(uint160(arnaud));
        // WETH -> USDT: token0 -> token1, oneForZero=false (zeroForOne)
        // USDT -> USDC: token1 -> token0, oneForZero=true
        uint256[] memory pools = _genV3PoolsDefault(
            WETH_USDT_UNIV3,    // pool1
            USDC_USDT_UNIV3,    // pool2
            false,               // pool1OneForZero: WETH(token0)->USDT(token1), zeroForOne
            true,                // pool2OneForZero: USDT(token1)->USDC(token0), oneForZero
            false,               // unwrapWeth: output is USDC, no unwrap
            transferMode
        );
        return abi.encodeWithSelector(
            DexRouter.uniswapV3SwapExactOutTo.selector,
            receiver,            // receiver
            USDC_OUT,            // amountOut (exact output)
            MAX_WETH_IN,         // maxConsume (slippage protection)
            pools
        );
    }

    /// @notice ETH -> USDT -> USDC two-pool V3 exactOut swap (ETH auto-wrapped to WETH)
    /// @dev ETH input doesn't use transferMode
    function _genETH2USDT2USDCExactOutData() internal view returns (bytes memory) {
        // receiver high bits store orderId, low bits are receiver address
        uint256 receiver = 123 << 160 | uint256(uint160(arnaud)); // orderId=123
        uint256[] memory pools = _genV3PoolsDefault(
            WETH_USDT_UNIV3,    // pool1
            USDC_USDT_UNIV3,    // pool2
            false,               // pool1OneForZero: WETH(token0)->USDT(token1), zeroForOne
            true,                // pool2OneForZero: USDT(token1)->USDC(token0), oneForZero
            false,               // unwrapWeth: output is USDC, no unwrap
            _MODE_LEGACY         // transferMode: ETH input only allows Legacy
        );
        return abi.encodeWithSelector(
            DexRouter.uniswapV3SwapExactOutTo.selector,
            receiver,            // receiver with orderId
            USDC_OUT,            // amountOut (exact output)
            MAX_ETH_IN,          // maxConsume (slippage protection)
            pools
        );
    }

    /// @notice USDT -> USDC -> ETH two-pool V3 exactOut swap (WETH unwrapped to ETH at the end)
    function _genUSDT2USDC2ETHExactOutData(uint256 transferMode) internal view returns (bytes memory) {
        uint256 receiver = uint256(uint160(arnaud));
        // USDT -> USDC: token1 -> token0, oneForZero=true
        // USDC -> WETH: token0 -> token1, oneForZero=false (zeroForOne), then unwrap to ETH
        uint256[] memory pools = _genV3PoolsDefault(
            USDC_USDT_UNIV3,    // pool1
            USDC_WETH_UNIV3,    // pool2
            true,                // pool1OneForZero: USDT(token1)->USDC(token0), oneForZero
            false,               // pool2OneForZero: USDC(token0)->WETH(token1), zeroForOne
            true,                // unwrapWeth: output WETH needs to be converted to ETH
            transferMode
        );
        return abi.encodeWithSelector(
            DexRouter.uniswapV3SwapExactOutTo.selector,
            receiver,            // receiver
            ETH_OUT,             // amountOut (exact output: 0.5 ETH)
            MAX_USDT_IN,         // maxConsume (slippage protection)
            pools
        );
    }

    /// @notice Generate a two-pool UniswapV3 swap route array for ExactOut
    /// @dev UniswapV3 pool encoding (uint256):
    ///      - bit255: ONE_FOR_ZERO_MASK (1<<255) - swap direction
    ///      - bit253: WETH_UNWRAP_MASK (1<<253) - last pool only, unwrap WETH to ETH
    ///      - bit251-249: TRANSFER_MODE - first pool only, transfer mode
    ///      - bit159-0: ADDRESS_MASK - pool address
    function _genV3Pools(
        address pool1,
        address pool2,
        bool pool1OneForZero,
        bool pool2OneForZero,
        bool unwrapWeth,
        uint256 transferMode
    ) internal pure returns (uint256[] memory pools) {
        pools = new uint256[](2);
        
        // First pool: includes transfer mode
        uint256 pool1Value = uint256(uint160(pool1));
        if (pool1OneForZero) pool1Value |= (1 << 255); // ONE_FOR_ZERO_MASK
        pool1Value |= transferMode;
        pools[0] = pool1Value;
        
        // Second pool: may include unwrap flag
        uint256 pool2Value = uint256(uint160(pool2));
        if (pool2OneForZero) pool2Value |= (1 << 255); // ONE_FOR_ZERO_MASK
        if (unwrapWeth) pool2Value |= (1 << 253);      // WETH_UNWRAP_MASK
        pools[1] = pool2Value;
        
        return pools;
    }
    
    /// @notice Simplified V3 pools generation method
    function _genV3PoolsDefault(
        address pool1,
        address pool2,
        bool pool1OneForZero,
        bool pool2OneForZero,
        bool unwrapWeth,
        uint256 transferMode
    ) internal pure returns (uint256[] memory) {
        return _genV3Pools(pool1, pool2, pool1OneForZero, pool2OneForZero, unwrapWeth, transferMode);
    }
}

