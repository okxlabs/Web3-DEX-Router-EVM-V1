---
name: "dependency"
description: "DexRouter 模块与外部依赖方向规则"
---

# 依赖规则

## 内部模块依赖关系

| 调用方 | 被调用方 | 方式 | 说明 |
|---|---|---|---|
| DexRouter | 路由库（SmartSwapRouter 等） | 库函数调用 | 编译时链接，委托路由逻辑 |
| 路由库 | CommonLib | 库函数调用 | 适配器执行、余额检查 |
| 路由库 | CommissionLib | 库函数调用 | 佣金收取和分配 |
| 路由库 | TransferLib | 库函数调用 | 代币转账处理 |
| 路由库 | EventLib | 库函数调用 | 事件发出 |
| DexRouter | ExtraDataLib | 库函数调用 | calldata 解析 |
| CommonLib | IAdapter | 外部调用 | 执行具体 DEX 协议交换 |
| TransferLib | IApproveProxy | 外部调用 | 传统授权模式代币转移（runtime claim 平面） |
| TransferLib | IPermit2 | 外部调用 | Permit2 模式代币转移 |
| DynamicRoute (JIT) | CommonLib | 库函数调用 | 试运行择优后执行赢家适配器 |
| DynamicRoute (JIT) | IAdapter | 外部调用 | dry-run / 真实执行候选适配器 |
| SecurityManager | ITokenApproveProxyAdmin | 外部调用 | 治理底层 TokenApproveProxy（管理平面，与 runtime claim 平面分离） |

- [Rule] 禁止反向调用：适配器 → 路由库、支撑库 → 路由库
- [Rule] 禁止循环依赖：库之间 **must** 保持单向调用
- [Rule] 适配器 **never** 直接访问 DexRouter 存储
- [Rule] SecurityManager **must** 仅经 `ITokenApproveProxyAdmin`（管理平面）访问 TokenApproveProxy，**never** 引入 `IApproveProxy`（runtime claim 平面）
- [Rule] DynamicRoute（JIT）虽实现 IAdapter，但属路由层原语，候选适配器 **must** 由可信后端提供，**never** 作为任意适配器分发的无许可入口

---

## 外部合约依赖

| 依赖 | 用途 | 地址（以太坊主网） |
|---|---|---|
| WETH | 原生 ETH 包装/解包 | `0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2` |
| ApproveProxy | 传统授权代理 | `0x70cBb871E8f30Fc8Ce23609E9E0Ea87B6b222F58` |
| Permit2 | Uniswap 通用授权系统 | `0x000000000022D473030F116dDEE9F6B43aC78BA3` |
| DEX 池（UniV2/V3/Curve 等） | 代币交换执行 | 各池地址编码在 calldata 中 |

- [Rule] 外部合约地址 **must** 在 Constants.sol 中声明为编译时常量，**never** 使用运行时变量
- [Rule] 外部合约地址为链专属，部署前 **must** 验证与目标链匹配
- [Rule] Permit2 地址通过 CREATE2 确定性生成，所有链为同一地址，但 **must** 确认目标链已部署

---

## 踩坑点

- [Pitfall] WETH 地址因链而异，**must** 使用目标链对应地址编译（详见 pitfalls/chain-specific.md）
- [Pitfall] Permit2 并非所有 EVM 链都已部署，未部署时 Permit2 模式 **must** 禁用
- [Pitfall] Constants.sol 中 `NATIVE_TOKEN_TRANSFER_GAS_LIMIT` **must** 按链设置，默认值可能不适用
