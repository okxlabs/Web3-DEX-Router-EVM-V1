---
name: "calldata-parsing"
description: "Calldata 解析相关踩坑记录——ERC-8021 后缀、对齐、标志位"
---

# Pitfall: Calldata 解析

## P-001: Calldata 后缀导致静默资金损失（ERC-8021）— 未修复，设计已完成

- **严重性:** 关键
- **状态:** ⚠️ **未实现** — 技术设计已完成（见 `docs/20260304-erc8021-compatibility/`），代码尚未合入
- **组件:** ExtraDataLib（目标修改文件）
- **当前代码现状:** `ExtraDataLib._getExtraDataEndPointAndLength()` 第 78 行直接使用 `calldatasize()` 作为右边界，`CommissionLib` 同样无 effectiveEnd 实现
- **原问题:** 外部系统在 ExtraData 之后追加数据（如 ERC-8021 归因后缀）时，佣金和正滑点被静默跳过（无 revert）
- **计划修复方案:** 在 `ExtraDataLib` 新增 `_computeEffectiveEnd()` 函数，反向扫描 11 个已知标志位（6 commission + 2 trim + 2 permit2 + 1 refundTo），首次命中即为真实 ExtraData 边界
- **残留风险:** 当前 ExtraDataLib 和 CommissionLib 均直接使用 `calldatasize()`，任何外部后缀都会导致解析错位
- [Rule] 修改 ExtraData 解析逻辑时 **must** 确保 effectiveEnd 覆盖所有解析路径，**never** 直接使用 `calldatasize()`
- [Rule] 新增 ExtraData 字段类型时 **must** 同步将新 flag 加入 `_computeEffectiveEnd()` 的扫描列表

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
