// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../common/TrimAndCommissionTestBase.t.sol";

/*
 * The smartSwap method is tested with condition1 * condition2 + condition3 * condition4:
 * condition1:
 *     (1) ERC20 -> ERC20
 *     (2) ETH -> ERC20
 *     (3) ERC20 -> ETH
 * condition2:
 *     (1) 8fromCommission + noTrim
 *     (2) 8toCommission + noTrim
 *     (3) 3fromCommission + 1trimOnlyTrim
 *     (4) 3toCommission + 1trimOnlyTrim
 *     (5) 3fromCommission + 1trimOnlyCharge
 *     (6) 3toCommission + 1trimOnlyCharge
 *     (7) 3fromCommission + 2trim
 *     (8) 3toCommission + 2trim
 *     (9) 8fromCommission + 1trimOnlyTrim
 *     (10) 8toCommission + 1trimOnlyTrim
 *     (11) 8fromCommission + 1trimOnlyCharge
 *     (12) 8toCommission + 1trimOnlyCharge
 *     (13) 8fromCommission + 2trim
 *     (14) 8toCommission + 2trim
 *     (15) 8fromCommissionToB + 2trim
 *     (16) 8toCommissionToB + 2trim
 * condition3:
 *     (1) ERC20 -> TaxToken(SAFEMOON)
 *     (2) TaxToken(SAFEMOON) -> ERC20
 * condition4:
 *     (1) 8fromCommission + noTrim
 *     (2) 8toCommission + noTrim
 *     (3) 3fromCommission + 2trim
 *     (4) 3toCommission + 2trim
 *     (5) 8fromCommission + 2trim
 *     (6) 8toCommission + 2trim
*/

