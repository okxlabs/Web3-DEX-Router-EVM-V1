---
name: "module-dexrouter"
description: "DexRouter 入口合约模块设计"
---

# Module: DexRouter

## 职责

DexRouter 是唯一的入口合约，负责接收用户交易、解析 calldata、应用守卫，并委托给对应的路由库执行。

不负责：路由策略实现（路由库）、具体 DEX 协议交互（适配器）、佣金计算（CommissionLib）。

## 核心函数（共 15 个）

| 类别 | 函数 | 委托至 |
|------|------|--------|
| SmartSwap | `smartSwapByOrderId()`, `smartSwapTo()` | SmartSwapRouter |
| DAG Swap | `dagSwapByOrderId()`, `dagSwapTo()` | DagRouter |
| Unxswap（V2 精确输入） | `unxswapByOrderId()`, `unxswapTo()`, `unxswapToWithBaseRequest()` | UnxswapRouter |
| UnxswapV3（V3 精确输入） | `uniswapV3SwapTo()`, `uniswapV3SwapToWithBaseRequest()` | UnxswapV3Router |
| Unxswap 精确输出 | `unxswapExactOutTo()`, `unxswapExactOutToByOrderId()` | UnxswapExactOutRouter |
| UnxswapV3 精确输出 | `uniswapV3SwapExactOutTo()` | UnxswapV3ExactOutRouter |
| SwapWrap | `swapWrap()`, `swapWrapToWithBaseRequest()` | SwapWrapRouter |
| V3 回调 | `uniswapV3SwapCallback()` | 按标志位分发 |

## 通用执行模式

每个公共函数遵循：
1. 守卫：`nonReentrant` + `whenNotPaused`
2. 从 ABI 编码参数计算 `swapDataLength`
3. `ExtraDataLib.getDecodedExtraData(swapDataLength)` → `ExtraData` 结构体
4. 使用 ExtraData 调用路由库函数

## 依赖关系

- 参考 [arch/dependency.md](../arch/dependency.md)

## 踩坑点

- [Pitfall] 字节码大小 **must** 控制在 EIP-170 限制（24,576 字节）以内。v1.0.7 全方法集 24,436B（余量 138B），v1.0.8-transfer-mode 通过 ADR-012 方法选择降至 14,164B（余量 10,412B）。实际余量取决于部署版本包含的方法集
- [Pitfall] 不同链的部署可能有不同的方法集（选择性包含/排除路由库）
