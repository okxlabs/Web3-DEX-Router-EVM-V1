# ERC-8021 DexRouter 兼容性方案 — PLAN（实施计划）

> 日期: 2026-03-05
> 状态: 草案 v4
> 作者: DexRouter Team
> 相关文档: [PRD](./PRD.md) | [SPEC](./SPEC.md)
> 对应决策: SPEC 方案 A（后向 bytes32 对齐扫描）

---

> 本部分仅描述方案 A 的具体实现，方案 B 已在 SPEC 2.3.9 中明确不采用。

## 1. 代码变更

### 1.1 添加 effectiveEnd 后向扫描逻辑

> 对应 SPEC TODO #1: CommissionLib.sol — 添加 effectiveEnd 后向扫描逻辑

**文件：** `contracts/8/libraries/CommissionLib.sol`

**插入位置：** `_getCommissionAndTrimInfo()` 函数的 `assembly ("memory-safe")` 块内，第 109 行（`_revertWithReason` 函数定义的 `}` 闭合括号）之后、第 111 行（`let commissionData := calldataload(...)` ）之前。

**变更前（第 109-111 行）：**

```solidity
            }

            let commissionData := calldataload(sub(calldatasize(), 0x20))
```

**变更后：**

```solidity
            }

            // Backward scan to find the true ExtraData boundary (effectiveEnd).
            // External suffixes (e.g. ERC-8021) may be appended after ExtraData,
            // so calldatasize() may no longer be the right edge.
            let calldataEnd := calldatasize()

            // Strip non-aligned suffix bytes: calldata should be 4B selector + N*32B
            let remainder := mod(sub(calldataEnd, 4), 0x20)
            let effectiveEnd := sub(calldataEnd, remainder)

            // Scan backward through 32-byte aligned positions to find the rightmost known flag.
            // Direct exact-match against all 8 known flag values (6 commission + 2 trim).
            let scanPos := effectiveEnd
            // 0x23 = 35: ensures scanPos >= 0x24 so calldataload reads from offset >= 4 (past selector)
            for { } gt(scanPos, 0x23) { scanPos := sub(scanPos, 0x20) } {
                // _COMMISSION_FLAG_MASK == _TRIM_FLAG_MASK (both 0xffffffffffff000...0), so one mask covers all flags
                let flagMasked := and(calldataload(sub(scanPos, 0x20)), _COMMISSION_FLAG_MASK)
                // exact match against all 8 known flag values (6 commission + 2 trim)
                if or(
                    or(
                        or(eq(flagMasked, FROM_TOKEN_COMMISSION), eq(flagMasked, TO_TOKEN_COMMISSION)),
                        or(eq(flagMasked, FROM_TOKEN_COMMISSION_DUAL), eq(flagMasked, TO_TOKEN_COMMISSION_DUAL))
                    ),
                    or(
                        or(eq(flagMasked, FROM_TOKEN_COMMISSION_MULTIPLE), eq(flagMasked, TO_TOKEN_COMMISSION_MULTIPLE)),
                        or(eq(flagMasked, TRIM_FLAG), eq(flagMasked, TRIM_DUAL_FLAG))
                    )
                ) {
                    effectiveEnd := scanPos
                    break
                }
            }

            let commissionData := calldataload(sub(effectiveEnd, 0x20))
```

**说明：** 扫描逻辑约 30 行 Yul 代码，插入后原有行号会整体下移。后续替换（1.2）以代码模式匹配为准，不依赖具体行号。

### 1.2 替换剩余 5 处 calldatasize() 锚点

> 对应 SPEC TODO #2: CommissionLib.sol — 替换 6 处 calldatasize() 锚点为 effectiveEnd

**文件：** `contracts/8/libraries/CommissionLib.sol`

**注意：** 第 1 处替换（第 111 行 `let commissionData := calldataload(sub(calldatasize(), 0x20))`）已在 1.1 中完成。以下为剩余 5 处，均在同一 assembly 块内。替换方式为纯文本替换 `calldatasize()` → `effectiveEnd`，解析逻辑不变。

**替换 2 — 原第 162 行（读取分佣的 token + toBCommission 数据）：**

