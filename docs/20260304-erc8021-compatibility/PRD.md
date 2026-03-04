# ERC-8021 DexRouter 兼容性方案 — PRD（产品需求文档）

> 日期: 2026-03-03
> 状态: 草案
> 作者: DexRouter Team
> 相关文档: [SPEC](./SPEC.md) | [PLAN](./PLAN.md)

---

### 1.1 背景：ERC-8021 是什么？

ERC-8021（Transaction Attribution，交易归因）是由 Conner Swenberg（@ilikesymmetry）提出的 ERC 草案，旨在标准化链上交易来源追踪。它允许钱包、应用和前端在交易中嵌入归因标识符，从而实现对 builder（开发者/构建者）的收入分成。

**官方链接：**

- 讨论帖: https://ethereum-magicians.org/t/erc-8021-transaction-attribution/25561
- 官网: https://www.erc8021.com/
- Base 博客: https://blog.base.dev/builder-codes-and-erc-8021-fixing-onchain-attribution

#### 1.1.1 核心机制

ERC-8021 在交易 calldata 的**末尾**追加一段固定格式的后缀：

```
原始 calldata | schemaData (变长) | schemaId (1 字节) | ercMarker (16 字节)
                                   <-------- ERC-8021 后缀 -------->
```

| 组件         | 大小     | 说明                                                           |
| ------------ | -------- | -------------------------------------------------------------- |
| `ercMarker`  | 16 字节  | 固定值 `0x80218021802180218021802180218021`，始终位于 calldata 最末尾 |
| `schemaId`   | 1 字节   | 模式类型标识符（目前仅定义了 Schema 0）                          |
| `schemaData` | 变长     | 归因数据载荷，格式由 `schemaId` 决定                             |

**Schema 0（Canonical Code Registry）：**

```
| codes (变长 ASCII) | codesLength (1 字节) | schemaId=0x00 (1 字节) | ercMarker (16 字节) |
```

- `codesLength`：1 字节，表示后续 `codes` 字段的长度
- `codes`：ASCII 编码的实体标识符，用逗号（0x2C）分隔
- 后缀总长度 = 18 + codesLength 字节

**示例：**
```
后缀: 0x 62617365617070 07 00 80218021802180218021802180218021
         ^^^^^^^^^^^^^^^^ ^^ ^^ ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
         "baseapp" (7B)  cLen schemaId=0  ercMarker (16B)
```

**倒序解析算法：**

1. 提取最后 16 字节 → 验证 ercMarker 是否匹配 `0x8021...8021`
2. 提取前一个字节 → `schemaId`，决定解析规则
3. 根据 schema 规范解析剩余字节

#### 1.1.2 设计定位：面向链下，而非链上

ERC-8021 明确设计为**链下索引器和分析系统**使用，而非供链上合约消费。提案原文指出：

> "Any existing smart contract can support ERC-8021 attribution **without modification**."
> （任何现有智能合约无需修改即可支持 ERC-8021 归因。）

其假设是：合约通过自身的 ABI 解码正常读取参数，尾部多余字节会被 EVM 的 ABI 解码自然忽略。链下索引器再从原始交易 calldata 中提取归因数据。

**然而，这一假设对于显式从 calldata 尾部读取原始数据的合约不成立**——而 DexRouter 恰恰就是这样做的。

#### 1.1.3 DexRouter 是否需要"支持" ERC-8021？

不需要。DexRouter 无需解析或处理 ERC-8021 归因数据。唯一的需求是：

> **当钱包或前端在 DexRouter 的 calldata 末尾追加了 ERC-8021 后缀时，DexRouter 必须仍能正常运行。**

这是一个**防御性兼容**问题，而非功能接入。

### 1.2 问题描述

DexRouter 使用自定义机制，通过 assembly（`calldatasize()` 和 `calldataload()`）从 **calldata 尾部**读取分佣（commission）、正滑点（trim）等配置数据。如果任何外部方（钱包、聚合器、MEV relay）在 DexRouter 交易的 calldata 末尾追加了 ERC-8021 后缀，合约将会：

1. 将 ERC-8021 marker 误解析为分佣数据
2. Flag 校验失败导致 revert，或
3. 解析出错误的值，导致手续费分配异常

**影响：** 在任何采用 ERC-8021 的链上，用户交易可能失败或执行错误。

### 1.3 功能边界

**做什么：**

- 确保 DexRouter 在有或没有外部后缀的情况下，都能正确解析自身的 ExtraData（分佣、正滑点）
- 通过基于 flag 扫描的精确识别机制定位 ExtraData 边界
- **完全向后兼容**：不改变现有 calldata 编码方式，不阻塞已有业务
- 最小化合约变更范围，支持快速上线

**不做什么：**

- 不解析或使用 ERC-8021 归因数据
- 不假设 calldata 末尾追加了什么数据、多长的数据
- 不在 adapter 合约中做 ERC-8021 支持（adapter 通过内部调用接收独立的 calldata，不受原始交易 calldata 影响）
- 不改动前端/后端的 calldata 编码逻辑

### 1.4 成功指标

1. DexRouter 在有或没有外部后缀时均能正确执行 swap 交易
2. **现有 calldata 格式完全兼容**，无需任何调用方变更
3. 分佣和正滑点数据的解析结果与当前行为完全一致
4. 无 ExtraData 的调用行为不变（无分佣/无正滑点）
5. 常见路径 gas 额外消耗可控
6. 合约体积增加 < 500 字节
