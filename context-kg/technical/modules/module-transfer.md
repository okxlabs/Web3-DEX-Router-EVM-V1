---
name: "module-transfer"
description: "转账系统模块设计——TransferLib 多模式代币转账"
---

# Module: Transfer System (TransferLib)

## 职责

处理 6 种转账模式的代币转移，包括 Permit2 签名模式的批量转账。

不负责：佣金计算（CommissionLib）、路由策略（路由库）。

## 转账模式

| 模式 | 值 | 机制 |
|------|------|------|
| `_MODE_LEGACY` | `0x00` | ApproveProxy.claimTokens() |
| `_MODE_PERMIT2_ALLOWANCE` | `0x02` | Permit2.transferFrom()（授权额度） |
| `_MODE_BY_INVEST` | `0x04` | Token 已在路由合约中 |
| `_MODE_PERMIT2_SIGNATURE` | `0x06` | Permit2.permitTransferFrom()（签名批量） |
| `_MODE_NO_TRANSFER` | `0x08` | 无需转账（仅 SmartSwap/DagSwap） |
| `_MODE_DIRECT` | `0x0A` | 直接 ERC20.transferFrom() |

## 兼容性矩阵

| 入口点 | Legacy | Direct | P2 Allowance | P2 Signature | ByInvest | NoTransfer |
|---|---|---|---|---|---|---|
| smartSwap / dagSwap | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| unxswap / uniswapV3 | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| swapWrap | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ |
| fromTokenCommission | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ |
| ExactOut 函数 | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |

## 兼容性矩阵理由

| ❌ 组合 | 原因 |
|---------|------|
| unxswap/uniswapV3 + NoTransfer | 这些路由器需要在执行前确认代币已到位，NoTransfer 无法保证 |
| swapWrap + ByInvest | ETH↔WETH 转换无需预存场景 |
| swapWrap + NoTransfer | ETH↔WETH 转换必须有实际 ETH/WETH 输入 |
| fromTokenCommission + ByInvest | ByInvest 模式下佣金从路由合约余额扣，但 from-token 佣金需从用户转入前扣，逻辑矛盾 |
| fromTokenCommission + NoTransfer | 无转账则无 from-token 可扣佣金 |

**NoTransfer 仅限 SmartSwap/DagSwap 的原因:** LaunchPad DEX（FourMeme、Xdock）场景，用户直接授权目标合约，DexRouter 仅编排 swap 路径不移动代币。只有 SmartSwap/DagSwap 支持这种"编排但不转账"的模式。

## Permit2 调用方式

`_MODE_PERMIT2_SIGNATURE` 模式下，TransferLib 通过高级 Solidity 调用 `IPermit2(_PERMIT2).permitTransferFrom(...)` 执行签名授权转账，不使用 assembly。

- Permit2 签名长度支持 64 和 65 字节两种格式
- [Rule] Permit2 owner 验证使用 `payer` 而非 `msg.sender`（V3 回调中 msg.sender 是池地址）

## 依赖关系

- 参考 [arch/dependency.md](../arch/dependency.md)

## 踩坑点

- [Pitfall] Permit2 签名模式下 ToC 批量转账直接从用户转给推荐人，ToB 则 **must** 先经合约再分发
- [Pitfall] Permit2 owner 验证使用 `payer` 而非 `msg.sender`（V3 回调中 msg.sender 是池地址）
- [Pitfall] Permit2 owner 验证使用 `payer` 而非 `msg.sender`
- [Pitfall] TRON 链 USDT transfer() 成功时返回 false，**must** 特殊处理跳过返回值校验
- [Pitfall] TRON 链禁止合约自转 TRX，**must** 在转账前检查 `to != address(this)`
