// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../common/TrimAndCommissionTestBase.t.sol";
import "@dex/interfaces/IPermit2.sol";

/*
 * SmartSwap Permit2 & Commission Test Matrix:
 * 
 * Swap Types:
 *     (1) ERC20 -> ETH (WETH -> ETH)
 *     (2) ERC20 -> ERC20 (WETH -> USDT)
 *     (3) ETH -> ERC20 (ETH -> USDT)
 * 
 * Transfer Modes:
 *     (1) Legacy mode (_MODE_LEGACY)
 *     (2) Permit2 signature mode (_MODE_PERMIT2_SIGNATURE)
 * 
 * Commission Count:
 *     (0) No commission
 *     (1) 1 referrer
 *     (2) 2 referrers
 *     (3) 3 referrers
 * 
 * Trim:
 *     (0) No trim
 *     (2) Dual trim (trim + charge)
 * 
 * Batches & AssetTo:
 *     (1) Single batch with single assetTo
 *     (2) Single batch with 2 assetTos (split routing)
 */

contract SmartSwapPermit2Test is TrimAndCommissionTestBase {
    uint256 public arnaudPrivateKey = 11111111111111111111;

    // ==================== ERC20 -> ERC20 (WETH -> USDT) Tests ====================
    
    // --- Legacy Mode ---
    // Commission: 0, Trim: 0, Batches: 1
    function test_WETH2USDT_legacy_0commission_0trim_1batch() 
        tokenLogAndCheck3(WETH, USDT, 1 * 10 ** 18, false, false, false, 0, _MODE_LEGACY) public {
        bytes memory swapData = _generateWETH2USDTSmartSwapData(_MODE_LEGACY);
        (bool success, ) = address(dexRouter).call(swapData);
        require(success, "call failed");
    }

    // Commission: 1, Trim: 0, Batches: 1
    function test_WETH2USDT_legacy_1commission_0trim_1batch() 
        tokenLogAndCheck3(WETH, USDT, 2 * 10 ** 18, false, false, true, 1, _MODE_LEGACY) public {
        bytes memory swapData = _generateWETH2USDTSmartSwapData(_MODE_LEGACY);
        bytes memory commissionData = _generate1CommissionData(true, WETH);
        bytes memory data = bytes.concat(swapData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // Commission: 2, Trim: 0, Batches: 1
    function test_WETH2USDT_legacy_2commission_0trim_1batch() 
        tokenLogAndCheck3(WETH, USDT, 2 * 10 ** 18, false, false, true, 2, _MODE_LEGACY) public {
        bytes memory swapData = _generateWETH2USDTSmartSwapData(_MODE_LEGACY);
        bytes memory commissionData = _generate2CommissionData(true, WETH);
        bytes memory data = bytes.concat(swapData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // Commission: 3, Trim: 0, Batches: 1
    function test_WETH2USDT_legacy_3commission_0trim_1batch() 
        tokenLogAndCheck3(WETH, USDT, 2 * 10 ** 18, false, false, true, 3, _MODE_LEGACY) public {
        bytes memory swapData = _generateWETH2USDTSmartSwapData(_MODE_LEGACY);
        bytes memory commissionData = _generateMultipleCommissionData(true, WETH, false, 3);
        bytes memory data = bytes.concat(swapData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // Commission: 3, Trim: 2, Batches: 1
    function test_WETH2USDT_legacy_3commission_2trim_1batch() 
        tokenLogAndCheck3(WETH, USDT, 2 * 10 ** 18, true, true, true, 3, _MODE_LEGACY) public {
        bytes memory swapData = _generateWETH2USDTSmartSwapData(_MODE_LEGACY);
        bytes memory trimData = _generate2TrimData();
        bytes memory commissionData = _generateMultipleCommissionData(true, WETH, false, 3);
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // Commission: 0, Trim: 2, Batches: 1
    function test_WETH2USDT_legacy_0commission_2trim_1batch() 
        tokenLogAndCheck3(WETH, USDT, 1 * 10 ** 18, true, true, false, 0, _MODE_LEGACY) public {
        bytes memory swapData = _generateWETH2USDTSmartSwapData(_MODE_LEGACY);
        bytes memory trimData = _generate2TrimData();
        bytes memory data = bytes.concat(swapData, trimData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // Commission: 3, Trim: 0, Batches: 2
    function test_WETH2USDT_legacy_3commission_0trim_2batch() 
        tokenLogAndCheck3(WETH, USDT, 2 * 10 ** 18, false, false, true, 3, _MODE_LEGACY) public {
        bytes memory swapData = _generateWETH2USDTSmartSwapDataMultiAssetTo(_MODE_LEGACY);
        bytes memory commissionData = _generateMultipleCommissionData(true, WETH, false, 3);
        bytes memory data = bytes.concat(swapData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // Commission: 3, Trim: 2, Batches: 2
    function test_WETH2USDT_legacy_3commission_2trim_2batch() 
        tokenLogAndCheck3(WETH, USDT, 2 * 10 ** 18, true, true, true, 3, _MODE_LEGACY) public {
        bytes memory swapData = _generateWETH2USDTSmartSwapDataMultiAssetTo(_MODE_LEGACY);
        bytes memory trimData = _generate2TrimData();
        bytes memory commissionData = _generateMultipleCommissionData(true, WETH, false, 3);
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // --- Permit2 Signature Mode ---
    // Commission: 0, Trim: 0, Batches: 1
    function test_WETH2USDT_permit2_0commission_0trim_1batch() 
        tokenLogAndCheck3(WETH, USDT, 1 * 10 ** 18, false, false, false, 0, _MODE_PERMIT2_SIGNATURE) public {
        bytes memory swapData = _generateWETH2USDTSmartSwapData(_MODE_PERMIT2_SIGNATURE);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1 * 10 ** 18;
        bytes memory permit2Info = _generatePermit2Info(WETH, amounts);
        bytes memory data = bytes.concat(swapData, permit2Info);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // Commission: 1, Trim: 0, Batches: 1
    function test_WETH2USDT_permit2_1commission_0trim_1batch() 
        tokenLogAndCheck3(WETH, USDT, 2 * 10 ** 18, false, false, true, 1, _MODE_PERMIT2_SIGNATURE) public {
        bytes memory swapData = _generateWETH2USDTSmartSwapData(_MODE_PERMIT2_SIGNATURE);
        bytes memory commissionData = _generate1CommissionData(true, WETH);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 2 * 10 ** 18;
        amounts[1] = 1 * 10 ** 18;
        bytes memory permit2Info = _generatePermit2Info(WETH, amounts);
        bytes memory data = bytes.concat(swapData, permit2Info, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // Commission: 2, Trim: 0, Batches: 1
    function test_WETH2USDT_permit2_2commission_0trim_1batch() 
        tokenLogAndCheck3(WETH, USDT, 2 * 10 ** 18, false, false, true, 2, _MODE_PERMIT2_SIGNATURE) public {
        bytes memory swapData = _generateWETH2USDTSmartSwapData(_MODE_PERMIT2_SIGNATURE);
        bytes memory commissionData = _generate2CommissionData(true, WETH);
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 2 * 10 ** 18;
        amounts[1] = 1 * 10 ** 18;
        amounts[2] = 1 * 10 ** 18;
        bytes memory permit2Info = _generatePermit2Info(WETH, amounts);
        bytes memory data = bytes.concat(swapData, permit2Info, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // Commission: 3, Trim: 0, Batches: 1
    function test_WETH2USDT_permit2_3commission_0trim_1batch() 
        tokenLogAndCheck3(WETH, USDT, 2 * 10 ** 18, false, false, true, 3, _MODE_PERMIT2_SIGNATURE) public {
        bytes memory swapData = _generateWETH2USDTSmartSwapData(_MODE_PERMIT2_SIGNATURE);
        bytes memory commissionData = _generateMultipleCommissionData(true, WETH, false, 3);
        uint256[] memory amounts = new uint256[](4);
        amounts[0] = 2 * 10 ** 18;
        amounts[1] = 1 * 10 ** 18;
        amounts[2] = 1 * 10 ** 18;
        amounts[3] = 1 * 10 ** 18;
        bytes memory permit2Info = _generatePermit2Info(WETH, amounts);
        bytes memory data = bytes.concat(swapData, permit2Info, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // Commission: 3, Trim: 2, Batches: 1
    function test_WETH2USDT_permit2_3commission_2trim_1batch() 
        tokenLogAndCheck3(WETH, USDT, 2 * 10 ** 18, true, true, true, 3, _MODE_PERMIT2_SIGNATURE) public {
        bytes memory swapData = _generateWETH2USDTSmartSwapData(_MODE_PERMIT2_SIGNATURE);
        bytes memory trimData = _generate2TrimData();
        bytes memory commissionData = _generateMultipleCommissionData(true, WETH, false, 3);
        uint256[] memory amounts = new uint256[](4);
        amounts[0] = 2 * 10 ** 18;
        amounts[1] = 1 * 10 ** 18;
        amounts[2] = 1 * 10 ** 18;
        amounts[3] = 1 * 10 ** 18;
        bytes memory permit2Info = _generatePermit2Info(WETH, amounts);
        bytes memory data = bytes.concat(swapData, permit2Info, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // Commission: 0, Trim: 2, Batches: 1
    function test_WETH2USDT_permit2_0commission_2trim_1batch() 
        tokenLogAndCheck3(WETH, USDT, 1 * 10 ** 18, true, true, false, 0, _MODE_PERMIT2_SIGNATURE) public {
        bytes memory swapData = _generateWETH2USDTSmartSwapData(_MODE_PERMIT2_SIGNATURE);
        bytes memory trimData = _generate2TrimData();
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1 * 10 ** 18;
        bytes memory permit2Info = _generatePermit2Info(WETH, amounts);
        bytes memory data = bytes.concat(swapData, permit2Info, trimData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // Commission: 3, Trim: 0, Batches: 2
    function test_WETH2USDT_permit2_3commission_0trim_2batch() 
        tokenLogAndCheck3(WETH, USDT, 2 * 10 ** 18, false, false, true, 3, _MODE_PERMIT2_SIGNATURE) public {
        bytes memory swapData = _generateWETH2USDTSmartSwapDataMultiAssetTo(_MODE_PERMIT2_SIGNATURE);
        bytes memory commissionData = _generateMultipleCommissionData(true, WETH, false, 3);
        uint256[] memory amounts = new uint256[](4);
        amounts[0] = 2 * 10 ** 18;
        amounts[1] = 1 * 10 ** 18;
        amounts[2] = 1 * 10 ** 18;
        amounts[3] = 1 * 10 ** 18;
        bytes memory permit2Info = _generatePermit2Info(WETH, amounts);
        bytes memory data = bytes.concat(swapData, permit2Info, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // Commission: 3, Trim: 2, Batches: 2
    function test_WETH2USDT_permit2_3commission_2trim_2batch() 
        tokenLogAndCheck3(WETH, USDT, 2 * 10 ** 18, true, true, true, 3, _MODE_PERMIT2_SIGNATURE) public {
        bytes memory swapData = _generateWETH2USDTSmartSwapDataMultiAssetTo(_MODE_PERMIT2_SIGNATURE);
        bytes memory trimData = _generate2TrimData();
        bytes memory commissionData = _generateMultipleCommissionData(true, WETH, false, 3);
        uint256[] memory amounts = new uint256[](4);
        amounts[0] = 2 * 10 ** 18;
        amounts[1] = 1 * 10 ** 18;
        amounts[2] = 1 * 10 ** 18;
        amounts[3] = 1 * 10 ** 18;
        bytes memory permit2Info = _generatePermit2Info(WETH, amounts);
        bytes memory data = bytes.concat(swapData, permit2Info, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // ==================== ERC20 -> ETH (USDT -> ETH) Tests ====================
    
    // --- Legacy Mode ---
    // Commission: 0, Trim: 0, Batches: 1
    function test_USDT2ETH_legacy_0commission_0trim_1batch() 
        tokenLogAndCheck3(USDT, ETH, 1000 * 10 ** 6, false, false, false, 0, _MODE_LEGACY) public {
        bytes memory swapData = _generateUSDT2ETHSmartSwapData(_MODE_LEGACY);
        (bool success, ) = address(dexRouter).call(swapData);
        require(success, "call failed");
    }

    // Commission: 1, Trim: 0, Batches: 1
    function test_USDT2ETH_legacy_1commission_0trim_1batch() 
        tokenLogAndCheck3(USDT, ETH, 2000 * 10 ** 6, false, false, true, 1, _MODE_LEGACY) public {
        bytes memory swapData = _generateUSDT2ETHSmartSwapData(_MODE_LEGACY);
        bytes memory commissionData = _generate1CommissionData(true, USDT);
        bytes memory data = bytes.concat(swapData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // Commission: 2, Trim: 0, Batches: 1
    function test_USDT2ETH_legacy_2commission_0trim_1batch() 
        tokenLogAndCheck3(USDT, ETH, 2000 * 10 ** 6, false, false, true, 2, _MODE_LEGACY) public {
        bytes memory swapData = _generateUSDT2ETHSmartSwapData(_MODE_LEGACY);
        bytes memory commissionData = _generate2CommissionData(true, USDT);
        bytes memory data = bytes.concat(swapData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // Commission: 3, Trim: 0, Batches: 1
    function test_USDT2ETH_legacy_3commission_0trim_1batch() 
        tokenLogAndCheck3(USDT, ETH, 2000 * 10 ** 6, false, false, true, 3, _MODE_LEGACY) public {
        bytes memory swapData = _generateUSDT2ETHSmartSwapData(_MODE_LEGACY);
        bytes memory commissionData = _generateMultipleCommissionData(true, USDT, false, 3);
        bytes memory data = bytes.concat(swapData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // Commission: 3, Trim: 2, Batches: 1
    function test_USDT2ETH_legacy_3commission_2trim_1batch() 
        tokenLogAndCheck3(USDT, ETH, 2000 * 10 ** 6, true, true, true, 3, _MODE_LEGACY) public {
        bytes memory swapData = _generateUSDT2ETHSmartSwapData(_MODE_LEGACY);
        bytes memory trimData = _generate2TrimData();
        bytes memory commissionData = _generateMultipleCommissionData(true, USDT, false, 3);
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // Commission: 0, Trim: 2, Batches: 1
    function test_USDT2ETH_legacy_0commission_2trim_1batch() 
        tokenLogAndCheck3(USDT, ETH, 1000 * 10 ** 6, true, true, false, 0, _MODE_LEGACY) public {
        bytes memory swapData = _generateUSDT2ETHSmartSwapData(_MODE_LEGACY);
        bytes memory trimData = _generate2TrimData();
        bytes memory data = bytes.concat(swapData, trimData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // Commission: 3, Trim: 0, Batches: 2
    function test_USDT2ETH_legacy_3commission_0trim_2batch() 
        tokenLogAndCheck3(USDT, ETH, 2000 * 10 ** 6, false, false, true, 3, _MODE_LEGACY) public {
        bytes memory swapData = _generateUSDT2ETHSmartSwapDataMultiAssetTo(_MODE_LEGACY);
        bytes memory commissionData = _generateMultipleCommissionData(true, USDT, false, 3);
        bytes memory data = bytes.concat(swapData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // Commission: 3, Trim: 2, Batches: 2
    function test_USDT2ETH_legacy_3commission_2trim_2batch() 
        tokenLogAndCheck3(USDT, ETH, 2000 * 10 ** 6, true, true, true, 3, _MODE_LEGACY) public {
        bytes memory swapData = _generateUSDT2ETHSmartSwapDataMultiAssetTo(_MODE_LEGACY);
        bytes memory trimData = _generate2TrimData();
        bytes memory commissionData = _generateMultipleCommissionData(true, USDT, false, 3);
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // --- Permit2 Signature Mode ---
    // Commission: 0, Trim: 0, Batches: 1
    function test_USDT2ETH_permit2_0commission_0trim_1batch() 
        tokenLogAndCheck3(USDT, ETH, 1000 * 10 ** 6, false, false, false, 0, _MODE_PERMIT2_SIGNATURE) public {
        bytes memory swapData = _generateUSDT2ETHSmartSwapData(_MODE_PERMIT2_SIGNATURE);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1000 * 10 ** 6;
        bytes memory permit2Info = _generatePermit2Info(USDT, amounts);
        bytes memory data = bytes.concat(swapData, permit2Info);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // Commission: 1, Trim: 0, Batches: 1
    function test_USDT2ETH_permit2_1commission_0trim_1batch() 
        tokenLogAndCheck3(USDT, ETH, 2000 * 10 ** 6, false, false, true, 1, _MODE_PERMIT2_SIGNATURE) public {
        bytes memory swapData = _generateUSDT2ETHSmartSwapData(_MODE_PERMIT2_SIGNATURE);
        bytes memory commissionData = _generate1CommissionData(true, USDT);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 2000 * 10 ** 6;
        amounts[1] = 1000 * 10 ** 6;
        bytes memory permit2Info = _generatePermit2Info(USDT, amounts);
        bytes memory data = bytes.concat(swapData, permit2Info, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // Commission: 2, Trim: 0, Batches: 1
    function test_USDT2ETH_permit2_2commission_0trim_1batch() 
        tokenLogAndCheck3(USDT, ETH, 2000 * 10 ** 6, false, false, true, 2, _MODE_PERMIT2_SIGNATURE) public {
        bytes memory swapData = _generateUSDT2ETHSmartSwapData(_MODE_PERMIT2_SIGNATURE);
        bytes memory commissionData = _generate2CommissionData(true, USDT);
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 2000 * 10 ** 6;
        amounts[1] = 1000 * 10 ** 6;
        amounts[2] = 1000 * 10 ** 6;
        bytes memory permit2Info = _generatePermit2Info(USDT, amounts);
        bytes memory data = bytes.concat(swapData, permit2Info, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // Commission: 3, Trim: 0, Batches: 1
    function test_USDT2ETH_permit2_3commission_0trim_1batch() 
        tokenLogAndCheck3(USDT, ETH, 2000 * 10 ** 6, false, false, true, 3, _MODE_PERMIT2_SIGNATURE) public {
        bytes memory swapData = _generateUSDT2ETHSmartSwapData(_MODE_PERMIT2_SIGNATURE);
        bytes memory commissionData = _generateMultipleCommissionData(true, USDT, false, 3);
        uint256[] memory amounts = new uint256[](4);
        amounts[0] = 2000 * 10 ** 6;
        amounts[1] = 1000 * 10 ** 6;
        amounts[2] = 1000 * 10 ** 6;
        amounts[3] = 1000 * 10 ** 6;
        bytes memory permit2Info = _generatePermit2Info(USDT, amounts);
        bytes memory data = bytes.concat(swapData, permit2Info, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // Commission: 3, Trim: 2, Batches: 1
    function test_USDT2ETH_permit2_3commission_2trim_1batch() 
        tokenLogAndCheck3(USDT, ETH, 2000 * 10 ** 6, true, true, true, 3, _MODE_PERMIT2_SIGNATURE) public {
        bytes memory swapData = _generateUSDT2ETHSmartSwapData(_MODE_PERMIT2_SIGNATURE);
        bytes memory trimData = _generate2TrimData();
        bytes memory commissionData = _generateMultipleCommissionData(true, USDT, false, 3);
        uint256[] memory amounts = new uint256[](4);
        amounts[0] = 2000 * 10 ** 6;
        amounts[1] = 1000 * 10 ** 6;
        amounts[2] = 1000 * 10 ** 6;
        amounts[3] = 1000 * 10 ** 6;
        bytes memory permit2Info = _generatePermit2Info(USDT, amounts);
        bytes memory data = bytes.concat(swapData, permit2Info, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // Commission: 0, Trim: 2, Batches: 1
    function test_USDT2ETH_permit2_0commission_2trim_1batch() 
        tokenLogAndCheck3(USDT, ETH, 1000 * 10 ** 6, true, true, false, 0, _MODE_PERMIT2_SIGNATURE) public {
        bytes memory swapData = _generateUSDT2ETHSmartSwapData(_MODE_PERMIT2_SIGNATURE);
        bytes memory trimData = _generate2TrimData();
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1000 * 10 ** 6;
        bytes memory permit2Info = _generatePermit2Info(USDT, amounts);
        bytes memory data = bytes.concat(swapData, permit2Info, trimData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // Commission: 3, Trim: 0, Batches: 2
    function test_USDT2ETH_permit2_3commission_0trim_2batch() 
        tokenLogAndCheck3(USDT, ETH, 2000 * 10 ** 6, false, false, true, 3, _MODE_PERMIT2_SIGNATURE) public {
        bytes memory swapData = _generateUSDT2ETHSmartSwapDataMultiAssetTo(_MODE_PERMIT2_SIGNATURE);
        bytes memory commissionData = _generateMultipleCommissionData(true, USDT, false, 3);
        uint256[] memory amounts = new uint256[](4);
        amounts[0] = 2000 * 10 ** 6;
        amounts[1] = 1000 * 10 ** 6;
        amounts[2] = 1000 * 10 ** 6;
        amounts[3] = 1000 * 10 ** 6;
        bytes memory permit2Info = _generatePermit2Info(USDT, amounts);
        bytes memory data = bytes.concat(swapData, permit2Info, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // Commission: 3, Trim: 2, Batches: 2
    function test_USDT2ETH_permit2_3commission_2trim_2batch() 
        tokenLogAndCheck3(USDT, ETH, 2000 * 10 ** 6, true, true, true, 3, _MODE_PERMIT2_SIGNATURE) public {
        bytes memory swapData = _generateUSDT2ETHSmartSwapDataMultiAssetTo(_MODE_PERMIT2_SIGNATURE);
        bytes memory trimData = _generate2TrimData();
        bytes memory commissionData = _generateMultipleCommissionData(true, USDT, false, 3);
        uint256[] memory amounts = new uint256[](4);
        amounts[0] = 2000 * 10 ** 6;
        amounts[1] = 1000 * 10 ** 6;
        amounts[2] = 1000 * 10 ** 6;
        amounts[3] = 1000 * 10 ** 6;
        bytes memory permit2Info = _generatePermit2Info(USDT, amounts);
        bytes memory data = bytes.concat(swapData, permit2Info, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // ==================== ETH -> ERC20 (ETH -> USDT) Tests ====================
    // Note: ETH -> ERC20 uses native ETH, so no permit2 signature mode for the fromToken
    
    // --- Legacy Mode ---
    // Commission: 0, Trim: 0, Batches: 1
    function test_ETH2USDT_legacy_0commission_0trim_1batch() 
        tokenLogAndCheck3(ETH, USDT, 1 * 10 ** 18, false, false, false, 0, _MODE_LEGACY) public {
        bytes memory swapData = _generateETH2USDTSmartSwapData();
        (bool success, ) = address(dexRouter).call{value: 1 * 10 ** 18}(swapData);
        require(success, "call failed");
    }

    // Commission: 1, Trim: 0, Batches: 1
    function test_ETH2USDT_legacy_1commission_0trim_1batch() 
        tokenLogAndCheck3(ETH, USDT, 2 * 10 ** 18, false, false, true, 1, _MODE_LEGACY) public {
        bytes memory swapData = _generateETH2USDTSmartSwapData();
        bytes memory commissionData = _generate1CommissionData(true, ETH);
        bytes memory data = bytes.concat(swapData, commissionData);
        (bool success, ) = address(dexRouter).call{value: 2 * 10 ** 18}(data);
        require(success, "call failed");
    }

    // Commission: 2, Trim: 0, Batches: 1
    function test_ETH2USDT_legacy_2commission_0trim_1batch() 
        tokenLogAndCheck3(ETH, USDT, 2 * 10 ** 18, false, false, true, 2, _MODE_LEGACY) public {
        bytes memory swapData = _generateETH2USDTSmartSwapData();
        bytes memory commissionData = _generate2CommissionData(true, ETH);
        bytes memory data = bytes.concat(swapData, commissionData);
        (bool success, ) = address(dexRouter).call{value: 2 * 10 ** 18}(data);
        require(success, "call failed");
    }

    // Commission: 3, Trim: 0, Batches: 1
    function test_ETH2USDT_legacy_3commission_0trim_1batch() 
        tokenLogAndCheck3(ETH, USDT, 2 * 10 ** 18, false, false, true, 3, _MODE_LEGACY) public {
        bytes memory swapData = _generateETH2USDTSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(true, ETH, false, 3);
        bytes memory data = bytes.concat(swapData, commissionData);
        (bool success, ) = address(dexRouter).call{value: 2 * 10 ** 18}(data);
        require(success, "call failed");
    }

    // Commission: 3, Trim: 2, Batches: 1
    function test_ETH2USDT_legacy_3commission_2trim_1batch() 
        tokenLogAndCheck3(ETH, USDT, 2 * 10 ** 18, true, true, true, 3, _MODE_LEGACY) public {
        bytes memory swapData = _generateETH2USDTSmartSwapData();
        bytes memory trimData = _generate2TrimData();
        bytes memory commissionData = _generateMultipleCommissionData(true, ETH, false, 3);
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call{value: 2 * 10 ** 18}(data);
        require(success, "call failed");
    }

    // Commission: 0, Trim: 2, Batches: 1
    function test_ETH2USDT_legacy_0commission_2trim_1batch() 
        tokenLogAndCheck3(ETH, USDT, 1 * 10 ** 18, true, true, false, 0, _MODE_LEGACY) public {
        bytes memory swapData = _generateETH2USDTSmartSwapData();
        bytes memory trimData = _generate2TrimData();
        bytes memory data = bytes.concat(swapData, trimData);
        (bool success, ) = address(dexRouter).call{value: 1 * 10 ** 18}(data);
        require(success, "call failed");
    }

    // Commission: 3, Trim: 0, Batches: 2
    function test_ETH2USDT_legacy_3commission_0trim_2batch() 
        tokenLogAndCheck3(ETH, USDT, 2 * 10 ** 18, false, false, true, 3, _MODE_LEGACY) public {
        bytes memory swapData = _generateETH2USDTSmartSwapDataMultiAssetTo();
        bytes memory commissionData = _generateMultipleCommissionData(true, ETH, false, 3);
        bytes memory data = bytes.concat(swapData, commissionData);
        (bool success, ) = address(dexRouter).call{value: 2 * 10 ** 18}(data);
        require(success, "call failed");
    }

    // Commission: 3, Trim: 2, Batches: 2
    function test_ETH2USDT_legacy_3commission_2trim_2batch() 
        tokenLogAndCheck3(ETH, USDT, 2 * 10 ** 18, true, true, true, 3, _MODE_LEGACY) public {
        bytes memory swapData = _generateETH2USDTSmartSwapDataMultiAssetTo();
        bytes memory trimData = _generate2TrimData();
        bytes memory commissionData = _generateMultipleCommissionData(true, ETH, false, 3);
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call{value: 2 * 10 ** 18}(data);
        require(success, "call failed");
    }

    // ==================== ToToken Commission Tests ====================
    // Test toToken commission (instead of fromToken commission)
    
    // WETH -> USDT with toToken commission, Legacy mode
    function test_WETH2USDT_legacy_3toCommission_0trim_1batch() 
        tokenLogAndCheck3(WETH, USDT, 1 * 10 ** 18, false, false, false, 3, _MODE_LEGACY) public {
        bytes memory swapData = _generateWETH2USDTSmartSwapData(_MODE_LEGACY);
        bytes memory commissionData = _generateMultipleCommissionData(false, USDT, false, 3);
        bytes memory data = bytes.concat(swapData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // WETH -> USDT with toToken commission + trim, Legacy mode
    function test_WETH2USDT_legacy_3toCommission_2trim_1batch() 
        tokenLogAndCheck3(WETH, USDT, 1 * 10 ** 18, true, true, false, 3, _MODE_LEGACY) public {
        bytes memory swapData = _generateWETH2USDTSmartSwapData(_MODE_LEGACY);
        bytes memory trimData = _generate2TrimData();
        bytes memory commissionData = _generateMultipleCommissionData(false, USDT, false, 3);
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // WETH -> USDT with toToken commission, Permit2 mode
    function test_WETH2USDT_permit2_3toCommission_0trim_1batch() 
        tokenLogAndCheck3(WETH, USDT, 1 * 10 ** 18, false, false, false, 3, _MODE_PERMIT2_SIGNATURE) public {
        bytes memory swapData = _generateWETH2USDTSmartSwapData(_MODE_PERMIT2_SIGNATURE);
        bytes memory commissionData = _generateMultipleCommissionData(false, USDT, false, 3);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1 * 10 ** 18;
        bytes memory permit2Info = _generatePermit2Info(WETH, amounts);
        bytes memory data = bytes.concat(swapData, permit2Info, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // WETH -> USDT with toToken commission + trim, Permit2 mode
    function test_WETH2USDT_permit2_3toCommission_2trim_1batch() 
        tokenLogAndCheck3(WETH, USDT, 1 * 10 ** 18, true, true, false, 3, _MODE_PERMIT2_SIGNATURE) public {
        bytes memory swapData = _generateWETH2USDTSmartSwapData(_MODE_PERMIT2_SIGNATURE);
        bytes memory trimData = _generate2TrimData();
        bytes memory commissionData = _generateMultipleCommissionData(false, USDT, false, 3);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1 * 10 ** 18;
        bytes memory permit2Info = _generatePermit2Info(WETH, amounts);
        bytes memory data = bytes.concat(swapData, permit2Info, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // ==================== ToBCommission Tests ====================
    // Test toBCommission flag (commission transferred to router first, then to referrers)

    // WETH -> USDT with fromToken commission + toBCommission, Legacy mode
    function test_WETH2USDT_legacy_3fromCommissionToB_0trim_1batch() 
        tokenLogAndCheck3(WETH, USDT, 2 * 10 ** 18, false, false, true, 3, _MODE_LEGACY) public {
        bytes memory swapData = _generateWETH2USDTSmartSwapData(_MODE_LEGACY);
        bytes memory commissionData = _generateMultipleCommissionData(true, WETH, true, 3); // toBCommission = true
        bytes memory data = bytes.concat(swapData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // WETH -> USDT with fromToken commission + toBCommission + trim, Legacy mode
    function test_WETH2USDT_legacy_3fromCommissionToB_2trim_1batch() 
        tokenLogAndCheck3(WETH, USDT, 2 * 10 ** 18, true, true, true, 3, _MODE_LEGACY) public {
        bytes memory swapData = _generateWETH2USDTSmartSwapData(_MODE_LEGACY);
        bytes memory trimData = _generate2TrimData();
        bytes memory commissionData = _generateMultipleCommissionData(true, WETH, true, 3); // toBCommission = true
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // WETH -> USDT with fromToken commission + toBCommission, Permit2 mode
    function test_WETH2USDT_permit2_3fromCommissionToB_0trim_1batch() 
        tokenLogAndCheck3(WETH, USDT, 2 * 10 ** 18, false, false, true, 3, _MODE_PERMIT2_SIGNATURE) public {
        bytes memory swapData = _generateWETH2USDTSmartSwapData(_MODE_PERMIT2_SIGNATURE);
        bytes memory commissionData = _generateMultipleCommissionData(true, WETH, true, 3); // toBCommission = true
        // For toBCommission, all amounts are transferred to router first, so only 1 transfer
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 3 * 10 ** 18; // swapAmount + all commission amounts
        bytes memory permit2Info = _generatePermit2Info(WETH, amounts);
        bytes memory data = bytes.concat(swapData, permit2Info, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // WETH -> USDT with fromToken commission + toBCommission + trim, Permit2 mode
    function test_WETH2USDT_permit2_3fromCommissionToB_2trim_1batch() 
        tokenLogAndCheck3(WETH, USDT, 2 * 10 ** 18, true, true, true, 3, _MODE_PERMIT2_SIGNATURE) public {
        bytes memory swapData = _generateWETH2USDTSmartSwapData(_MODE_PERMIT2_SIGNATURE);
        bytes memory trimData = _generate2TrimData();
        bytes memory commissionData = _generateMultipleCommissionData(true, WETH, true, 3); // toBCommission = true
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 3 * 10 ** 18; // swapAmount + all commission amounts
        bytes memory permit2Info = _generatePermit2Info(WETH, amounts);
        bytes memory data = bytes.concat(swapData, permit2Info, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // ==================== Internal Helper Functions ====================

    function _generateWETH2USDTSmartSwapData(uint256 mode) internal view returns (bytes memory) {
        return _generateSmartSwapData(
            WETH,
            USDT,
            oneEther,
            address(UniversalUniV3Adapter),
            address(UniversalUniV3Adapter),
            false,
            address(WETH_USDT_UNIV3),
            abi.encode(0, abi.encode(WETH, USDT, 0)),
            mode
        );
    }

    function _generateWETH2USDTSmartSwapDataMultiAssetTo(uint256 mode) internal view returns (bytes memory) {
        return _generateSmartSwapDataMultiAssetTo(
            WETH,
            USDT,
            oneEther,
            address(UniversalUniV3Adapter),
            address(UniversalUniV3Adapter),
            false,
            address(WETH_USDT_UNIV3),
            abi.encode(0, abi.encode(WETH, USDT, 0)),
            mode
        );
    }

    function _generateUSDT2ETHSmartSwapData(uint256 mode) internal view returns (bytes memory) {
        return _generateSmartSwapData(
            USDT,
            ETH,
            1000 * 10 ** 6,
            address(UniversalUniV3Adapter),
            address(UniversalUniV3Adapter),
            true,
            address(WETH_USDT_UNIV3),
            abi.encode(0, abi.encode(USDT, WETH, 0)),
            mode
        );
    }

    function _generateUSDT2ETHSmartSwapDataMultiAssetTo(uint256 mode) internal view returns (bytes memory) {
        return _generateSmartSwapDataMultiAssetTo(
            USDT,
            ETH,
            1000 * 10 ** 6,
            address(UniversalUniV3Adapter),
            address(UniversalUniV3Adapter),
            true,
            address(WETH_USDT_UNIV3),
            abi.encode(0, abi.encode(USDT, WETH, 0)),
            mode
        );
    }

    function _generateETH2USDTSmartSwapData() internal view returns (bytes memory) {
        return _generateSmartSwapData(
            ETH,
            USDT,
            oneEther,
            address(UniversalUniV3Adapter),
            address(UniversalUniV3Adapter),
            false,
            address(WETH_USDT_UNIV3),
            abi.encode(0, abi.encode(WETH, USDT, 0)),
            _MODE_LEGACY // ETH swaps don't use permit2 for fromToken
        );
    }

    function _generateETH2USDTSmartSwapDataMultiAssetTo() internal view returns (bytes memory) {
        return _generateSmartSwapDataMultiAssetTo(
            ETH,
            USDT,
            oneEther,
            address(UniversalUniV3Adapter),
            address(UniversalUniV3Adapter),
            false,
            address(WETH_USDT_UNIV3),
            abi.encode(0, abi.encode(WETH, USDT, 0)),
            _MODE_LEGACY // ETH swaps don't use permit2 for fromToken
        );
    }

    function _generateSmartSwapData(
        address fromToken,
        address toToken,
        uint256 fromTokenAmount,
        address assetTo,
        address adapter,
        bool isReverse,
        address poolAddress,
        bytes memory extraData,
        uint256 mode
    ) internal view returns (bytes memory) {
        SwapInfo memory swapInfo;
        // baseRequest
        swapInfo.baseRequest = _generateBaseRequest(fromToken, toToken, fromTokenAmount);
        // batchesAmount
        swapInfo.batchesAmount = new uint256[](1);
        swapInfo.batchesAmount[0] = fromTokenAmount;
        // batches
        swapInfo.batches = new UniversalRouter.RouterPath[][](1);
        swapInfo.batches[0] = new UniversalRouter.RouterPath[](1);
        swapInfo.batches[0][0].mixAdapters = new address[](1);
        swapInfo.batches[0][0].mixAdapters[0] = adapter;
        swapInfo.batches[0][0].assetTo = new address[](1);
        swapInfo.batches[0][0].assetTo[0] = assetTo;
        swapInfo.batches[0][0].rawData = new uint256[](1);
        swapInfo.batches[0][0].rawData[0] = uint256(bytes32(abi.encodePacked(uint8(isReverse ? 0x80 : 0x00), uint88(10000), poolAddress)));
        swapInfo.batches[0][0].extraData = new bytes[](1);
        swapInfo.batches[0][0].extraData[0] = extraData;
        swapInfo.batches[0][0].fromToken = uint256(uint160(fromToken == ETH ? WETH : fromToken)) | mode;
        // extraData
        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);

        return abi.encodeWithSelector(
            UniversalRouter.smartSwapTo.selector,
            swapInfo.orderId, arnaud, swapInfo.baseRequest, swapInfo.batchesAmount, swapInfo.batches, swapInfo.extraData
        );
    }

    function _generateSmartSwapDataMultiAssetTo(
        address fromToken,
        address toToken,
        uint256 fromTokenAmount,
        address assetTo,
        address adapter,
        bool isReverse,
        address poolAddress,
        bytes memory extraData,
        uint256 mode
    ) internal view returns (bytes memory) {
        SwapInfo memory swapInfo;
        // baseRequest
        swapInfo.baseRequest = _generateBaseRequest(fromToken, toToken, fromTokenAmount);
        // batchesAmount
        swapInfo.batchesAmount = new uint256[](1);
        swapInfo.batchesAmount[0] = fromTokenAmount;
        // batches with 2 assetTo (split 50/50)
        swapInfo.batches = new UniversalRouter.RouterPath[][](1);
        swapInfo.batches[0] = new UniversalRouter.RouterPath[](1);
        swapInfo.batches[0][0].mixAdapters = new address[](2);
        swapInfo.batches[0][0].mixAdapters[0] = adapter;
        swapInfo.batches[0][0].mixAdapters[1] = adapter;
        swapInfo.batches[0][0].assetTo = new address[](2);
        swapInfo.batches[0][0].assetTo[0] = assetTo;
        swapInfo.batches[0][0].assetTo[1] = assetTo;
        swapInfo.batches[0][0].rawData = new uint256[](2);
        // Split 50/50 (5000 weight each)
        swapInfo.batches[0][0].rawData[0] = uint256(bytes32(abi.encodePacked(uint8(isReverse ? 0x80 : 0x00), uint88(5000), poolAddress)));
        swapInfo.batches[0][0].rawData[1] = uint256(bytes32(abi.encodePacked(uint8(isReverse ? 0x80 : 0x00), uint88(5000), poolAddress)));
        swapInfo.batches[0][0].extraData = new bytes[](2);
        swapInfo.batches[0][0].extraData[0] = extraData;
        swapInfo.batches[0][0].extraData[1] = extraData;
        swapInfo.batches[0][0].fromToken = uint256(uint160(fromToken == ETH ? WETH : fromToken)) | mode;
        // extraData
        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);

        return abi.encodeWithSelector(
            UniversalRouter.smartSwapTo.selector,
            swapInfo.orderId, arnaud, swapInfo.baseRequest, swapInfo.batchesAmount, swapInfo.batches, swapInfo.extraData
        );
    }

    function _generatePermit2Info(
        address token,
        uint256[] memory amounts
    ) internal view returns (bytes memory) {
        IPermit2.PermitBatchTransferFrom memory permit = getPermitBatchTransferFrom(
            token,
            amounts,
            1, // nonce
            2524579200 // deadline 2050-01-01 00:00:00
        );
        bytes memory signature = getPermitBatchTransferSignature(
            permit,
            arnaudPrivateKey,
            address(dexRouter),
            Permit2EthDomainSeperator
        );
        bytes memory permit2Info = _buildPermit2InfoUnified(
            amounts,
            permit.nonce,
            permit.deadline,
            arnaud,
            signature
        );

        return permit2Info;
    }
}

