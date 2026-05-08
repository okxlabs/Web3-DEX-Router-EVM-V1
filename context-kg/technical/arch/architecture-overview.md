---
name: "architecture-overview"
description: "DexRouter 整体架构描述——入口点、路由库、适配器层、支撑库"
---

# 本合约职责

- 合约名称: DexRouter
- 业务定位: OKX DEX 聚合器，覆盖多条 EVM 链的代币交换路由

---

# 架构概览

DexRouter 是一个**基于库的入口点**，而非代理/delegatecall 模式。所有路由逻辑位于 Solidity `library` 合约中，作为静态函数从主 DexRouter 合约调用。

```
用户交易
  │
  ▼
┌─────────────────────────────────────────────────────────────────┐
│  DexRouter.sol（入口点）                                          │
│  - nonReentrant、whenNotPaused 守卫                              │
│  - ExtraDataLib.getDecodedExtraData() 解析 calldata              │
│  - 委托给路由库                                                    │
├─────────────────────────────────────────────────────────────────┤
│  路由库（contracts/8/router/）                                     │
│  ┌──────────────┬──────────────┬──────────────┐                │
│  │SmartSwapRouter│ DagRouter   │SwapWrapRouter │                │
│  ├──────────────┼──────────────┼──────────────┤                │
│  │UnxswapRouter │UnxswapV3Router│              │                │
│  ├──────────────┼──────────────┤              │                │
│  │UnxswapExact  │UnxswapV3Exact│              │                │
│  │OutRouter     │OutRouter     │              │                │
│  └──────────────┴──────────────┴──────────────┘                │
├─────────────────────────────────────────────────────────────────┤
│  支撑库                                                           │
│  CommissionLib │ TransferLib │ ExtraDataLib │ TrimLib           │
│  EventLib      │ CommonLib   │ Constants    │ TempStorage       │
│  PausableModuleV2 │ ExactOutSwapHelper                         │
├─────────────────────────────────────────────────────────────────┤
│  适配器层（contracts/8/adapter/）— 190+ 个适配器                    │
│  UniswapV2 │ UniswapV3 │ Curve │ Balancer │ PancakeSwap │ ... │
└─────────────────────────────────────────────────────────────────┘
```

---

# 分层定义与边界规则

| 层 | 职责 | 允许 | 禁止 |
|---|---|---|---|
| DexRouter（入口点） | 参数解析、守卫、委托路由 | 调用路由库函数 | 包含业务逻辑 / 直接调用适配器 |
| 路由库（router/） | 路由策略实现、swap 编排 | 调用 CommonLib / TransferLib / CommissionLib | 直接访问存储 / 修改状态变量 |
| 支撑库（libraries/） | 佣金计算、转账处理、ExtraData 解析 | 纯函数 + assembly | 调用路由库 / 包含路由逻辑 |
| 适配器（adapter/） | 具体 DEX 协议集成 | 实现 IAdapter(sellBase/sellQuote) | 调用路由库 / 访问 DexRouter 存储 |
| 接口（interfaces/） | 结构体和接口定义 | 纯定义 | 包含逻辑 |
| 常量（Constants.sol） | 链专属地址和限制值 | 常量声明 | 包含逻辑 |

---

# 文件结构

```
contracts/8/
  DexRouter.sol              # 入口点（单一合约）
  router/                    # 路由库（7 个库）
  libraries/                 # 支撑库（10 个库）
  interfaces/                # 接口和结构体
    IDexRouter.sol           # 核心结构体（BaseRequest、RouterPath、ExtraData 等）
    IAdapter.sol             # 适配器接口（sellBase、sellQuote）
    permit2/                 # Permit2 接口（分为 4 个文件）
  adapter/                   # 协议适配器（190+ 个文件）
```

---

# 继承关系

```solidity
contract DexRouter is EthReceiver, IDexRouter, IUniswapV3SwapCallback, PausableModuleV2, ReentrancyGuard
```

---

# Memo 透传机制（ADR-009）

Memo 数据嵌入 calldata 但合约不做任何处理（零存储、零事件、零 Gas 成本）。仅用于第三方（如 Debox）的链上索引数据归因。

- 无佣金时: `calldata = swapData + memo + EMPTY(32B)`
- 有佣金时: `calldata = swapData + memo + commissionInfo`
- [Rule] 合约 **never** 读取或处理 memo 内容
- [Warning] 解析规则在旧佣金（32B）和新佣金（64B+）之间有所不同

---

# 服务依赖关系与规则

- 参考 [dependency.md](dependency.md) 了解完整依赖方向
