# EVM 动态路由 JIT Routing 最终方案

> 来源: https://okg-block.sg.larksuite.com/docx/H4tzd49ezofEMpxsgoNlee2AgUf
> 抓取时间: 2026-05-10
> PRD last_modified: 2026-05-07T00:59:03Z

前置评审稿: https://okg-block.sg.larksuite.com/wiki/GmfVwbS2wi3rWykCpb6lvcN8gce
Solana JIT 方案: https://okg-block.sg.larksuite.com/docx/GE8FdTZeioo3Z4xarOclz6Flgxh
调研报告: https://okg-block.sg.larksuite.com/wiki/IXoLw25HXiUvbDkouXUl4pq1g4f

## TL;DR
做什么: 在 DexRouter 上新增「动态路由」能力——链上 swap 执行时刻对一组预打包的候选逐个进行「dry-run + revert 拿结果」，选出实测输出最大的候选作为 winner 再真实执行。不依赖任何 view 报价，也不依赖我们复刻协议逻辑。

MVP 范围: 新增 1 个 JitAdapter 合约 (immutable)；首发 L2 小范围灰度；候选池覆盖 PMM (OKX RFQ) + UniV2/V3 等主流 AMM。

最小侵入: DexRouter / DagRouter / CommonUtils / CommonLib / IAdapter 接口 / 现有 60+ adapter / ApproveProxy 全部不动。

与评审稿的两处关键演化:
- 比价机制: Per-protocol Quoter → dry-run + revert
- 失败处理: try winner / catch runnerUp → 不做 fallback

本次需团队最后确认的事项:
- candidates 数量上限 (建议 ≤ 8) §9.1
- L1 启用金额阈值 (建议 ≥ $5K 启用, ≥ $50K 放开候选数) §9.2
- adapter dry-run 兼容性 review 通过标准 §9.3

---

## 2. 整体架构
- 新合约 JitAdapter 实现 IAdapter, 被 DagRouter 当普通 adapter 调用。
- JitAdapter 继承 CommonLib, 复用 _exeAdapter (真实执行) + ORIGIN_PAYER 机制。
- DexRouter / DagRouter / CommonUtils / CommonLib / IAdapter 接口 / 现有 60+ adapter / ApproveProxy 全部不改。

## 3. 核心机制: Dry-run + 比价 + 真实执行

### 3.1 单次执行流程 (4 步)
1. Decode extraData: (fromToken, toToken, mode, candidates); 从 msg.data 末尾 calldataload 提取 refundTo
2. Dry-run 循环: self._dryRun → safeTransfer → _tryExeAdapter (low-level call 不冒泡) → measure balanceOf(to) → revert with magic-prefixed (amountOut, ok, underlyingReason)
3. argmax(quotes), require > 0
4. 真实执行 winner; 失败冒泡 revert, 不做 fallback

### 3.5 Revert 数据编码 (魔数前缀)
- `DRY_RUN_RESULT_MAGIC = bytes4(keccak256("JIT_DRY_RUN_RESULT"))`
- _dryRun 用 _tryExeAdapter (low-level call 不冒泡), JitAdapter 自己写最外层 magic revert, payload = (amountOut, ok, underlyingReason)
- 外层 catch 严格校验 data.length >= 4 + magic 前缀, 再 abi.decode

### 3.6 candidates 数量硬约束
`require cs.length >= 2 && cs.length <= 255`

### 3.8 JitAdapter 与 underlying adapter 交互
- 3.8.1 c.assetTo per-candidate (UniV2=pool, UniV3/PMM=adapter)
- 3.8.2 必须 low-level call 透传 ORIGIN_PAYER (继承 CommonLib, 复用 _exeAdapter)
- 3.8.3 refundTo 从 calldata 末尾 + marker 校验提取 (同 UniV3Adapter)
- 3.8.4 to 参数透传 underlying, 测量 balanceOf(to) before/after
- 3.8.5 c.rawData 携带 packed pool + reverse, 与 RouterPath.rawData[i] 同款

## 4. 核心数据结构

```solidity
struct Candidate {
    address adapter;
    address assetTo;
    uint256 rawData;   // packed pool (160 bit) + reverse (1 bit)
    bytes   extraData;
}

// extraData 顶层
abi.encode(
    fromToken: address,
    toToken:   address,
    mode:      uint8,           // V1 固定 0 = MODE_AUTO
    candidates: Candidate[]
)
```

## Events
- `JitWinnerSelected(uint8 winnerIdx, uint256[] quotes, address winnerAdapter)`
- `JitDryRunFailed(uint8 candidateIdx, address adapter, bytes reason)`

## 5. 核心伪代码 (节选)
- JitAdapter is IAdapter, ReentrancyGuard, CommonLib
- `PER_DRYRUN_GAS_LIMIT = 500_000`
- sellBase / sellQuote 都进 _runJit
- 入口约束: mode == MODE_AUTO, 2 <= cs.length <= 255, fromToken/toToken != _ETH
- _dryRunSafe 通过 try this._dryRun{gas: PER_DRYRUN_GAS_LIMIT}(...) 调用
- _dryRun require msg.sender == address(this)
- _tryExeAdapter: low-level address(adapter).call(encodePacked(sel, args, ORIGIN_PAYER + refundTo))
- _findMax 返回 winnerIdx (uint8)
- _stripMagic 跳过 4-byte 前缀

## 6. 已拍板决策 (摘要)
- JIT 放在 adapter 层 (JitAdapter)
- 比价=dry-run+revert, 不要 Quoter
- 不做 fallback
- Mode 保留字段, V1 仅 MODE_AUTO
- 不保留 version 字段
- fromToken/toToken 必须顶层传入
- to 透传 (不替换为 self)
- c.assetTo per-candidate
- c.rawData 携带 pool+reverse
- refundTo 走 ORIGIN_PAYER 机制
- 真实执行用 _exeAdapter, dry-run 用 _tryExeAdapter
- per-dry-run gas 限额 500K
- JitAdapter 永久 immutable, 无 admin
- nonReentrant
- native ETH 禁止 (后端先 wrap WETH)

## 7. 实施前置工作
- 7.1 Adapter dry-run 兼容性 review
- 7.2 PMM 商务沟通
- 7.3 Token 类型边界 (native / FOT)
- 7.4 Gas budget 估算策略 (后端)

## 8. 后端 / SDK 对接 (摘要)
- RouterPath 单条 JIT edge: mixAdapters[i]=JitAdapter, assetTo[i]=JitAdapter, rawData[i].pool=JitAdapter (占位), extraData[i]=abi.encode(fromToken,toToken,mode,candidates)
- refundTo 不进 extraData (DagRouter 会通过 CommonLib 追加)

## 9. 团队拍板项
- 9.1 candidates 数量上限 (推荐 ≤ 8, 合约不硬限死, 由后端决策)
- 9.2 L1 启用金额阈值 (后端 + PM 决策)
- 9.3 adapter 入选 review 通过标准: 不用 gasleft 条件判断; 不依赖 msg.sender 特定地址; fork 一致性 0 偏差
