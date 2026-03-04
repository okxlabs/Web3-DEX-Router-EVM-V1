# ERC-8021 DexRouter 兼容性方案 — PLAN（实施计划）

> 日期: 2026-03-03
> 状态: 草案
> 作者: DexRouter Team
> 相关文档: [PRD](./PRD.md) | [SPEC](./SPEC.md)

---

> 本部分仅描述方案 A 的具体实现，方案 B 已在 SPEC 2.3.9 中明确不采用。

### 3.1 变更 1：添加 effectiveEnd 后向扫描逻辑

**文件：** `contracts/8/libraries/CommissionLib.sol`

**插入位置：** `_getCommissionAndTrimInfo()` 函数的 `assembly ("memory-safe")` 块内，第 109 行（`_revertWithReason` 函数定义结束）之后、第 111 行（`let commissionData := calldataload(...)` ）之前。

**插入代码：**

```solidity
            // ===== effectiveEnd: backward scan for known flag to locate ExtraData boundary =====
            // When external suffixes (e.g. ERC-8021) are appended after ExtraData,
            // calldatasize() no longer points to ExtraData's right edge.
            // This scan finds the rightmost known flag word to determine the true boundary.
            let calldataEnd := calldatasize()
            let effectiveEnd := calldataEnd  // default: fallback to calldatasize() (backward compatible)

            // Align calldataEnd to (4 + 32*N) boundary
            // Guarantee: calldata = 4B selector + ABI(32*A) + ExtraData(32*B) → always 4+32*N
            // Any non-aligned remainder is external suffix bytes
            let remainder := mod(sub(calldataEnd, 4), 0x20)
            let scanPos := sub(calldataEnd, remainder)

            // Backward scan all 32-byte aligned positions (no fixed upper bound)
            // Stop at selector boundary (scanPos <= 0x23 means no more full word to read)
            for { } gt(scanPos, 0x23) { scanPos := sub(scanPos, 0x20) } {

                let word := calldataload(sub(scanPos, 0x20))

                // Pre-filter: check common traits of known flags
                // - All 6 commission flags share bytes[2:3] = 0x0afc
                // - All 2 trim flags share bytes[0:3] = 0x77777777
                // This eliminates ~99.998% of positions with only 2 comparisons
                let high6 := shr(208, word)
                let mid2 := and(shr(16, high6), 0xffff)
                let high4 := shr(16, high6)

                if or(eq(mid2, 0x0afc), eq(high4, 0x77777777)) {
                    // Full 8-way match against all known flag values
                    let flagMasked := and(word, _COMMISSION_FLAG_MASK)
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
            }
            // ===== scan complete =====
            // effectiveEnd now points to the right edge of the outermost ExtraData flag word
            // If no flag found, effectiveEnd = calldatasize() (no ExtraData, same as current behavior)
```

### 3.2 变更 2：替换 6 处 calldatasize() 锚点

**文件：** `contracts/8/libraries/CommissionLib.sol`

在同一 assembly 块内，将以下 6 处 `calldatasize()` 替换为 `effectiveEnd`：

**替换 1 — 第 111 行（读取最后 32 字节，检查分佣 flag）：**

```solidity
// 变更前:
let commissionData := calldataload(sub(calldatasize(), 0x20))

// 变更后:
let commissionData := calldataload(sub(effectiveEnd, 0x20))
```

**替换 2 — 第 162 行（读取分佣的 token + toBCommission 数据）：**

```solidity
// 变更前:
commissionData := calldataload(sub(calldatasize(), 0x40))

// 变更后:
commissionData := calldataload(sub(effectiveEnd, 0x40))
```

**替换 3 — 第 198 行（多推荐人模式循环读取第 i 个分佣对）：**

```solidity
// 变更前:
commissionData := calldataload(sub(calldatasize(), add(0x40, mul(i, 0x20))))

// 变更后:
commissionData := calldataload(sub(effectiveEnd, add(0x40, mul(i, 0x20))))
```

**替换 4 — 第 227 行（跳过分佣数据后，读取第 1 个正滑点 word）：**

```solidity
// 变更前:
let trimData := calldataload(sub(calldatasize(), add(offset, 0x20)))

// 变更后:
let trimData := calldataload(sub(effectiveEnd, add(offset, 0x20)))
```

