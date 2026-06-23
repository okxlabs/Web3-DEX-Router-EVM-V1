---
name: "knowledge-base"
description: "DexRouter 主规则和全局约束——最高权威文件，冲突时无条件服从此文件"
---

# Knowledge Base — 主规则

## Solidity 版本与编译器约束

- [Rule] DexRouter 入口合约使用 Solidity `0.8.17`，库和适配器使用 `^0.8.0`
- [Rule] 编译器优化 **must** 开启，200 次运行（Foundry 默认）
- [Rule] 核心合约许可证为 MIT

## 架构约束

- [Rule] 所有路由逻辑 **must** 以 Solidity `library` 实现，**never** 使用代理/delegatecall 模式（ADR-001）
- [Rule] 仅 DexRouter.sol 为入口合约，**never** 部署其他入口点
- [Rule] 协议适配器 **must** 为 `contract`（实现 IAdapter），路由器和工具 **must** 为 `library`
- [Rule] DexRouter + 所有链接库 **must** 在 EIP-170 字节码限制（24,576 字节）以内
- [Rule] ExtraData **must** 追加在 ABI 编码参数之后，**never** 作为额外函数参数（ADR-002）

## 安全约束

- [Rule] 所有公共 swap 函数 **must** 同时使用 `nonReentrant` + `whenNotPaused` 守卫
- [Rule] 所有 swap **must** 执行截止时间检查：`require(block.timestamp <= deadline)`
- [Rule] 所有 swap **must** 执行最小返回检查：`require(returnAmount >= minReturnAmount)`
- [Rule] `minReturnAmount` 表示用户扣除所有费用后实际收到的金额（ADR-011），**never** 为原始 swap 输出
- [Rule] Permit2 **must** 强制 `permit2Info.owner == msg.sender`（或 payer），**never** 使用 witness 模式（ADR-014）
- [Rule] 佣金费率 **must** ≤ `COMMISSION_RATE_LIMIT`（30,000,000 = 3%），**never** 允许超限
- [Rule] 正滑点费率 **must** ≤ `TRIM_RATE_LIMIT`（100 = 10%），**never** 允许超限
- [Rule] 佣金/正滑点地址 **must** 非零地址

## 转账模式约束

- [Rule] `_MODE_NO_TRANSFER` (0x08) 仅由 SmartSwap 和 DagSwap 支持，**never** 用于 unxswap/uniswapV3/swapWrap
- [Rule] `_MODE_BY_INVEST` 模式下佣金 payer **must** 为 `address(this)`（ADR-013），**never** 使用 msg.sender
- [Rule] Permit2 转账模式 **must** 确认目标链已部署 Permit2 合约
- [Rule] 转账模式编码在 token 字段比特位 [251:249]，**never** 修改此位置

## 佣金系统约束

- [Rule] ToB 佣金资金 **must** 经过 DexRouter 合约路由（合规审计），**never** 直接转账（ADR-003）
- [Rule] ToC 佣金可直接从用户转给推荐人（Gas 效率）
- [Rule] 多推荐人分配时最后一个推荐人 **must** 获得余额（`totalAmount - sum(前面)`），**never** 使用公式计算（避免舍入粉尘）
- [Rule] 佣金费率精度为 `DENOMINATOR = 10^9`（9 位小数）（ADR-007）

## 正滑点约束

- [Rule] 精确输出交换 **never** 支持正滑点（输出金额固定，不存在正滑点）
- [Rule] SwapWrap (ETH↔WETH) **never** 支持正滑点（1:1 转换，无价格滑点）
- [Rule] 有 to-token 佣金或正滑点时，swap 接收者 **must** 设为 `address(this)`，**never** 直接发给用户

## Calldata 编码约束

