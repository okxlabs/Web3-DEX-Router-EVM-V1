---
name: "quality"
description: "DexRouter 质量知识域——安全约定、审查规范"
---

# 质量知识域

## 安全约定

- [Rule] **ReentrancyGuard**: 所有公共 swap 函数 **must** 使用 `nonReentrant` 修饰符
- [Rule] **PausableModuleV2**: 所有公共 swap 函数 **must** 使用 `whenNotPaused` 修饰符
- [Rule] **截止时间检查**: `require(block.timestamp <= deadline)`
- [Rule] **最小返回检查**: `require(returnAmount >= minReturnAmount)`
- [Rule] **费率限制**: 佣金 ≤ 3%，正滑点 ≤ 10%
- [Rule] **地址验证**: 佣金/正滑点地址 **must** 非零
- [Rule] **退款**: 多余 ETH 和未使用代币 **must** 退还给用户

## 代码审查重点

1. 字节码大小是否在 EIP-170 限制内
2. 新增的转账路径是否覆盖所有 6 种转账模式
3. 新增的佣金/正滑点逻辑是否与 ExtraData 解析一致
4. 多推荐人分配是否保持"最后一个获得余额"模式
5. 链专属常量是否正确
6. Assembly 代码是否有 memory-safe 注解和用途注释
7. [Rule] Adapter 中 **never** 使用 `tx.origin` 获取用户地址（经典攻击向量：用户 → 恶意合约 → router → adapter → pool），**must** 使用 `msg.sender` 或 DexRouter 传入的 `payerOrigin`
8. [Rule] 任何可外部传入的 `refundTo` / `payerOrigin` 参数 **must** 验证其来源合法性
9. 新增 Adapter 是否包含退款逻辑（防止资金留存）
10. 涉及负数 tick 的除法是否使用 floor 取整而非向零取整

## 外部审计记录

### MixBytes 审计（2026）

| Finding | 严重性 | 状态 | 说明 |
|---------|--------|------|------|
| M-1: TotalWeight Validation | Medium | 已修复 | totalWeight 校验不严格 |
| M-2 (前C1) | Medium→Low | 已修复 | 降级为 L15 |
| M-3: Slippage Check | Medium | 已缓解 | 无法在所有路径上统一为 router balance delta（FourMeme 要求输出直接发送至 tx.origin），已增加 nonReentrant 缓解 |
| M-4: Direct Adapter Transfers (noTransfer 重入) | Medium→Low | 已修复 | 移除 `_exeHop/_exeForks` 中的 noTransfer 优化，降级为 L16 |
| L-1: Permit2 Mode Silently Skips Token Transfer | Low | 已修复 | |
| L-6: UniV3 未显式拒绝 fee-on-transfer token | Low | 保留 | 已知风险，当前由后端路由规避 |
| L-11: delegatecall 前 memory 未清零 | Low | 已修复 | |
| L-13: TRON_USDT 硬编码地址 | Low | 保留 | Tron 链特有设计决策 |
| L-2/3/4/5/7/9/10/12 | Low | 保留 | 非安全问题，维护性/防御性建议 |

### Cantina 审计（2026）

| Finding | 严重性 | 状态 | 说明 |
|---------|--------|------|------|
| **F-62: ExactOut 重入漏洞** | **Medium** | **已修复** | `uniswapV3SwapExactOutTo` 缺少 nonReentrant，恶意 receiver 可重入覆盖 TempStorage，绕过 maxConsume 滑点保护。修复：添加 nonReentrant |
| F-251: LidoAdapter wstETH→stETH Bug | Low | 已修复 | unwrap 后应读 `stETH.balanceOf()` 而非 `wstETH.balanceOf()` |
| F-187: FluidDex 缺少 receive 函数 | Low | 待修复 | FluidLite 线上仅支持 U-U，暂无影响 |
| F-300: FF_factory 地址 | — | Reject | 有脚本替代地址，审计方未见脚本 |
| F-213: CommissionLib totalRate 计算 | — | Reject | ExactOut 的 CommissionInfo 仅 2 referrer，与主路由 8 referrer 无关 |
| F-131/189/190/11 | — | Reject | 已知设计决策或数学上不可行 |

### 审计教训

- [Pitfall] 所有公共 swap 入口 **must** 在上线前逐一验证 `nonReentrant` 修饰符是否存在（F-62 教训）
- [Pitfall] 每轮审计完的 fix commit **must** 及时合并到 main，避免同一问题在不同分支重复提出（F-11 vs 内部审计重复）
- [Warning] FourMeme 等协议要求输出直接发送至 `tx.origin`，这使得统一的 router balance delta 滑点检查无法实施（M-3 限制）

## 审查决策记录

误报抑制记录参见 `docs/review-decisions.md`。
