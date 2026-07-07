---
name: "business"
description: "DexRouter 业务知识域——收费返佣规则、资金流、业务场景"
---

# 业务知识域

## 项目定位

DexRouter 是 OKX 的生产级 DEX 聚合器合约，覆盖多条 EVM 链。通过将代币交换委托给协议特定的适配器来路由最优路径。

## 核心业务能力

- **代币交换**: 支持 V2/V3/V4 精确输入和精确输出交换
- **多路径路由**: SmartSwap（批次分割）、DAG（有向无环图）路由
- **收费系统**: 根据 Token 类型按费率表收取交易费用
- **返佣系统**: 邀请码机制，交易时实时链上分佣
- **正滑点捕获**: 超出预期输出的正向滑点捕获与分配
- **多转账模式**: Legacy、Direct、Permit2（授权/签名）、ByInvest、NoTransfer
  > Direct 模式通过 `transferFrom` 直接转账，用于佣金分配和通用转账场景

## 目标用户

- OKX DEX 前端用户（ToC）
- 企业合作方集成（ToB）
- LaunchPad 平台集成
- PMM/RFQ 做市商

---

## 收费规则（Fee）

> 来源: DEX 新版 Fee&Referral PRD

### 收费方式

OKX DEX 根据交易中涉及的 **Token 类型**收取费用：
- Token 类型在清单中明确列出（代币符号和名称）
- 清单在 OKX DEX Fees 网站上公开，定期更新

### 费率表

| 交易对类型 | 费率 | 说明 |
|-----------|------|------|
| Native/wNative/stNative/LST ↔ Native/wNative/stNative/LST | **0%** | 对价格/费用极敏感 |
| Native/wNative/stNative/LST ↔ Stablecoin | **0%** | 对价格/费用极敏感 |
| Stablecoin ↔ Stablecoin | **0%** | 对价格/费用极敏感 |
| Others ↔ Others | **0%** | 小币对小币交易量占比小，返佣意义不大 |
| Mainstream Token ↔ Native/wNative/stNative/LST | **0.25%** | |
| Mainstream Token ↔ Stablecoin | **0.25%** | |
| Mainstream Token ↔ Mainstream Token | **0.25%** | |
| Mainstream Token ↔ Others | **0.25%** | |
| Native/wNative/stNative/LST ↔ Others | **0.85%** | |
| Stablecoin ↔ Others | **0.85%** | |

> **链上安全上限**: 合约层面 `COMMISSION_RATE_LIMIT = 30000000`，`DENOMINATOR = 10^9`，即最大佣金率 3%。上述费率表由后端控制，合约只做上限校验。
>
> **佣金编码精度**: 链上 rate 使用十亿分之一精度。例如 0.25% = 2,500,000（非 25/10000）。

### 佣金模式约束

- From-token 和 to-token 佣金**互斥**，不可同时收取
- 单笔交易最多支持 **3-8 个 referrer**（多地址佣金模式，`MAX_COMMISSION_MULTIPLE_NUM = 8`）
- **NoTransfer / ByInvest 模式下**：from-token 佣金不可用
- **ByInvest 模式下**：from-token 和 to-token 佣金均不可用

### 链支持

- **收费**: 所有 EVM 链 + Solana 链
- **返佣**: Ethereum、Base、BNB Smart Chain、Arbitrum 及其他 EVM 兼容链

---

## 返佣规则（Referral）