- [Rule] Calldata 布局 **must** 保持 32 字节对齐：`(calldatasize - 4) % 32 == 0`
- [Rule] ExtraData 解析 **must** 从右到左（先佣金 → 后正滑点 → 后 Permit2 → 后 RefundTo）
- [Rule] 标志位为 48 位（6 字节），**never** 缩短标志位长度
- [Rule] 佣金/正滑点解析 **must** 使用 effectiveEnd（反向扫描去除外部后缀）作为右边界，**never** 直接使用 `calldatasize()`
- [Warning] effectiveEnd **尚未实现**。当前 ExtraDataLib 和 CommissionLib 均直接使用 `calldatasize()`，设计文档见 `docs/20260304-erc8021-compatibility/`

## 代币处理约束

- [Rule] 原生 ETH 转账 **must** 使用 `call{value: amount, gas: NATIVE_TOKEN_TRANSFER_GAS_LIMIT}("")` 并检查 success
- [Rule] ERC20 转账 **must** 使用 `SafeERC20.safeTransfer()` / `safeTransferFrom()`
- [Rule] **never** 在 assembly 中直接 `mstore` 到任意内存地址，**must** 使用 Solidity 内存分配
- [Rule] 转账收费代币 **must** 使用余额差异检查，**never** 信任转账返回值

## 链特定约束

- [Rule] `_WETH`、`_APPROVE_PROXY`、`_PERMIT2` 地址在编译时链专属，**must** 与目标链匹配
- [Rule] Constants.sol 中 `NATIVE_TOKEN_TRANSFER_GAS_LIMIT` **must** 按链覆盖
- [Rule] zkSync 部署 **must** 使用 `hardhat-zksync`，**never** 使用标准 Foundry
- [Rule] TRON 链 **must** 处理 USDT 非标准 transfer 返回值和禁止合约自转 TRX 的限制（独立分支维护）

## DAG 路由约束

- [Rule] DAG 节点 **must** 由后端预排序，合约仅验证不排序（ADR-010）。**Why:** 合约内拓扑排序约多消耗 100K Gas
- [Rule] 节点索引 **must** 从 0 开始到 N-1，连续且唯一
- [Rule] 所有边 **must** 满足 `inputIndex < outputIndex`（无环保证）
- [Rule] 每个节点的出边权重总和 **must** 为 10000（100%）
- [Rule] 节点的所有输入 **must** 完成后才能执行（输入优先）
- [Rule] 节点的所有输出 **must** 完成后下游才能启动（输出优先）
- [Rule] 不相关的路径可以任意顺序执行（独立性）
- [Rule] 不可达的不同节点可以持有相同代币（代币可合并性）
- [Rule] 排序错误导致运行时失败（余额不足），而非显式 revert

## 暂停机制约束（PausableModuleV2）

- [Rule] **owner** 可以无限期暂停和恢复
- [Rule] **reporters** 可以暂停最多 24 小时（紧急情况），到期自动恢复
- [Rule] 状态值：`NOT_PAUSED = 1`，`OWNER_PAUSED = max(uint64)`，reporter 暂停 = `block.timestamp + 24h`
- [Rule] 只有 owner 可以添加/移除 reporters
- [Rule] 所有公共 swap 函数 **must** 使用 `whenNotPaused` 修饰符检查暂停状态

## 关键常量（以太坊主网）

| 常量 | 值 | 说明 |
|------|------|------|
| `_WETH` | `0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2` | 链专属，编译时确定 |
| `_APPROVE_PROXY` | `0x70cBb871E8f30Fc8Ce23609E9E0Ea87B6b222F58` | 链专属，编译时确定 |
| `_PERMIT2` | `0x000000000022D473030F116dDEE9F6B43aC78BA3` | CREATE2 确定性地址，所有链相同 |
| `_ETH` | `0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE` | 原生 ETH 占位符 |
| `COMMISSION_RATE_LIMIT` | `30,000,000` | 最高 3% |
| `TRIM_RATE_LIMIT` | `100` | 最高 10%（分母 1000） |
| `DENOMINATOR` | `10^9` | 佣金费率分母 |
| `TRIM_DENOMINATOR` | `1000` | 正滑点费率分母 |
| `MIN_COMMISSION_MULTIPLE_NUM` | `3` | 多推荐人最少数量 |
| `MAX_COMMISSION_MULTIPLE_NUM` | `8` | 多推荐人最多数量 |
| `NATIVE_TOKEN_TRANSFER_GAS_LIMIT` | `100,000` | 原生代币转账 Gas 限制，**must** 按链覆盖 |

