---
name: "swap-flow"
description: "代币交换核心流程——通用 swap 执行步骤与资金流向"
---

# 核心流程: 代币交换

## 流程元信息

- 触发入口: DexRouter 的 15 个公共 swap 函数
- 主要实体: BaseRequest, RouterPath, ExtraData, CommissionInfo, TrimInfo

---

## 通用执行流程

1. **DexRouter（入口点）** — 接收交易，应用 `nonReentrant` + `whenNotPaused` 守卫
2. **ExtraDataLib** — 计算 swapDataLength，从右到左解析 ExtraData → CommissionInfo, TrimInfo, Permit2Info, RefundTo
3. **TransferLib** — 按转账模式将 fromToken 从用户转入合约/池
4. **CommissionLib（from-token）** — 如有 from-token 佣金，在 swap 前收取并分配
5. **路由库** — 执行 swap（SmartSwap/DagSwap/Unxswap/UnxswapV3/SwapWrap）
6. **CommissionLib（to-token）** — 如有 to-token 佣金，从 swap 输出中收取并分配
7. **TrimLib** — 如有正滑点，从超出 expectAmountOut 的部分捕获
8. **EventLib** — 事件触发顺序: SwapOrderId（最先）→ CommissionAndTrimInfo → (swap 执行中的佣金/trim 事件) → OrderRecord（最后）
9. **最终检查** — `require(returnAmount >= minReturnAmount)`

---

## middleReceiver 逻辑

当存在 to-token 佣金或正滑点时：
```
swapReceiver = (hasToTokenCommission || hasTrim) ? address(this) : receiver
```
合约接收 swap 输出后，扣除佣金和正滑点，再将余额发给用户。

---

## 正滑点计算

### 单正滑点（0x777777771111）
```
excess = actualOutput - expectAmountOut
maxCapture = actualOutput × trimRate / 1000
capturedAmount = min(excess, maxCapture)
userReceives = actualOutput - capturedAmount
```

### 双正滑点含收费（0x777777772222）
```
chargeAmount = capturedAmount × chargeRate / 1000
trimAmount = capturedAmount - chargeAmount
→ trimAmount 发送至 trimAddress
→ chargeAmount 发送至 chargeAddress
```

---

## 异常分支

| 场景 | 处理方式 |
|------|----------|
| 截止时间超过 | revert: `require(block.timestamp <= deadline)` |
| 返回金额不足 | revert: `require(returnAmount >= minReturnAmount)` |
| 佣金费率超限 | revert: 费率验证失败 |
| 正滑点 + 精确输出 | revert: 不支持的组合 |
| 正滑点 + SwapWrap | revert: 不支持的组合 |
| UniV3 池流动性耗尽 | 部分输入未消耗，需退款逻辑 |
| Permit2 不存在 | revert: 外部调用失败 |

---

## 踩坑点

- [Pitfall] `minReturnAmount` 是扣除所有费用后用户实际收到的金额，**never** 为原始 swap 输出
- [Pitfall] from-token 佣金在 swap 前扣除，to-token 佣金在 swap 后扣除，顺序 **never** 颠倒
- [Pitfall] 正滑点捕获发生在 minReturn 检查之前