```solidity
// 变更前:
commissionData := calldataload(sub(calldatasize(), 0x40))

// 变更后:
commissionData := calldataload(sub(effectiveEnd, 0x40))
```

**替换 3 — 原第 198 行（多推荐人模式循环读取第 i 个分佣对）：**

```solidity
// 变更前:
commissionData := calldataload(sub(calldatasize(), add(0x40, mul(i, 0x20))))

// 变更后:
commissionData := calldataload(sub(effectiveEnd, add(0x40, mul(i, 0x20))))
```

**替换 4 — 原第 227 行（跳过分佣数据后，读取第 1 个正滑点 word）：**

```solidity
// 变更前:
let trimData := calldataload(sub(calldatasize(), add(offset, 0x20)))

// 变更后:
let trimData := calldataload(sub(effectiveEnd, add(offset, 0x20)))
```

**替换 5 — 原第 248 行（读取第 2 个正滑点 word）：**

```solidity
// 变更前:
trimData := calldataload(sub(calldatasize(), add(offset, 0x40)))

// 变更后:
trimData := calldataload(sub(effectiveEnd, add(offset, 0x40)))
```

**替换 6 — 原第 278 行（双正滑点模式，读取第 3 个正滑点 word）：**

```solidity
// 变更前:
trimData := calldataload(sub(calldatasize(), add(offset, 0x60)))

// 变更后:
trimData := calldataload(sub(effectiveEnd, add(offset, 0x60)))
```

**验证清单：** 变更完成后，`_getCommissionAndTrimInfo()` 函数的 assembly 块内应无任何 `calldatasize()` 调用（仅在扫描逻辑的 `let calldataEnd := calldatasize()` 处使用一次）。

### 1.3 CommissionAndTrimInfo 事件 emit 改为 assembly

> 合约体积优化：将 Solidity 的 `emit CommissionAndTrimInfo(...)` 改为 assembly `log1`，节省约 58 字节。

**文件：** `contracts/8/libraries/CommissionLib.sol`

**变更位置：** `_getCommissionAndTrimInfo()` 函数的 assembly 块结束后、函数末尾。

**变更前：**

```solidity
        if (commissionInfo.isFromTokenCommission || commissionInfo.isToTokenCommission || trimInfo.hasTrim) {
            emit CommissionAndTrimInfo(
                commissionInfo.toBCommission,
                trimInfo.toBTrim,
                trimInfo.trimRate,
                trimInfo.chargeRate
            );
        }
```

**变更后：**

```solidity
        // if (commissionInfo.isFromTokenCommission || commissionInfo.isToTokenCommission || trimInfo.hasTrim) {
        //     emit CommissionAndTrimInfo(
        //         commissionInfo.toBCommission,
        //         trimInfo.toBTrim,
        //         trimInfo.trimRate,
        //         trimInfo.chargeRate
        //     );
        // }
        assembly {
            if or(or(mload(commissionInfo), mload(add(commissionInfo, 0x20))), mload(trimInfo)) {
                let ptr := mload(0x40)
                mstore(ptr, mload(add(commissionInfo, 0x60)))        // toBCommission
                mstore(add(ptr, 0x20), mload(add(trimInfo, 0x60)))   // toBTrim
                mstore(add(ptr, 0x40), mload(add(trimInfo, 0x20)))   // trimRate
                mstore(add(ptr, 0x60), mload(add(trimInfo, 0xa0)))   // chargeRate
                log1(ptr, 0x80, 0x7970b0744fdb6cf0b120e5e0a5f4da3ab8cbec6d5d9ec8a4f327ccc1d8a5eb8b)
            }
        }
```

**说明：** `log1` 的 topic hash `0x7970b0...eb8b` 是 `keccak256("CommissionAndTrimInfo(uint256,uint256,uint256,uint256)")` 的结果。原 Solidity emit 保留为注释供参考。

### 1.4 注释掉 CommissionAndTrimInfo 事件定义

> 与其他已改为 assembly emit 的事件（CommissionFromTokenRecord、CommissionToTokenRecord、PositiveSlippageTrimRecord）保持一致风格。

**文件：** `contracts/8/libraries/CommissionLib.sol`

**变更前：**

