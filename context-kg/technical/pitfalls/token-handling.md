---
name: "token-handling"
description: "代币处理相关踩坑记录——转账收费代币、资金留存"
---

# Pitfall: 代币处理

## P-003: 转账收费代币处理

- **严重性:** 中等
- **组件:** UnxswapRouter, TransferLib
- [Pitfall] 某些代币收取转账费用（如 SafeMoon），实际收到金额与转账金额不同
- 正确做法: 使用 `_IS_TOKEN0_TAX` / `_IS_TOKEN1_TAX` 标志位，设置时使用余额差异检查

## P-006: TempStorage 存储槽碰撞风险

- **严重性:** 低
- **组件:** TempStorage.sol
- [Pitfall] TempStorage 使用 keccak256 哈希存储槽作为 Solidity 0.8.17 中缺乏 `transient` 关键字的变通方案
- 正确做法: 槽键使用 `"okx.unxswap.v3.router."` 前缀进行域分隔，值在使用后 **must** 清除
- [Convention] 升级 Solidity 版本时，考虑迁移到原生 `transient` 存储

## P-007: EIP-170 字节码大小限制

- **严重性:** 高
- **组件:** DexRouter.sol
- [Pitfall] DexRouter + 所有链接库 **must** 在 24,576 字节限制内
- 正确做法:
  - 使用 `npm run size` 监控字节码大小
  - 在 Gas 关键路径使用 assembly（更小字节码）
  - 在 assembly 中发出事件比 Solidity `emit` 每个节省约 200 字节

## P-016: DexRouter 资金留存 — UniV3 池流动性耗尽

- **严重性:** 高
- **组件:** UnxswapV3Router, 适配器层
- [Pitfall] UniV3 池流动性耗尽时仅消耗部分输入，余额滞留在 DexRouter
- 正确做法: 在 DexRouter 和 UniV3 类型适配器中 **must** 添加退款逻辑

## P-017: 资金留存 — LaunchPad 上限限制

- **严重性:** 中等
- **组件:** FourMemeAdapter, AspectaAdapter, VirtualsAdapter
- [Pitfall] LaunchPad 有购买上限，超出部分滞留在 DexRouter
- 正确做法: 每个 LaunchPad 适配器 **must** 包含退款逻辑

## P-018: Unxswap/UniV3 中多余 msg.value 未退款

- **严重性:** 高
- **组件:** UnxswapRouter, UnxswapV3Router
- [Pitfall] 仅检查 `msg.value >= amountIn`，多余 ETH 留在合约中
- [Warning] 生产环境已发生（BSC 和 ETH 主网交易哈希已记录）
- 正确做法: 后端/前端 **must** 确保 `msg.value == amountIn` 精确相等

## P-013: FourMeme 8004 代币两步交易要求

- **严重性:** 中等
- **组件:** Adapter, FourMemeAdapter
- [Pitfall] FourMeme 8004 代币需要两笔独立交易（铸造 NFT + 购买），单次 DexRouter 调用无法覆盖
- 正确做法: 后端/API **must** 检测 8004 代币并引导用户完成两步流程

## P-014: Permit2 Owner 检查使用 payer 而非 msg.sender

- **严重性:** 中等
- **组件:** TransferLib.handlePermit2SigModeWithCommission()
- [Pitfall] Permit2 owner 验证使用 `payer` 而非 `msg.sender`（V3 回调中 msg.sender 是池地址）
- 正确做法: 所有路由库 **must** 确保 `payer` 设置为原始 `msg.sender`

## P-015: NoTransfer 模式限制

- **严重性:** 中等
- **组件:** TransferLib, SmartSwapRouter, DagRouter
- [Pitfall] `_MODE_NO_TRANSFER` (0x08) 仅由 SmartSwap 和 DagSwap 支持
- 正确做法: 后端/API **must** 按入口点强制模式兼容性

## P-022: 资金留存 — RFQ 订单正滑点导致中间 token 滞留

- **严重性:** 中等
- **组件:** Native PMM Adapter
- [Pitfall] AMM → Native PMM 路径中，正滑点导致 Native PMM Adapter 留存中间 token
- 触发条件: 多跳路由中 AMM 产生正滑点，超出部分传给 PMM Adapter 但未被消耗
- 正确做法: Adapter **must** 增加 refund 逻辑，将未消耗的中间 token 返还付款方
- 影响范围: Native PMM RFQ（已完成）、OKX RFQ（开发中）

## P-023: UniV3 类池子负 Tick 除法取整错误

- **严重性:** 高（影响询价准确性）
- **组件:** Quoter 合约
- [Pitfall] Solidity 除法向零取整，当 `currTick < 0 && currTick % tickSpacing != 0` 时，`compressed = currTick / tickSpacing` 比正确的 floor 值偏大 1，导致 tick 查询起点偏移到错误的 word
- 正确做法: **must** 加入 `if (tick < 0 && (tick % tickSpacing != 0)) compressed--;`

## P-024: Tax Token 自动 swap 与用户交易冲突

- **严重性:** 中等
- **组件:** Adapter
- [Pitfall] Tax Token 的 `_transferWithTax` 在转账后自动触发 `swapAndSendTax()`，该函数使用 `balanceOf(address(this))` 作为兑换数量。当用户通过 claimTokens 将代币转入池子时，税收 swap 会将池子中全部代币（含用户转入部分）一起卖出，导致用户实际可兑换数量为 0
- 正确做法: 此类代币应标记为貔貅（honeypot），后端 **must** 识别并阻止路由

## P-025: UniV4 RebaseToken 精度问题

- **严重性:** 中等
- **组件:** UniV4 Adapter
- [Pitfall] Rebase Token（如 eETH）在 `sharesForAmount()` 转换时产生舍入误差，导致 PoolManager 的 `settle` 后 delta 无法清零，触发 `CurrencyNotSettled` revert
- 正确做法: 合约层无法解决，前端 **must** 提示用户 Rebase Token 与 UniV4 不兼容
