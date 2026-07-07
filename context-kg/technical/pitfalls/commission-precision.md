---
name: "commission-precision"
description: "佣金精度与分配相关踩坑记录"
---

# Pitfall: 佣金精度

## P-002: from_commission + trim 组合边缘情况

- **严重性:** 中等
- **组件:** CommissionLib, Gas 模块
- [Pitfall] `from_commission` 和 `trim` 同时出现时 Gas 估算可能不准确
- 触发条件: 生产数据中罕见的边缘情况同时包含两者
- 正确做法: 验证 Gas 分解是否正确

## P-010: 多推荐人最后推荐人余额模式

- **严重性:** 低
- **组件:** CommissionLib
- [Pitfall] 多推荐人间分配佣金时整数除法产生舍入粉尘
- 正确做法: 最后一个推荐人 **must** 获得 `totalAmount - sum(前面)` 而非公式结果
- [Warning] 代码审查者 **must** 验证此模式在任何佣金分配变更中得以保持

## P-012: 多费率佣金中 fromTokenAmount 精度损失

- **严重性:** 高
- **组件:** CommissionLib, 后端计算
- [Pitfall] 累积整数除法舍入导致链上与后端计算值不同（差异可达 3 wei）
- 触发条件: 顺序应用 `floor(amount × rate / DENOMINATOR)` 产生的结果与后端单步计算不同
- [Warning] FourMeme 代币有 `amount % 10^9 == 0` 约束，精度损失可达 999,999,999 wei
- 正确做法:
  - 后端使用迭代调整算法（从 floor 估计值递增直到总额超过 UI 金额）
  - 标准代币接受 ±1-2 wei 差异
  - 有模数约束的代币在佣金计算前 **must** 应用约束对齐