contract SmartSwapMultiCommissionTest is TrimAndCommissionTestBase {
    // ==================== ERC20->ERC20 ====================
    // (1) WETH->USDT with 8fromCommission and noTrim
    function test_multiCommission_smartSwapTo_WETH2USDT_8fromCommission_noTrim() tokenLogAndCheck2(WETH, USDT, 2 * 10 ** 18, false, false, true, 8) public {
        bytes memory swapData = _generateWETH2USDTSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(true, WETH, false, 8);
        bytes memory data = bytes.concat(swapData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (2) WETH->USDT with 8toCommission and noTrim
    function test_multiCommission_smartSwapTo_WETH2USDT_8toCommission_noTrim() tokenLogAndCheck2(WETH, USDT, 1 * 10 ** 18, false, false, false, 8) public {
        bytes memory swapData = _generateWETH2USDTSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(false, USDT, false, 8);
        bytes memory data = bytes.concat(swapData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (3) WETH->USDT with 3fromCommission and 1trimOnlyTrim
    function test_multiCommission_smartSwapTo_WETH2USDT_3fromCommission_1trimOnlyTrim() tokenLogAndCheck2(WETH, USDT, 2 * 10 ** 18, true, false, true, 3) public {
        bytes memory swapData = _generateWETH2USDTSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(true, WETH, false, 3);
        bytes memory trimData = _generate1TrimOnlyTrimData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }
    
    // (4) WETH->USDT with 3toCommission and 1trimOnlyTrim
    function test_multiCommission_smartSwapTo_WETH2USDT_3toCommission_1trimOnlyTrim() tokenLogAndCheck2(WETH, USDT, 1 * 10 ** 18, true, false, false, 3) public {
        bytes memory swapData = _generateWETH2USDTSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(false, USDT, false, 3);
        bytes memory trimData = _generate1TrimOnlyTrimData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }
    // (5) WETH->USDT with 3fromCommission and 1trimOnlyCharge
    function test_multiCommission_smartSwapTo_WETH2USDT_3fromCommission_1trimOnlyCharge() tokenLogAndCheck2(WETH, USDT, 2 * 10 ** 18, false, true, true, 3) public {
        bytes memory swapData = _generateWETH2USDTSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(true, WETH, false, 3);
        bytes memory trimData = _generate1TrimOnlyChargeData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (6) WETH->USDT with 3toCommission and 1trimOnlyCharge
    function test_multiCommission_smartSwapTo_WETH2USDT_3toCommission_1trimOnlyCharge() tokenLogAndCheck2(WETH, USDT, 1 * 10 ** 18, false, true, false, 3) public {
        bytes memory swapData = _generateWETH2USDTSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(false, USDT, false, 3);
        bytes memory trimData = _generate1TrimOnlyChargeData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (7) WETH->USDT with 3fromCommission and 2trim
    function test_multiCommission_smartSwapTo_WETH2USDT_3fromCommission_2trim() tokenLogAndCheck2(WETH, USDT, 2 * 10 ** 18, true, true, true, 3) public {
        bytes memory swapData = _generateWETH2USDTSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(true, WETH, false, 3);
        bytes memory trimData = _generate2TrimData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (8) WETH->USDT with 3toCommission and 2trim
    function test_multiCommission_smartSwapTo_WETH2USDT_3toCommission_2trim() tokenLogAndCheck2(WETH, USDT, 1 * 10 ** 18, true, true, false, 3) public {
        bytes memory swapData = _generateWETH2USDTSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(false, USDT, false, 3);
        bytes memory trimData = _generate2TrimData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (9) WETH->USDT with 8fromCommission and 1trimOnlyTrim
    function test_multiCommission_smartSwapTo_WETH2USDT_8fromCommission_1trimOnlyTrim() tokenLogAndCheck2(WETH, USDT, 2 * 10 ** 18, true, false, true, 8) public {
        bytes memory swapData = _generateWETH2USDTSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(true, WETH, false, 8);
        bytes memory trimData = _generate1TrimOnlyTrimData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (10) WETH->USDT with 8toCommission and 1trimOnlyTrim
    function test_multiCommission_smartSwapTo_WETH2USDT_8toCommission_1trimOnlyTrim() tokenLogAndCheck2(WETH, USDT, 1 * 10 ** 18, true, false, false, 8) public {
        bytes memory swapData = _generateWETH2USDTSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(false, USDT, false, 8);
        bytes memory trimData = _generate1TrimOnlyTrimData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (11) WETH->USDT with 8fromCommission and 1trimOnlyCharge
    function test_multiCommission_smartSwapTo_WETH2USDT_8fromCommission_1trimOnlyCharge() tokenLogAndCheck2(WETH, USDT, 2 * 10 ** 18, false, true, true, 8) public {
        bytes memory swapData = _generateWETH2USDTSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(true, WETH, false, 8);
        bytes memory trimData = _generate1TrimOnlyChargeData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }
    // (12) WETH->USDT with 8toCommission and 1trimOnlyCharge
    function test_multiCommission_smartSwapTo_WETH2USDT_8toCommission_1trimOnlyCharge() tokenLogAndCheck2(WETH, USDT, 1 * 10 ** 18, false, true, false, 8) public {
        bytes memory swapData = _generateWETH2USDTSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(false, USDT, false, 8);
        bytes memory trimData = _generate1TrimOnlyChargeData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }
    // (13) WETH->USDT with 8fromCommission and 2trim
    function test_multiCommission_smartSwapTo_WETH2USDT_8fromCommission_2trim() tokenLogAndCheck2(WETH, USDT, 2 * 10 ** 18, true, true, true, 8) public {
        bytes memory swapData = _generateWETH2USDTSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(true, WETH, false, 8);
        bytes memory trimData = _generate2TrimData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }
    // (14) WETH->USDT with 8toCommission and 2trim
    function test_multiCommission_smartSwapTo_WETH2USDT_8toCommission_2trim() tokenLogAndCheck2(WETH, USDT, 1 * 10 ** 18, true, true, false, 8) public {
        bytes memory swapData = _generateWETH2USDTSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(false, USDT, false, 8);
        bytes memory trimData = _generate2TrimData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (15) WETH->USDT with 8fromCommissionToB and 2trim
    function test_multiCommission_smartSwapTo_WETH2USDT_8fromCommissionToB_2trim() tokenLogAndCheck2(WETH, USDT, 2 * 10 ** 18, true, true, true, 8) public {
        bytes memory swapData = _generateWETH2USDTSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(true, WETH, true, 8);
        bytes memory trimData = _generate2TrimData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (16) WETH->USDT with 8toCommissionToB and 2trim
    function test_multiCommission_smartSwapTo_WETH2USDT_8toCommissionToB_2trim() tokenLogAndCheck2(WETH, USDT, 1 * 10 ** 18, true, true, false, 8) public {
        bytes memory swapData = _generateWETH2USDTSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(false, USDT, true, 8);
        bytes memory trimData = _generate2TrimData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (17) USDT->WETH with 8fromCommission and noTrim
    function test_multiCommission_smartSwapTo_USDT2WETH_8fromCommission_noTrim() tokenLogAndCheck2(USDT, WETH, 2000 * 10 ** 6, false, false, true, 8) public {
        bytes memory swapData = _generateUSDT2WETHSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(true, USDT, false, 8);
        bytes memory data = bytes.concat(swapData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (18) USDT->WETH with 8toCommission and noTrim
    function test_multiCommission_smartSwapTo_USDT2WETH_8toCommission_noTrim() tokenLogAndCheck2(USDT, WETH, 1000 * 10 ** 6, false, false, false, 8) public {
        bytes memory swapData = _generateUSDT2WETHSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(false, WETH, false, 8);
        bytes memory data = bytes.concat(swapData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (19) USDT->WETH with 3fromCommission and 1trimOnlyTrim
    function test_multiCommission_smartSwapTo_USDT2WETH_3fromCommission_1trimOnlyTrim() tokenLogAndCheck2(USDT, WETH, 2000 * 10 ** 6, true, false, true, 3) public {
        bytes memory swapData = _generateUSDT2WETHSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(true, USDT, false, 3);
        bytes memory trimData = _generate1TrimOnlyTrimData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (20) USDT->WETH with 3toCommission and 1trimOnlyTrim
    function test_multiCommission_smartSwapTo_USDT2WETH_3toCommission_1trimOnlyTrim() tokenLogAndCheck2(USDT, WETH, 1000 * 10 ** 6, true, false, false, 3) public {
        bytes memory swapData = _generateUSDT2WETHSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(false, WETH, false, 3);
        bytes memory trimData = _generate1TrimOnlyTrimData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (21) USDT->WETH with 3fromCommission and 1trimOnlyCharge
    function test_multiCommission_smartSwapTo_USDT2WETH_3fromCommission_1trimOnlyCharge() tokenLogAndCheck2(USDT, WETH, 2000 * 10 ** 6, false, true, true, 3) public {
        bytes memory swapData = _generateUSDT2WETHSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(true, USDT, false, 3);
        bytes memory trimData = _generate1TrimOnlyChargeData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (22) USDT->WETH with 3toCommission and 1trimOnlyCharge
    function test_multiCommission_smartSwapTo_USDT2WETH_3toCommission_1trimOnlyCharge() tokenLogAndCheck2(USDT, WETH, 1000 * 10 ** 6, false, true, false, 3) public {
        bytes memory swapData = _generateUSDT2WETHSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(false, WETH, false, 3);
        bytes memory trimData = _generate1TrimOnlyChargeData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (23) USDT->WETH with 3fromCommission and 2trim
    function test_multiCommission_smartSwapTo_USDT2WETH_3fromCommission_2trim() tokenLogAndCheck2(USDT, WETH, 2000 * 10 ** 6, true, true, true, 3) public {
        bytes memory swapData = _generateUSDT2WETHSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(true, USDT, false, 3);
        bytes memory trimData = _generate2TrimData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (24) USDT->WETH with 3toCommission and 2trim
    function test_multiCommission_smartSwapTo_USDT2WETH_3toCommission_2trim() tokenLogAndCheck2(USDT, WETH, 1000 * 10 ** 6, true, true, false, 3) public {
        bytes memory swapData = _generateUSDT2WETHSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(false, WETH, false, 3);
        bytes memory trimData = _generate2TrimData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (25) USDT->WETH with 8fromCommission and 1trimOnlyTrim
    function test_multiCommission_smartSwapTo_USDT2WETH_8fromCommission_1trimOnlyTrim() tokenLogAndCheck2(USDT, WETH, 2000 * 10 ** 6, true, false, true, 8) public {
        bytes memory swapData = _generateUSDT2WETHSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(true, USDT, false, 8);
        bytes memory trimData = _generate1TrimOnlyTrimData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (26) USDT->WETH with 8toCommission and 1trimOnlyTrim
    function test_multiCommission_smartSwapTo_USDT2WETH_8toCommission_1trimOnlyTrim() tokenLogAndCheck2(USDT, WETH, 1000 * 10 ** 6, true, false, false, 8) public {
        bytes memory swapData = _generateUSDT2WETHSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(false, WETH, false, 8);
        bytes memory trimData = _generate1TrimOnlyTrimData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (27) USDT->WETH with 8fromCommission and 1trimOnlyCharge
    function test_multiCommission_smartSwapTo_USDT2WETH_8fromCommission_1trimOnlyCharge() tokenLogAndCheck2(USDT, WETH, 2000 * 10 ** 6, false, true, true, 8) public {
        bytes memory swapData = _generateUSDT2WETHSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(true, USDT, false, 8);
        bytes memory trimData = _generate1TrimOnlyChargeData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (28) USDT->WETH with 8toCommission and 1trimOnlyCharge
    function test_multiCommission_smartSwapTo_USDT2WETH_8toCommission_1trimOnlyCharge() tokenLogAndCheck2(USDT, WETH, 1000 * 10 ** 6, false, true, false, 8) public {
        bytes memory swapData = _generateUSDT2WETHSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(false, WETH, false, 8);
        bytes memory trimData = _generate1TrimOnlyChargeData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (29) USDT->WETH with 8fromCommission and 2trim
    function test_multiCommission_smartSwapTo_USDT2WETH_8fromCommission_2trim() tokenLogAndCheck2(USDT, WETH, 2000 * 10 ** 6, true, true, true, 8) public {
        bytes memory swapData = _generateUSDT2WETHSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(true, USDT, false, 8);
        bytes memory trimData = _generate2TrimData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (30) USDT->WETH with 8toCommission and 2trim
    function test_multiCommission_smartSwapTo_USDT2WETH_8toCommission_2trim() tokenLogAndCheck2(USDT, WETH, 1000 * 10 ** 6, true, true, false, 8) public {
        bytes memory swapData = _generateUSDT2WETHSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(false, WETH, false, 8);
        bytes memory trimData = _generate2TrimData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (31) USDT->WETH with 8fromCommissionToB and 2trim
    function test_multiCommission_smartSwapTo_USDT2WETH_8fromCommissionToB_2trim() tokenLogAndCheck2(USDT, WETH, 2000 * 10 ** 6, true, true, true, 8) public {
        bytes memory swapData = _generateUSDT2WETHSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(true, USDT, true, 8);
        bytes memory trimData = _generate2TrimData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (32) USDT->WETH with 8toCommissionToB and 2trim
    function test_multiCommission_smartSwapTo_USDT2WETH_8toCommissionToB_2trim() tokenLogAndCheck2(USDT, WETH, 1000 * 10 ** 6, true, true, false, 8) public {
        bytes memory swapData = _generateUSDT2WETHSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(false, WETH, true, 8);
        bytes memory trimData = _generate2TrimData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // ==================== ETH->ERC20 ====================
    // (1) ETH->USDT with 8fromCommission and noTrim
    function test_multiCommission_smartSwapTo_ETH2USDT_8fromCommission_noTrim() tokenLogAndCheck2(ETH, USDT, 2 * 10 ** 18, false, false, true, 8) public {
        bytes memory swapData = _generateETH2USDTSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(true, ETH, false, 8);
        bytes memory data = bytes.concat(swapData, commissionData);
        (bool success, ) = address(dexRouter).call{value: 2 * 10 ** 18}(data);
        require(success, "call failed");
    }

    // (2) ETH->USDT with 8toCommission and noTrim
    function test_multiCommission_smartSwapTo_ETH2USDT_8toCommission_noTrim() tokenLogAndCheck2(ETH, USDT, 1 * 10 ** 18, false, false, false, 8) public {
        bytes memory swapData = _generateETH2USDTSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(false, USDT, false, 8);
        bytes memory data = bytes.concat(swapData, commissionData);
        (bool success, ) = address(dexRouter).call{value: 1 * 10 ** 18}(data);
        require(success, "call failed");
    }
    
    // (3) ETH->USDT with 3fromCommission and 1trimOnlyTrim
    function test_multiCommission_smartSwapTo_ETH2USDT_3fromCommission_1trimOnlyTrim() tokenLogAndCheck2(ETH, USDT, 2 * 10 ** 18, true, false, true, 3) public {
        bytes memory swapData = _generateETH2USDTSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(true, ETH, false, 3);
        bytes memory trimData = _generate1TrimOnlyTrimData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call{value: 2 * 10 ** 18}(data);
        require(success, "call failed");
    }

    // (4) ETH->USDT with 3toCommission and 1trimOnlyTrim
    function test_multiCommission_smartSwapTo_ETH2USDT_3toCommission_1trimOnlyTrim() tokenLogAndCheck2(ETH, USDT, 1 * 10 ** 18, true, false, false, 3) public {
        bytes memory swapData = _generateETH2USDTSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(false, USDT, false, 3);
        bytes memory trimData = _generate1TrimOnlyTrimData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call{value: 1 * 10 ** 18}(data);
        require(success, "call failed");
    }

    // (5) ETH->USDT with 3fromCommission and 1trimOnlyCharge
    function test_multiCommission_smartSwapTo_ETH2USDT_3fromCommission_1trimOnlyCharge() tokenLogAndCheck2(ETH, USDT, 2 * 10 ** 18, false, true, true, 3) public {
        bytes memory swapData = _generateETH2USDTSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(true, ETH, false, 3);
        bytes memory trimData = _generate1TrimOnlyChargeData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call{value: 2 * 10 ** 18}(data);
        require(success, "call failed");
    }

    // (6) ETH->USDT with 3toCommission and 1trimOnlyCharge
    function test_multiCommission_smartSwapTo_ETH2USDT_3toCommission_1trimOnlyCharge() tokenLogAndCheck2(ETH, USDT, 1 * 10 ** 18, false, true, false, 3) public {
        bytes memory swapData = _generateETH2USDTSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(false, USDT, false, 3);
        bytes memory trimData = _generate1TrimOnlyChargeData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call{value: 1 * 10 ** 18}(data);
        require(success, "call failed");
    }

    // (7) ETH->USDT with 3fromCommission and 2trim
    function test_multiCommission_smartSwapTo_ETH2USDT_3fromCommission_2trim() tokenLogAndCheck2(ETH, USDT, 2 * 10 ** 18, true, true, true, 3) public {
        bytes memory swapData = _generateETH2USDTSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(true, ETH, false, 3);
        bytes memory trimData = _generate2TrimData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call{value: 2 * 10 ** 18}(data);
        require(success, "call failed");
    }

    // (8) ETH->USDT with 3toCommission and 2trim
    function test_multiCommission_smartSwapTo_ETH2USDT_3toCommission_2trim() tokenLogAndCheck2(ETH, USDT, 1 * 10 ** 18, true, true, false, 3) public {
        bytes memory swapData = _generateETH2USDTSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(false, USDT, false, 3);
        bytes memory trimData = _generate2TrimData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call{value: 1 * 10 ** 18}(data);
        require(success, "call failed");
    }

    // (9) ETH->USDT with 8fromCommission and 1trimOnlyTrim
    function test_multiCommission_smartSwapTo_ETH2USDT_8fromCommission_1trimOnlyTrim() tokenLogAndCheck2(ETH, USDT, 2 * 10 ** 18, true, false, true, 8) public {
        bytes memory swapData = _generateETH2USDTSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(true, ETH, false, 8);
        bytes memory trimData = _generate1TrimOnlyTrimData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call{value: 2 * 10 ** 18}(data);
        require(success, "call failed");
    }

    // (10) ETH->USDT with 8toCommission and 1trimOnlyTrim
    function test_multiCommission_smartSwapTo_ETH2USDT_8toCommission_1trimOnlyTrim() tokenLogAndCheck2(ETH, USDT, 1 * 10 ** 18, true, false, false, 8) public {
        bytes memory swapData = _generateETH2USDTSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(false, USDT, false, 8);
        bytes memory trimData = _generate1TrimOnlyTrimData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call{value: 1 * 10 ** 18}(data);
        require(success, "call failed");
    }

    // (11) ETH->USDT with 8fromCommission and 1trimOnlyCharge
    function test_multiCommission_smartSwapTo_ETH2USDT_8fromCommission_1trimOnlyCharge() tokenLogAndCheck2(ETH, USDT, 2 * 10 ** 18, false, true, true, 8) public {
        bytes memory swapData = _generateETH2USDTSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(true, ETH, false, 8);
        bytes memory trimData = _generate1TrimOnlyChargeData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call{value: 2 * 10 ** 18}(data);
        require(success, "call failed");
    }

    // (12) ETH->USDT with 8toCommission and 1trimOnlyCharge
    function test_multiCommission_smartSwapTo_ETH2USDT_8toCommission_1trimOnlyCharge() tokenLogAndCheck2(ETH, USDT, 1 * 10 ** 18, false, true, false, 8) public {
        bytes memory swapData = _generateETH2USDTSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(false, USDT, false, 8);
        bytes memory trimData = _generate1TrimOnlyChargeData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call{value: 1 * 10 ** 18}(data);
        require(success, "call failed");
    }

    // (13) ETH->USDT with 8fromCommission and 2trim
    function test_multiCommission_smartSwapTo_ETH2USDT_8fromCommission_2trim() tokenLogAndCheck2(ETH, USDT, 2 * 10 ** 18, true, true, true, 8) public {
        bytes memory swapData = _generateETH2USDTSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(true, ETH, false, 8);
        bytes memory trimData = _generate2TrimData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call{value: 2 * 10 ** 18}(data);
        require(success, "call failed");
    }

    // (14) ETH->USDT with 8toCommission and 2trim
    function test_multiCommission_smartSwapTo_ETH2USDT_8toCommission_2trim() tokenLogAndCheck2(ETH, USDT, 1 * 10 ** 18, true, true, false, 8) public {
        bytes memory swapData = _generateETH2USDTSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(false, USDT, false, 8);
        bytes memory trimData = _generate2TrimData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call{value: 1 * 10 ** 18}(data);
        require(success, "call failed");
    }

    // (15) ETH->USDT with 8fromCommissionToB and 2trim
    function test_multiCommission_smartSwapTo_ETH2USDT_8fromCommissionToB_2trim() tokenLogAndCheck2(ETH, USDT, 2 * 10 ** 18, true, true, true, 8) public {
        bytes memory swapData = _generateETH2USDTSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(true, ETH, true, 8);
        bytes memory trimData = _generate2TrimData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call{value: 2 * 10 ** 18}(data);
        require(success, "call failed");
    }

    // (16) ETH->USDT with 8toCommissionToB and 2trim
    function test_multiCommission_smartSwapTo_ETH2USDT_8toCommissionToB_2trim() tokenLogAndCheck2(ETH, USDT, 1 * 10 ** 18, true, true, false, 8) public {
        bytes memory swapData = _generateETH2USDTSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(false, USDT, true, 8);
        bytes memory trimData = _generate2TrimData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call{value: 1 * 10 ** 18}(data);
        require(success, "call failed");
    }

    // ==================== ERC20->ETH ====================
    // (1) USDT->ETH with 8fromCommission and noTrim
    function test_multiCommission_smartSwapTo_USDT2ETH_8fromCommission_noTrim() tokenLogAndCheck2(USDT, ETH, 2000 * 10 ** 6, false, false, true, 8) public {
        bytes memory swapData = _generateUSDT2ETHSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(true, USDT, false, 8);
        bytes memory data = bytes.concat(swapData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (2) USDT->ETH with 8toCommission and noTrim
    function test_multiCommission_smartSwapTo_USDT2ETH_8toCommission_noTrim() tokenLogAndCheck2(USDT, ETH, 1000 * 10 ** 6, false, false, false, 8) public {
        bytes memory swapData = _generateUSDT2ETHSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(false, ETH, false, 8);
        bytes memory data = bytes.concat(swapData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (3) USDT->ETH with 3fromCommission and 1trimOnlyTrim
    function test_multiCommission_smartSwapTo_USDT2ETH_3fromCommission_1trimOnlyTrim() tokenLogAndCheck2(USDT, ETH, 2000 * 10 ** 6, true, false, true, 3) public {
        bytes memory swapData = _generateUSDT2ETHSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(true, USDT, false, 3);
        bytes memory trimData = _generate1TrimOnlyTrimData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (4) USDT->ETH with 3toCommission and 1trimOnlyTrim
    function test_multiCommission_smartSwapTo_USDT2ETH_3toCommission_1trimOnlyTrim() tokenLogAndCheck2(USDT, ETH, 1000 * 10 ** 6, true, false, false, 3) public {
        bytes memory swapData = _generateUSDT2ETHSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(false, ETH, false, 3);
        bytes memory trimData = _generate1TrimOnlyTrimData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (5) USDT->ETH with 3fromCommission and 1trimOnlyCharge
    function test_multiCommission_smartSwapTo_USDT2ETH_3fromCommission_1trimOnlyCharge() tokenLogAndCheck2(USDT, ETH, 2000 * 10 ** 6, false, true, true, 3) public {
        bytes memory swapData = _generateUSDT2ETHSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(true, USDT, false, 3);
        bytes memory trimData = _generate1TrimOnlyChargeData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (6) USDT->ETH with 3toCommission and 1trimOnlyCharge
    function test_multiCommission_smartSwapTo_USDT2ETH_3toCommission_1trimOnlyCharge() tokenLogAndCheck2(USDT, ETH, 1000 * 10 ** 6, false, true, false, 3) public {
        bytes memory swapData = _generateUSDT2ETHSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(false, ETH, false, 3);
        bytes memory trimData = _generate1TrimOnlyChargeData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (7) USDT->ETH with 3fromCommission and 2trim
    function test_multiCommission_smartSwapTo_USDT2ETH_3fromCommission_2trim() tokenLogAndCheck2(USDT, ETH, 2000 * 10 ** 6, true, true, true, 3) public {
        bytes memory swapData = _generateUSDT2ETHSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(true, USDT, false, 3);
        bytes memory trimData = _generate2TrimData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (8) USDT->ETH with 3toCommission and 2trim
    function test_multiCommission_smartSwapTo_USDT2ETH_3toCommission_2trim() tokenLogAndCheck2(USDT, ETH, 1000 * 10 ** 6, true, true, false, 3) public {
        bytes memory swapData = _generateUSDT2ETHSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(false, ETH, false, 3);
        bytes memory trimData = _generate2TrimData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (9) USDT->ETH with 8fromCommission and 1trimOnlyTrim
    function test_multiCommission_smartSwapTo_USDT2ETH_8fromCommission_1trimOnlyTrim() tokenLogAndCheck2(USDT, ETH, 2000 * 10 ** 6, true, false, true, 8) public {
        bytes memory swapData = _generateUSDT2ETHSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(true, USDT, false, 8);
        bytes memory trimData = _generate1TrimOnlyTrimData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (10) USDT->ETH with 8toCommission and 1trimOnlyTrim
    function test_multiCommission_smartSwapTo_USDT2ETH_8toCommission_1trimOnlyTrim() tokenLogAndCheck2(USDT, ETH, 1000 * 10 ** 6, true, false, false, 8) public {
        bytes memory swapData = _generateUSDT2ETHSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(false, ETH, false, 8);
        bytes memory trimData = _generate1TrimOnlyTrimData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (11) USDT->ETH with 8fromCommission and 1trimOnlyCharge
    function test_multiCommission_smartSwapTo_USDT2ETH_8fromCommission_1trimOnlyCharge() tokenLogAndCheck2(USDT, ETH, 2000 * 10 ** 6, false, true, true, 8) public {
        bytes memory swapData = _generateUSDT2ETHSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(true, USDT, false, 8);
        bytes memory trimData = _generate1TrimOnlyChargeData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (12) USDT->ETH with 8toCommission and 1trimOnlyCharge
    function test_multiCommission_smartSwapTo_USDT2ETH_8toCommission_1trimOnlyCharge() tokenLogAndCheck2(USDT, ETH, 1000 * 10 ** 6, false, true, false, 8) public {
        bytes memory swapData = _generateUSDT2ETHSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(false, ETH, false, 8);
        bytes memory trimData = _generate1TrimOnlyChargeData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (13) USDT->ETH with 8fromCommission and 2trim
    function test_multiCommission_smartSwapTo_USDT2ETH_8fromCommission_2trim() tokenLogAndCheck2(USDT, ETH, 2000 * 10 ** 6, true, true, true, 8) public {
        bytes memory swapData = _generateUSDT2ETHSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(true, USDT, false, 8);
        bytes memory trimData = _generate2TrimData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (14) USDT->ETH with 8toCommission and 2trim
    function test_multiCommission_smartSwapTo_USDT2ETH_8toCommission_2trim() tokenLogAndCheck2(USDT, ETH, 1000 * 10 ** 6, true, true, false, 8) public {
        bytes memory swapData = _generateUSDT2ETHSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(false, ETH, false, 8);
        bytes memory trimData = _generate2TrimData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (15) USDT->ETH with 8fromCommissionToB and 2trim
    function test_multiCommission_smartSwapTo_USDT2ETH_8fromCommissionToB_2trim() tokenLogAndCheck2(USDT, ETH, 2000 * 10 ** 6, true, true, true, 8) public {
        bytes memory swapData = _generateUSDT2ETHSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(true, USDT, true, 8);
        bytes memory trimData = _generate2TrimData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (16) USDT->ETH with 8toCommissionToB and 2trim
    function test_multiCommission_smartSwapTo_USDT2ETH_8toCommissionToB_2trim() tokenLogAndCheck2(USDT, ETH, 1000 * 10 ** 6, true, true, false, 8) public {
        bytes memory swapData = _generateUSDT2ETHSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(false, ETH, true, 8);
        bytes memory trimData = _generate2TrimData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // ==================== ERC20->TaxToken(SAFEMOON) ====================
    // (1) ERC20->TaxToken(SAFEMOON) with 8fromCommission and noTrim
    function test_multiCommission_smartSwapTo_WETH2SAFEMOON_8fromCommission_noTrim() tokenLogAndCheck2(WETH, SAFEMOON, 0.02 * 10 ** 18, false, false, true, 8) public {
        bytes memory swapData = _generateWETH2SAFEMOONSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(true, WETH, false, 8);
        bytes memory data = bytes.concat(swapData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (2) ERC20->TaxToken(SAFEMOON) with 8toCommission and noTrim
    function test_multiCommission_smartSwapTo_WETH2SAFEMOON_8toCommission_noTrim() tokenLogAndCheck2(WETH, SAFEMOON, 0.01 * 10 ** 18, false, false, false, 8) public {
        bytes memory swapData = _generateWETH2SAFEMOONSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(false, SAFEMOON, false, 8);
        bytes memory data = bytes.concat(swapData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (3) ERC20->TaxToken(SAFEMOON) with 3fromCommission and 2trim
    function test_multiCommission_smartSwapTo_WETH2SAFEMOON_3fromCommission_2trim() tokenLogAndCheck2(WETH, SAFEMOON, 0.02 * 10 ** 18, true, true, true, 3) public {
        bytes memory swapData = _generateWETH2SAFEMOONSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(true, WETH, false, 3);
        bytes memory trimData = _generate2TrimData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (4) ERC20->TaxToken(SAFEMOON) with 3toCommission and 2trim
    function test_multiCommission_smartSwapTo_WETH2SAFEMOON_3toCommission_2trim() tokenLogAndCheck2(WETH, SAFEMOON, 0.01 * 10 ** 18, true, true, false, 3) public {
        bytes memory swapData = _generateWETH2SAFEMOONSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(false, SAFEMOON, false, 3);
        bytes memory trimData = _generate2TrimData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (5) ERC20->TaxToken(SAFEMOON) with 8fromCommission and 2trim
    function test_multiCommission_smartSwapTo_WETH2SAFEMOON_8fromCommission_2trim() tokenLogAndCheck2(WETH, SAFEMOON, 0.02 * 10 ** 18, true, true, true, 8) public {
        bytes memory swapData = _generateWETH2SAFEMOONSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(true, WETH, false, 8);
        bytes memory trimData = _generate2TrimData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (6) ERC20->TaxToken(SAFEMOON) with 8toCommission and 2trim
    function test_multiCommission_smartSwapTo_WETH2SAFEMOON_8toCommission_2trim() tokenLogAndCheck2(WETH, SAFEMOON, 0.01 * 10 ** 18, true, true, false, 8) public {
        bytes memory swapData = _generateWETH2SAFEMOONSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(false, SAFEMOON, false, 8);
        bytes memory trimData = _generate2TrimData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (7) ERC20->TaxToken(SAFEMOON) with 8fromCommissionToB and 2trim
    function test_multiCommission_smartSwapTo_WETH2SAFEMOON_8fromCommissionToB_2trim() tokenLogAndCheck2(WETH, SAFEMOON, 0.02 * 10 ** 18, true, true, true, 8) public {
        bytes memory swapData = _generateWETH2SAFEMOONSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(true, WETH, true, 8);
        bytes memory trimData = _generate2TrimData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (8) ERC20->TaxToken(SAFEMOON) with 8toCommissionToB and 2trim
    function test_multiCommission_smartSwapTo_WETH2SAFEMOON_8toCommissionToB_2trim() tokenLogAndCheck2(WETH, SAFEMOON, 0.01 * 10 ** 18, true, true, false, 8) public {
        bytes memory swapData = _generateWETH2SAFEMOONSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(false, SAFEMOON, true, 8);
        bytes memory trimData = _generate2TrimData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // ==================== TaxToken(SAFEMOON)->ERC20 ====================
    // (1) TaxToken(SAFEMOON)->ERC20 with 8fromCommission and noTrim
    function test_multiCommission_smartSwapTo_SAFEMOON2WETH_8fromCommission_noTrim() tokenLogAndCheck2(SAFEMOON, WETH, 2 * 10 ** 27, false, false, true, 8) public {
        bytes memory swapData = _generateSAFEMOON2WETHSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(true, SAFEMOON, false, 8);
        bytes memory data = bytes.concat(swapData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (2) TaxToken(SAFEMOON)->ERC20 with 8toCommission and noTrim
    function test_multiCommission_smartSwapTo_SAFEMOON2WETH_8toCommission_noTrim() tokenLogAndCheck2(SAFEMOON, WETH, 1 * 10 ** 27, false, false, false, 8) public {
        bytes memory swapData = _generateSAFEMOON2WETHSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(false, WETH, false, 8);
        bytes memory data = bytes.concat(swapData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (3) TaxToken(SAFEMOON)->ERC20 with 3fromCommission and 2trim
    function test_multiCommission_smartSwapTo_SAFEMOON2WETH_3fromCommission_2trim() tokenLogAndCheck2(SAFEMOON, WETH, 2 * 10 ** 27, true, true, true, 3) public {
        bytes memory swapData = _generateSAFEMOON2WETHSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(true, SAFEMOON, false, 3);
        bytes memory trimData = _generate2TrimData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (4) TaxToken(SAFEMOON)->ERC20 with 3toCommission and 2trim
    function test_multiCommission_smartSwapTo_SAFEMOON2WETH_3toCommission_2trim() tokenLogAndCheck2(SAFEMOON, WETH, 1 * 10 ** 27, true, true, false, 3) public {
        bytes memory swapData = _generateSAFEMOON2WETHSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(false, WETH, false, 3);
        bytes memory trimData = _generate2TrimData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (5) TaxToken(SAFEMOON)->ERC20 with 8fromCommission and 2trim
    function test_multiCommission_smartSwapTo_SAFEMOON2WETH_8fromCommission_2trim() tokenLogAndCheck2(SAFEMOON, WETH, 2 * 10 ** 27, true, true, true, 8) public {
        bytes memory swapData = _generateSAFEMOON2WETHSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(true, SAFEMOON, false, 8);
        bytes memory trimData = _generate2TrimData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (6) TaxToken(SAFEMOON)->ERC20 with 8toCommission and 2trim
    function test_multiCommission_smartSwapTo_SAFEMOON2WETH_8toCommission_2trim() tokenLogAndCheck2(SAFEMOON, WETH, 1 * 10 ** 27, true, true, false, 8) public {
        bytes memory swapData = _generateSAFEMOON2WETHSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(false, WETH, false, 8);
        bytes memory trimData = _generate2TrimData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (7) TaxToken(SAFEMOON)->ERC20 with 8fromCommissionToB and 2trim
    function test_multiCommission_smartSwapTo_SAFEMOON2WETH_8fromCommissionToB_2trim() tokenLogAndCheck2(SAFEMOON, WETH, 2 * 10 ** 27, true, true, true, 8) public {
        bytes memory swapData = _generateSAFEMOON2WETHSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(true, SAFEMOON, true, 8);
        bytes memory trimData = _generate2TrimData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (8) TaxToken(SAFEMOON)->ERC20 with 8toCommissionToB and 2trim
    function test_multiCommission_smartSwapTo_SAFEMOON2WETH_8toCommissionToB_2trim() tokenLogAndCheck2(SAFEMOON, WETH, 1 * 10 ** 27, true, true, false, 8) public {
        bytes memory swapData = _generateSAFEMOON2WETHSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(false, WETH, true, 8);
        bytes memory trimData = _generate2TrimData();
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // ==================== Internal Functions ====================
    function _generateWETH2USDTSmartSwapData() internal view returns (bytes memory) {
        return _generateSmartSwapData(
            WETH,
            USDT,
            oneEther,
            address(UniversalUniV3Adapter),
            address(UniversalUniV3Adapter),
            false,
            address(WETH_USDT_UNIV3),
            abi.encode(0, abi.encode(WETH, USDT, 0))
        );
    }

    function _generateUSDT2WETHSmartSwapData() internal view returns (bytes memory) {
        return _generateSmartSwapData(
            USDT,
            WETH,
            1000 * 10 ** 6,
            address(UniversalUniV3Adapter),
            address(UniversalUniV3Adapter),
            false,
            address(WETH_USDT_UNIV3),
            abi.encode(0, abi.encode(USDT, WETH, 0))
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
            abi.encode(0, abi.encode(WETH, USDT, 0))
        );
    }

    function _generateUSDT2ETHSmartSwapData() internal view returns (bytes memory) {
        return _generateSmartSwapData(
            USDT,
            ETH,
            1000 * 10 ** 6,
            address(UniversalUniV3Adapter),
            address(UniversalUniV3Adapter),
            true,
            address(WETH_USDT_UNIV3),
            abi.encode(0, abi.encode(USDT, WETH, 0))
        );
    }

    function _generateWETH2SAFEMOONSmartSwapData() internal view returns (bytes memory) {
        return _generateSmartSwapData(
            WETH,
            SAFEMOON,
            0.01 * 10 ** 18,
            address(WETH_SAFEMOON_UNIV2),
            address(UniV2Adapter),
            false,
            address(WETH_SAFEMOON_UNIV2),
            "0x"
        );
    }

    function _generateSAFEMOON2WETHSmartSwapData() internal view returns (bytes memory) {
        return _generateSmartSwapData(
            SAFEMOON,
            WETH,
            1 * 10 ** 27,
            address(WETH_SAFEMOON_UNIV2),
            address(UniV2Adapter),
            true,
            address(WETH_SAFEMOON_UNIV2),
            "0x"
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
        bytes memory extraData
    ) internal view returns (bytes memory) {
        SwapInfo memory swapInfo;
        // baseRequest
        swapInfo.baseRequest = _generateBaseRequest(fromToken, toToken, fromTokenAmount);
        // batchesAmount
        swapInfo.batchesAmount = new uint256[](1);
        swapInfo.batchesAmount[0] = fromTokenAmount;
        // batches
        swapInfo.batches = new DexRouter.RouterPath[][](1);
        swapInfo.batches[0] = new DexRouter.RouterPath[](1);
        swapInfo.batches[0][0].mixAdapters = new address[](1);
        swapInfo.batches[0][0].mixAdapters[0] = adapter;
        swapInfo.batches[0][0].assetTo = new address[](1);
        swapInfo.batches[0][0].assetTo[0] = assetTo;
        swapInfo.batches[0][0].rawData = new uint256[](1);
        swapInfo.batches[0][0].rawData[0] = uint256(bytes32(abi.encodePacked(uint8(isReverse ? 0x80 : 0x00), uint88(10000), poolAddress)));
        swapInfo.batches[0][0].extraData = new bytes[](1);
        swapInfo.batches[0][0].extraData[0] = extraData;
        swapInfo.batches[0][0].fromToken = uint256(uint160(fromToken == ETH ? WETH : fromToken));
        // extraData
        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);

        return abi.encodeWithSelector(
            DexRouter.smartSwapTo.selector,
            swapInfo.orderId, arnaud, swapInfo.baseRequest, swapInfo.batchesAmount, swapInfo.batches, swapInfo.extraData
        );
    }
}