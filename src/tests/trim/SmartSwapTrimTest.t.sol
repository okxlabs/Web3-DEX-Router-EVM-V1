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
 *     (1) noTrim + noCommission
 *     (2) 1trimOnlyTrim + noCommission
 *     (3) 1trimOnlyCharge + noCommission
 *     (4) 2trim + noCommission
 *     (5) 1trimOnlyTrim + 1toCommission
 *     (6) 1trimOnlyCharge + 1toCommission
 *     (7) 2trim + 1toCommission
 *     (8) 1trimOnlyTrim + 2toCommission
 *     (9) 1trimOnlyCharge + 2toCommission
 *     (10) 2trim + 2toCommission
 *     (11) 2trim + 2fromCommission
 * condition3:
 *     (1) ERC20 -> TaxToken(SAFEMOON)
 *     (2) TaxToken(SAFEMOON) -> ERC20
 * condition4:
 *     (1) noTrim + noCommission
 *     (2) noTrim + 2fromCommission
 *     (3) notrim + 2toCommission
 *     (4) 2trim + noCommission
 *     (5) 2trim + 2fromCommission
 *     (6) 2trim + 2toCommission
*/
contract SmartSwapTrimTest is TrimAndCommissionTestBase {
    // ==================== ERC20->ERC20 ====================
    // WETH->USDT with noTrim and noCommission
    function test_trim_smartSwapTo_WETH2USDT_noTrim_noCommission() tokenLogAndCheck(WETH, USDT, oneEther, false, false, false, false, false)  public {
        bytes memory swapData = _generateWETH2USDTSmartSwapData();
        (bool success, ) = address(dexRouter).call(swapData);
        require(success, "call failed");
    }

    // WETH->USDT with 1trimOnlyTrim and noCommission
    function test_trim_smartSwapTo_WETH2USDT_1trimOnlyTrim_noCommission() tokenLogAndCheck(WETH, USDT, oneEther, true, false, false, false, false) public {
        bytes memory swapData = _generateWETH2USDTSmartSwapData();
        bytes memory trimData = _generate1TrimOnlyTrimData();
        bytes memory data = bytes.concat(swapData, trimData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // WETH->USDT with 1trimOnlyCharge and noCommission
    function test_trim_smartSwapTo_WETH2USDT_1trimOnlyCharge_noCommission() tokenLogAndCheck(WETH, USDT, oneEther, false, true, false, false, false) public {
        bytes memory swapData = _generateWETH2USDTSmartSwapData();
        bytes memory trimData = _generate1TrimOnlyChargeData();
        bytes memory data = bytes.concat(swapData, trimData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // WETH->USDT with 2trim and noCommission
    function test_trim_smartSwapTo_WETH2USDT_2trim_noCommission() tokenLogAndCheck(WETH, USDT, oneEther, true, true, false, false, false) public {
        bytes memory swapData = _generateWETH2USDTSmartSwapData();
        bytes memory trimData = _generate2TrimData();
        bytes memory data = bytes.concat(swapData, trimData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // WETH->USDT with 1trimOnlyTrim and 1toCommission
    function test_trim_smartSwapTo_WETH2USDT_1trimOnlyTrim_1toCommission() tokenLogAndCheck(WETH, USDT, oneEther, true, false, false, true, false) public {
        bytes memory swapData = _generateWETH2USDTSmartSwapData();
        bytes memory trimData = _generate1TrimOnlyTrimData();
        bytes memory commissionData = _generate1CommissionData(false, USDT);
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // WETH->USDT with 1trimOnlyCharge and 1toCommission
    function test_trim_smartSwapTo_WETH2USDT_1trimOnlyCharge_1toCommission() tokenLogAndCheck(WETH, USDT, oneEther, false, true, false, true, false) public {
        bytes memory swapData = _generateWETH2USDTSmartSwapData();
        bytes memory trimData = _generate1TrimOnlyChargeData();
        bytes memory commissionData = _generate1CommissionData(false, USDT);
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // WETH->USDT with 2trim and 1toCommission
    function test_trim_smartSwapTo_WETH2USDT_2trim_1toCommission() tokenLogAndCheck(WETH, USDT, oneEther, true, true, false, true, false) public {
        bytes memory swapData = _generateWETH2USDTSmartSwapData();
        bytes memory trimData = _generate2TrimData();
        bytes memory commissionData = _generate1CommissionData(false, USDT);
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // WETH->USDT with 1trimOnlyTrim and 2toCommission
    function test_trim_smartSwapTo_WETH2USDT_1trimOnlyTrim_2toCommission() tokenLogAndCheck(WETH, USDT, oneEther, true, false, false, true, true) public {
        bytes memory swapData = _generateWETH2USDTSmartSwapData();
        bytes memory trimData = _generate1TrimOnlyTrimData();
        bytes memory commissionData = _generate2CommissionData(false, USDT);
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // WETH->USDT with 1trimOnlyCharge and 2toCommission
    function test_trim_smartSwapTo_WETH2USDT_1trimOnlyCharge_2toCommission() tokenLogAndCheck(WETH, USDT, oneEther, false, true, false, true, true) public {
        bytes memory swapData = _generateWETH2USDTSmartSwapData();
        bytes memory trimData = _generate1TrimOnlyChargeData();
        bytes memory commissionData = _generate2CommissionData(false, USDT);
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // WETH->USDT with 2trim and 2toCommission
    function test_trim_smartSwapTo_WETH2USDT_2trim_2toCommission() tokenLogAndCheck(WETH, USDT, oneEther, true, true, false, true, true) public {
        bytes memory swapData = _generateWETH2USDTSmartSwapData();
        bytes memory trimData = _generate2TrimData();
        bytes memory commissionData = _generate2CommissionData(false, USDT);
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }
    
    // WETH->USDT with 2trim and 2fromCommission
    function test_trim_smartSwapTo_WETH2USDT_2trim_2fromCommission() tokenLogAndCheck(WETH, USDT, 2 * 10 ** 18, true, true, true, true, true) public {
        bytes memory swapData = _generateWETH2USDTSmartSwapData();
        bytes memory trimData = _generate2TrimData();
        bytes memory commissionData = _generate2CommissionData(true, WETH);
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // USDT->WETH with 1trimOnlyTrim and noCommission
    function test_trim_smartSwapTo_USDT2WETH_1trimOnlyTrim_noCommission() tokenLogAndCheck(USDT, WETH, 1000 * 10 ** 6, true, false, false, false, false) public {
        bytes memory swapData = _generateUSDT2WETHSmartSwapData();
        bytes memory trimData = _generate1TrimOnlyTrimData();
        bytes memory data = bytes.concat(swapData, trimData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // USDT->WETH with 1trimOnlyCharge and noCommission
    function test_trim_smartSwapTo_USDT2WETH_1trimOnlyCharge_noCommission() tokenLogAndCheck(USDT, WETH, 1000 * 10 ** 6, false, true, false, false, false) public {
        bytes memory swapData = _generateUSDT2WETHSmartSwapData();
        bytes memory trimData = _generate1TrimOnlyChargeData();
        bytes memory data = bytes.concat(swapData, trimData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // USDT->WETH with 2trim and noCommission
    function test_trim_smartSwapTo_USDT2WETH_2trim_noCommission() tokenLogAndCheck(USDT, WETH, 1000 * 10 ** 6, true, true, false, false, false) public {
        bytes memory swapData = _generateUSDT2WETHSmartSwapData();
        bytes memory trimData = _generate2TrimData();
        bytes memory data = bytes.concat(swapData, trimData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // USDT->WETH with 1trimOnlyTrim and 1toCommission
    function test_trim_smartSwapTo_USDT2WETH_1trimOnlyTrim_1toCommission() tokenLogAndCheck(USDT, WETH, 1000 * 10 ** 6, true, false, false, true, false) public {
        bytes memory swapData = _generateUSDT2WETHSmartSwapData();
        bytes memory trimData = _generate1TrimOnlyTrimData();
        bytes memory commissionData = _generate1CommissionData(false, WETH);
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // USDT->WETH with 1trimOnlyCharge and 1toCommission
    function test_trim_smartSwapTo_USDT2WETH_1trimOnlyCharge_1toCommission() tokenLogAndCheck(USDT, WETH, 1000 * 10 ** 6, false, true, false, true, false) public {
        bytes memory swapData = _generateUSDT2WETHSmartSwapData();
        bytes memory trimData = _generate1TrimOnlyChargeData();
        bytes memory commissionData = _generate1CommissionData(false, WETH);
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // USDT->WETH with 2trim and 1toCommission
    function test_trim_smartSwapTo_USDT2WETH_2trim_1toCommission() tokenLogAndCheck(USDT, WETH, 1000 * 10 ** 6, true, true, false, true, false) public {
        bytes memory swapData = _generateUSDT2WETHSmartSwapData();
        bytes memory trimData = _generate2TrimData();
        bytes memory commissionData = _generate1CommissionData(false, WETH);
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // USDT->WETH with 1trimOnlyTrim and 2toCommission
    function test_trim_smartSwapTo_USDT2WETH_1trimOnlyTrim_2toCommission() tokenLogAndCheck(USDT, WETH, 1000 * 10 ** 6, true, false, false, true, true) public {
        bytes memory swapData = _generateUSDT2WETHSmartSwapData();
        bytes memory trimData = _generate1TrimOnlyTrimData();
        bytes memory commissionData = _generate2CommissionData(false, WETH);
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // USDT->WETH with 1trimOnlyCharge and 2toCommission
    function test_trim_smartSwapTo_USDT2WETH_1trimOnlyCharge_2toCommission() tokenLogAndCheck(USDT, WETH, 1000 * 10 ** 6, false, true, false, true, true) public {
        bytes memory swapData = _generateUSDT2WETHSmartSwapData();
        bytes memory trimData = _generate1TrimOnlyChargeData();
        bytes memory commissionData = _generate2CommissionData(false, WETH);
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // USDT->WETH with 2trim and 2toCommission
    function test_trim_smartSwapTo_USDT2WETH_2trim_2toCommission() tokenLogAndCheck(USDT, WETH, 1000 * 10 ** 6, true, true, false, true, true) public {
        bytes memory swapData = _generateUSDT2WETHSmartSwapData();
        bytes memory trimData = _generate2TrimData();
        bytes memory commissionData = _generate2CommissionData(false, WETH);
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }
    
    // USDT->WETH with 2trim and 2fromCommission
    function test_trim_smartSwapTo_USDT2WETH_2trim_2fromCommission() tokenLogAndCheck(USDT, WETH, 2 * 10 ** 18, true, true, true, true, true) public {
        bytes memory swapData = _generateUSDT2WETHSmartSwapData();
        bytes memory trimData = _generate2TrimData();
        bytes memory commissionData = _generate2CommissionData(true, USDT);
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // ==================== ETH->ERC20 ====================
    // ETH->ERC20 with noTrim and noCommission
    function test_trim_smartSwapTo_ETH2USDT_noTrim_noCommission() tokenLogAndCheck(ETH, USDT, oneEther, false, false, false, false, false)  public {
        bytes memory swapData = _generateETH2USDTSmartSwapData();
        (bool success, ) = address(dexRouter).call{value: oneEther}(swapData);
        require(success, "call failed");
    }

    // ETH->ERC20 with 1trimOnlyTrim and noCommission
    function test_trim_smartSwapTo_ETH2USDT_1trimOnlyTrim_noCommission() tokenLogAndCheck(ETH, USDT, oneEther, true, false, false, false, false) public {
        bytes memory swapData = _generateETH2USDTSmartSwapData();
        bytes memory trimData = _generate1TrimOnlyTrimData();
        bytes memory data = bytes.concat(swapData, trimData);
        (bool success, ) = address(dexRouter).call{value: oneEther}(data);
        require(success, "call failed");
    }

    // ETH->ERC20 with 1trimOnlyTrim and noCommission
    function test_trim_smartSwapTo_ETH2USDT_1trimOnlyCharge_noCommission() tokenLogAndCheck(ETH, USDT, oneEther, false, true, false, false, false) public {
        bytes memory swapData = _generateETH2USDTSmartSwapData();
        bytes memory trimData = _generate1TrimOnlyChargeData();
        bytes memory data = bytes.concat(swapData, trimData);
        (bool success, ) = address(dexRouter).call{value: oneEther}(data);
        require(success, "call failed");
    }

    // ETH->ERC20 with 2trim and noCommission
    function test_trim_smartSwapTo_ETH2USDT_2trim_noCommission() tokenLogAndCheck(ETH, USDT, oneEther, true, true, false, false, false) public {
        bytes memory swapData = _generateETH2USDTSmartSwapData();
        bytes memory trimData = _generate2TrimData();
        bytes memory data = bytes.concat(swapData, trimData);
        (bool success, ) = address(dexRouter).call{value: oneEther}(data);
        require(success, "call failed");
    }

    // ETH->ERC20 with 1trimOnlyTrim and 1toCommission
    function test_trim_smartSwapTo_ETH2USDT_1trimOnlyTrim_1toCommission() tokenLogAndCheck(ETH, USDT, oneEther, true, false, false, true, false) public {
        bytes memory swapData = _generateETH2USDTSmartSwapData();
        bytes memory trimData = _generate1TrimOnlyTrimData();
        bytes memory commissionData = _generate1CommissionData(false, USDT);
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call{value: oneEther}(data);
        require(success, "call failed");
    }

    // ETH->ERC20 with 1trimOnlyCharge and 1toCommission
    function test_trim_smartSwapTo_ETH2USDT_1trimOnlyCharge_1toCommission() tokenLogAndCheck(ETH, USDT, oneEther, false, true, false, true, false) public {
        bytes memory swapData = _generateETH2USDTSmartSwapData();
        bytes memory trimData = _generate1TrimOnlyChargeData();
        bytes memory commissionData = _generate1CommissionData(false, USDT);
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call{value: oneEther}(data);
        require(success, "call failed");
    }

    // ETH->ERC20 with 2trim and 1toCommission
    function test_trim_smartSwapTo_ETH2USDT_2trim_1toCommission() tokenLogAndCheck(ETH, USDT, oneEther, true, true, false, true, false) public {
        bytes memory swapData = _generateETH2USDTSmartSwapData();
        bytes memory trimData = _generate2TrimData();
        bytes memory commissionData = _generate1CommissionData(false, USDT);
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call{value: oneEther}(data);
        require(success, "call failed");
    }

    // ETH->ERC20 with 1trimOnlyTrim and 2toCommission
    function test_trim_smartSwapTo_ETH2USDT_1trimOnlyTrim_2toCommission() tokenLogAndCheck(ETH, USDT, oneEther, true, false, false, true, true) public {
        bytes memory swapData = _generateETH2USDTSmartSwapData();
        bytes memory trimData = _generate1TrimOnlyTrimData();
        bytes memory commissionData = _generate2CommissionData(false, USDT);
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call{value: oneEther}(data);
        require(success, "call failed");
    }

    // ETH->ERC20 with 1trimOnlyCharge and 2toCommission
    function test_trim_smartSwapTo_ETH2USDT_1trimOnlyCharge_2toCommission() tokenLogAndCheck(ETH, USDT, oneEther, false, true, false, true, true) public {
        bytes memory swapData = _generateETH2USDTSmartSwapData();
        bytes memory trimData = _generate1TrimOnlyChargeData();
        bytes memory commissionData = _generate2CommissionData(false, USDT);
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call{value: oneEther}(data);
        require(success, "call failed");
    }

    // ETH->ERC20 with 2trim and 2toCommission
    function test_trim_smartSwapTo_ETH2USDT_2trim_2toCommission() tokenLogAndCheck(ETH, USDT, oneEther, true, true, false, true, true) public {
        bytes memory swapData = _generateETH2USDTSmartSwapData();
        bytes memory trimData = _generate2TrimData();
        bytes memory commissionData = _generate2CommissionData(false, USDT);
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call{value: oneEther}(data);
        require(success, "call failed");
    }
    
    // ETH->ERC20 with 2trim and 2fromCommission
    function test_trim_smartSwapTo_ETH2USDT_2trim_2fromCommission() tokenLogAndCheck(ETH, USDT, 2 * 10 ** 18, true, true, true, true, true) public {
        bytes memory swapData = _generateETH2USDTSmartSwapData();
        bytes memory trimData = _generate2TrimData();
        bytes memory commissionData = _generate2CommissionData(true, ETH);
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call{value: 2 * 10 ** 18}(data);
        require(success, "call failed");
    }

    // ==================== ERC20->ETH ====================
    // ERC20->ETH with noTrim and noCommission
    function test_trim_smartSwapTo_USDT2ETH_noTrim_noCommission() tokenLogAndCheck(USDT, ETH, 1000 * 10 ** 6, false, false, false, false, false)  public {
        bytes memory swapData = _generateUSDT2ETHSmartSwapData();
        (bool success, ) = address(dexRouter).call(swapData);
        require(success, "call failed");
    }

    // ERC20->ETH with 1trimOnlyTrim and noCommission
    function test_trim_smartSwapTo_USDT2ETH_1trimOnlyTrim_noCommission() tokenLogAndCheck(USDT, ETH, 1000 * 10 ** 6, true, false, false, false, false) public {
        bytes memory swapData = _generateUSDT2ETHSmartSwapData();
        bytes memory trimData = _generate1TrimOnlyTrimData();
        bytes memory data = bytes.concat(swapData, trimData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // ERC20->ETH with 1trimOnlyCharge and noCommission
    function test_trim_smartSwapTo_USDT2ETH_1trimOnlyCharge_noCommission() tokenLogAndCheck(USDT, ETH, 1000 * 10 ** 6, false, true, false, false, false) public {
        bytes memory swapData = _generateUSDT2ETHSmartSwapData();
        bytes memory trimData = _generate1TrimOnlyChargeData();
        bytes memory data = bytes.concat(swapData, trimData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // ERC20->ETH with 2trim and noCommission
    function test_trim_smartSwapTo_USDT2ETH_2trim_noCommission() tokenLogAndCheck(USDT, ETH, 1000 * 10 ** 6, true, true, false, false, false) public {
        bytes memory swapData = _generateUSDT2ETHSmartSwapData();
        bytes memory trimData = _generate2TrimData();
        bytes memory data = bytes.concat(swapData, trimData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // ERC20->ETH with 1trimOnlyTrim and 1toCommission
    function test_trim_smartSwapTo_USDT2ETH_1trimOnlyTrim_1toCommission() tokenLogAndCheck(USDT, ETH, 1000 * 10 ** 6, true, false, false, true, false) public {
        bytes memory swapData = _generateUSDT2ETHSmartSwapData();
        bytes memory trimData = _generate1TrimOnlyTrimData();
        bytes memory commissionData = _generate1CommissionData(false, ETH);
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // ERC20->ETH with 1trimOnlyCharge and 1toCommission
    function test_trim_smartSwapTo_USDT2ETH_1trimOnlyCharge_1toCommission() tokenLogAndCheck(USDT, ETH, 1000 * 10 ** 6, false, true, false, true, false) public {
        bytes memory swapData = _generateUSDT2ETHSmartSwapData();
        bytes memory trimData = _generate1TrimOnlyChargeData();
        bytes memory commissionData = _generate1CommissionData(false, ETH);
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // ERC20->ETH with 2trim and 1toCommission
    function test_trim_smartSwapTo_USDT2ETH_2trim_1toCommission() tokenLogAndCheck(USDT, ETH, 1000 * 10 ** 6, true, true, false, true, false) public {
        bytes memory swapData = _generateUSDT2ETHSmartSwapData();
        bytes memory trimData = _generate2TrimData();
        bytes memory commissionData = _generate1CommissionData(false, ETH);
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // ERC20->ETH with 1trimOnlyTrim and 2toCommission
    function test_trim_smartSwapTo_USDT2ETH_1trimOnlyTrim_2toCommission() tokenLogAndCheck(USDT, ETH, 1000 * 10 ** 6, true, false, false, true, true) public {
        bytes memory swapData = _generateUSDT2ETHSmartSwapData();
        bytes memory trimData = _generate1TrimOnlyTrimData();
        bytes memory commissionData = _generate2CommissionData(false, ETH);
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // ERC20->ETH with 1trimOnlyCharge and 2toCommission
    function test_trim_smartSwapTo_USDT2ETH_1trimOnlyCharge_2toCommission() tokenLogAndCheck(USDT, ETH, 1000 * 10 ** 6, false, true, false, true, true) public {
        bytes memory swapData = _generateUSDT2ETHSmartSwapData();
        bytes memory trimData = _generate1TrimOnlyChargeData();
        bytes memory commissionData = _generate2CommissionData(false, ETH);
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // ERC20->ETH with 2trim and 2toCommission
    function test_trim_smartSwapTo_USDT2ETH_2trim_2toCommission() tokenLogAndCheck(USDT, ETH, 1000 * 10 ** 6, true, true, false, true, true) public {
        bytes memory swapData = _generateUSDT2ETHSmartSwapData();
        bytes memory trimData = _generate2TrimData();
        bytes memory commissionData = _generate2CommissionData(false, ETH);
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }
    
    // ERC20->ETH with 2trim and 2fromCommission
    function test_trim_smartSwapTo_USDT2ETH_2trim_2fromCommission() tokenLogAndCheck(USDT, ETH, 2000 * 10 ** 6, true, true, true, true, true) public {
        bytes memory swapData = _generateUSDT2ETHSmartSwapData();
        bytes memory trimData = _generate2TrimData();
        bytes memory commissionData = _generate2CommissionData(true, USDT);
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // ================= ERC20->TaxToken(SAFEMOON) ================
    // ERC20->TaxToken(SAFEMOON) with noTrim and noCommission
    function test_trim_smartSwapTo_WETH2SAFEMOON_noTrim_noCommission() tokenLogAndCheck(WETH, SAFEMOON, 0.01 * 10 ** 18, false, false, false, false, false) public {
        bytes memory swapData = _generateWETH2SAFEMOONSmartSwapData();
        (bool success, ) = address(dexRouter).call(swapData);
        require(success, "call failed");
    }

    // ERC20->TaxToken(SAFEMOON) with noTrim and 2fromCommission
    function test_trim_smartSwapTo_WETH2SAFEMOON_noTrim_2fromCommission() tokenLogAndCheck(WETH, SAFEMOON, 0.02 * 10 ** 18, false, false, true, true, true) public {
        bytes memory swapData = _generateWETH2SAFEMOONSmartSwapData();
        bytes memory commissionData = _generate2CommissionData(true, WETH);
        bytes memory data = bytes.concat(swapData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // ERC20->TaxToken(SAFEMOON) with noTrim and 2toCommission
    function test_trim_smartSwapTo_WETH2SAFEMOON_noTrim_2toCommission() tokenLogAndCheck(WETH, SAFEMOON, 0.01 * 10 ** 18, false, false, false, true, true) public {
        bytes memory swapData = _generateWETH2SAFEMOONSmartSwapData();
        bytes memory commissionData = _generate2CommissionData(false, SAFEMOON);
        bytes memory data = bytes.concat(swapData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // ERC20->TaxToken(SAFEMOON) with 2trim and noCommission
    function test_trim_smartSwapTo_WETH2SAFEMOON_2trim_noCommission() tokenLogAndCheck(WETH, SAFEMOON, 0.01 * 10 ** 18, true, true, false, false, false) public {
        bytes memory swapData = _generateWETH2SAFEMOONSmartSwapData();
        bytes memory trimData = _generate2TrimData();
        bytes memory data = bytes.concat(swapData, trimData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // ERC20->TaxToken(SAFEMOON) with 2trim and 2fromCommission
    function test_trim_smartSwapTo_WETH2SAFEMOON_2trim_2fromCommission() tokenLogAndCheck(WETH, SAFEMOON, 0.02 * 10 ** 18, true, true, true, true, true) public {
        bytes memory swapData = _generateWETH2SAFEMOONSmartSwapData();
        bytes memory trimData = _generate2TrimData();
        bytes memory commissionData = _generate2CommissionData(true, WETH);
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // ERC20->TaxToken(SAFEMOON) with 2trim and 2toCommission
    function test_trim_smartSwapTo_WETH2SAFEMOON_2trim_2toCommission() tokenLogAndCheck(WETH, SAFEMOON, 0.01 * 10 ** 18, true, true, false, true, true) public {
        bytes memory swapData = _generateWETH2SAFEMOONSmartSwapData();
        bytes memory trimData = _generate2TrimData();
        bytes memory commissionData = _generate2CommissionData(false, SAFEMOON);
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // ==================== TaxToken(SAFEMOON)->ERC20 ====================
    // TaxToken(SAFEMOON)->ERC20 with noTrim and noCommission
    function test_trim_smartSwapTo_SAFEMOON2WETH_noTrim_noCommission() tokenLogAndCheck(SAFEMOON, WETH, 1 * 10 ** 27, false, false, false, false, false) public {
        bytes memory swapData = _generateSAFEMOON2WETHSmartSwapData();
        (bool success, ) = address(dexRouter).call(swapData);
        require(success, "call failed");
    }

    // TaxToken(SAFEMOON)->ERC20 with noTrim and 2fromCommission
    function test_trim_smartSwapTo_SAFEMOON2WETH_noTrim_2fromCommission() tokenLogAndCheck(SAFEMOON, WETH, 2 * 10 ** 27, false, false, true, true, true) public {
        bytes memory swapData = _generateSAFEMOON2WETHSmartSwapData();
        bytes memory commissionData = _generate2CommissionData(true, SAFEMOON);
        bytes memory data = bytes.concat(swapData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // TaxToken(SAFEMOON)->ERC20 with noTrim and 2toCommission
    function test_trim_smartSwapTo_SAFEMOON2WETH_noTrim_2toCommission() tokenLogAndCheck(SAFEMOON, WETH, 1 * 10 ** 27, false, false, false, true, true) public {
        bytes memory swapData = _generateSAFEMOON2WETHSmartSwapData();
        bytes memory commissionData = _generate2CommissionData(false, WETH);
        bytes memory data = bytes.concat(swapData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // TaxToken(SAFEMOON)->ERC20 with 2trim and noCommission
    function test_trim_smartSwapTo_SAFEMOON2WETH_2trim_noCommission() tokenLogAndCheck(SAFEMOON, WETH, 1 * 10 ** 27, true, true, false, false, false) public {
        bytes memory swapData = _generateSAFEMOON2WETHSmartSwapData();
        bytes memory trimData = _generate2TrimData();
        bytes memory data = bytes.concat(swapData, trimData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }
    
    // TaxToken(SAFEMOON)->ERC20 with 2trim and 2fromCommission
    function test_trim_smartSwapTo_SAFEMOON2WETH_2trim_2fromCommission() tokenLogAndCheck(SAFEMOON, WETH, 2 * 10 ** 27, true, true, true, true, true) public {
        bytes memory swapData = _generateSAFEMOON2WETHSmartSwapData();
        bytes memory trimData = _generate2TrimData();
        bytes memory commissionData = _generate2CommissionData(true, SAFEMOON);
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // TaxToken(SAFEMOON)->ERC20 with 2trim and 2toCommission
    function test_trim_smartSwapTo_SAFEMOON2WETH_2trim_2toCommission() tokenLogAndCheck(SAFEMOON, WETH, 1 * 10 ** 27, true, true, false, true, true) public {
        bytes memory swapData = _generateSAFEMOON2WETHSmartSwapData();
        bytes memory trimData = _generate2TrimData();
        bytes memory commissionData = _generate2CommissionData(false, WETH);
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // ==================== Internal Functions ====================
    function _generateWETH2USDTSmartSwapData() internal view returns (bytes memory) {
        SwapInfo memory swapInfo;
        // baseRequest
        swapInfo.baseRequest = _generateBaseRequest(WETH, USDT, oneEther);
        // batchesAmount
        swapInfo.batchesAmount = new uint256[](1);
        swapInfo.batchesAmount[0] = oneEther;
        // batches
        swapInfo.batches = new DexRouter.RouterPath[][](1);
        swapInfo.batches[0] = new DexRouter.RouterPath[](1);
        swapInfo.batches[0][0].mixAdapters = new address[](1);
        swapInfo.batches[0][0].mixAdapters[0] = address(UniversalUniV3Adapter);
        swapInfo.batches[0][0].assetTo = new address[](1);
        swapInfo.batches[0][0].assetTo[0] = address(UniversalUniV3Adapter);
        swapInfo.batches[0][0].rawData = new uint256[](1);
        swapInfo.batches[0][0].rawData[0] = uint256(bytes32(abi.encodePacked(uint8(0x00), uint88(10000), address(WETH_USDT_UNIV3))));
        swapInfo.batches[0][0].extraData = new bytes[](1);
        swapInfo.batches[0][0].extraData[0] = abi.encode(0, abi.encode(WETH, USDT, 0));
        swapInfo.batches[0][0].fromToken = uint256(uint160(WETH));
        // extraData
        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);

        return abi.encodeWithSelector(
            DexRouter.smartSwapTo.selector,
            swapInfo.orderId, arnaud, swapInfo.baseRequest, swapInfo.batchesAmount, swapInfo.batches, swapInfo.extraData
        );
    }

    function _generateUSDT2WETHSmartSwapData() internal view returns (bytes memory) {
        SwapInfo memory swapInfo;
        // baseRequest
        swapInfo.baseRequest = _generateBaseRequest(USDT, WETH, oneEther);
        // batchesAmount
        swapInfo.batchesAmount = new uint256[](1);
        swapInfo.batchesAmount[0] = 1000 * 10 ** 6;
        // batches
        swapInfo.batches = new DexRouter.RouterPath[][](1);
        swapInfo.batches[0] = new DexRouter.RouterPath[](1);
        swapInfo.batches[0][0].mixAdapters = new address[](1);
        swapInfo.batches[0][0].mixAdapters[0] = address(UniversalUniV3Adapter);
        swapInfo.batches[0][0].assetTo = new address[](1);
        swapInfo.batches[0][0].assetTo[0] = address(UniversalUniV3Adapter);
        swapInfo.batches[0][0].rawData = new uint256[](1);
        swapInfo.batches[0][0].rawData[0] = uint256(bytes32(abi.encodePacked(uint8(0x00), uint88(10000), address(WETH_USDT_UNIV3))));
        swapInfo.batches[0][0].extraData = new bytes[](1);
        swapInfo.batches[0][0].extraData[0] = abi.encode(0, abi.encode(USDT, WETH, 0));
        swapInfo.batches[0][0].fromToken = uint256(uint160(USDT));
        // extraData
        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);

        return abi.encodeWithSelector(
            DexRouter.smartSwapTo.selector,
            swapInfo.orderId, arnaud, swapInfo.baseRequest, swapInfo.batchesAmount, swapInfo.batches, swapInfo.extraData
        );
    }

    function _generateETH2USDTSmartSwapData() internal view returns (bytes memory) {
        SwapInfo memory swapInfo;
        // baseRequest
        swapInfo.baseRequest = _generateBaseRequest(ETH, USDT, oneEther);
        // batchesAmount
        swapInfo.batchesAmount = new uint256[](1);
        swapInfo.batchesAmount[0] = oneEther;
        // batches
        swapInfo.batches = new DexRouter.RouterPath[][](1);
        swapInfo.batches[0] = new DexRouter.RouterPath[](1);
        swapInfo.batches[0][0].mixAdapters = new address[](1);
        swapInfo.batches[0][0].mixAdapters[0] = address(UniversalUniV3Adapter);
        swapInfo.batches[0][0].assetTo = new address[](1);
        swapInfo.batches[0][0].assetTo[0] = address(UniversalUniV3Adapter);
        swapInfo.batches[0][0].rawData = new uint256[](1);
        swapInfo.batches[0][0].rawData[0] = uint256(bytes32(abi.encodePacked(uint8(0x00), uint88(10000), address(WETH_USDT_UNIV3))));
        swapInfo.batches[0][0].extraData = new bytes[](1);
        swapInfo.batches[0][0].extraData[0] = abi.encode(0, abi.encode(WETH, USDT, 0));
        swapInfo.batches[0][0].fromToken = uint256(uint160(WETH));
        // extraData
        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);

        return abi.encodeWithSelector(
            DexRouter.smartSwapTo.selector,
            swapInfo.orderId, arnaud, swapInfo.baseRequest, swapInfo.batchesAmount, swapInfo.batches, swapInfo.extraData
        ); 
    }

    function _generateUSDT2ETHSmartSwapData() internal view returns (bytes memory) {
        SwapInfo memory swapInfo;
        // baseRequest
        swapInfo.baseRequest = _generateBaseRequest(USDT, ETH, 1000 * 10 ** 6);
        // batchesAmount
        swapInfo.batchesAmount = new uint256[](1);
        swapInfo.batchesAmount[0] = 1000 * 10 ** 6;
        // batches
        swapInfo.batches = new DexRouter.RouterPath[][](1);
        swapInfo.batches[0] = new DexRouter.RouterPath[](1);
        swapInfo.batches[0][0].mixAdapters = new address[](1);
        swapInfo.batches[0][0].mixAdapters[0] = address(UniversalUniV3Adapter);
        swapInfo.batches[0][0].assetTo = new address[](1);
        swapInfo.batches[0][0].assetTo[0] = address(UniversalUniV3Adapter);
        swapInfo.batches[0][0].rawData = new uint256[](1);
        swapInfo.batches[0][0].rawData[0] = uint256(bytes32(abi.encodePacked(uint8(0x80), uint88(10000), address(WETH_USDT_UNIV3))));
        swapInfo.batches[0][0].extraData = new bytes[](1);
        swapInfo.batches[0][0].extraData[0] = abi.encode(0, abi.encode(USDT, WETH, 0));
        swapInfo.batches[0][0].fromToken = uint256(uint160(USDT));
        // extraData
        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);

        return abi.encodeWithSelector(
            DexRouter.smartSwapTo.selector,
            swapInfo.orderId, arnaud, swapInfo.baseRequest, swapInfo.batchesAmount, swapInfo.batches, swapInfo.extraData
        ); 
    }

    function _generateWETH2SAFEMOONSmartSwapData() internal view returns (bytes memory) {
        SwapInfo memory swapInfo;
        // baseRequest
        swapInfo.baseRequest = _generateBaseRequest(WETH, SAFEMOON, 0.01 * 10 ** 18);
        // batchesAmount
        swapInfo.batchesAmount = new uint256[](1);
        swapInfo.batchesAmount[0] = 0.01 * 10 ** 18;
        // batches
        swapInfo.batches = new DexRouter.RouterPath[][](1);
        swapInfo.batches[0] = new DexRouter.RouterPath[](1);
        swapInfo.batches[0][0].mixAdapters = new address[](1);
        swapInfo.batches[0][0].mixAdapters[0] = address(UniV2Adapter);
        swapInfo.batches[0][0].assetTo = new address[](1);
        swapInfo.batches[0][0].assetTo[0] = address(WETH_SAFEMOON_UNIV2);
        swapInfo.batches[0][0].rawData = new uint256[](1);
        swapInfo.batches[0][0].rawData[0] = uint256(bytes32(abi.encodePacked(uint8(0x00), uint88(10000), address(WETH_SAFEMOON_UNIV2))));
        swapInfo.batches[0][0].extraData = new bytes[](1);
        swapInfo.batches[0][0].fromToken = uint256(uint160(WETH));
        // extraData
        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);

        return abi.encodeWithSelector(
            DexRouter.smartSwapTo.selector,
            swapInfo.orderId, arnaud, swapInfo.baseRequest, swapInfo.batchesAmount, swapInfo.batches, swapInfo.extraData
        );
    }

    function _generateSAFEMOON2WETHSmartSwapData() internal view returns (bytes memory) {
        SwapInfo memory swapInfo;
        // baseRequest
        swapInfo.baseRequest = _generateBaseRequest(SAFEMOON, WETH, 1 * 10 ** 27);
        // batchesAmount
        swapInfo.batchesAmount = new uint256[](1);
        swapInfo.batchesAmount[0] = 1 * 10 ** 27;
        // batches
        swapInfo.batches = new DexRouter.RouterPath[][](1);
        swapInfo.batches[0] = new DexRouter.RouterPath[](1);
        swapInfo.batches[0][0].mixAdapters = new address[](1);
        swapInfo.batches[0][0].mixAdapters[0] = address(UniV2Adapter);
        swapInfo.batches[0][0].assetTo = new address[](1);
        swapInfo.batches[0][0].assetTo[0] = address(WETH_SAFEMOON_UNIV2);
        swapInfo.batches[0][0].rawData = new uint256[](1);
        swapInfo.batches[0][0].rawData[0] = uint256(bytes32(abi.encodePacked(uint8(0x80), uint88(10000), address(WETH_SAFEMOON_UNIV2))));
        swapInfo.batches[0][0].extraData = new bytes[](1);
        swapInfo.batches[0][0].fromToken = uint256(uint160(SAFEMOON));
        // extraData
        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);

        return abi.encodeWithSelector(
            DexRouter.smartSwapTo.selector,
            swapInfo.orderId, arnaud, swapInfo.baseRequest, swapInfo.batchesAmount, swapInfo.batches, swapInfo.extraData
        );
    }
}