**替换 5 — 第 248 行（读取第 2 个正滑点 word）：**

```solidity
// 变更前:
trimData := calldataload(sub(calldatasize(), add(offset, 0x40)))

// 变更后:
trimData := calldataload(sub(effectiveEnd, add(offset, 0x40)))
```

**替换 6 — 第 278 行（双正滑点模式，读取第 3 个正滑点 word）：**

```solidity
// 变更前:
trimData := calldataload(sub(calldatasize(), add(offset, 0x60)))

// 变更后:
trimData := calldataload(sub(effectiveEnd, add(offset, 0x60)))
```

**无需修改其他文件。** DexRouter.sol、adapter 合约、调用方 SDK、前端编码逻辑均保持不变。

### 3.3 测试设计

#### 3.3.1 新增测试文件：后缀容忍度测试

**文件：** `src/tests/suffix/SuffixToleranceTest.t.sol`

**继承：** `TrimAndCommissionTestBase`（复用现有的 swap data 生成、余额检查、分佣/正滑点构建工具）

**辅助函数：构造模拟 ERC-8021 后缀**

```solidity
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
```

**测试矩阵（每个测试函数 = ExtraData 配置 × 后缀配置的一种组合）：**

| # | 测试函数 | ExtraData 配置 | 后缀 | 预期行为 |
|---|---------|---------------|------|---------|
| 1 | `test_singleCommission_withERC8021Suffix` | 单推荐人分佣 | ERC-8021 "baseapp"（25B） | 分佣正确解析，推荐人收到佣金 |
| 2 | `test_dualCommission_withERC8021Suffix` | 双推荐人分佣 | ERC-8021 "baseapp"（25B） | 两个推荐人都收到佣金 |
| 3 | `test_multiCommission_withERC8021Suffix` | 3 推荐人分佣 | ERC-8021 "baseapp"（25B） | 三个推荐人都收到佣金 |
| 4 | `test_singleTrim_withERC8021Suffix` | 单正滑点 | ERC-8021 "baseapp"（25B） | 正滑点正确截留 |
| 5 | `test_dualTrim_withERC8021Suffix` | 双正滑点（含 charge） | ERC-8021 "baseapp"（25B） | 正滑点 + charge 正确截留 |
| 6 | `test_commissionAndTrim_withERC8021Suffix` | 单分佣 + 单正滑点 | ERC-8021 "baseapp"（25B） | 分佣 + 正滑点都正确 |
| 7 | `test_commissionAndTrim_withLongSuffix` | 单分佣 + 单正滑点 | ERC-8021 最长后缀（273B） | 分佣 + 正滑点都正确 |
| 8 | `test_noExtraData_withERC8021Suffix` | 无 ExtraData | ERC-8021 "baseapp"（25B） | 无分佣无正滑点，swap 正常 |
| 9 | `test_noExtraData_withLongSuffix` | 无 ExtraData | 273B 随机后缀 | 无分佣无正滑点，swap 正常 |
| 10 | `test_commission_with32ByteAlignedSuffix` | 单分佣 | 32B 后缀（精确对齐） | 分佣正确（测试对齐边界） |
| 11 | `test_commission_with33ByteSuffix` | 单分佣 | 33B 后缀（非对齐） | 分佣正确（测试非对齐边界） |

**每个测试函数的实现模式：**

```solidity
function test_singleCommission_withERC8021Suffix() public {
    // 1. 构造基础 swap calldata（复用现有 helper）
    bytes memory swapData = _generateWETH2USDTSmartSwapData();

    // 2. 构造 ExtraData（分佣 + 可选正滑点）
    uint256[] memory rates = new uint256[](1);
    rates[0] = 300;  // 0.3%
    address[] memory referrers = new address[](1);
    referrers[0] = referrer1;
    bytes memory commissionData = _buildCommissionInfoUnified(
        true, false, USDT, false, rates, referrers
    );

    // 3. 构造 ERC-8021 后缀
    bytes memory suffix = _buildERC8021Suffix("baseapp");

    // 4. 拼接: swapData + commissionData + suffix
    bytes memory data = bytes.concat(swapData, commissionData, suffix);

    // 5. 记录执行前余额
    uint256 referrerBalBefore = IERC20(USDT).balanceOf(referrer1);

    // 6. 执行调用
    (bool success, ) = address(dexRouter).call(data);
    assertTrue(success, "swap should succeed with ERC-8021 suffix");

    // 7. 验证推荐人收到佣金（与无后缀时的金额一致）
    uint256 referrerBalAfter = IERC20(USDT).balanceOf(referrer1);
    assertGt(referrerBalAfter, referrerBalBefore, "referrer should receive commission");
}
```