## 架构决策理由（ADR 摘要）

以下记录关键架构决策的"为什么"，帮助在边界情况下做出正确判断。

### ADR-001: 基于库而非代理/delegatecall
- **Why:** 库编译时链接，无存储布局冲突、无代理 SLOAD 开销、单一合约地址简化审计
- **Trade-off:** 升级需重新部署整个合约，字节码大小是所有库的总和

### ADR-002: Calldata 尾部追加 ExtraData 而非额外函数参数
- **Why:** 零接口变更，现有调用方无需修改；标志位检测使数据存在可选；向后兼容
- **Trade-off:** 需要 assembly 自定义解析，无法使用标准 ABI 解码

### ADR-003: ToB/ToC 佣金资金流分离
- **Why:** 合规要求 B2B 收入流经受控中间方提供审计跟踪；B2C 无此要求，直接转账省 Gas
- **Trade-off:** Permit2 签名模式需为两种路径分别处理批量转账逻辑

### ADR-004: 引入 Permit2 转账模式
- **Why:** 签名模式无需单独 approve 交易（用户体验）；nonce+deadline 防重放（安全）；生态已广泛采用
- **Trade-off:** 目标链必须已部署 Permit2；签名验证增加 Gas 但为用户省一笔 approve 交易

### ADR-007: 佣金费率 9 位小数精度
- **Why:** 4 位精度不足以满足精细化费率协商；6 字节编码适配 calldata 字段布局（6B 标志 + 6B 费率 + 20B 地址 = 32B）
- **Trade-off:** 累积整数除法可能产生 ±1-2 wei 精度差异

### ADR-010: DAG 后端预排序
- **Why:** 节省约 100K Gas；若索引连续唯一且 inputIndex < outputIndex，按索引顺序即为拓扑排序
- **Trade-off:** 后端必须确保正确排序，排序错误导致运行时余额不足而非显式 revert

### ADR-011: minReturnAmount 为扣费后的值
- **Why:** 前端展示最终到账金额即为 minReturn，与 Solana 实现对齐，用户滑点保护应用于实际到账
- **Trade-off:** 后端必须计算 `minReturn = expectedSwapOutput - expectedCommission - expectedTrim`

### ADR-012: 通过方法选择管理合约大小
- **Why:** v1.0.7 全方法集运行时大小 24,436B（距限制仅 138B）；v1.0.8-transfer-mode 通过方法选择降至 14,164B（余量 10,412B）。库架构允许选择性不链接未使用路由库，不同版本/链的字节码大小差异很大
- **Trade-off:** 不同链部署可能有不同方法集，API/后端必须知道每条链可用方法

### ADR-013: ByInvest 模式佣金使用路由合约作为付款方
- **Why:** ByInvest 模式下代币已预存于路由合约，付款方应与持币实体一致
- **Trade-off:** 佣金验证必须检查路由合约余额而非用户授权

### ADR-014: Permit2 Owner 检查替代 Witness
- **Why:** 直接相等检查比 witness 编码更简单、省 Gas；Permit2 nonce 已防重放
- **Trade-off:** 不支持元交易或中继器场景

### ADR-015: 从 TokenApprove 迁移至 Permit2
- **Why:** 传统 TokenApprove 有中心化 owner 单点故障、无过期机制；Permit2 去中心化且支持限时授权
- **Trade-off:** 4-5 个月实现周期；传统模式保留向后兼容
