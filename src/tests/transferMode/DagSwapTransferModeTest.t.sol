// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../common/TrimAndCommissionTestBase.t.sol";
import "@dex/interfaces/permit2/IPermit2.sol";

/*
 * DagSwap method test cases - Complete cross-combination testing.
 * All swap cases use 2-hop DAG path (node0 -> node1 -> node2).
 *
 * Test Dimensions:
 * 1. Transfer Modes (5): Legacy / Direct / Permit2Signature / Permit2Allowance / ByInvest
 *    - ETH input only allows Legacy mode
 *    - ByInvest mode doesn't allow commission
 * 2. Swap Types (3): ERC20->ERC20->ERC20 / ERC20->ERC20->ETH / ETH->ERC20->ERC20
 * 3. Commission (5): None / 8 fromToken ToC / 8 fromToken ToB / 8 toToken ToC / 8 toToken ToB
 * 4. Trim (2): None / 2 trim (trim + charge)
 *
 * Total: 4 modes * 2 ERC20 types * 5 comm * 2 trim + 1 * 2 ERC20 types * 1 comm * 2 trim + 1 * 1 ETH type * 5 comm * 2 trim = 94 cases
 */

contract DagSwapTransferModeTest is TrimAndCommissionTestBase {
    // fromToken commission requires extra amount (swap amount + commission amount)
    uint256 constant twoEther = 2 * 10 ** 18;
    uint256 constant USDT_AMOUNT = 1000 * 10 ** 6;
    uint256 constant TWO_USDT_AMOUNT = 2000 * 10 ** 6;

    // ============================================================================
    // WETH -> USDT -> USDC (ERC20 -> ERC20 -> ERC20)
    // ============================================================================

    // -------------------- Legacy Mode --------------------
    // noTrim
    function test_dagSwap_WETH2USDT2USDC_legacy_noTrim_noComm() tokenLogAndCheck3(WETH, USDC, oneEther, false, false, false, 0, _MODE_LEGACY) public {
        _execSwap(_genWETH2USDT2USDCDagData(_MODE_LEGACY));
    }
    function test_dagSwap_WETH2USDT2USDC_legacy_noTrim_8fromCommToC() tokenLogAndCheck3(WETH, USDC, twoEther, false, false, true, 8, _MODE_LEGACY) public {
        _execSwapWithComm(_genWETH2USDT2USDCDagData(_MODE_LEGACY), _generateMultipleCommissionData(true, WETH, false, 8));
    }
    function test_dagSwap_WETH2USDT2USDC_legacy_noTrim_8fromCommToB() tokenLogAndCheck3(WETH, USDC, twoEther, false, false, true, 8, _MODE_LEGACY) public {
        _execSwapWithComm(_genWETH2USDT2USDCDagData(_MODE_LEGACY), _generateMultipleCommissionData(true, WETH, true, 8));
    }
    function test_dagSwap_WETH2USDT2USDC_legacy_noTrim_8toCommToC() tokenLogAndCheck3(WETH, USDC, oneEther, false, false, false, 8, _MODE_LEGACY) public {
        _execSwapWithComm(_genWETH2USDT2USDCDagData(_MODE_LEGACY), _generateMultipleCommissionData(false, USDC, false, 8));
    }
    function test_dagSwap_WETH2USDT2USDC_legacy_noTrim_8toCommToB() tokenLogAndCheck3(WETH, USDC, oneEther, false, false, false, 8, _MODE_LEGACY) public {
        _execSwapWithComm(_genWETH2USDT2USDCDagData(_MODE_LEGACY), _generateMultipleCommissionData(false, USDC, true, 8));
    }
    // 2trim
    function test_dagSwap_WETH2USDT2USDC_legacy_2trim_noComm() tokenLogAndCheck3(WETH, USDC, oneEther, true, true, false, 0, _MODE_LEGACY) public {
        _execSwapWithTrim(_genWETH2USDT2USDCDagData(_MODE_LEGACY), _generate2TrimData());
    }
    function test_dagSwap_WETH2USDT2USDC_legacy_2trim_8fromCommToC() tokenLogAndCheck3(WETH, USDC, twoEther, true, true, true, 8, _MODE_LEGACY) public {
        _execSwapWithTrimComm(_genWETH2USDT2USDCDagData(_MODE_LEGACY), _generate2TrimData(), _generateMultipleCommissionData(true, WETH, false, 8));
    }
    function test_dagSwap_WETH2USDT2USDC_legacy_2trim_8fromCommToB() tokenLogAndCheck3(WETH, USDC, twoEther, true, true, true, 8, _MODE_LEGACY) public {
        _execSwapWithTrimComm(_genWETH2USDT2USDCDagData(_MODE_LEGACY), _generate2TrimData(), _generateMultipleCommissionData(true, WETH, true, 8));
    }
    function test_dagSwap_WETH2USDT2USDC_legacy_2trim_8toCommToC() tokenLogAndCheck3(WETH, USDC, oneEther, true, true, false, 8, _MODE_LEGACY) public {
        _execSwapWithTrimComm(_genWETH2USDT2USDCDagData(_MODE_LEGACY), _generate2TrimData(), _generateMultipleCommissionData(false, USDC, false, 8));
    }
    function test_dagSwap_WETH2USDT2USDC_legacy_2trim_8toCommToB() tokenLogAndCheck3(WETH, USDC, oneEther, true, true, false, 8, _MODE_LEGACY) public {
        _execSwapWithTrimComm(_genWETH2USDT2USDCDagData(_MODE_LEGACY), _generate2TrimData(), _generateMultipleCommissionData(false, USDC, true, 8));
    }

    // -------------------- Direct Mode --------------------
    // noTrim
    function test_dagSwap_WETH2USDT2USDC_direct_noTrim_noComm() tokenLogAndCheck3(WETH, USDC, oneEther, false, false, false, 0, _MODE_DIRECT) public {
        _execSwap(_genWETH2USDT2USDCDagData(_MODE_DIRECT));
    }
    function test_dagSwap_WETH2USDT2USDC_direct_noTrim_8fromCommToC() tokenLogAndCheck3(WETH, USDC, twoEther, false, false, true, 8, _MODE_DIRECT) public {
        _execSwapWithComm(_genWETH2USDT2USDCDagData(_MODE_DIRECT), _generateMultipleCommissionData(true, WETH, false, 8));
    }
    function test_dagSwap_WETH2USDT2USDC_direct_noTrim_8fromCommToB() tokenLogAndCheck3(WETH, USDC, twoEther, false, false, true, 8, _MODE_DIRECT) public {
        _execSwapWithComm(_genWETH2USDT2USDCDagData(_MODE_DIRECT), _generateMultipleCommissionData(true, WETH, true, 8));
    }
    function test_dagSwap_WETH2USDT2USDC_direct_noTrim_8toCommToC() tokenLogAndCheck3(WETH, USDC, oneEther, false, false, false, 8, _MODE_DIRECT) public {
        _execSwapWithComm(_genWETH2USDT2USDCDagData(_MODE_DIRECT), _generateMultipleCommissionData(false, USDC, false, 8));
    }
    function test_dagSwap_WETH2USDT2USDC_direct_noTrim_8toCommToB() tokenLogAndCheck3(WETH, USDC, oneEther, false, false, false, 8, _MODE_DIRECT) public {
        _execSwapWithComm(_genWETH2USDT2USDCDagData(_MODE_DIRECT), _generateMultipleCommissionData(false, USDC, true, 8));
    }
    // 2trim
    function test_dagSwap_WETH2USDT2USDC_direct_2trim_noComm() tokenLogAndCheck3(WETH, USDC, oneEther, true, true, false, 0, _MODE_DIRECT) public {
        _execSwapWithTrim(_genWETH2USDT2USDCDagData(_MODE_DIRECT), _generate2TrimData());
    }
    function test_dagSwap_WETH2USDT2USDC_direct_2trim_8fromCommToC() tokenLogAndCheck3(WETH, USDC, twoEther, true, true, true, 8, _MODE_DIRECT) public {
        _execSwapWithTrimComm(_genWETH2USDT2USDCDagData(_MODE_DIRECT), _generate2TrimData(), _generateMultipleCommissionData(true, WETH, false, 8));
    }
    function test_dagSwap_WETH2USDT2USDC_direct_2trim_8fromCommToB() tokenLogAndCheck3(WETH, USDC, twoEther, true, true, true, 8, _MODE_DIRECT) public {
        _execSwapWithTrimComm(_genWETH2USDT2USDCDagData(_MODE_DIRECT), _generate2TrimData(), _generateMultipleCommissionData(true, WETH, true, 8));
    }
    function test_dagSwap_WETH2USDT2USDC_direct_2trim_8toCommToC() tokenLogAndCheck3(WETH, USDC, oneEther, true, true, false, 8, _MODE_DIRECT) public {
        _execSwapWithTrimComm(_genWETH2USDT2USDCDagData(_MODE_DIRECT), _generate2TrimData(), _generateMultipleCommissionData(false, USDC, false, 8));
    }
    function test_dagSwap_WETH2USDT2USDC_direct_2trim_8toCommToB() tokenLogAndCheck3(WETH, USDC, oneEther, true, true, false, 8, _MODE_DIRECT) public {
        _execSwapWithTrimComm(_genWETH2USDT2USDCDagData(_MODE_DIRECT), _generate2TrimData(), _generateMultipleCommissionData(false, USDC, true, 8));
    }

    // -------------------- Permit2 Signature Mode --------------------
    // noTrim
    function test_dagSwap_WETH2USDT2USDC_permit2Sig_noTrim_noComm() tokenLogAndCheck3(WETH, USDC, oneEther, false, false, false, 0, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2Sig(_genWETH2USDT2USDCDagData(_MODE_PERMIT2_SIGNATURE), WETH, oneEther);
    }
    function test_dagSwap_WETH2USDT2USDC_permit2Sig_noTrim_8fromCommToC() tokenLogAndCheck3(WETH, USDC, twoEther, false, false, true, 8, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigFromCommToC(_genWETH2USDT2USDCDagData(_MODE_PERMIT2_SIGNATURE), WETH, oneEther, 8, _generateMultipleCommissionData(true, WETH, false, 8));
    }
    function test_dagSwap_WETH2USDT2USDC_permit2Sig_noTrim_8fromCommToB() tokenLogAndCheck3(WETH, USDC, twoEther, false, false, true, 8, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigComm(_genWETH2USDT2USDCDagData(_MODE_PERMIT2_SIGNATURE), WETH, twoEther, _generateMultipleCommissionData(true, WETH, true, 8));
    }
    function test_dagSwap_WETH2USDT2USDC_permit2Sig_noTrim_8toCommToC() tokenLogAndCheck3(WETH, USDC, oneEther, false, false, false, 8, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigComm(_genWETH2USDT2USDCDagData(_MODE_PERMIT2_SIGNATURE), WETH, oneEther, _generateMultipleCommissionData(false, USDC, false, 8));
    }
    function test_dagSwap_WETH2USDT2USDC_permit2Sig_noTrim_8toCommToB() tokenLogAndCheck3(WETH, USDC, oneEther, false, false, false, 8, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigComm(_genWETH2USDT2USDCDagData(_MODE_PERMIT2_SIGNATURE), WETH, oneEther, _generateMultipleCommissionData(false, USDC, true, 8));
    }
    // 2trim
    function test_dagSwap_WETH2USDT2USDC_permit2Sig_2trim_noComm() tokenLogAndCheck3(WETH, USDC, oneEther, true, true, false, 0, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigTrim(_genWETH2USDT2USDCDagData(_MODE_PERMIT2_SIGNATURE), WETH, oneEther, _generate2TrimData());
    }
    function test_dagSwap_WETH2USDT2USDC_permit2Sig_2trim_8fromCommToC() tokenLogAndCheck3(WETH, USDC, twoEther, true, true, true, 8, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigTrimFromCommToC(_genWETH2USDT2USDCDagData(_MODE_PERMIT2_SIGNATURE), WETH, oneEther, 8, _generate2TrimData(), _generateMultipleCommissionData(true, WETH, false, 8));
    }
    function test_dagSwap_WETH2USDT2USDC_permit2Sig_2trim_8fromCommToB() tokenLogAndCheck3(WETH, USDC, twoEther, true, true, true, 8, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigTrimComm(_genWETH2USDT2USDCDagData(_MODE_PERMIT2_SIGNATURE), WETH, twoEther, _generate2TrimData(), _generateMultipleCommissionData(true, WETH, true, 8));
    }
    function test_dagSwap_WETH2USDT2USDC_permit2Sig_2trim_8toCommToC() tokenLogAndCheck3(WETH, USDC, oneEther, true, true, false, 8, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigTrimComm(_genWETH2USDT2USDCDagData(_MODE_PERMIT2_SIGNATURE), WETH, oneEther, _generate2TrimData(), _generateMultipleCommissionData(false, USDC, false, 8));
    }
    function test_dagSwap_WETH2USDT2USDC_permit2Sig_2trim_8toCommToB() tokenLogAndCheck3(WETH, USDC, oneEther, true, true, false, 8, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigTrimComm(_genWETH2USDT2USDCDagData(_MODE_PERMIT2_SIGNATURE), WETH, oneEther, _generate2TrimData(), _generateMultipleCommissionData(false, USDC, true, 8));
    }

    // -------------------- Permit2 Allowance Mode --------------------
    // noTrim
    function test_dagSwap_WETH2USDT2USDC_permit2Allow_noTrim_noComm() tokenLogAndCheck3(WETH, USDC, oneEther, false, false, false, 0, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwap(_genWETH2USDT2USDCDagData(_MODE_PERMIT2_ALLOWANCE));
    }
    function test_dagSwap_WETH2USDT2USDC_permit2Allow_noTrim_8fromCommToC() tokenLogAndCheck3(WETH, USDC, twoEther, false, false, true, 8, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithComm(_genWETH2USDT2USDCDagData(_MODE_PERMIT2_ALLOWANCE), _generateMultipleCommissionData(true, WETH, false, 8));
    }
    function test_dagSwap_WETH2USDT2USDC_permit2Allow_noTrim_8fromCommToB() tokenLogAndCheck3(WETH, USDC, twoEther, false, false, true, 8, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithComm(_genWETH2USDT2USDCDagData(_MODE_PERMIT2_ALLOWANCE), _generateMultipleCommissionData(true, WETH, true, 8));
    }
    function test_dagSwap_WETH2USDT2USDC_permit2Allow_noTrim_8toCommToC() tokenLogAndCheck3(WETH, USDC, oneEther, false, false, false, 8, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithComm(_genWETH2USDT2USDCDagData(_MODE_PERMIT2_ALLOWANCE), _generateMultipleCommissionData(false, USDC, false, 8));
    }
    function test_dagSwap_WETH2USDT2USDC_permit2Allow_noTrim_8toCommToB() tokenLogAndCheck3(WETH, USDC, oneEther, false, false, false, 8, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithComm(_genWETH2USDT2USDCDagData(_MODE_PERMIT2_ALLOWANCE), _generateMultipleCommissionData(false, USDC, true, 8));
    }
    // 2trim
    function test_dagSwap_WETH2USDT2USDC_permit2Allow_2trim_noComm() tokenLogAndCheck3(WETH, USDC, oneEther, true, true, false, 0, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithTrim(_genWETH2USDT2USDCDagData(_MODE_PERMIT2_ALLOWANCE), _generate2TrimData());
    }
    function test_dagSwap_WETH2USDT2USDC_permit2Allow_2trim_8fromCommToC() tokenLogAndCheck3(WETH, USDC, twoEther, true, true, true, 8, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithTrimComm(_genWETH2USDT2USDCDagData(_MODE_PERMIT2_ALLOWANCE), _generate2TrimData(), _generateMultipleCommissionData(true, WETH, false, 8));
    }
    function test_dagSwap_WETH2USDT2USDC_permit2Allow_2trim_8fromCommToB() tokenLogAndCheck3(WETH, USDC, twoEther, true, true, true, 8, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithTrimComm(_genWETH2USDT2USDCDagData(_MODE_PERMIT2_ALLOWANCE), _generate2TrimData(), _generateMultipleCommissionData(true, WETH, true, 8));
    }
    function test_dagSwap_WETH2USDT2USDC_permit2Allow_2trim_8toCommToC() tokenLogAndCheck3(WETH, USDC, oneEther, true, true, false, 8, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithTrimComm(_genWETH2USDT2USDCDagData(_MODE_PERMIT2_ALLOWANCE), _generate2TrimData(), _generateMultipleCommissionData(false, USDC, false, 8));
    }
    function test_dagSwap_WETH2USDT2USDC_permit2Allow_2trim_8toCommToB() tokenLogAndCheck3(WETH, USDC, oneEther, true, true, false, 8, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithTrimComm(_genWETH2USDT2USDCDagData(_MODE_PERMIT2_ALLOWANCE), _generate2TrimData(), _generateMultipleCommissionData(false, USDC, true, 8));
    }

    // -------------------- ByInvest Mode (no commission allowed) --------------------
    // noTrim
    function test_dagSwap_WETH2USDT2USDC_byInvest_noTrim_noComm() tokenLogAndCheck3(WETH, USDC, oneEther, false, false, false, 0, _MODE_BY_INVEST) public {
        IERC20(WETH).transfer(address(dexRouter), oneEther);
        _execSwap(_genWETH2USDT2USDCDagData(_MODE_BY_INVEST));
    }
    // 2trim
    function test_dagSwap_WETH2USDT2USDC_byInvest_2trim_noComm() tokenLogAndCheck3(WETH, USDC, oneEther, true, true, false, 0, _MODE_BY_INVEST) public {
        IERC20(WETH).transfer(address(dexRouter), oneEther);
        _execSwapWithTrim(_genWETH2USDT2USDCDagData(_MODE_BY_INVEST), _generate2TrimData());
    }

    // ============================================================================
    // USDT -> USDC -> ETH (ERC20 -> ERC20 -> ETH)
    // ============================================================================

    // -------------------- Legacy Mode --------------------
    // noTrim
    function test_dagSwap_USDT2USDC2ETH_legacy_noTrim_noComm() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, false, false, false, 0, _MODE_LEGACY) public {
        _execSwap(_genUSDT2USDC2ETHDagData(_MODE_LEGACY));
    }
    function test_dagSwap_USDT2USDC2ETH_legacy_noTrim_8fromCommToC() tokenLogAndCheck3(USDT, ETH, TWO_USDT_AMOUNT, false, false, true, 8, _MODE_LEGACY) public {
        _execSwapWithComm(_genUSDT2USDC2ETHDagData(_MODE_LEGACY), _generateMultipleCommissionData(true, USDT, false, 8));
    }
    function test_dagSwap_USDT2USDC2ETH_legacy_noTrim_8fromCommToB() tokenLogAndCheck3(USDT, ETH, TWO_USDT_AMOUNT, false, false, true, 8, _MODE_LEGACY) public {
        _execSwapWithComm(_genUSDT2USDC2ETHDagData(_MODE_LEGACY), _generateMultipleCommissionData(true, USDT, true, 8));
    }
    function test_dagSwap_USDT2USDC2ETH_legacy_noTrim_8toCommToC() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, false, false, false, 8, _MODE_LEGACY) public {
        _execSwapWithComm(_genUSDT2USDC2ETHDagData(_MODE_LEGACY), _generateMultipleCommissionData(false, ETH, false, 8));
    }
    function test_dagSwap_USDT2USDC2ETH_legacy_noTrim_8toCommToB() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, false, false, false, 8, _MODE_LEGACY) public {
        _execSwapWithComm(_genUSDT2USDC2ETHDagData(_MODE_LEGACY), _generateMultipleCommissionData(false, ETH, true, 8));
    }
    // 2trim
    function test_dagSwap_USDT2USDC2ETH_legacy_2trim_noComm() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, true, true, false, 0, _MODE_LEGACY) public {
        _execSwapWithTrim(_genUSDT2USDC2ETHDagData(_MODE_LEGACY), _generate2TrimData());
    }
    function test_dagSwap_USDT2USDC2ETH_legacy_2trim_8fromCommToC() tokenLogAndCheck3(USDT, ETH, TWO_USDT_AMOUNT, true, true, true, 8, _MODE_LEGACY) public {
        _execSwapWithTrimComm(_genUSDT2USDC2ETHDagData(_MODE_LEGACY), _generate2TrimData(), _generateMultipleCommissionData(true, USDT, false, 8));
    }
    function test_dagSwap_USDT2USDC2ETH_legacy_2trim_8fromCommToB() tokenLogAndCheck3(USDT, ETH, TWO_USDT_AMOUNT, true, true, true, 8, _MODE_LEGACY) public {
        _execSwapWithTrimComm(_genUSDT2USDC2ETHDagData(_MODE_LEGACY), _generate2TrimData(), _generateMultipleCommissionData(true, USDT, true, 8));
    }
    function test_dagSwap_USDT2USDC2ETH_legacy_2trim_8toCommToC() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, true, true, false, 8, _MODE_LEGACY) public {
        _execSwapWithTrimComm(_genUSDT2USDC2ETHDagData(_MODE_LEGACY), _generate2TrimData(), _generateMultipleCommissionData(false, ETH, false, 8));
    }
    function test_dagSwap_USDT2USDC2ETH_legacy_2trim_8toCommToB() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, true, true, false, 8, _MODE_LEGACY) public {
        _execSwapWithTrimComm(_genUSDT2USDC2ETHDagData(_MODE_LEGACY), _generate2TrimData(), _generateMultipleCommissionData(false, ETH, true, 8));
    }

    // -------------------- Direct Mode --------------------
    // noTrim
    function test_dagSwap_USDT2USDC2ETH_direct_noTrim_noComm() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, false, false, false, 0, _MODE_DIRECT) public {
        _execSwap(_genUSDT2USDC2ETHDagData(_MODE_DIRECT));
    }
    function test_dagSwap_USDT2USDC2ETH_direct_noTrim_8fromCommToC() tokenLogAndCheck3(USDT, ETH, TWO_USDT_AMOUNT, false, false, true, 8, _MODE_DIRECT) public {
        _execSwapWithComm(_genUSDT2USDC2ETHDagData(_MODE_DIRECT), _generateMultipleCommissionData(true, USDT, false, 8));
    }
    function test_dagSwap_USDT2USDC2ETH_direct_noTrim_8fromCommToB() tokenLogAndCheck3(USDT, ETH, TWO_USDT_AMOUNT, false, false, true, 8, _MODE_DIRECT) public {
        _execSwapWithComm(_genUSDT2USDC2ETHDagData(_MODE_DIRECT), _generateMultipleCommissionData(true, USDT, true, 8));
    }
    function test_dagSwap_USDT2USDC2ETH_direct_noTrim_8toCommToC() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, false, false, false, 8, _MODE_DIRECT) public {
        _execSwapWithComm(_genUSDT2USDC2ETHDagData(_MODE_DIRECT), _generateMultipleCommissionData(false, ETH, false, 8));
    }
    function test_dagSwap_USDT2USDC2ETH_direct_noTrim_8toCommToB() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, false, false, false, 8, _MODE_DIRECT) public {
        _execSwapWithComm(_genUSDT2USDC2ETHDagData(_MODE_DIRECT), _generateMultipleCommissionData(false, ETH, true, 8));
    }
    // 2trim
    function test_dagSwap_USDT2USDC2ETH_direct_2trim_noComm() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, true, true, false, 0, _MODE_DIRECT) public {
        _execSwapWithTrim(_genUSDT2USDC2ETHDagData(_MODE_DIRECT), _generate2TrimData());
    }
    function test_dagSwap_USDT2USDC2ETH_direct_2trim_8fromCommToC() tokenLogAndCheck3(USDT, ETH, TWO_USDT_AMOUNT, true, true, true, 8, _MODE_DIRECT) public {
        _execSwapWithTrimComm(_genUSDT2USDC2ETHDagData(_MODE_DIRECT), _generate2TrimData(), _generateMultipleCommissionData(true, USDT, false, 8));
    }
    function test_dagSwap_USDT2USDC2ETH_direct_2trim_8fromCommToB() tokenLogAndCheck3(USDT, ETH, TWO_USDT_AMOUNT, true, true, true, 8, _MODE_DIRECT) public {
        _execSwapWithTrimComm(_genUSDT2USDC2ETHDagData(_MODE_DIRECT), _generate2TrimData(), _generateMultipleCommissionData(true, USDT, true, 8));
    }
    function test_dagSwap_USDT2USDC2ETH_direct_2trim_8toCommToC() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, true, true, false, 8, _MODE_DIRECT) public {
        _execSwapWithTrimComm(_genUSDT2USDC2ETHDagData(_MODE_DIRECT), _generate2TrimData(), _generateMultipleCommissionData(false, ETH, false, 8));
    }
    function test_dagSwap_USDT2USDC2ETH_direct_2trim_8toCommToB() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, true, true, false, 8, _MODE_DIRECT) public {
        _execSwapWithTrimComm(_genUSDT2USDC2ETHDagData(_MODE_DIRECT), _generate2TrimData(), _generateMultipleCommissionData(false, ETH, true, 8));
    }

    // -------------------- Permit2 Signature Mode --------------------
    // noTrim
    function test_dagSwap_USDT2USDC2ETH_permit2Sig_noTrim_noComm() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, false, false, false, 0, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2Sig(_genUSDT2USDC2ETHDagData(_MODE_PERMIT2_SIGNATURE), USDT, USDT_AMOUNT);
    }
    function test_dagSwap_USDT2USDC2ETH_permit2Sig_noTrim_8fromCommToC() tokenLogAndCheck3(USDT, ETH, TWO_USDT_AMOUNT, false, false, true, 8, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigFromCommToC(_genUSDT2USDC2ETHDagData(_MODE_PERMIT2_SIGNATURE), USDT, USDT_AMOUNT, 8, _generateMultipleCommissionData(true, USDT, false, 8));
    }
    function test_dagSwap_USDT2USDC2ETH_permit2Sig_noTrim_8fromCommToB() tokenLogAndCheck3(USDT, ETH, TWO_USDT_AMOUNT, false, false, true, 8, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigComm(_genUSDT2USDC2ETHDagData(_MODE_PERMIT2_SIGNATURE), USDT, TWO_USDT_AMOUNT, _generateMultipleCommissionData(true, USDT, true, 8));
    }
    function test_dagSwap_USDT2USDC2ETH_permit2Sig_noTrim_8toCommToC() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, false, false, false, 8, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigComm(_genUSDT2USDC2ETHDagData(_MODE_PERMIT2_SIGNATURE), USDT, USDT_AMOUNT, _generateMultipleCommissionData(false, ETH, false, 8));
    }
    function test_dagSwap_USDT2USDC2ETH_permit2Sig_noTrim_8toCommToB() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, false, false, false, 8, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigComm(_genUSDT2USDC2ETHDagData(_MODE_PERMIT2_SIGNATURE), USDT, USDT_AMOUNT, _generateMultipleCommissionData(false, ETH, true, 8));
    }
    // 2trim
    function test_dagSwap_USDT2USDC2ETH_permit2Sig_2trim_noComm() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, true, true, false, 0, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigTrim(_genUSDT2USDC2ETHDagData(_MODE_PERMIT2_SIGNATURE), USDT, USDT_AMOUNT, _generate2TrimData());
    }
    function test_dagSwap_USDT2USDC2ETH_permit2Sig_2trim_8fromCommToC() tokenLogAndCheck3(USDT, ETH, TWO_USDT_AMOUNT, true, true, true, 8, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigTrimFromCommToC(_genUSDT2USDC2ETHDagData(_MODE_PERMIT2_SIGNATURE), USDT, USDT_AMOUNT, 8, _generate2TrimData(), _generateMultipleCommissionData(true, USDT, false, 8));
    }
    function test_dagSwap_USDT2USDC2ETH_permit2Sig_2trim_8fromCommToB() tokenLogAndCheck3(USDT, ETH, TWO_USDT_AMOUNT, true, true, true, 8, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigTrimComm(_genUSDT2USDC2ETHDagData(_MODE_PERMIT2_SIGNATURE), USDT, TWO_USDT_AMOUNT, _generate2TrimData(), _generateMultipleCommissionData(true, USDT, true, 8));
    }
    function test_dagSwap_USDT2USDC2ETH_permit2Sig_2trim_8toCommToC() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, true, true, false, 8, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigTrimComm(_genUSDT2USDC2ETHDagData(_MODE_PERMIT2_SIGNATURE), USDT, USDT_AMOUNT, _generate2TrimData(), _generateMultipleCommissionData(false, ETH, false, 8));
    }
    function test_dagSwap_USDT2USDC2ETH_permit2Sig_2trim_8toCommToB() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, true, true, false, 8, _MODE_PERMIT2_SIGNATURE) public {
        _execSwapWithPermit2SigTrimComm(_genUSDT2USDC2ETHDagData(_MODE_PERMIT2_SIGNATURE), USDT, USDT_AMOUNT, _generate2TrimData(), _generateMultipleCommissionData(false, ETH, true, 8));
    }

    // -------------------- Permit2 Allowance Mode --------------------
    // noTrim
    function test_dagSwap_USDT2USDC2ETH_permit2Allow_noTrim_noComm() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, false, false, false, 0, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwap(_genUSDT2USDC2ETHDagData(_MODE_PERMIT2_ALLOWANCE));
    }
    function test_dagSwap_USDT2USDC2ETH_permit2Allow_noTrim_8fromCommToC() tokenLogAndCheck3(USDT, ETH, TWO_USDT_AMOUNT, false, false, true, 8, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithComm(_genUSDT2USDC2ETHDagData(_MODE_PERMIT2_ALLOWANCE), _generateMultipleCommissionData(true, USDT, false, 8));
    }
    function test_dagSwap_USDT2USDC2ETH_permit2Allow_noTrim_8fromCommToB() tokenLogAndCheck3(USDT, ETH, TWO_USDT_AMOUNT, false, false, true, 8, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithComm(_genUSDT2USDC2ETHDagData(_MODE_PERMIT2_ALLOWANCE), _generateMultipleCommissionData(true, USDT, true, 8));
    }
    function test_dagSwap_USDT2USDC2ETH_permit2Allow_noTrim_8toCommToC() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, false, false, false, 8, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithComm(_genUSDT2USDC2ETHDagData(_MODE_PERMIT2_ALLOWANCE), _generateMultipleCommissionData(false, ETH, false, 8));
    }
    function test_dagSwap_USDT2USDC2ETH_permit2Allow_noTrim_8toCommToB() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, false, false, false, 8, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithComm(_genUSDT2USDC2ETHDagData(_MODE_PERMIT2_ALLOWANCE), _generateMultipleCommissionData(false, ETH, true, 8));
    }
    // 2trim
    function test_dagSwap_USDT2USDC2ETH_permit2Allow_2trim_noComm() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, true, true, false, 0, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithTrim(_genUSDT2USDC2ETHDagData(_MODE_PERMIT2_ALLOWANCE), _generate2TrimData());
    }
    function test_dagSwap_USDT2USDC2ETH_permit2Allow_2trim_8fromCommToC() tokenLogAndCheck3(USDT, ETH, TWO_USDT_AMOUNT, true, true, true, 8, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithTrimComm(_genUSDT2USDC2ETHDagData(_MODE_PERMIT2_ALLOWANCE), _generate2TrimData(), _generateMultipleCommissionData(true, USDT, false, 8));
    }
    function test_dagSwap_USDT2USDC2ETH_permit2Allow_2trim_8fromCommToB() tokenLogAndCheck3(USDT, ETH, TWO_USDT_AMOUNT, true, true, true, 8, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithTrimComm(_genUSDT2USDC2ETHDagData(_MODE_PERMIT2_ALLOWANCE), _generate2TrimData(), _generateMultipleCommissionData(true, USDT, true, 8));
    }
    function test_dagSwap_USDT2USDC2ETH_permit2Allow_2trim_8toCommToC() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, true, true, false, 8, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithTrimComm(_genUSDT2USDC2ETHDagData(_MODE_PERMIT2_ALLOWANCE), _generate2TrimData(), _generateMultipleCommissionData(false, ETH, false, 8));
    }
    function test_dagSwap_USDT2USDC2ETH_permit2Allow_2trim_8toCommToB() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, true, true, false, 8, _MODE_PERMIT2_ALLOWANCE) public {
        _execSwapWithTrimComm(_genUSDT2USDC2ETHDagData(_MODE_PERMIT2_ALLOWANCE), _generate2TrimData(), _generateMultipleCommissionData(false, ETH, true, 8));
    }

    // -------------------- ByInvest Mode (no commission allowed) --------------------
    // noTrim
    function test_dagSwap_USDT2USDC2ETH_byInvest_noTrim_noComm() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, false, false, false, 0, _MODE_BY_INVEST) public {
        SafeERC20.safeTransfer(IERC20(USDT), address(dexRouter), USDT_AMOUNT);
        _execSwap(_genUSDT2USDC2ETHDagData(_MODE_BY_INVEST));
    }
    // 2trim
    function test_dagSwap_USDT2USDC2ETH_byInvest_2trim_noComm() tokenLogAndCheck3(USDT, ETH, USDT_AMOUNT, true, true, false, 0, _MODE_BY_INVEST) public {
        SafeERC20.safeTransfer(IERC20(USDT), address(dexRouter), USDT_AMOUNT);
        _execSwapWithTrim(_genUSDT2USDC2ETHDagData(_MODE_BY_INVEST), _generate2TrimData());
    }

    // ============================================================================
    // ETH -> USDT -> USDC (ETH -> ERC20 -> ERC20)
    // Note: ETH input only allows Legacy mode (no transferMode encoding)
    // ============================================================================

    // noTrim
    function test_dagSwap_ETH2USDT2USDC_noTrim_noComm() tokenLogAndCheck3(ETH, USDC, oneEther, false, false, false, 0, _MODE_LEGACY) public {
        _execSwapWithValue(_genETH2USDT2USDCDagData(), oneEther);
    }
    function test_dagSwap_ETH2USDT2USDC_noTrim_8fromCommToC() tokenLogAndCheck3(ETH, USDC, twoEther, false, false, true, 8, _MODE_LEGACY) public {
        _execSwapWithValueComm(_genETH2USDT2USDCDagData(), twoEther, _generateMultipleCommissionData(true, ETH, false, 8));
    }
    function test_dagSwap_ETH2USDT2USDC_noTrim_8fromCommToB() tokenLogAndCheck3(ETH, USDC, twoEther, false, false, true, 8, _MODE_LEGACY) public {
        _execSwapWithValueComm(_genETH2USDT2USDCDagData(), twoEther, _generateMultipleCommissionData(true, ETH, true, 8));
    }
    function test_dagSwap_ETH2USDT2USDC_noTrim_8toCommToC() tokenLogAndCheck3(ETH, USDC, oneEther, false, false, false, 8, _MODE_LEGACY) public {
        _execSwapWithValueComm(_genETH2USDT2USDCDagData(), oneEther, _generateMultipleCommissionData(false, USDC, false, 8));
    }
    function test_dagSwap_ETH2USDT2USDC_noTrim_8toCommToB() tokenLogAndCheck3(ETH, USDC, oneEther, false, false, false, 8, _MODE_LEGACY) public {
        _execSwapWithValueComm(_genETH2USDT2USDCDagData(), oneEther, _generateMultipleCommissionData(false, USDC, true, 8));
    }
    // 2trim
    function test_dagSwap_ETH2USDT2USDC_2trim_noComm() tokenLogAndCheck3(ETH, USDC, oneEther, true, true, false, 0, _MODE_LEGACY) public {
        _execSwapWithValueTrim(_genETH2USDT2USDCDagData(), oneEther, _generate2TrimData());
    }
    function test_dagSwap_ETH2USDT2USDC_2trim_8fromCommToC() tokenLogAndCheck3(ETH, USDC, twoEther, true, true, true, 8, _MODE_LEGACY) public {
        _execSwapWithValueTrimComm(_genETH2USDT2USDCDagData(), twoEther, _generate2TrimData(), _generateMultipleCommissionData(true, ETH, false, 8));
    }
    function test_dagSwap_ETH2USDT2USDC_2trim_8fromCommToB() tokenLogAndCheck3(ETH, USDC, twoEther, true, true, true, 8, _MODE_LEGACY) public {
        _execSwapWithValueTrimComm(_genETH2USDT2USDCDagData(), twoEther, _generate2TrimData(), _generateMultipleCommissionData(true, ETH, true, 8));
    }
    function test_dagSwap_ETH2USDT2USDC_2trim_8toCommToC() tokenLogAndCheck3(ETH, USDC, oneEther, true, true, false, 8, _MODE_LEGACY) public {
        _execSwapWithValueTrimComm(_genETH2USDT2USDCDagData(), oneEther, _generate2TrimData(), _generateMultipleCommissionData(false, USDC, false, 8));
    }
    function test_dagSwap_ETH2USDT2USDC_2trim_8toCommToB() tokenLogAndCheck3(ETH, USDC, oneEther, true, true, false, 8, _MODE_LEGACY) public {
        _execSwapWithValueTrimComm(_genETH2USDT2USDCDagData(), oneEther, _generate2TrimData(), _generateMultipleCommissionData(false, USDC, true, 8));
    }

    // ============================================================================
    // Internal Execution Helpers
    // ============================================================================

    function _execSwap(bytes memory swapData) internal {
        (bool success, ) = address(dexRouter).call(swapData);
        require(success, "swap failed");
    }

    function _execSwapWithValue(bytes memory swapData, uint256 value) internal {
        (bool success, ) = address(dexRouter).call{value: value}(swapData);
        require(success, "swap failed");
    }

    function _execSwapWithComm(bytes memory swapData, bytes memory commData) internal {
        (bool success, ) = address(dexRouter).call(bytes.concat(swapData, commData));
        require(success, "swap failed");
    }

    function _execSwapWithTrim(bytes memory swapData, bytes memory trimData) internal {
        (bool success, ) = address(dexRouter).call(bytes.concat(swapData, trimData));
        require(success, "swap failed");
    }

    function _execSwapWithTrimComm(bytes memory swapData, bytes memory trimData, bytes memory commData) internal {
        (bool success, ) = address(dexRouter).call(bytes.concat(swapData, trimData, commData));
        require(success, "swap failed");
    }

    function _execSwapWithValueComm(bytes memory swapData, uint256 value, bytes memory commData) internal {
        (bool success, ) = address(dexRouter).call{value: value}(bytes.concat(swapData, commData));
        require(success, "swap failed");
    }

    function _execSwapWithValueTrim(bytes memory swapData, uint256 value, bytes memory trimData) internal {
        (bool success, ) = address(dexRouter).call{value: value}(bytes.concat(swapData, trimData));
        require(success, "swap failed");
    }

    function _execSwapWithValueTrimComm(bytes memory swapData, uint256 value, bytes memory trimData, bytes memory commData) internal {
        (bool success, ) = address(dexRouter).call{value: value}(bytes.concat(swapData, trimData, commData));
        require(success, "swap failed");
    }

    function _execSwapWithPermit2Sig(bytes memory swapData, address token, uint256 amount) internal {
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        bytes memory permit2Info = _generatePermit2Info(token, amounts);
        (bool success, ) = address(dexRouter).call(bytes.concat(swapData, permit2Info));
        require(success, "swap failed");
    }

    function _execSwapWithPermit2SigComm(bytes memory swapData, address token, uint256 amount, bytes memory commData) internal {
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        bytes memory permit2Info = _generatePermit2Info(token, amounts);
        (bool success, ) = address(dexRouter).call(bytes.concat(swapData, permit2Info, commData));
        require(success, "swap failed");
    }

    function _execSwapWithPermit2SigTrim(bytes memory swapData, address token, uint256 amount, bytes memory trimData) internal {
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        bytes memory permit2Info = _generatePermit2Info(token, amounts);
        (bool success, ) = address(dexRouter).call(bytes.concat(swapData, permit2Info, trimData));
        require(success, "swap failed");
    }

    function _execSwapWithPermit2SigTrimComm(bytes memory swapData, address token, uint256 amount, bytes memory trimData, bytes memory commData) internal {
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        bytes memory permit2Info = _generatePermit2Info(token, amounts);
        (bool success, ) = address(dexRouter).call(bytes.concat(swapData, permit2Info, trimData, commData));
        require(success, "swap failed");
    }

    // Permit2 signature + fromToken ToC commission (requires multiple amounts in permit2 signature)
    function _execSwapWithPermit2SigFromCommToC(bytes memory swapData, address token, uint256 swapAmount, uint256 commCount, bytes memory commData) internal {
        uint256[] memory amounts = new uint256[](commCount + 1);
        amounts[0] = swapAmount;
        uint256 commAmountEach = swapAmount / 10; // 10% per commission
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
        uint256 commAmountEach = swapAmount / 10; // 10% per commission
        for (uint256 i = 0; i < commCount; i++) {
            amounts[i + 1] = commAmountEach;
        }
        bytes memory permit2Info = _generatePermit2Info(token, amounts);
        (bool success, ) = address(dexRouter).call(bytes.concat(swapData, permit2Info, trimData, commData));
        require(success, "swap failed");
    }

    // ============================================================================
    // DAG Swap Data Generation Functions
    // ============================================================================

    /// @notice WETH -> USDT -> USDC two-hop DAG swap
    /// @dev DAG path: node0(WETH) -> node1(USDT) -> node2(USDC)
    function _genWETH2USDT2USDCDagData(uint256 mode) internal view returns (bytes memory) {
        DexRouter.BaseRequest memory baseRequest = _generateBaseRequest(WETH, USDC, oneEther);
        DexRouter.RouterPath[] memory paths = _buildTwoHopDagPaths(
            WETH,                    // node0 token
            USDT,                    // node1 token (intermediate)
            WETH_USDT_UNIV3,         // pool0: WETH->USDT
            USDC_USDT_UNIV3,         // pool1: USDT->USDC
            false,                   // pool0 reverse: WETH(token0)->USDT(token1)
            true,                    // pool1 reverse: USDT(token1)->USDC(token0)
            mode
        );
        return abi.encodeWithSelector(DexRouter.dagSwapTo.selector, 0, arnaud, baseRequest, paths);
    }

    /// @notice ETH -> USDT -> USDC two-hop DAG swap (ETH auto-wrapped to WETH)
    /// @dev ETH input only allows Legacy mode
    function _genETH2USDT2USDCDagData() internal view returns (bytes memory) {
        DexRouter.BaseRequest memory baseRequest = _generateBaseRequest(ETH, USDC, oneEther);
        DexRouter.RouterPath[] memory paths = _buildTwoHopDagPaths(
            WETH,                    // node0 token (ETH becomes WETH)
            USDT,                    // node1 token (intermediate)
            WETH_USDT_UNIV3,         // pool0: WETH->USDT
            USDC_USDT_UNIV3,         // pool1: USDT->USDC
            false,                   // pool0 reverse: WETH(token0)->USDT(token1)
            true,                    // pool1 reverse: USDT(token1)->USDC(token0)
            _MODE_LEGACY             // ETH input only allows Legacy
        );
        return abi.encodeWithSelector(DexRouter.dagSwapTo.selector, 0, arnaud, baseRequest, paths);
    }

    /// @notice USDT -> USDC -> ETH two-hop DAG swap (WETH unwrapped to ETH at the end)
    function _genUSDT2USDC2ETHDagData(uint256 mode) internal view returns (bytes memory) {
        DexRouter.BaseRequest memory baseRequest = _generateBaseRequest(USDT, ETH, USDT_AMOUNT);
        DexRouter.RouterPath[] memory paths = _buildTwoHopDagPaths(
            USDT,                    // node0 token
            USDC,                    // node1 token (intermediate)
            USDC_USDT_UNIV3,         // pool0: USDT->USDC
            USDC_WETH_UNIV3,         // pool1: USDC->WETH
            true,                    // pool0 reverse: USDT(token1)->USDC(token0)
            false,                   // pool1 reverse: USDC(token0)->WETH(token1)
            mode
        );
        return abi.encodeWithSelector(DexRouter.dagSwapTo.selector, 0, arnaud, baseRequest, paths);
    }

    /// @notice Build a two-hop DAG path (node0 -> node1 -> node2)
    /// @dev DAG rawData encoding: [8bits inputIndex][8bits outputIndex][72bits weight][160bits poolAddress]
    function _buildTwoHopDagPaths(
        address node0Token,
        address node1Token,
        address pool0,
        address pool1,
        bool pool0Reverse,
        bool pool1Reverse,
        uint256 mode
    ) internal view returns (DexRouter.RouterPath[] memory paths) {
        paths = new DexRouter.RouterPath[](2);
        
        // Node 0: node0Token -> node1Token
        paths[0] = _buildDagNode(
            node0Token,
            pool0,
            pool0Reverse,
            0,      // inputIndex = 0 (this is node 0)
            1,      // outputIndex = 1 (output to node 1)
            mode
        );
        
        // Node 1: node1Token -> finalToken (to node2/receiver)
        paths[1] = _buildDagNode(
            node1Token,
            pool1,
            pool1Reverse,
            1,      // inputIndex = 1 (this is node 1)
            2,      // outputIndex = 2 (output to final receiver)
            0       // no mode for intermediate nodes
        );
        
        return paths;
    }

    /// @notice Build a single DAG node
    /// @dev rawData encoding for DAG:
    ///      bit[0-159]: poolAddress (160 bits)
    ///      bit[160-175]: weight (16 bits, 10000 = 100%)
    ///      bit[176-183]: outputIndex (8 bits)
    ///      bit[184-191]: inputIndex (8 bits)
    ///      bit[255]: reverse flag
    function _buildDagNode(
        address fromToken,
        address pool,
        bool reverse,
        uint256 inputIndex,
        uint256 outputIndex,
        uint256 mode
    ) internal view returns (DexRouter.RouterPath memory path) {
        path.mixAdapters = new address[](1);
        path.mixAdapters[0] = UniversalUniV3Adapter;
        
        path.assetTo = new address[](1);
        path.assetTo[0] = UniversalUniV3Adapter;
        
        path.rawData = new uint256[](1);
        // DAG rawData encoding
        uint256 rawData = uint256(uint160(pool));
        rawData |= uint256(10000) << 160;           // weight = 10000 (100%)
        rawData |= uint256(outputIndex) << 176;     // outputIndex at bit[176-183]
        rawData |= uint256(inputIndex) << 184;      // inputIndex at bit[184-191]
        if (reverse) rawData |= uint256(0x80) << 248;  // reverse flag at highest byte
        path.rawData[0] = rawData;
        
        path.extraData = new bytes[](1);
        // extraData for UniV3 adapter: (direction, (token0, token1, fee))
        (address token0, address token1) = _getPoolTokens(pool);
        path.extraData[0] = reverse ? abi.encode(0, abi.encode(token1, token0, 0)) : abi.encode(0, abi.encode(token0, token1, 0));
        
        path.fromToken = uint256(uint160(fromToken)) | mode;
        
        return path;
    }

    /// @notice Get token0 and token1 from pool (sorted by address)
    function _getPoolTokens(address pool) internal view returns (address token0, address token1) {
        if (pool == WETH_USDT_UNIV3) {
            return (WETH, USDT); // WETH < USDT by address
        } else if (pool == USDC_USDT_UNIV3) {
            return (USDC, USDT); // USDC < USDT by address
        } else if (pool == USDC_WETH_UNIV3) {
            return (USDC, WETH); // USDC < WETH by address
        }
        revert("unknown pool");
    }
}

