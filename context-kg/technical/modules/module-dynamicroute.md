---
name: "module-dynamicroute"
description: "DynamicRoute 模块设计——JIT(Just-In-Time)动态路由原语,试运行候选适配器后择优执行"
---

# Module: DynamicRoute (JIT 动态路由)

> 来源: `contracts/8/adapter/DynamicRoute.sol`

## 职责

`DynamicRoute` 是一个 **JIT(Just-In-Time)动态路由原语**:给定 N 个候选适配器,先在链上**试运行(dry-run)**每个候选,挑出实际产出最高的"赢家",再真正执行赢家,最后用执行后余额校验锁定信任。

- [Rule] `DynamicRoute` **虽然**位于 `adapter/` 目录并实现 `IAdapter`,但**不是标准适配器**。标准适配器(UniV3Adapter、CurveAdapter 等)是对单个具体池的薄封装;`DynamicRoute` 是路由层原语,通过沙箱机制在多个候选间择优。
- [Rule] 信任模型 **must** 绑定到 **EVM 实测交付**(执行后 `toToken` 余额增量),**never** 信任候选适配器在 dry-run 阶段的"承诺"。

不负责:佣金/正滑点(CommissionLib)、calldata 解析(ExtraDataLib)。

## 合约属性

- 不可变、无 admin、无升级、**无存储状态**(仅 `ReentrancyGuard._status` 槽)。
- [Rule] **故意不实现** `receive()` / `payable fallback()`——向本合约发送原生 ETH 必定 revert(不变量 S-24)。

## 常量

| 常量 | 值 | 说明 |
|------|------|------|
| `ORIGIN_PAYER` | `0x3ca20afc2ccc…0000` | 追加在适配器 calldata 末尾的 payer 标记(与 CommonLib 一致) |
| `MODE_AUTO` | `0` | 当前唯一支持的模式 |
| `MIN_CANDIDATES` | `2` | 候选数下界 |
| `MAX_CANDIDATES` | `8` | 候选数上界 |
| `DRY_RUN_RESULT_MAGIC` | `bytes4(keccak256("JIT_DRY_RUN_RESULT"))` | dry-run revert payload 的魔数前缀(`public` 便于测试断言其不与 `Error(string)`/`Panic(uint256)`/`IAdapter` selector 冲突) |

## 数据结构

```solidity
struct Candidate {
    address adapter;    // 候选适配器
    address assetTo;    // 输入代币转入地址(通常是池)
    uint256 rawData;    // 低 160 位 = pool 地址,bit255 = reverse 标志(镜像 DagRouter._exeEdge)
    bytes   extraData;  // 透传给适配器的扩展数据
}
```

## 核心流程(`_runJit`)

1. `abi.decode` 出 `(fromToken, toToken, mode, Candidate[] cs)`。
2. 校验:`mode == MODE_AUTO`;`MIN_CANDIDATES <= cs.length <= MAX_CANDIDATES`;`fromToken != _ETH && toToken != _ETH`(用 WETH);`fromToken != toToken`。
3. `amount = fromToken.balanceOf(this)`,要求 `> 0`;`refundTo = _extractRefundTo()`。
4. **在任何 dry-run 之前**记录 `prevTo = toToken.balanceOf(to)`(基线跨越整个外层帧)。
5. 逐个 `_dryRunSafe` 得到 `quotes[i]`;`winner = argmax(quotes)`,要求 `quotes[winner] > 0`(否则 `"JIT: all candidates dead"`)。
6. 真正执行赢家:转入 `amount` 到 `cs[winner].assetTo`,调 `CommonLib.exeAdapter`。
7. **执行后校验**:`require(toToken.balanceOf(to) - prevTo >= quotes[winner], "JIT: real exec below quote")`。
8. `emit JitWinnerSelected(winner, quotes, cs[winner].adapter)`。

- [Rule] 执行后校验用 `>=`:允许超额交付(rebase 代币、攻击者多付),但 **must** 阻断任何"承诺多于交付"的攻击——包括 gas 侧信道或任何能区分两阶段的手段。

