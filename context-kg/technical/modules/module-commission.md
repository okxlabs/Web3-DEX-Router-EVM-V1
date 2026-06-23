---
name: "module-commission"
description: "佣金系统模块设计——CommissionLib 佣金收取与分配"
---

# Module: Commission System (CommissionLib)

## 职责

处理 from-token / to-token 佣金的计算、验证和分配，支持 1-8 个推荐人。

不负责：正滑点计算（TrimLib）、代币转账执行（TransferLib）。

## 核心逻辑

### From-Token 佣金
在 swap **之前**从输入代币中收取：
```
commissionAmount = inputAmount × totalRate / (DENOMINATOR - totalRate)
```

### To-Token 佣金
在 swap **之后**从输出代币中收取：
```
commissionAmount = outputAmount × rate / DENOMINATOR
```

### 关键常量
- `DENOMINATOR = 10^9`
- `COMMISSION_RATE_LIMIT = 30,000,000`（最高 3%）
- 推荐人数量：最少 1，最多 8（`MIN_COMMISSION_MULTIPLE_NUM = 3`，`MAX_COMMISSION_MULTIPLE_NUM = 8`）

## 标志位编码

| 标志位 | 值 | 模式 |
|--------|------|------|
| `FROM_TOKEN_COMMISSION` | `0x3ca20afc2aaa` | 1 个推荐人，from-token |
| `TO_TOKEN_COMMISSION` | `0x3ca20afc2bbb` | 1 个推荐人，to-token |
| `FROM_TOKEN_COMMISSION_DUAL` | `0x22220afc2aaa` | 2 个推荐人，from-token |
| `TO_TOKEN_COMMISSION_DUAL` | `0x22220afc2bbb` | 2 个推荐人，to-token |
| `FROM_TOKEN_COMMISSION_MULTIPLE` | `0x88880afc2aaa` | 3-8 个推荐人，from-token |
| `TO_TOKEN_COMMISSION_MULTIPLE` | `0x88880afc2bbb` | 3-8 个推荐人，to-token |

## 依赖关系

- 参考 [arch/dependency.md](../arch/dependency.md)

## 踩坑点

- [Pitfall] 多推荐人分配时最后一个推荐人 **must** 获得余额，**never** 使用公式（避免舍入粉尘）
- [Pitfall] 多费率累积整数除法导致链上与后端精度差异，标准代币接受 ±1-2 wei 差异
- [Pitfall] 对有模数约束的代币（FourMeme），佣金计算前 **must** 应用约束对齐
- [Pitfall] `from_commission + trim` 组合罕见但存在，Gas 估算可能不准确
