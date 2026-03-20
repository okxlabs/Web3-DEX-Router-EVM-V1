// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../common/TrimAndCommissionTestBase.t.sol";

contract SuffixFuzzTest is TrimAndCommissionTestBase {

    // ==================== Fuzz Tests ====================

    /// @dev Fuzz: single commission + random suffix → commission always parsed correctly
    function testFuzz_singleCommission_withRandomSuffix(
        uint256 suffixLength,
        uint256 suffixSeed
    ) public {
        suffixLength = bound(suffixLength, 1, 1024);

        vm.startPrank(arnaud);
        deal(WETH, arnaud, oneEther);
        SafeERC20.safeApprove(IERC20(WETH), address(tokenApprove), oneEther);

        bytes memory swapData = _generateWETH2USDTSmartSwapData();
        bytes memory commissionData = _generate1CommissionData(false, USDT);
        bytes memory suffix = _buildRandomSuffix(suffixLength, suffixSeed);

        uint256 referrerBalBefore = IERC20(USDT).balanceOf(referrerAddresses[0]);

        bytes memory data = bytes.concat(swapData, commissionData, suffix);
        (bool success, ) = address(dexRouter).call(data);
        assertTrue(success, "swap should succeed with random suffix");

        uint256 referrerBalAfter = IERC20(USDT).balanceOf(referrerAddresses[0]);
        assertGt(referrerBalAfter, referrerBalBefore, "referrer should receive commission");

        vm.stopPrank();
    }

    /// @dev Fuzz: no ExtraData + random suffix → no commission, swap succeeds
    function testFuzz_noExtraData_withRandomSuffix(
        uint256 suffixLength,
        uint256 suffixSeed
    ) public {
        suffixLength = bound(suffixLength, 1, 1024);

        vm.startPrank(arnaud);
        deal(WETH, arnaud, oneEther);
        SafeERC20.safeApprove(IERC20(WETH), address(tokenApprove), oneEther);

        bytes memory swapData = _generateWETH2USDTSmartSwapData();
        bytes memory suffix = _buildRandomSuffix(suffixLength, suffixSeed);

        bytes memory data = bytes.concat(swapData, suffix);
        (bool success, ) = address(dexRouter).call(data);
        assertTrue(success, "swap should succeed with random suffix and no ExtraData");

        vm.stopPrank();
    }

    /// @dev Fuzz: commission + trim + random suffix → both parsed correctly
    function testFuzz_commissionAndTrim_withRandomSuffix(
        uint256 suffixLength,
        uint256 suffixSeed
    ) public {
        suffixLength = bound(suffixLength, 1, 1024);

        vm.startPrank(arnaud);
        deal(WETH, arnaud, oneEther);
        SafeERC20.safeApprove(IERC20(WETH), address(tokenApprove), oneEther);

        bytes memory swapData = _generateWETH2USDTSmartSwapData();
        bytes memory trimData = _generate1TrimOnlyTrimData();
        bytes memory commissionData = _generate1CommissionData(false, USDT);
        bytes memory suffix = _buildRandomSuffix(suffixLength, suffixSeed);

        uint256 referrerBalBefore = IERC20(USDT).balanceOf(referrerAddresses[0]);
        uint256 trimBalBefore = IERC20(USDT).balanceOf(trimAddress);

        bytes memory data = bytes.concat(swapData, trimData, commissionData, suffix);
        (bool success, ) = address(dexRouter).call(data);
        assertTrue(success, "swap should succeed with trim + commission + random suffix");

        uint256 referrerBalAfter = IERC20(USDT).balanceOf(referrerAddresses[0]);
        uint256 trimBalAfter = IERC20(USDT).balanceOf(trimAddress);
        assertGt(referrerBalAfter, referrerBalBefore, "referrer should receive commission");
        assertGt(trimBalAfter, trimBalBefore, "trim address should receive positive slippage");

        vm.stopPrank();
    }

    // ==================== Internal Helpers ====================

    function _buildRandomSuffix(uint256 length, uint256 seed) internal pure returns (bytes memory) {
        bytes memory suffix = new bytes(length);
        for (uint256 i = 0; i < length; i++) {
            suffix[i] = bytes1(uint8(uint256(keccak256(abi.encodePacked(seed, i))) % 256));
        }
        return suffix;
    }

    // Copied from SmartSwapTrimTest.t.sol
    function _generateWETH2USDTSmartSwapData() internal view returns (bytes memory) {
        SwapInfo memory swapInfo;
        swapInfo.baseRequest = _generateBaseRequest(WETH, USDT, oneEther);
        swapInfo.batchesAmount = new uint256[](1);
        swapInfo.batchesAmount[0] = oneEther;
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
        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);
        return abi.encodeWithSelector(
            DexRouter.smartSwapTo.selector,
            swapInfo.orderId, arnaud, swapInfo.baseRequest, swapInfo.batchesAmount, swapInfo.batches, swapInfo.extraData
        );
    }
}