#### 3.3.2 新增测试：Fuzz 测试

**添加到同一测试文件或独立文件 `src/tests/suffix/SuffixFuzzTest.t.sol`。**

```solidity
/// @dev Fuzz: single commission + random suffix → commission always parsed correctly
function testFuzz_singleCommission_withRandomSuffix(
    uint256 suffixLength,
    uint256 suffixSeed
) public {
    // Bound suffix length to reasonable range (1-1024 bytes)
    suffixLength = bound(suffixLength, 1, 1024);

    // 1. 构造带分佣的 swap calldata
    bytes memory swapData = _generateWETH2USDTSmartSwapData();
    bytes memory commissionData = _generate1CommissionData(false, USDT);

    // 2. 构造随机后缀
    bytes memory suffix = _buildRandomSuffix(suffixLength, suffixSeed);

    // 3. 拼接并执行
    bytes memory data = bytes.concat(swapData, commissionData, suffix);
    uint256 referrerBalBefore = IERC20(USDT).balanceOf(referrer1);
    (bool success, ) = address(dexRouter).call(data);
    assertTrue(success, "swap should succeed with random suffix");

    // 4. 验证分佣正确
    uint256 referrerBalAfter = IERC20(USDT).balanceOf(referrer1);
    assertGt(referrerBalAfter, referrerBalBefore, "referrer should receive commission");
}

/// @dev Fuzz: no ExtraData + random suffix → no commission, swap succeeds
function testFuzz_noExtraData_withRandomSuffix(
    uint256 suffixLength,
    uint256 suffixSeed
) public {
    suffixLength = bound(suffixLength, 1, 1024);

    bytes memory swapData = _generateWETH2USDTSmartSwapData();
    bytes memory suffix = _buildRandomSuffix(suffixLength, suffixSeed);

    bytes memory data = bytes.concat(swapData, suffix);
    (bool success, ) = address(dexRouter).call(data);
    assertTrue(success, "swap should succeed with random suffix and no ExtraData");
}

/// @dev Fuzz: commission + trim + random suffix → both parsed correctly
function testFuzz_commissionAndTrim_withRandomSuffix(
    uint256 suffixLength,
    uint256 suffixSeed
) public {
    suffixLength = bound(suffixLength, 1, 1024);

    bytes memory swapData = _generateWETH2USDTSmartSwapData();
    bytes memory trimData = _generate1TrimOnlyTrimData();
    bytes memory commissionData = _generate1CommissionData(false, USDT);
    bytes memory suffix = _buildRandomSuffix(suffixLength, suffixSeed);

    bytes memory data = bytes.concat(swapData, trimData, commissionData, suffix);
    (bool success, ) = address(dexRouter).call(data);
    assertTrue(success, "swap should succeed with trim + commission + random suffix");
}
```

#### 3.3.3 回归验证

运行全部现有测试，确认向后兼容：

```bash
# 全量测试（所有现有 commission/trim/adapter 测试必须通过）
forge test --match-path "src/tests/**" -vvv

# 合约体积检查（增量 < 500 字节）
npm run size
```

现有测试文件（不修改、仅验证通过）：

| 目录 | 文件 | 覆盖范围 |
|------|------|---------|
| `src/tests/commission/` | `CommissionTest1-3.t.sol`、`DualCommissionTokenTest.t.sol`、`Dual*ETHTest.t.sol`、`WrapCommissionTest.t.sol` | 单/双推荐人分佣，ETH/ERC20 |
| `src/tests/trim/` | `SmartSwapTrimTest.t.sol`、`DagSwapTrimTest.t.sol`、`MultiCallTrimTest.t.sol` 等 | 单/双正滑点，各 swap 方法 |
| `src/tests/multiCommission/` | `SmartSwapMultiCommissionTest.t.sol` | 3-8 推荐人分佣 |
| `src/tests/exactout/` | `ExactOut*CommissionTest.t.sol` | ExactOut 模式分佣 |