## Dry-run 沙箱机制

- `_dryRun`(`external`):仅允许自调用(`require(msg.sender == address(this), "JIT: only self")`)。转入 `amount` → 经 `_tryExeAdapter` 执行 → 计算 `amountOut` → **总是**以魔数前缀 revert,payload = `DRY_RUN_RESULT_MAGIC ‖ abi.encode(amountOut, ok, ok ? "" : underlyingReason)`。正常 return 路径永不走到。
- `_dryRunSafe`:`try this._dryRun(...) catch (bytes data)`。
  - [Rule] 合法 payload 最小长度 = MAGIC(4) + `abi.encode(uint256,bool,空 bytes)`(128) = **132 字节**;`< 132` 一律视为候选"死亡"返回 0,**never** 贸然 `abi.decode`(越界 revert 会拖垮整笔 swap)。该判断同时覆盖 `< 4` 的 selector 读取保护。
  - 校验 `sel == DRY_RUN_RESULT_MAGIC`;解出 `(out, ok, reason)`;`!ok` 时 `emit JitDryRunFailed(idx, adapter, reason)` 并返回 0。
- `_tryExeAdapter`:镜像 `CommonLib._exeAdapter` 的 calldata 布局(selector + args + `ORIGIN_PAYER` + refundTo),但返回 `(ok, returndata)` 而非冒泡。
  - [Rule] 仅用于 dry-run 路径,使恶意适配器**无法伪造外层魔数 revert**——其伪造字节只能落入 payload 的 `underlyingReason` 槽。

## Gas 模型

- [Rule] **不**在候选间分配 gas:每次调用转发所有剩余 gas(受 EIP-150 的 63/64 规则约束),与其它经 `CommonLib._exeAdapter` 的适配器一致。
  - **Why:** (1) 候选由后端路由层提供且**可信**,本合约**不是**任意适配器分发的无许可入口;(2) 各适配器族(RFQ/PMM 签名恢复、多池 Curve、深 tick 的 V3 等)单跳 gas 差异极大,任何保守的静态上限都可能误伤诚实候选并 revert,对可信候选又无实际防护意义。

## 纯函数辅助

- `_findMax`:argmax;全零输入返回 0,由调用方经 `quotes[winner] == 0` 拒绝。
- `_stripMagic`:返回 `data[4:]`,32 字节字对齐 memcpy(约 10x 省 gas)。[Pitfall] 输出**仅**适合 `abi.decode`,**never** 对 `inner` 做 hash 或字符串化(尾部字节未初始化)。
- `_decodeRawData`:`pool = rawData & _ADDRESS_MASK`,`reverse = rawData & _REVERSE_MASK != 0`(镜像 `DagRouter._exeEdge`)。
- `_extractRefundTo`:读取末 32 字节 calldata,校验 `ORIGIN_PAYER` 标记,返回 refundTo;标记不匹配 → refundTo == 0(底层适配器随后跳过余额退款)。

## 事件

| 事件 | 触发 |
|------|------|
| `JitWinnerSelected(uint8 winnerIdx, uint256[] quotes, address winnerAdapter)` | 赢家选定并执行成功 |
| `JitDryRunFailed(uint8 candidateIdx, address adapter, bytes reason)` | 某候选 dry-run 执行失败(`ok == false`) |

## 依赖关系

- 参考 [arch/dependency.md](../arch/dependency.md)
- 入口经 `IAdapter.sellBase/sellQuote`(均 `nonReentrant`)→ `_runJit`;真正执行经 `CommonLib.exeAdapter`。

## 踩坑点

- [Pitfall] 候选列表必须满足 `2 <= len <= 8` 且 `fromToken != toToken`、非原生 ETH(用 WETH),否则入口即 revert。
- [Pitfall] dry-run payload `< 132` 字节即判为死亡候选;适配器若返回非标准短 revert 数据会被静默丢弃(不计入择优)。
- [Pitfall] 全部候选 dry-run 产出为 0 时整笔 swap revert(`"JIT: all candidates dead"`)。
