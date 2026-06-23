---

## name: "terminology"
description: "DexRouter 领域术语表——统一术语定义与命名映射"

# 领域术语表


| 术语                  | 说明                                                                 | 代码引用                                               |
| ------------------- | ------------------------------------------------------------------ | -------------------------------------------------- |
| DexRouter           | DEX 聚合器入口合约，基于库架构                                                  | `contracts/8/DexRouter.sol`                        |
| SmartSwap           | 基于批次的分割路由策略                                                        | `SmartSwapRouter`                                  |
| DagSwap             | 基于 DAG（有向无环图）的多路径路由策略                                              | `DagRouter`                                        |
| Unxswap             | Gas 优化的 Uniswap V2 风格精确输入交换                                        | `UnxswapRouter`                                    |
| UnxswapV3           | 基于 Uniswap V3 回调的精确输入交换                                            | `UnxswapV3Router`                                  |
| ExactOut            | 精确输出交换，输出固定、输入动态                                                   | `UnxswapExactOutRouter`, `UnxswapV3ExactOutRouter` |
| SwapWrap            | ETH ↔ WETH 转换                                                      | `SwapWrapRouter`                                   |
| ExtraData           | ABI 参数后追加的扩展数据（佣金/正滑点/Permit2/退款地址）                                | `ExtraDataLib`                                     |
| Commission          | 佣金，从交换金额中按费率扣除分给推荐人                                                | `CommissionLib`                                    |
| FromTokenCommission | 在 swap 之前从输入代币中收取的佣金                                               | `CommissionLib`                                    |
| ToTokenCommission   | 在 swap 之后从输出代币中收取的佣金                                               | `CommissionLib`                                    |
| Trim / 正滑点          | 正滑点捕获，当 swap 输出超过预期时捕获超出部分                                         | `TrimLib`, `CommissionLib`                         |
| Charge              | 正滑点中的收费部分（双正滑点模式）                                                  | `CommissionLib`                                    |
| ToB                 | 企业端模式，资金必须经合约中转（合规要求）                                              | `CommissionLib`                                    |
| ToC                 | 消费者端模式，资金可直接从用户转给推荐人                                               | `CommissionLib`                                    |
| Referrer / 推荐人      | 佣金接收方，每笔交易支持 1-8 个                                                 | `CommissionInfo`                                   |
| TransferMode        | 代币转账模式，编码在 token 字段比特位 [251:249]                                   | `TransferLib`                                      |
| Legacy              | 传统转账模式，通过 ApproveProxy.claimTokens()                               | `_MODE_LEGACY = 0x00`                              |
| Direct              | 直接 ERC20 transferFrom                                              | `_MODE_DIRECT = 0x0A`                              |
| Permit2Allowance    | Permit2 授权额度转账                                                     | `_MODE_PERMIT2_ALLOWANCE = 0x02`                   |
| Permit2Signature    | Permit2 签名批量转账（最新）                                                 | `_MODE_PERMIT2_SIGNATURE = 0x06`                   |
| ByInvest            | 代币已预存至路由合约                                                         | `_MODE_BY_INVEST = 0x04`                           |
| NoTransfer          | 无需转账（LaunchPad 场景）                                                 | `_MODE_NO_TRANSFER = 0x08`                         |
| Adapter / 适配器       | DEX 协议集成，实现 IAdapter 接口                                            | `contracts/8/adapter/`                             |
| sellBase            | 适配器正向交换                                                            | `IAdapter.sellBase()`                              |
| sellQuote           | 适配器反向交换                                                            | `IAdapter.sellQuote()`                             |
| RouterPath          | 路由路径结构体，描述跳转链                                                      | `IDexRouter.RouterPath`                            |
| BaseRequest         | 基础请求结构体（fromToken, toToken, fromTokenAmount, minReturnAmount, deadLine） | `IDexRouter.BaseRequest`                           |
| effectiveEnd        | ExtraData 真实边界（应对 ERC-8021 后缀），⚠️ 尚未实现，设计已完成          | 计划: `ExtraDataLib._computeEffectiveEnd()`         |
| PausableModuleV2    | 暂停模块，支持 owner 无限期暂停和 reporter 24 小时紧急暂停                            | `PausableModuleV2`                                 |
| ApproveProxy        | 传统授权代理合约                                                           | `_APPROVE_PROXY`                                   |
| DENOMINATOR         | 佣金费率分母 = 10^9                                                      | `Constants`                                        |
| TRIM_DENOMINATOR    | 正滑点费率分母 = 1000                                                     | `Constants`                                        |
| middleReceiver      | 中间接收者，有 to-token 佣金或正滑点时设为 address(this)                           | `CommissionLib`                                    |
| Memo                | 透传数据，合约不处理，用于第三方链上索引                                               | calldata 中                                         |
| ERC-8021            | 交易归因标准，在 calldata 后追加后缀                                            | 外部标准                                               |


