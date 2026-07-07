---
name: "module-extradata"
description: "ExtraData 解析模块设计——calldata 布局与从右到左解析"
---

# Module: ExtraData System (ExtraDataLib)

## 职责

从 calldata 末尾解析 ExtraData（佣金、正滑点、Permit2、退款地址），返回 ExtraData 结构体。

不负责：佣金执行（CommissionLib）、转账执行（TransferLib）。

## Calldata 布局

```
┌──────────────────────┬──────────────────────────────────────────┐
│  4B 选择器            │                                          │
│  + ABI 编码参数       │           ExtraData（可选）                │
│  (swapData)          │ refundTo │ permit2Info │ trimInfo │ comm │
└──────────────────────┴──────────────────────────────────────────┘
                                                            ↑
                                               effectiveEnd（≤ calldatasize）
```

## 解析顺序（从右到左）

1. **CommissionInfo** — 在最后 32B 字段中检测佣金标志位
2. **TrimInfo** — 跳过佣金后检测正滑点标志位
3. **Permit2Info** — 跳过正滑点后检测 permit2 标志位
4. **RefundTo** — 可选的 32B 退款地址

## 4 个独立可选字段

ExtraData 由 4 个独立可选字段组成，每个字段通过 48-bit flag 匹配检测：

| # | 字段 | Flag 类型 | 大小（bytes32 单位） |
|---|------|-----------|---------------------|
| 1 | CommissionInfo | 6 个 flag（from/to × single/dual/multiple） | 0 或 referrerNum+1 |
| 2 | TrimInfo | TRIM_FLAG, TRIM_DUAL_FLAG | 0, 2, 或 3 |
| 3 | Permit2Info | SIG65_FLAG, SIG64_FLAG | 0 或 amountLength+4 |
| 4 | RefundTo | REFUND_TO_ADDRESS_FLAG | 0 或 1 |

## 16 种有效基本组合

4 个字段独立可选 → 2^4 = 16 种基本组合：

| # | Commission | Trim | Permit2 | RefundTo |
|---|:---:|:---:|:---:|:---:|
| 1 | - | - | - | - |
| 2 | Y | - | - | - |
| 3 | - | Y | - | - |
| 4 | Y | Y | - | - |
| 5 | - | - | Y | - |
| 6 | Y | - | Y | - |
| 7 | - | Y | Y | - |
| 8 | Y | Y | Y | - |
| 9 | - | - | - | Y |
| 10 | Y | - | - | Y |
| 11 | - | Y | - | Y |
| 12 | Y | Y | - | Y |
| 13 | - | - | Y | Y |
| 14 | Y | - | Y | Y |
| 15 | - | Y | Y | Y |
| 16 | Y | Y | Y | Y |

子类型变体进一步扩展组合数：
- Commission: 6 种 flag（from/to × 1/2/3-8 个推荐人）
- Trim: 2 种 flag（单 trim / 双 trim+charge）
- Permit2: 2 种 flag（sig64 / sig65）× amountLength（1-9）

## 两条解析路径

| 路径 | 函数 | 处理字段 | 使用场景 |
|------|------|---------|---------|
| ExtraDataLib | `getDecodedExtraData()` | 全部 4 个字段（Commission + Trim + Permit2 + RefundTo） | 所有 swap 函数均走此路径 |

## 依赖关系

- 参考 [arch/dependency.md](../arch/dependency.md)

## ERC-8021 兼容性（effectiveEnd 反向扫描）— ✅ 已实现

> **状态:** ✅ **已实现**。边界还原**内联在** `ExtraDataLib._getExtraDataEndPointAndLength(swapDataLength)`（并非独立的 `_computeEffectiveEnd()` 函数）。设计文档见 `docs/20260304-erc8021-compatibility/`。
> **当前代码:** ExtraDataLib 用反向扫描得到的 `endPoints[0]` 锚定全部解析；CommissionLib 不再引用 `calldatasize()`，改为消费 `endPoints`。

**背景:** ERC-8021 在 calldata 末尾追加归因后缀 `原始calldata | schemaData(变长) | schemaId(1B) | ercMarker(16B)`。DexRouter 从右到左解析 ExtraData，外部后缀会导致解析错位 → 佣金/正滑点被静默跳过（无 revert）。

**实际实现（`_getExtraDataEndPointAndLength(swapDataLength)`）:**

```
1. endPoint = calldatasize() - ((calldatasize() - 4) % 0x20)   // 剥离非对齐的尾部后缀
2. 自 endPoint 向后以 0x20 步长扫描，下界为 swapDataLength（gt(scanPos, swapDataLength)）:
     flagMasked = calldataload(scanPos - 0x20) & _COMMISSION_FLAG_MASK
     精确匹配 11 个已知标志位（6 佣金 + 2 正滑点 + 2 Permit2 + 1 RefundTo）:
       FROM_TOKEN_COMMISSION / TO_TOKEN_COMMISSION
       FROM_TOKEN_COMMISSION_DUAL / TO_TOKEN_COMMISSION_DUAL
       FROM_TOKEN_COMMISSION_MULTIPLE / TO_TOKEN_COMMISSION_MULTIPLE
       TRIM_FLAG / TRIM_DUAL_FLAG
       PERMIT2_INFO_SIG65_FLAG / PERMIT2_INFO_SIG64_FLAG
       REFUND_TO_ADDRESS_FLAG
     命中 → endPoint = scanPos, break
3. endPoint 写入 endPoints[0]，锚定后续所有 ExtraData 解析
4. 未命中任何 flag → 退化为"无 ExtraData"（各 length 为 0）
```

**设计要点:**
- [Rule] `_COMMISSION_FLAG_MASK == _TRIM_FLAG_MASK == _PERMIT2_INFO_FLAG_MASK == _REFUND_TO_MASK`（均为 `0xffffffffffff000...0`），一次 mask 覆盖全部 11 个标志位
- [Rule] 反向扫描下界为 `swapDataLength`（调用方 `DexRouter` 各入口传入）：此前的字节保证是 swapData，不可能含 ExtraData，从而避免误读 ABI 参数中形似 flag 的值
- [Rule] 非对齐字节直接剥离（`(calldatasize() - 4) % 0x20`），ERC-8021 后缀通常不是 32B 对齐的
- 无后缀时: `endPoints[0] == calldatasize()`，零行为差异
- 命中后由 `_validateExtraDataBoundaries(endPoints, lengths, swapDataLength)` 校验边界

## Permit2Info Calldata 布局

```
┌──────────┬───────┬──────────┬───────────┬──────────┐
│ 标志位(6B)│ owner │  nonce   │ deadline  │ signature│
│          │(20B)  │ (32B)    │  (32B)    │(64/65B)  │
└──────────┴───────┴──────────┴───────────┴──────────┘
```

- 65 字节签名（r,s,v）— 标志位 `0x92527fff1a65`
- 64 字节签名（r,s 无 v）— 标志位 `0x92527fff1a64`

## 踩坑点

- [Pitfall] effectiveEnd 已实现（内联于 `_getExtraDataEndPointAndLength`）；旧文档"未实现/直接用 calldatasize()"的描述已过时
- [Pitfall] effectiveEnd 反向扫描下界为 `swapDataLength`，若一直扫到下界仍未命中任何已知 flag，则视为无 ExtraData（各 length 为 0），而非 revert
- [Pitfall] Calldata **must** 保持 32 字节对齐 `(calldatasize - 4) % 32 == 0`，非对齐字节被 effectiveEnd 算法直接剥离
