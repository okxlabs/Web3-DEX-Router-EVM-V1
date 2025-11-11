// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../common/TrimAndCommissionTestBase.t.sol";

contract CommissionAndTrimRoundingTest is TrimAndCommissionTestBase {
    // Test toToken commission with commission rate 1 / 10^9, rounding result = 1, and the amount in event is 1.
    function test_normalAmountOut_toTokenCommissionRounding_result_gt_0() tokenLogAndCheck(WETH, USDT, 3 * 10 ** 17, false, false, false, true, false) public {
        bytes memory swapData = _generateWETH2USDTSmartSwapData(3 * 10 ** 17); // 3 * 10^17 WETH -> 1,294,111,181 USDT, rounding result with 1/10^9 is 1.
        uint256[] memory commissionRates_ = new uint256[](1);
        commissionRates_[0] = 1;
        address[] memory referrerAddresses_ = new address[](1);
        referrerAddresses_[0] = referrerAddresses[0];
        bytes memory commissionData = _buildCommissionInfoUnified(
            false, // isFromTokenCommission
            true, // isToTokenCommission
            USDT, // token
            false, // isToBCommission
            commissionRates_,
            referrerAddresses_
        );
        bytes memory data = bytes.concat(swapData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
        // USDT balance of user is 1,294,111,180
        // USDT balance of referrerAddress is 1, and the modifier also ensure the referrerAddress balance > 0
    }

    // Test toToken commission with commission rate 1 / 10^9, the rounding result = 0, and the amount in event is 0
    function test_normalAmountOut_toTokenCommissionRounding_result_eq_0() tokenLogAndCheck(WETH, USDT, 2 * 10 ** 17, false, false, false, false, false) public {
        bytes memory swapData = _generateWETH2USDTSmartSwapData(2 * 10 ** 17); // 2 * 10^17 WETH -> 862,740,908 USDT, rounding result with 1/10^9 is 0.
        uint256[] memory commissionRates_ = new uint256[](1);
        commissionRates_[0] = 1;
        address[] memory referrerAddresses_ = new address[](1);
        referrerAddresses_[0] = referrerAddresses[0];
        bytes memory commissionData = _buildCommissionInfoUnified(
            false, // isFromTokenCommission
            true, // isToTokenCommission
            USDT, // token
            false, // isToBCommission
            commissionRates_,
            referrerAddresses_
        );
        bytes memory data = bytes.concat(swapData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
        // USDT balance of user is 862,740,908
        // USDT balance of referrerAddress is 0, and the modifier also ensure the referrerAddress balance is 0
    }

    // Test toToken commission with commission rate 1%, rounding result = 1, and the amount in event is 1.
    function test_smallAmountOut_toTokenCommissionRounding_result_gt_0() tokenLogAndCheck(WETH, USDT, 3 * 10 ** 10, false, false, false, true, false) public {
        bytes memory swapData = _generateWETH2USDTSmartSwapData(3 * 10 ** 10); // 3 * 10^10 WETH -> 129 USDT, rounding result with 1% is 1.
        uint256[] memory commissionRates_ = new uint256[](1);
        commissionRates_[0] = 10000000;
        address[] memory referrerAddresses_ = new address[](1);
        referrerAddresses_[0] = referrerAddresses[0];
        bytes memory commissionData = _buildCommissionInfoUnified(
            false, // isFromTokenCommission
            true, // isToTokenCommission
            USDT, // token
            false, // isToBCommission
            commissionRates_,
            referrerAddresses_
        );
        bytes memory data = bytes.concat(swapData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
        // USDT balance of user is 128
        // USDT balance of referrerAddress is 1, and the modifier also ensure the referrerAddress balance > 0
    }

    // Test toToken commission with commission rate 1%, rounding result = 0, and the amount in event is 0.
    function test_smallAmountOut_toTokenCommissionRounding_result_eq_0() tokenLogAndCheck(WETH, USDT, 2 * 10 ** 10, false, false, false, false, false) public {
        bytes memory swapData = _generateWETH2USDTSmartSwapData(2 * 10 ** 10); // 2 * 10^10 WETH -> 86 USDT, rounding result with 1% is 0.
        uint256[] memory commissionRates_ = new uint256[](1);
        commissionRates_[0] = 10000000;
        address[] memory referrerAddresses_ = new address[](1);
        referrerAddresses_[0] = referrerAddresses[0];
        bytes memory commissionData = _buildCommissionInfoUnified(
            false, // isFromTokenCommission
            true, // isToTokenCommission
            USDT, // token
            false, // isToBCommission
            commissionRates_,
            referrerAddresses_
        );
        bytes memory data = bytes.concat(swapData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
        // USDT balance of user is 86
        // USDT balance of referrerAddress is 0, and the modifier also ensure the referrerAddress balance is 0
    }

    // Test toToken trim with trim rate 1 / 1000, rounding result is 1, and the amount in event is 1.
    function test_smallAmountOut_toTokenTrimRounding_result_gt_0() tokenLogAndCheck(WETH, USDT, 3 * 10 ** 11, true, false, false, false, false) public {
        bytes memory swapData = _generateWETH2USDTSmartSwapData(3 * 10 ** 11); // 3 * 10^11 WETH -> 1,294 USDT, rounding result with 1/1000 is 1.
        bytes memory trimData = _buildTrimInfoUnified(
            1, // trimRate 1/1000
            trimAddress, // trimAddress
            10, // expectAmountOut 10, but usually the trimAmount will be the allowedMaxTrimAmount cause the expectAmountOut is too small
            0, // chargeRate 0%, all for trim
            address(0), // chargeAddress
            true // isToBTrim
        );
        bytes memory data = bytes.concat(swapData, trimData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
        // USDT balance of user is 1,293
        // USDT balance of referrerAddress is 1, and the modifier also ensure the referrerAddress balance > 0
    }

    // Test toToken trim with trim rate 1 / 1000, and rounding result = 0, and the amount in event is 0.
    function test_smallAmountOut_toTokenTrimRounding_result_eq_0() tokenLogAndCheck(WETH, USDT, 2 * 10 ** 11, false, false, false, false, false) public {
        bytes memory swapData = _generateWETH2USDTSmartSwapData(2 * 10 ** 11); // 2 * 10^11 WETH -> 862 USDT, rounding result with 1/1000 is 0.
        bytes memory trimData = _buildTrimInfoUnified(
            1, // trimRate 1/1000
            trimAddress, // trimAddress
            10, // expectAmountOut 10, but usually the trimAmount will be the allowedMaxTrimAmount cause the expectAmountOut is too small
            0, // chargeRate 0%, all for trim
            address(0), // chargeAddress
            true // isToBTrim
        );
        bytes memory data = bytes.concat(swapData, trimData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
        // USDT balance of user is 862
        // USDT balance of referrerAddress is 0, and the modifier also ensure the referrerAddress balance is 0
    }

    // ==================== Internal Functions ====================
    function _generateWETH2USDTSmartSwapData(uint256 fromTokenAmount) internal view returns (bytes memory) {
        SwapInfo memory swapInfo;
        // baseRequest
        swapInfo.baseRequest = _generateBaseRequest(WETH, USDT, fromTokenAmount);
        // batchesAmount
        swapInfo.batchesAmount = new uint256[](1);
        swapInfo.batchesAmount[0] = fromTokenAmount;
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
}