```solidity
    event CommissionAndTrimInfo(
        uint256 toBCommission,
        uint256 toBTrim,
        uint256 trimRate,
        uint256 chargeRate
    );
```

**变更后：**

```solidity
    // @notice CommissionAndTrimInfo is emitted in assembly, commentted out for contract size saving
    // event CommissionAndTrimInfo(
    //     uint256 toBCommission, // 0 for no commission, 1 for no-toB commission, 2 for toB commission
    //     uint256 toBTrim, // 0 for no trim, 1 for no-toB trim, 2 for toB trim
    //     uint256 trimRate,
    //     uint256 chargeRate
    // );
```

**说明：** 经验证，注释掉事件定义对合约 bytecode 大小无影响（0 字节差异），因为该事件仅通过 assembly `log1` emit，编译器不会为未使用 `emit` 的事件定义生成额外 bytecode。此变更纯粹为代码风格一致性。

**无需修改其他文件。** DexRouter.sol、adapter 合约、调用方 SDK、前端编码逻辑均保持不变。

## 2. 测试设计

### 2.1 新增测试文件：后缀容忍度测试

> 对应 SPEC TODO #3: 新增后缀容忍度单元测试

**文件：** `src/tests/suffix/SuffixToleranceTest.t.sol`

**继承：** `TrimAndCommissionTestBase`（定义在 `src/tests/common/TrimAndCommissionTestBase.t.sol`，提供 `setUp()`、余额检查 modifier、commission/trim data 构建工具）

**注意：** `_generateWETH2USDTSmartSwapData()` 等 swap data 生成函数**不在基类中**，各测试文件需自行定义。从 `src/tests/trim/SmartSwapTrimTest.t.sol` 第 559-585 行复制。

**完整测试文件结构：**

```solidity
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
```

**测试矩阵总览：**

| # | 测试函数 | ExtraData 配置 | 后缀 | 预期行为 |
|---|---------|---------------|------|---------|
| 1 | `test_singleCommission_withERC8021Suffix` | 单推荐人分佣 | ERC-8021 "baseapp"（25B） | `referrerAddresses[0]` 收到佣金 |
| 2 | `test_dualCommission_withERC8021Suffix` | 双推荐人分佣 | ERC-8021 "baseapp"（25B） | 两个推荐人都收到佣金 |
| 3 | `test_multiCommission_withERC8021Suffix` | 3 推荐人分佣 | ERC-8021 "baseapp"（25B） | 三个推荐人都收到佣金 |
| 4 | `test_singleTrim_withERC8021Suffix` | 单正滑点 | ERC-8021 "baseapp"（25B） | `trimAddress` 收到正滑点 |
| 5 | `test_dualTrim_withERC8021Suffix` | 双正滑点（含 charge） | ERC-8021 "baseapp"（25B） | `trimAddress` 和 `chargeAddress` 都收到 |
| 6 | `test_commissionAndTrim_withERC8021Suffix` | 单分佣 + 单正滑点 | ERC-8021 "baseapp"（25B） | 分佣 + 正滑点都正确 |
| 7 | `test_commissionAndTrim_withLongSuffix` | 单分佣 + 单正滑点 | ERC-8021 最长后缀（273B） | 分佣 + 正滑点都正确 |
| 8 | `test_noExtraData_withERC8021Suffix` | 无 ExtraData | ERC-8021 "baseapp"（25B） | 无分佣无正滑点，swap 正常 |
| 9 | `test_noExtraData_withLongSuffix` | 无 ExtraData | 273B 随机后缀 | 无分佣无正滑点，swap 正常 |
| 10 | `test_singleCommission_with512ByteRandomSuffix` | 单推荐人分佣 | 512B 随机后缀 | 分佣正确 |
| 11 | `test_singleCommission_with1024ByteRandomSuffix` | 单推荐人分佣 | 1024B 随机后缀 | 分佣正确 |
| 12 | `test_dualCommission_with512ByteRandomSuffix` | 双推荐人分佣 | 512B 随机后缀 | 两个推荐人都收到佣金 |
| 13 | `test_singleTrim_with512ByteRandomSuffix` | 单正滑点 | 512B 随机后缀 | `trimAddress` 收到正滑点 |
| 14 | `test_commissionAndTrim_with512ByteRandomSuffix` | 单分佣 + 单正滑点 | 512B 随机后缀 | 分佣 + 正滑点都正确 |
| 15 | `test_commissionAndTrim_with1024ByteRandomSuffix` | 单分佣 + 单正滑点 | 1024B 随机后缀 | 分佣 + 正滑点都正确 |
| 16 | `test_noExtraData_with1024ByteRandomSuffix` | 无 ExtraData | 1024B 随机后缀 | 无分佣无正滑点，swap 正常 |
| 17 | `test_commission_with32ByteAlignedSuffix` | 单分佣 | 32B 随机后缀（对齐） | 分佣正确（对齐边界测试） |
| 18 | `test_commission_with33ByteSuffix` | 单分佣 | 33B 随机后缀（非对齐） | 分佣正确（非对齐边界测试） |

