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
| effectiveEnd        | ExtraData 真实右边界（反向扫描去除 ERC-8021 后缀），✅ 已实现             | `ExtraDataLib._getExtraDataEndPointAndLength()` → `endPoints[0]` |
| PausableModuleV2    | 暂停模块，支持 owner 无限期暂停和 reporter 24 小时紧急暂停                            | `PausableModuleV2`                                 |
| ApproveProxy        | 传统授权代理合约                                                           | `_APPROVE_PROXY`                                   |
| DENOMINATOR         | 佣金费率分母 = 10^9                                                      | `Constants`                                        |
| TRIM_DENOMINATOR    | 正滑点费率分母 = 1000                                                     | `Constants`                                        |
| middleReceiver      | 中间接收者，有 to-token 佣金或正滑点时设为 address(this)                           | `CommissionLib`                                    |
| Memo                | 透传数据，合约不处理，用于第三方链上索引                                               | calldata 中                                         |
| ERC-8021            | 交易归因标准，在 calldata 后追加后缀（由 effectiveEnd 反向扫描剥离）                 | 外部标准                                               |
| DynamicRoute / JIT  | Just-In-Time 动态路由原语，试运行 N 个候选适配器后择优执行，执行后余额校验              | `contracts/8/adapter/DynamicRoute.sol`             |
| Candidate           | JIT 候选适配器结构体（adapter, assetTo, rawData, extraData）                  | `DynamicRoute.Candidate`                           |
| dry-run / 试运行      | JIT 在沙箱内试执行候选并以魔数前缀 revert 回传产出（`DRY_RUN_RESULT_MAGIC`）        | `DynamicRoute._dryRun()`                           |
| SecurityManager     | TokenApproveProxy 的治理封装：白名单镜像 + 新增(admin)/移除(admin或安全角色)拆分 | `contracts/8/SecurityManager.sol`                  |
| SECURITY_ROLE       | 应急响应角色，仅可移除（吊销）proxy，不可新增                                       | `keccak256("SECURITY_ROLE")`                       |
| TokenApprove        | 用户代币授权目标合约（runtime claim 平面）                                       | `contracts/8/TokenApprove.sol`                     |
| TokenApproveProxy   | 授权代理，被 SecurityManager 治理（管理平面经 ITokenApproveProxyAdmin）         | `contracts/8/TokenApproveProxy.sol`                |


