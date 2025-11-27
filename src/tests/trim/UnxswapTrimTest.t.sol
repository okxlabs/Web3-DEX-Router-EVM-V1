// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../common/TrimAndCommissionTestBase.t.sol";

/*
 * The unxswap method is tested with condition1 * condition2:
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
*/
contract UnxswapTrimTest is TrimAndCommissionTestBase {

    // ==================== ERC20->ERC20 ====================
    // ERC20->ERC20 with noTrim and noCommission
    function test_trim_unxswapTo_WETH2USDT_noTrim_noCommission() tokenLogAndCheck(WETH, USDT, oneEther, false, false, false, false, false)  public {
        bytes memory swapData = _generateWETH2USDTUnxswapData();
        (bool success, ) = address(dexRouter).call(swapData);
        require(success, "call failed");
    }

    // ERC20->ERC20 with 1trimOnlyTrim and noCommission
    function test_trim_unxswapTo_WETH2USDT_1trimOnlyTrim_noCommission() tokenLogAndCheck(WETH, USDT, oneEther, true, false, false, false, false) public {
        bytes memory swapData = _generateWETH2USDTUnxswapData();
        bytes memory trimData = _generate1TrimOnlyTrimData();
        bytes memory data = bytes.concat(swapData, trimData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // ERC20->ERC20 with 1trimOnlyCharge and noCommission
    function test_trim_unxswapTo_WETH2USDT_1trimOnlyCharge_noCommission() tokenLogAndCheck(WETH, USDT, oneEther, false, true, false, false, false) public {
        bytes memory swapData = _generateWETH2USDTUnxswapData();
        bytes memory trimData = _generate1TrimOnlyChargeData();
        bytes memory data = bytes.concat(swapData, trimData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // ERC20->ERC20 with 2trim and noCommission
    function test_trim_unxswapTo_WETH2USDT_2trim_noCommission() tokenLogAndCheck(WETH, USDT, oneEther, true, true, false, false, false) public {
        bytes memory swapData = _generateWETH2USDTUnxswapData();
        bytes memory trimData = _generate2TrimData();
        bytes memory data = bytes.concat(swapData, trimData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // ERC20->ERC20 with 1trimOnlyTrim and 1toCommission
    function test_trim_unxswapTo_WETH2USDT_1trimOnlyTrim_1toCommission() tokenLogAndCheck(WETH, USDT, oneEther, true, false, false, true, false) public {
        bytes memory swapData = _generateWETH2USDTUnxswapData();
        bytes memory trimData = _generate1TrimOnlyTrimData();
        bytes memory commissionData = _generate1CommissionData(false, USDT);
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // ERC20->ERC20 with 1trimOnlyCharge and 1toCommission
    function test_trim_unxswapTo_WETH2USDT_1trimOnlyCharge_1toCommission() tokenLogAndCheck(WETH, USDT, oneEther, false, true, false, true, false) public {
        bytes memory swapData = _generateWETH2USDTUnxswapData();
        bytes memory trimData = _generate1TrimOnlyChargeData();
        bytes memory commissionData = _generate1CommissionData(false, USDT);
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // ERC20->ERC20 with 2trim and 1toCommission
    function test_trim_unxswapTo_WETH2USDT_2trim_1toCommission() tokenLogAndCheck(WETH, USDT, oneEther, true, true, false, true, false) public {
        bytes memory swapData = _generateWETH2USDTUnxswapData();
        bytes memory trimData = _generate2TrimData();
        bytes memory commissionData = _generate1CommissionData(false, USDT);
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // ERC20->ERC20 with 1trimOnlyTrim and 2toCommission
    function test_trim_unxswapTo_WETH2USDT_1trimOnlyTrim_2toCommission() tokenLogAndCheck(WETH, USDT, oneEther, true, false, false, true, true) public {
        bytes memory swapData = _generateWETH2USDTUnxswapData();
        bytes memory trimData = _generate1TrimOnlyTrimData();
        bytes memory commissionData = _generate2CommissionData(false, USDT);
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // ERC20->ERC20 with 1trimOnlyCharge and 2toCommission
    function test_trim_unxswapTo_WETH2USDT_1trimOnlyCharge_2toCommission() tokenLogAndCheck(WETH, USDT, oneEther, false, true, false, true, true) public {
        bytes memory swapData = _generateWETH2USDTUnxswapData();
        bytes memory trimData = _generate1TrimOnlyChargeData();
        bytes memory commissionData = _generate2CommissionData(false, USDT);
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // ERC20->ERC20 with 2trim and 2toCommission
    function test_trim_unxswapTo_WETH2USDT_2trim_2toCommission() tokenLogAndCheck(WETH, USDT, oneEther, true, true, false, true, true) public {
        bytes memory swapData = _generateWETH2USDTUnxswapData();
        bytes memory trimData = _generate2TrimData();
        bytes memory commissionData = _generate2CommissionData(false, USDT);
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }
    
    // ERC20->ERC20 with 2trim and 2fromCommission
    function test_trim_unxswapTo_WETH2USDT_2trim_2fromCommission() tokenLogAndCheck(WETH, USDT, 2 * 10 ** 18, true, true, true, true, true) public {
        bytes memory swapData = _generateWETH2USDTUnxswapData();
        bytes memory trimData = _generate2TrimData();
        bytes memory commissionData = _generate2CommissionData(true, WETH);
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // ==================== ETH->ERC20 ====================
    // ETH->ERC20 with noTrim and noCommission
    function test_trim_unxswapTo_ETH2USDT_noTrim_noCommission() tokenLogAndCheck(ETH, USDT, oneEther, false, false, false, false, false)  public {
        bytes memory swapData = _generateETH2USDTUnxswapData();
        (bool success, ) = address(dexRouter).call{value: oneEther}(swapData);
        require(success, "call failed");
    }

    // ETH->ERC20 with 1trimOnlyTrim and noCommission
    function test_trim_unxswapTo_ETH2USDT_1trimOnlyTrim_noCommission() tokenLogAndCheck(ETH, USDT, oneEther, true, false, false, false, false) public {
        bytes memory swapData = _generateETH2USDTUnxswapData();
        bytes memory trimData = _generate1TrimOnlyTrimData();
        bytes memory data = bytes.concat(swapData, trimData);
        (bool success, ) = address(dexRouter).call{value: oneEther}(data);
        require(success, "call failed");
    }

    // ETH->ERC20 with 1trimOnlyCharge and noCommission
    function test_trim_unxswapTo_ETH2USDT_1trimOnlyCharge_noCommission() tokenLogAndCheck(ETH, USDT, oneEther, false, true, false, false, false) public {
        bytes memory swapData = _generateETH2USDTUnxswapData();
        bytes memory trimData = _generate1TrimOnlyChargeData();
        bytes memory data = bytes.concat(swapData, trimData);
        (bool success, ) = address(dexRouter).call{value: oneEther}(data);
        require(success, "call failed");
    }

    // ETH->ERC20 with 2trim and noCommission
    function test_trim_unxswapTo_ETH2USDT_2trim_noCommission() tokenLogAndCheck(ETH, USDT, oneEther, true, true, false, false, false) public {
        bytes memory swapData = _generateETH2USDTUnxswapData();
        bytes memory trimData = _generate2TrimData();
        bytes memory data = bytes.concat(swapData, trimData);
        (bool success, ) = address(dexRouter).call{value: oneEther}(data);
        require(success, "call failed");
    }

    // ETH->ERC20 with 1trimOnlyTrim and 1toCommission
    function test_trim_unxswapTo_ETH2USDT_1trimOnlyTrim_1toCommission() tokenLogAndCheck(ETH, USDT, oneEther, true, false, false, true, false) public {
        bytes memory swapData = _generateETH2USDTUnxswapData();
        bytes memory trimData = _generate1TrimOnlyTrimData();
        bytes memory commissionData = _generate1CommissionData(false, USDT);
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call{value: oneEther}(data);
        require(success, "call failed");
    }

    // ETH->ERC20 with 1trimOnlyCharge and 1toCommission
    function test_trim_unxswapTo_ETH2USDT_1trimOnlyCharge_1toCommission() tokenLogAndCheck(ETH, USDT, oneEther, false, true, false, true, false) public {
        bytes memory swapData = _generateETH2USDTUnxswapData();
        bytes memory trimData = _generate1TrimOnlyChargeData();
        bytes memory commissionData = _generate1CommissionData(false, USDT);
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call{value: oneEther}(data);
        require(success, "call failed");
    }

    // ETH->ERC20 with 2trim and 1toCommission
    function test_trim_unxswapTo_ETH2USDT_2trim_1toCommission() tokenLogAndCheck(ETH, USDT, oneEther, true, true, false, true, false) public {
        bytes memory swapData = _generateETH2USDTUnxswapData();
        bytes memory trimData = _generate2TrimData();
        bytes memory commissionData = _generate1CommissionData(false, USDT);
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call{value: oneEther}(data);
        require(success, "call failed");
    }

    // ETH->ERC20 with 1trimOnlyTrim and 2toCommission
    function test_trim_unxswapTo_ETH2USDT_1trimOnlyTrim_2toCommission() tokenLogAndCheck(ETH, USDT, oneEther, true, false, false, true, true) public {
        bytes memory swapData = _generateETH2USDTUnxswapData();
        bytes memory trimData = _generate1TrimOnlyTrimData();
        bytes memory commissionData = _generate2CommissionData(false, USDT);
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call{value: oneEther}(data);
        require(success, "call failed");
    }

    // ETH->ERC20 with 1trimOnlyCharge and 2toCommission
    function test_trim_unxswapTo_ETH2USDT_1trimOnlyCharge_2toCommission() tokenLogAndCheck(ETH, USDT, oneEther, false, true, false, true, true) public {
        bytes memory swapData = _generateETH2USDTUnxswapData();
        bytes memory trimData = _generate1TrimOnlyChargeData();
        bytes memory commissionData = _generate2CommissionData(false, USDT);
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call{value: oneEther}(data);
        require(success, "call failed");
    }

    // ETH->ERC20 with 2trim and 2toCommission
    function test_trim_unxswapTo_ETH2USDT_2trim_2toCommission() tokenLogAndCheck(ETH, USDT, oneEther, true, true, false, true, true) public {
        bytes memory swapData = _generateETH2USDTUnxswapData();
        bytes memory trimData = _generate2TrimData();
        bytes memory commissionData = _generate2CommissionData(false, USDT);
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call{value: oneEther}(data);
        require(success, "call failed");
    }
    
    // ETH->ERC20 with 2trim and 2fromCommission
    function test_trim_unxswapTo_ETH2USDT_2trim_2fromCommission() tokenLogAndCheck(ETH, USDT, 2 * 10 ** 18, true, true, true, true, true) public {
        bytes memory swapData = _generateETH2USDTUnxswapData();
        bytes memory trimData = _generate2TrimData();
        bytes memory commissionData = _generate2CommissionData(true, ETH);
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call{value: 2 * 10 ** 18}(data);
        require(success, "call failed");
    }

    // ETH->ERC20 with 2trim and 2fromCommission
    function test_trim_unxswapTo_ETH2USDT_2trim_2fromCommission_ETHisAddressE() tokenLogAndCheck(ETH, USDT, 2 * 10 ** 18, true, true, true, true, true) public {
        bytes memory swapData = _generateETH2USDTUnxswapData2();
        bytes memory trimData = _generate2TrimData();
        bytes memory commissionData = _generate2CommissionData(true, ETH);
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call{value: 2 * 10 ** 18}(data);
        require(success, "call failed");
    }

    // ==================== ERC20->ETH ====================
    // ERC20->ETH with noTrim and noCommission
    function test_trim_unxswapTo_USDT2ETH_noTrim_noCommission() tokenLogAndCheck(USDT, ETH, 1000 * 10 ** 6, false, false, false, false, false)  public {
        bytes memory swapData = _generateUSDT2ETHUnxswapData();
        (bool success, ) = address(dexRouter).call(swapData);
        require(success, "call failed");
    }

    // ERC20->ETH with 1trimOnlyTrim and noCommission
    function test_trim_unxswapTo_USDT2ETH_1trimOnlyTrim_noCommission() tokenLogAndCheck(USDT, ETH, 1000 * 10 ** 6, true, false, false, false, false) public {
        bytes memory swapData = _generateUSDT2ETHUnxswapData();
        bytes memory trimData = _generate1TrimOnlyTrimData();
        bytes memory data = bytes.concat(swapData, trimData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // ERC20->ETH with 1trimOnlyCharge and noCommission
    function test_trim_unxswapTo_USDT2ETH_1trimOnlyCharge_noCommission() tokenLogAndCheck(USDT, ETH, 1000 * 10 ** 6, false, true, false, false, false) public {
        bytes memory swapData = _generateUSDT2ETHUnxswapData();
        bytes memory trimData = _generate1TrimOnlyChargeData();
        bytes memory data = bytes.concat(swapData, trimData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // ERC20->ETH with 2trim and noCommission
    function test_trim_unxswapTo_USDT2ETH_2trim_noCommission() tokenLogAndCheck(USDT, ETH, 1000 * 10 ** 6, true, true, false, false, false) public {
        bytes memory swapData = _generateUSDT2ETHUnxswapData();
        bytes memory trimData = _generate2TrimData();
        bytes memory data = bytes.concat(swapData, trimData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // ERC20->ETH with 1trimOnlyTrim and 1toCommission
    function test_trim_unxswapTo_USDT2ETH_1trimOnlyTrim_1toCommission() tokenLogAndCheck(USDT, ETH, 1000 * 10 ** 6, true, false, false, true, false) public {
        bytes memory swapData = _generateUSDT2ETHUnxswapData();
        bytes memory trimData = _generate1TrimOnlyTrimData();
        bytes memory commissionData = _generate1CommissionData(false, ETH);
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // ERC20->ETH with 1trimOnlyCharge and 1toCommission
    function test_trim_unxswapTo_USDT2ETH_1trimOnlyCharge_1toCommission() tokenLogAndCheck(USDT, ETH, 1000 * 10 ** 6, false, true, false, true, false) public {
        bytes memory swapData = _generateUSDT2ETHUnxswapData();
        bytes memory trimData = _generate1TrimOnlyChargeData();
        bytes memory commissionData = _generate1CommissionData(false, ETH);
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // ERC20->ETH with 2trim and 1toCommission
    function test_trim_unxswapTo_USDT2ETH_2trim_1toCommission() tokenLogAndCheck(USDT, ETH, 1000 * 10 ** 6, true, true, false, true, false) public {
        bytes memory swapData = _generateUSDT2ETHUnxswapData();
        bytes memory trimData = _generate2TrimData();
        bytes memory commissionData = _generate1CommissionData(false, ETH);
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // ERC20->ETH with 1trimOnlyTrim and 2toCommission
    function test_trim_unxswapTo_USDT2ETH_1trimOnlyTrim_2toCommission() tokenLogAndCheck(USDT, ETH, 1000 * 10 ** 6, true, false, false, true, true) public {
        bytes memory swapData = _generateUSDT2ETHUnxswapData();
        bytes memory trimData = _generate1TrimOnlyTrimData();
        bytes memory commissionData = _generate2CommissionData(false, ETH);
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // ERC20->ETH with 1trimOnlyCharge and 2toCommission
    function test_trim_unxswapTo_USDT2ETH_1trimOnlyCharge_2toCommission() tokenLogAndCheck(USDT, ETH, 1000 * 10 ** 6, false, true, false, true, true) public {
        bytes memory swapData = _generateUSDT2ETHUnxswapData();
        bytes memory trimData = _generate1TrimOnlyChargeData();
        bytes memory commissionData = _generate2CommissionData(false, ETH);
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // ERC20->ETH with 2trim and 2toCommission
    function test_trim_unxswapTo_USDT2ETH_2trim_2toCommission() tokenLogAndCheck(USDT, ETH, 1000 * 10 ** 6, true, true, false, true, true) public {
        bytes memory swapData = _generateUSDT2ETHUnxswapData();
        bytes memory trimData = _generate2TrimData();
        bytes memory commissionData = _generate2CommissionData(false, ETH);
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }
    
    // ERC20->ETH with 2trim and 2fromCommission
    function test_trim_unxswapTo_USDT2ETH_2trim_2fromCommission() tokenLogAndCheck(USDT, ETH, 2000 * 10 ** 6, true, true, true, true, true) public {
        bytes memory swapData = _generateUSDT2ETHUnxswapData();
        bytes memory trimData = _generate2TrimData();
        bytes memory commissionData = _generate2CommissionData(true, USDT);
        bytes memory data = bytes.concat(swapData, trimData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // ==================== Internal Functions ====================
    function _generateWETH2USDTUnxswapData() internal view returns (bytes memory) {
        uint256 srcToken = uint256(uint160(WETH));
        uint256 amount = oneEther;
        uint256 minReturn = 0;
        address receiver = arnaud;
        bytes32[] memory pools = new bytes32[](1);
        pools[0] = bytes32(abi.encodePacked(uint8(0x00), uint56(0), uint32(amount * 996 / 1000), address(WETH_USDT_UNIV2)));
        return abi.encodeWithSelector(
            DexRouter.unxswapTo.selector, srcToken, amount, minReturn, receiver, pools
        );
    }

    function _generateETH2USDTUnxswapData() internal view returns (bytes memory) {
        uint256 srcToken = 123 << 160;
        uint256 amount = oneEther;
        uint256 minReturn = 0;
        address receiver = arnaud;
        bytes32[] memory pools = new bytes32[](1);
        pools[0] = bytes32(abi.encodePacked(uint8(0x00), uint56(0), uint32(amount * 996 / 1000), address(WETH_USDT_UNIV2)));
        return abi.encodeWithSelector(
            DexRouter.unxswapTo.selector, srcToken, amount, minReturn, receiver, pools
        );
    }

    function _generateETH2USDTUnxswapData2() internal view returns (bytes memory) {
        uint256 srcToken = 456 << 160 | uint256(uint160(ETH));
        uint256 amount = oneEther;
        uint256 minReturn = 0;
        address receiver = arnaud;
        bytes32[] memory pools = new bytes32[](1);
        pools[0] = bytes32(abi.encodePacked(uint8(0x00), uint56(0), uint32(amount * 996 / 1000), address(WETH_USDT_UNIV2)));
        return abi.encodeWithSelector(
            DexRouter.unxswapTo.selector, srcToken, amount, minReturn, receiver, pools
        );
    }

    function _generateUSDT2ETHUnxswapData() internal view returns (bytes memory) {
        uint256 srcToken = uint256(uint160(USDT));
        uint256 amount = 1000 * 10 ** 6;
        uint256 minReturn = 0;
        address receiver = arnaud;
        bytes32[] memory pools = new bytes32[](1);
        pools[0] = bytes32(abi.encodePacked(uint8(0xc0), uint56(0), uint32(amount * 996 / 1000), address(WETH_USDT_UNIV2)));
        return abi.encodeWithSelector(
            DexRouter.unxswapTo.selector, srcToken, amount, minReturn, receiver, pools
        );
    }
}