> 来源: [OKX DEX 邀请返佣计划](https://web3.okx.com/zh-hans/help/whats-dex-referral-program)

### 核心机制

1. **邀请码生成**: 邀请人通过助记词钱包生成邀请码，平台服务器存储邀请码属性（不记录邀请关系）
2. **用户绑定**: 用户点击邀请链接后，签名绑定，信息存储在被邀请人**设备端**（自托管），支持多设备自动同步
3. **交易及返佣**: 交易时设备端将邀请码信息传给服务端，服务端校验并组 calldata 携带邀请码信息，交易时**实时完成链上返佣分配**

### 邀请码规则

- 所有用户都可使用助记词钱包生成邀请码
- 每个助记词钱包最多生成 **100 个**邀请码
- 邀请码长度 5-15 位字母或数字，创建后**不可修改或删除**
- 首个邀请码自动设为默认码
- 默认使用多链钱包的 EVM、Solana 地址作为链上佣金接收地址

### 绑定关系

- 被邀请人签名即绑定（1 步完成），无需关联 CEX 账户
- 支持助记词钱包和私钥钱包（私钥钱包仅支持 Solana 和 EVM）
- 绑定维度: `<设备 + 钱包>`，单设备单钱包仅能绑定一个邀请码
- 邀请码属性存储在用户设备端，平台**不记录**绑定关系
- 同一钱包可在不同设备绑定不同邀请码

### 返佣等级

| 等级 | 总返佣比例 | 月交易量门槛 |
|------|-----------|------------|
| 1 级 | 20% | 无门槛 |
| 2 级 | 30% | $100K |
| 3 级 | 35% | $300K |
| 4 级 | 40% | $1M |
| 5 级 | 45% | $3M |
| 6 级 | 50% | $10M |

- 每个等级支持设置 0-20% 的受邀人优惠比例
- **返佣计算**: 实际返佣比例 = 总返佣比例 - 受邀人优惠比例
- **升级**: 每小时评估，达标后 2 小时内自动升级
- **降级**: 每月评估前 3 个月交易量，连续 3 月未达标则降至历史最高达标等级

### 佣金发放 — 实时分佣

1. 用户发起交易，交易携带邀请码信息（邀请码、邀请人地址、返佣比例等）并签名
2. 平台校验邀请码信息与服务器记录一致
3. 交易上链后手续费自动分配：
   - 邀请人返佣 → 直接支付到邀请人该链钱包地址（实时到账）
   - 用户折扣 → 直接减免交易手续费
   - 剩余手续费 → 归平台

**不产生返佣的情况:**
- 邀请钱包或邀请码被冻结
- 受邀人交易的是免 UI 服务费的代币对

---

## 正滑点捕获（Trim）

> 来源: EVM正滑点捕获功能设计文档

### 概述

正滑点（Positive Slippage）是指实际交易获得的代币数量超过预期报价数量的部分。Trim 是正滑点捕获机制，采用与 commission 类似的 calldata 扩展方式实现。目前 API 侧已设计和开发正滑点收益功能，对指定客户类型收取正滑点收益，同时允许部分大客户使用正滑点捕获收益功能。

### 核心术语

| 术语 | 含义 |
|------|------|
| trim_flag | 正滑点捕获标志位，用于识别不同的捕获模式 |
| trim_rate | 正滑点捕获比例，精度为 1000，上限为 100（对应 10%） |
| trim_address | 正滑点收益接收地址 |
| expect_amount_out | 预期输出金额（UI 询价的 amountOut），用于计算正滑点基准 |
| charge_rate | 对正滑点捕获部分收费的比例，精度 1000，上限 1000（对应 100%） |
| charge_address | 接受对正滑点捕获部分收费的地址 |
| isToBTrim | 判断是否是来自 B 端客户的交易，默认为 false。**编码为 1 bit**（mask `0x80`，位于 expect_amount_out 所在 bytes32 的第 7 字节最高位） |

### Trim 模式

| 标志 flag | 含义 | 数据长度 |
|-----------|------|----------|
| `0x777777771111` | 单地址 trim | 64 字节 |
| `0x777777772222` | 双地址 trim | 96 字节 |

- **单地址模式**: 正滑点收益发送到一个地址（trim_address）
- **双地址模式**: 按比例分配，trim_address 接收捕获部分，charge_address 从中收费

### 字节编码结构

**单地址 trim（64 字节）:**
```
第1个 bytes32: trim_flag (6B) + isToBTrim (1bit, mask 0x80) + padding (5B) + expect_amount_out (20B)
第2个 bytes32: trim_flag (6B) + trim_rate (6B) + trim_address (20B)
```

**双地址 trim（96 字节）:**
```
第1个 bytes32: trim_flag (6B) + isToBTrim (1bit, mask 0x80) + padding (5B) + expect_amount_out (20B)
第2个 bytes32: trim_flag (6B) + trim_rate (6B) + trim_address (20B)
第3个 bytes32: trim_flag (6B) + charge_rate (6B) + charge_address (20B)
```

> **isToBTrim flag**: 定义在第1个 bytes32 的 padding 最高位（第7字节），合约解析后仅在事件中给出，不做其他用途。

### ExtraData 组合规则

ExtraDataLib 支持 4 种可选的 ExtraData 区域，共 16 种有效组合（2^4）。从 calldata 末尾从右向左排列：

| RefundTo | Permit2Info | TrimInfo | CommissionInfo | 说明 |
|----------|-------------|----------|----------------|------|
| ✗ | ✗ | ✗ | ✗ | 纯 swap，无 ExtraData |
| ✗ | ✗ | ✗ | ✓ | 仅收佣金 |
| ✗ | ✗ | ✓ | ✗ | 仅正滑点 |
| ✗ | ✗ | ✓ | ✓ | 佣金 + 正滑点 |
| ✗ | ✓ | ✗ | ✗ | 仅 Permit2 授权 |
| ✗ | ✓ | ✗ | ✓ | Permit2 + 佣金 |
| ✗ | ✓ | ✓ | ✓ | Permit2 + 佣金 + 正滑点 |
| ✓ | ✗ | ✗ | ✗ | 仅 RefundTo（ByInvest） |
| ... | ... | ... | ... | 其余组合类推 |

**关键规则:**
- **CommissionInfo** 始终在 calldata 最右侧（当存在时）
- **解析顺序**: Commission → Trim → Permit2Info → RefundTo（从右向左）
- 每种 ExtraData 通过特定的 flag 前缀识别（commission flag `0x3ca20afc2...`、trim flag `0x777777771...` 等）

### Calldata 完整布局

**ExtraData 区域从 calldata 末尾从右向左解析，顺序为：**

```
[4B selector] [ABI params (swapData)] [(memo)?] [RefundTo?] [Permit2Info?] [TrimInfo?] [CommissionInfo?]
                                                                                        ↑ calldatasize()
```

> memo 区域为透传数据，合约不解析，用于第三方链上索引。位于 swapData 与 ExtraData 之间的间隙中。

ExtraDataLib 从 `calldatasize()` 开始，按以下顺序从右向左解析 4 种 ExtraData：
1. **CommissionInfo**（最右，紧贴 calldata 末尾）
2. **TrimInfo**（在 CommissionInfo 左侧）
3. **Permit2Info**（在 TrimInfo 左侧，含签名授权转账参数）
4. **RefundTo**（最左的 ExtraData，ByInvest 模式下多余 fromToken 退还地址）

### 交易流程与 Receiver 路由

DexRouter 合约整体遵循"fromToken 分佣 → swap → toToken 分佣 → trim 收取"流程。根据是否收 toTokenCommission 和是否收 trim，需要为 swap 和 toTokenCommission 指定不同的 middleReceiver：

| 场景 | toTokenCommission | trim | swapReceiver | toTokenCommissionReceiver |
|------|-------------------|------|-------------|--------------------------|
| case1 | 不收 ✗ | 不收 ✗ | receiver | 无所谓 |
| case2 | 收 ✓ | 不收 ✗ | address(this) | receiver |
| case3 | 不收 ✗ | 收 ✓ 且有正滑点 | address(this) | 无所谓 |
| case4 | 收 ✓ | 收 ✓ 且有正滑点 | address(this) | address(this) |
| case5 | 不收 ✗ | 收 ✓ 但无正滑点 | address(this) | 无所谓 |
| case6 | 收 ✓ | 收 ✓ 但无正滑点 | address(this) | address(this) |

> **注意**: 只要收正滑点，不管有没有正滑点收益都需要先转给 `address(this)`，因为是否有正滑点收益需要在处理正滑点时才能判断，若在更早步骤判断会对现有流程和代码有很大改动。

---

## 收费资金流（Fee Distribution Fund Flow）

### EVM 资金流规则

| 场景 | 资金流方向 | 原因 |
|------|-----------|------|
| 收 from-token 且是 ERC20 | 用户地址 → 收费返佣地址 | 用户已授权，可直接转账 |
| 收 from-token 且是 native | Router → 返佣地址 | Native token 技术限制，不能直接让用户转账 |
| 收 to-token（所有场景） | Router → 返佣地址 | 用户未授权新换到的 toToken，且 pool 通常只支持一个目标地址 |

### SOL 资金流规则

- 任何场景下都是用户地址 → 收费返佣地址转账

### ToB/ToC 资金流区别

- **ToB（企业端）**: 资金 **must** 先通过 DexRouter 合约再分配（合规要求）
- **ToC（消费者端）**: 资金直接从用户分配，不经过 DexRouter（Gas 效率）

### 地址分配方案

| 场景 | Address 数量 | Token 数量 |
|------|-------------|-----------|
| toB | 最大 3 个 | 最大 4 个 |
| toC | 最大 3 个 | 最大 3 个 |
| cedefi | 最大 2 个 | 最大 2 个 |

### 资金管理要求

- 平台需建立独立的费用收集地址并配备访问控制策略

---

## PMM/RFQ 做市商业务

> PMM Protocol 是独立合约，DexRouter 通过 `PmmRFQAdapter` 调用。

- DexRouter 通过 `PmmRFQAdapter` 与外部 PMM Protocol 合约交互
- 交易流程：API 接入 → 数据同步 → 价格聚合 → 路径选择 → 报价返回 → 订单签名 → 交易执行 → 资金流转
- 订单结构体关键字段：`maker`（做市商地址）、`settler`（结算地址）、`allowedSender`（限制执行者，防订单窃取，零地址表示公开订单）
- EIP-712 签名域等参数由 PMM Protocol 合约定义，不在 DexRouter 仓库内管理
