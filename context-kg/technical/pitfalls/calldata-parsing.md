---
name: "calldata-parsing"
description: "Calldata 解析相关踩坑记录——ERC-8021 后缀、对齐、标志位"
---

# Pitfall: Calldata 解析

## P-001: Calldata 后缀导致静默资金损失（ERC-8021）— ✅ 已修复

- **严重性:** 关键
- **状态:** ✅ **已实现** — effectiveEnd 反向扫描已合入(设计文档见 `docs/20260304-erc8021-compatibility/`)
- **组件:** ExtraDataLib(`contracts/8/libraries/ExtraDataLib.sol`,以及 `contracts/exactout/` 同名库)
- **原问题:** 外部系统在 ExtraData 之后追加数据(如 ERC-8021 归因后缀)时,佣金和正滑点被静默跳过(无 revert)
- **实际实现:** 边界还原**内联在** `ExtraDataLib._getExtraDataEndPointAndLength(swapDataLength)` 中(并非独立的 `_computeEffectiveEnd()` 函数):
  - 起点 `endPoint = calldatasize() - ((calldatasize() - 4) % 0x20)`,先剥离非对齐的尾部后缀;
  - 自该点起以 32 字节对齐**反向扫描**,下界为 `swapDataLength`(此前的字节保证是 swapData,不可能含 ExtraData,避免误读 ABI 参数里形似 flag 的值);
  - 命中 **11 个已知标志位**(6 commission 变体 + 2 trim + 2 permit2 + 1 refundTo,共用同一 `_COMMISSION_FLAG_MASK`)中任意一个即为真实右边界,写入 `endPoints[0]` 锚定后续全部解析;
  - 未命中任何 flag → 退化为"无 ExtraData"(各 length 为 0)。
- **下游:** `_validateExtraDataBoundaries(endPoints, lengths, swapDataLength)` 校验边界;`CommissionLib` 不再引用 `calldatasize()`,改为消费 `ExtraDataLib` 给出的 `endPoints`。`swapDataLength` 由 `DexRouter` 各入口传入 `getDecodedExtraData(swapDataLength)`。
- [Rule] ExtraData / 佣金 / 正滑点解析 **must** 以反向扫描得到的 effectiveEnd(`endPoints[0]`)为右边界,**never** 直接使用 `calldatasize()`。
- [Rule] 新增 ExtraData 字段类型时 **must** 同步将新 flag 加入 `_getExtraDataEndPointAndLength()` 的反向扫描标志位列表。
- [Pitfall] 旧文档曾标注本项"未实现/CommissionLib 直接用 calldatasize()";该描述已过时——以 `_getExtraDataEndPointAndLength` 的反向扫描实现为准。

## P-008: 精确输出交换不支持正滑点

- **严重性:** 低
- **组件:** ExactOutSwapHelper, UnxswapExactOutRouter, UnxswapV3ExactOutRouter
- [Pitfall] 精确输出交换中 ExtraData 包含正滑点数据将导致 revert
- 触发条件: 后端错误地为精确输出路由编码正滑点
- 正确做法: 后端/API **never** 为精确输出交换编码正滑点数据

## P-009: SwapWrap 不支持正滑点

- **严重性:** 低
- **组件:** SwapWrapRouter
- [Pitfall] `swapWrap()` 在 `trimInfo.hasTrim == true` 时显式 revert
- 触发条件: 后端错误地为 wrap/unwrap 路由编码正滑点
- 正确做法: 后端/API **never** 为 ETH↔WETH 转换编码正滑点数据
