// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../common/TrimAndCommissionTestBase.t.sol";

contract SuffixToleranceTest is TrimAndCommissionTestBase {

    // ==================== Tests: Commission + Suffix ====================

    // Test 1: Single commission + ERC-8021 suffix
    function test_singleCommission_withERC8021Suffix()
        tokenLogAndCheck(WETH, USDT, oneEther, false, false, false, true, false)
        public
    {
        bytes memory swapData = _generateWETH2USDTSmartSwapData();
        bytes memory commissionData = _generate1CommissionData(false, USDT);
        bytes memory suffix = _buildERC8021Suffix("baseapp");
        bytes memory data = bytes.concat(swapData, commissionData, suffix);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // Test 2: Dual commission + ERC-8021 suffix
    function test_dualCommission_withERC8021Suffix()
        tokenLogAndCheck(WETH, USDT, oneEther, false, false, false, true, true)
        public
    {
        bytes memory swapData = _generateWETH2USDTSmartSwapData();
        bytes memory commissionData = _generate2CommissionData(false, USDT);
        bytes memory suffix = _buildERC8021Suffix("baseapp");
        bytes memory data = bytes.concat(swapData, commissionData, suffix);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // Test 3: Multiple (3) commission + ERC-8021 suffix
    function test_multiCommission_withERC8021Suffix()
        tokenLogAndCheck2(WETH, USDT, oneEther, false, false, false, 3)
        public
    {
        bytes memory swapData = _generateWETH2USDTSmartSwapData();
        bytes memory commissionData = _generateMultipleCommissionData(false, USDT, false, 3);
        bytes memory suffix = _buildERC8021Suffix("baseapp");
        bytes memory data = bytes.concat(swapData, commissionData, suffix);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // ==================== Tests: Trim + Suffix ====================

    // Test 4: Single trim + ERC-8021 suffix
    function test_singleTrim_withERC8021Suffix()
        tokenLogAndCheck(WETH, USDT, oneEther, true, false, false, false, false)
        public
    {
        bytes memory swapData = _generateWETH2USDTSmartSwapData();
        bytes memory trimData = _generate1TrimOnlyTrimData();
        bytes memory suffix = _buildERC8021Suffix("baseapp");
        bytes memory data = bytes.concat(swapData, trimData, suffix);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // Test 5: Dual trim (with charge) + ERC-8021 suffix
    function test_dualTrim_withERC8021Suffix()
        tokenLogAndCheck(WETH, USDT, oneEther, true, true, false, false, false)
        public
    {
        bytes memory swapData = _generateWETH2USDTSmartSwapData();
        bytes memory trimData = _generate2TrimData();
        bytes memory suffix = _buildERC8021Suffix("baseapp");
        bytes memory data = bytes.concat(swapData, trimData, suffix);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // ==================== Tests: Commission + Trim + Suffix ====================

    // Test 6: Single commission + single trim + ERC-8021 suffix
    function test_commissionAndTrim_withERC8021Suffix()
        tokenLogAndCheck(WETH, USDT, oneEther, true, false, false, true, false)
        public
    {
        bytes memory swapData = _generateWETH2USDTSmartSwapData();
        bytes memory trimData = _generate1TrimOnlyTrimData();
        bytes memory commissionData = _generate1CommissionData(false, USDT);
        bytes memory suffix = _buildERC8021Suffix("baseapp");
        bytes memory data = bytes.concat(swapData, trimData, commissionData, suffix);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // Test 7: Single commission + single trim + long ERC-8021 suffix (273B, Schema 0 max)
    function test_commissionAndTrim_withLongSuffix()
        tokenLogAndCheck(WETH, USDT, oneEther, true, false, false, true, false)
        public
    {
        bytes memory swapData = _generateWETH2USDTSmartSwapData();
        bytes memory trimData = _generate1TrimOnlyTrimData();
        bytes memory commissionData = _generate1CommissionData(false, USDT);
        // 273B = max Schema 0 suffix: 255 bytes codes + 1B codesLength + 1B schemaId + 16B marker
        bytes memory longCode = new bytes(255);
        for (uint256 i = 0; i < 255; i++) {
            longCode[i] = bytes1(uint8(0x61 + (i % 26))); // a-z repeating
        }
        bytes memory suffix = abi.encodePacked(
            longCode,
            uint8(255),
            uint8(0x00),
            bytes16(0x80218021802180218021802180218021)
        );
        bytes memory data = bytes.concat(swapData, trimData, commissionData, suffix);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // ==================== Tests: No ExtraData + Suffix ====================

    // Test 8: No ExtraData + ERC-8021 suffix (should still swap normally)
    function test_noExtraData_withERC8021Suffix()
        tokenLogAndCheck(WETH, USDT, oneEther, false, false, false, false, false)
        public
    {
        bytes memory swapData = _generateWETH2USDTSmartSwapData();
        bytes memory suffix = _buildERC8021Suffix("baseapp");
        bytes memory data = bytes.concat(swapData, suffix);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // Test 9: No ExtraData + 273B random suffix
    function test_noExtraData_withLongSuffix()
        tokenLogAndCheck(WETH, USDT, oneEther, false, false, false, false, false)
        public
    {
        bytes memory swapData = _generateWETH2USDTSmartSwapData();
        bytes memory suffix = _buildRandomSuffix(273, 42);
        bytes memory data = bytes.concat(swapData, suffix);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // ==================== Tests: Large Random Suffix ====================

    // Test 10: Single commission + 512B random suffix
    function test_singleCommission_with512ByteRandomSuffix()
        tokenLogAndCheck(WETH, USDT, oneEther, false, false, false, true, false)
        public
    {
        bytes memory swapData = _generateWETH2USDTSmartSwapData();
        bytes memory commissionData = _generate1CommissionData(false, USDT);
        bytes memory suffix = _buildRandomSuffix(512, 7890);
        bytes memory data = bytes.concat(swapData, commissionData, suffix);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // Test 11: Single commission + 1024B random suffix
    function test_singleCommission_with1024ByteRandomSuffix()
        tokenLogAndCheck(WETH, USDT, oneEther, false, false, false, true, false)
        public
    {
        bytes memory swapData = _generateWETH2USDTSmartSwapData();
        bytes memory commissionData = _generate1CommissionData(false, USDT);
        bytes memory suffix = _buildRandomSuffix(1024, 1111);
        bytes memory data = bytes.concat(swapData, commissionData, suffix);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // Test 12: Dual commission + 512B random suffix
    function test_dualCommission_with512ByteRandomSuffix()
        tokenLogAndCheck(WETH, USDT, oneEther, false, false, false, true, true)
        public
    {
        bytes memory swapData = _generateWETH2USDTSmartSwapData();
        bytes memory commissionData = _generate2CommissionData(false, USDT);
        bytes memory suffix = _buildRandomSuffix(512, 2222);
        bytes memory data = bytes.concat(swapData, commissionData, suffix);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // Test 13: Single trim + 512B random suffix
    function test_singleTrim_with512ByteRandomSuffix()
        tokenLogAndCheck(WETH, USDT, oneEther, true, false, false, false, false)
        public
    {
        bytes memory swapData = _generateWETH2USDTSmartSwapData();
        bytes memory trimData = _generate1TrimOnlyTrimData();
        bytes memory suffix = _buildRandomSuffix(512, 3333);
        bytes memory data = bytes.concat(swapData, trimData, suffix);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // Test 14: Commission + trim + 512B random suffix
    function test_commissionAndTrim_with512ByteRandomSuffix()
        tokenLogAndCheck(WETH, USDT, oneEther, true, false, false, true, false)
        public
    {
        bytes memory swapData = _generateWETH2USDTSmartSwapData();
        bytes memory trimData = _generate1TrimOnlyTrimData();
        bytes memory commissionData = _generate1CommissionData(false, USDT);
        bytes memory suffix = _buildRandomSuffix(512, 4444);
        bytes memory data = bytes.concat(swapData, trimData, commissionData, suffix);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // Test 15: Commission + trim + 1024B random suffix
    function test_commissionAndTrim_with1024ByteRandomSuffix()
        tokenLogAndCheck(WETH, USDT, oneEther, true, false, false, true, false)
        public
    {
        bytes memory swapData = _generateWETH2USDTSmartSwapData();
        bytes memory trimData = _generate1TrimOnlyTrimData();
        bytes memory commissionData = _generate1CommissionData(false, USDT);
        bytes memory suffix = _buildRandomSuffix(1024, 5555);
        bytes memory data = bytes.concat(swapData, trimData, commissionData, suffix);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // Test 16: No ExtraData + 1024B random suffix
    function test_noExtraData_with1024ByteRandomSuffix()
        tokenLogAndCheck(WETH, USDT, oneEther, false, false, false, false, false)
        public
    {
        bytes memory swapData = _generateWETH2USDTSmartSwapData();
        bytes memory suffix = _buildRandomSuffix(1024, 6666);
        bytes memory data = bytes.concat(swapData, suffix);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // ==================== Tests: Alignment Edge Cases ====================

    // Test 17: Single commission + exactly 32-byte aligned suffix
    function test_commission_with32ByteAlignedSuffix()
        tokenLogAndCheck(WETH, USDT, oneEther, false, false, false, true, false)
        public
    {
        bytes memory swapData = _generateWETH2USDTSmartSwapData();
        bytes memory commissionData = _generate1CommissionData(false, USDT);
        bytes memory suffix = _buildRandomSuffix(32, 123);
        bytes memory data = bytes.concat(swapData, commissionData, suffix);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // Test 18: Single commission + 33-byte (non-aligned) suffix
    function test_commission_with33ByteSuffix()
        tokenLogAndCheck(WETH, USDT, oneEther, false, false, false, true, false)
        public
    {
        bytes memory swapData = _generateWETH2USDTSmartSwapData();
        bytes memory commissionData = _generate1CommissionData(false, USDT);
        bytes memory suffix = _buildRandomSuffix(33, 456);
        bytes memory data = bytes.concat(swapData, commissionData, suffix);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // ==================== Internal Helpers ====================

    // ---- Suffix Helpers ----

    /// @dev Build a simulated ERC-8021 Schema 0 suffix
    /// @param code ASCII entity code (e.g. "baseapp")
    /// @return ERC-8021 formatted suffix bytes
    function _buildERC8021Suffix(string memory code) internal pure returns (bytes memory) {
        bytes memory codeBytes = bytes(code);
        // Schema 0: codes | codesLength (1B) | schemaId=0x00 (1B) | ercMarker (16B)
        return abi.encodePacked(
            codeBytes,
            uint8(codeBytes.length),
            uint8(0x00),
            bytes16(0x80218021802180218021802180218021)
        );
    }

    /// @dev Build an arbitrary-length random suffix (for non-ERC-8021 scenarios)
    /// @param length Suffix length in bytes
    /// @param seed Random seed
    /// @return Random bytes of given length
    function _buildRandomSuffix(uint256 length, uint256 seed) internal pure returns (bytes memory) {
        bytes memory suffix = new bytes(length);
        for (uint256 i = 0; i < length; i++) {
            suffix[i] = bytes1(uint8(uint256(keccak256(abi.encodePacked(seed, i))) % 256));
        }
        return suffix;
    }

    // ---- Swap Data Generators ----
    // Copied from SmartSwapTrimTest.t.sol (lines 559-585)

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
