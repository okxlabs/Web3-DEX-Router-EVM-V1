---
name: "contract-interface-conventions"
description: "智能合约接口规范——函数命名、参数编码、事件定义"
---

# 智能合约接口规范

## 函数命名规范

- 公共入口点: 驼峰命名无前缀（`smartSwapTo`, `dagSwapTo`）
- 内部/私有函数: 以 `_` 为前缀（`_unxswapInternal`, `_doUnxswap`）
- 验证函数: `validate` 前缀（`validateCommissionInfo`, `validateTrimInfo`）
- [Rule] 入口点命名 **must** 反映路由策略 + 操作类型

---

## 事件规范

### 核心事件（EventLib 发出）
```solidity
event OrderRecord(address fromToken, address toToken, address sender, uint256 fromAmount, uint256 returnAmount);
event SwapOrderId(uint256 id);
event CommissionAndTrimInfo(uint256 toBCommission, uint256 toBTrim, uint256 trimRate, uint256 chargeRate);
```

### 佣金事件（CommissionLib 在 assembly 中发出）
```solidity
event CommissionFromTokenRecord(address fromTokenAddress, uint256 commissionAmount, address referrerAddress, uint256 rate);
event CommissionToTokenRecord(address toTokenAddress, uint256 commissionAmount, address referrerAddress, uint256 rate);
```

### 正滑点事件（CommissionLib 在 assembly 中发出）
```solidity
event PositiveSlippageTrimRecord(address toTokenAddress, uint256 trimAmount, address trimAddress);
event PositiveSlippageChargeRecord(address toTokenAddress, uint256 chargeAmount, address chargeAddress);
```

- [Rule] 事件命名 **must** 使用帕斯卡命名法
- [Rule] 佣金事件 **must** 包含方向（FromToken / ToToken）
- [Rule] 正滑点事件 **must** 包含用途（Trim / Charge）

### 事件触发流程

```
Start Swap
  → SwapOrderId（订单 ID，最先触发）
  → CommissionAndTrimInfo（汇总：toBCommission/toBTrim/trimRate/chargeRate）
  → CommissionFromTokenRecord（如有 from-token 佣金，每个推荐人一个事件）
  → Execute Swap（适配器执行）
  → CommissionToTokenRecord（如有 to-token 佣金，每个推荐人一个事件）
  → PositiveSlippageTrimRecord（如有正滑点捕获）
  → PositiveSlippageChargeRecord（如有正滑点收费）
  → OrderRecord（最终：fromToken/toToken/sender/fromAmount/returnAmount，最后触发）
End Swap
```

### CommissionAndTrimInfo 字段含义

- `toBCommission`: 0 = 无佣金，1 = 非 ToB 佣金（ToC），2 = ToB 佣金
- `toBTrim`: 0 = 无正滑点，1 = 非 ToB 正滑点，2 = ToB 正滑点

### OrderRecord 已知限制

- [Warning] `fromAmount` 不扣除退款——Adapter 退款场景下 OrderRecord 中的 fromAmount 与链上实际消耗不一致
- [Warning] LaunchPad Adapter 的 OrderRecord 与 DexRouter OrderRecord 的 Topic0 不同，解析时 **must** 区分来源

---

## ExtraData 编码规范

### 佣金字段（每字段 32 字节）
```
[标志位(6B)][费率(6B)][地址(20B)]
```

### Token 字段
```
[isToB(1B)][referrerNum(1B)][填充(10B)][token(20B)]
isToB: 0x80 = ToB, 0x00 = ToC
```

### 正滑点字段
```
[trimFlag(6B)][费率/isToB(6B)][地址/金额(20B)]
```

---

## 标志位碰撞规避

- 所有佣金标志位在第 2-3 字节共享 `0afc`
- 所有正滑点标志位在第 0-3 字节共享 `77777777`
- Permit2 标志位在第 0-4 字节共享 `92527fff1a`
- [Rule] 48 位标志位：随机碰撞概率约 3.5×10⁻¹⁵，**never** 缩短标志位长度

---

## 错误处理规范

- [Rule] 使用描述性字符串消息: `require(receiver != address(0), "not addr(0)")`
- [Convention] 优先使用自定义错误以节省 Gas: `error AlreadyPaused()`
- [Convention] Assembly revert 使用十六进制编码消息以优化大小

### 验证顺序
1. 守卫（nonReentrant, whenNotPaused）
2. 参数验证（地址、金额、截止时间）
3. 佣金/正滑点验证（费率、地址）
4. 业务逻辑执行
5. 返回金额验证（>= minReturn）