### 2.2 新增测试：Fuzz 测试

> 对应 SPEC TODO #4: 新增 Fuzz 测试

**文件：** `src/tests/suffix/SuffixFuzzTest.t.sol`

```solidity
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
```

### 2.3 回归验证

> 对应 SPEC TODO #5: 回归验证

运行全部现有测试，确认向后兼容：

```bash
# 全量测试（所有现有 commission/trim/adapter 测试必须通过）
forge test --match-path "src/tests/**" -vvv

# 新增后缀测试
forge test --match-path "src/tests/suffix/**" -vvv

# 合约体积检查（deployed bytecode 不超过 EIP-170 限制 24,576 字节）
forge build --sizes 2>&1 | grep DexRouter
```

现有测试文件（不修改、仅验证通过）：

| 目录 | 文件 | 覆盖范围 |
|------|------|---------|
| `src/tests/commission/` | `CommissionTest1-3.t.sol`、`DualCommissionTokenTest.t.sol`、`Dual*ETHTest.t.sol`、`WrapCommissionTest.t.sol` | 单/双推荐人分佣，ETH/ERC20 |
| `src/tests/trim/` | `SmartSwapTrimTest.t.sol`、`DagSwapTrimTest.t.sol`、`MultiCallTrimTest.t.sol` 等 | 单/双正滑点，各 swap 方法 |
| `src/tests/multiCommission/` | `SmartSwapMultiCommissionTest.t.sol` | 3-8 推荐人分佣 |
| `src/tests/exactout/` | `ExactOut*CommissionTest.t.sol` | ExactOut 模式分佣 |

### 2.4 合约体积验证

> 对应 SPEC TODO #6: 合约体积验证

```bash
# 验证 DexRouter deployed bytecode 不超过 EIP-170 限制（24,576 字节）
forge build --sizes 2>&1 | grep DexRouter
```

## 3. 覆盖率检查

| SPEC TODO | PLAN 章节 | 状态 |
|-----------|----------|------|
| TODO #1: CommissionLib.sol — 添加 effectiveEnd 后向扫描逻辑 | 1.1 | ✅ 已实现（移除 Layer 1 预过滤以节省体积） |
| TODO #2: CommissionLib.sol — 替换 6 处 calldatasize() 锚点为 effectiveEnd | 1.1 + 1.2 | ✅ |
| 体积优化: CommissionAndTrimInfo emit 改为 assembly | 1.3 | ✅ |
| 风格统一: 注释掉 CommissionAndTrimInfo 事件定义 | 1.4 | ✅ |
| TODO #3: 新增后缀容忍度单元测试 | 2.1 | ✅ |
| TODO #4: 新增 Fuzz 测试 | 2.2 | ✅ |
| TODO #5: 回归验证 | 2.3 | ✅ |
| TODO #6: 合约体积验证 | 2.4 | ✅ |

## 4. 合约体积记录

| 阶段 | DexRouter Runtime Size | EIP-170 上限 | 余量 |
|------|----------------------|-------------|------|
| 实现后（含 Layer 1 预过滤 + Solidity emit） | 超限 | 24,576 B | 不足 |
| 移除 Layer 1 预过滤 + emit 改为 assembly | 24,573 B | 24,576 B | **3 B** |
| 注释掉事件定义 | 24,573 B | 24,576 B | **3 B**（无变化） |
