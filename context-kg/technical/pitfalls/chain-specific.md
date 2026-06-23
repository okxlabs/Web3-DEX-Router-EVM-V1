---
name: "chain-specific"
description: "链特定问题踩坑记录——WETH 地址、Permit2、zkSync、TRON"
---

# Pitfall: 链特定问题

## P-004: WETH 地址因链而异

- **严重性:** 高
- **组件:** Constants.sol, 部署
- [Pitfall] `_WETH` 硬编码为以太坊主网地址，每条链地址不同
- 正确做法: Constants.sol 在编译时 **must** 为链专属版本，部署脚本 **must** 验证地址匹配
- [Warning] `_APPROVE_PROXY` 和 `_PERMIT2` 同理

## P-005: Permit2 合约可用性

- **严重性:** 中等
- **组件:** TransferLib, Constants.sol
- [Pitfall] 规范 Permit2 合约并非所有 EVM 链都已部署
- 触发条件: DexRouter 部署在没有 Permit2 的链上
- 正确做法: 后端/API **must** 仅为部署了 Permit2 的链编码 Permit2 模式；Legacy (0x00) 和 Direct (0x0A) 始终可用
- 验证方法: 字节码与 ETH 主网对比，参见 `scripts/permit2_bytecode_compare.js`

## P-011: zkSync 部署差异

- **严重性:** 中等
- **组件:** 部署, hardhat-zksync
- [Pitfall] zkSync Era 使用不同的 EVM 实现，标准 Foundry 部署可能不可用
- 正确做法: **must** 使用 `hardhat-zksync` 工具，主网部署前先在测试网验证
- 配置: `scripts/deployed/zkSyncEra/base.js`

## P-019: 各链原生代币转账 Gas 限制

- **严重性:** 中等
- **组件:** CommissionLib, TransferLib
- [Pitfall] 不同链对 `CALL` 操作码 Gas 成本不同，Gas 限制过低导致转账失败
- 正确做法: `NATIVE_TOKEN_TRANSFER_GAS_LIMIT` **must** 按链覆盖（Constants.sol 中默认 100,000）
- [Warning] 接收方合约复杂操作约消耗 7,000 Gas

## P-020: TRON USDT 非标准 transfer 返回值

- **严重性:** 关键（仅 TRON 链）
- **组件:** SafeERC20, UnxswapV3Router, CommissionLib
- [Pitfall] TRON USDT 的 `transfer()` 成功时返回 `false`，SafeERC20 的 `safeTransfer()` 会 revert
- 正确做法: 对 TRON USDT 地址 **must** 跳过返回值校验
- [Warning] 仅影响 TRON 链，代码在独立分支维护

## P-021: TRON 禁止合约自转 TRX

- **严重性:** 关键（仅 TRON 链）
- **组件:** CommissionLib, TransferLib, SwapWrapRouter
- [Pitfall] TRON 不允许合约向自身地址转账 TRX（`address(this).call{value: amount}("")` 失败）
- 触发场景: to-token commission 的 middleReceiver、Trim 捕获、退款逻辑
- 正确做法: 所有原生代币转账路径 **must** 检查 `to != address(this)`
- [Warning] 仅影响 TRON 链，代码在独立分支维护

## P-022: Monad 链 Gas 收取 gas limit 而非 gas used

- **严重性:** 高
- **组件:** 部署, Gas 预估
- [Pitfall] Monad 链收取的是 **gas limit** 而非 **gas used**，与标准 EVM 行为不同
- Cold State Access 成本约为以太坊 3.9 倍，Precompiles 成本提高 2-5 倍
- 正确做法: Gas 预估 **must** 使用 `eth_estimateGas` + `debug_traceTransaction`，Foundry **never** 能准确预估 Monad Gas
- [Warning] gas limit 设置过高会直接导致用户多付费用（不退还差额）

## P-023: Mantle 链 gas limit 需设置极大值

- **严重性:** 中等
- **组件:** 部署, 合约管理平台
- [Pitfall] Mantle 链的 gas limit **must** 设置为极大值（如 900,000,000），否则交易失败
- [Warning] 合约管理平台 gas limit 填写即为交易实际使用的上限，与其他链行为不同
