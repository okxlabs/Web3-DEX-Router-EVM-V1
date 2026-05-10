# Security Audit Report — JIT Routing

> 分支: `feat/oli-jit-routing`
> 审计员立场: 保守, 反自我说服. "应该没事" 视为红旗.
> slither 状态 (`env-capabilities.json`): **不可用**; 本审计为 **manual review only**, 不降级判定标准.

---

## Phase 1: 静态分析与可重现性

### 1.1 Gate 重跑结果
| 命令 | 结果 |
|------|------|
| `forge fmt --check contracts/8/jit-routing src/tests/jit-routing` | ✅ PASS |
| `forge build` (全项目) | ✅ PASS |
| `FOUNDRY_TEST=src/tests/jit-routing forge test` | 48/49 (1 known test bug, §4.1) |
| `npm test -- --runInBand` | ✅ PASS (48/48 after AC-15 exclusion) |

审计员独立重跑, 结果 **完全可重现**. Stage 4 的 gate 数据真实.

### 1.2 slither
- `env-capabilities.json:slither_available = false`
- `which slither`: `not found`
- 本 audit **未运行 slither**. 按 env-capabilities 约定, 明示 "manual review only". 不生成 slither-raw.txt.
- 仍走 Phase 2-5 全套手工 review, 不降级标准.

---

## Phase 2: 安全考量逐条对照 (S-01..S-26)

> 每条对照 TD Phase 4 清单. "适用" 项: 找到代码中防护位置 + Stage 3 对应测试 + 独立验证防护逻辑真的能挡住. "不适用" 项: 独立反验 dev 判断, 不接受单方面声明.

### S-01 Reentrancy (跨函数)
- **适用**. 防护: `nonReentrant` 修饰 `sellBase` / `sellQuote`.
- 代码: `JitAdapter.sol:63, 77`. 继承 `ReentrancyGuard` (OZ v4 非 Upgradeable).
- OZ v4 ReentrancyGuard 机制: 入 set `_status=2`, 出 restore `_status=1`. 有效阻止 cross-function.
- Negative test: `test_AC20_reentrancy_blocked` (JitAdapterAttack.t.sol:42).
- **独立验证**: 构造恶意 `MockReentrantAdapter` 在 `sellBase` 调用期间回调 `jit.sellBase` → ReentrancyGuard 拦截 → 回调失败 → _tryExeAdapter 得 ok=false → quote=0 → 其他候选正常赢. ✅ 验证通过.

### S-02 Reentrancy (同函数, 跨 candidate)
- **适用**. 同 S-01 防护.
- 独立验证: 多候选循环期间, 若任一候选回调 sellBase, 被 nonReentrant 拦截. 由 test_AC20 + test_I02 覆盖. ✅

### S-03 Reentrancy (只读)
- **不适用**. 独立反验:
  - JitAdapter 无 state 变量 (只有继承 ReentrancyGuard 的 `_status`).
  - 无 view 函数暴露内部一致性约束.
  - `DRY_RUN_RESULT_MAGIC` 是 constant, 不受重入影响.
- ✅ 反验通过.

### S-04 整数溢出 (0.8 checked)
- **不适用**. 独立反验:
  - JitAdapter 无 `unchecked` 块.
  - 算术只有 `IERC20(toToken).balanceOf(to) - prev` (JitAdapter.sol:104). underflow 可能性: 仅当 to 的 toToken 余额在 call 期间减少. 但 swap 不会减少 `to` 余额 (swap 只增加). 恶意 adapter 若从 `to` 地址转走 token, `to != address(this)`, adapter 无权转出. 唯一例外是 `to` 主动授权 adapter transfer. 但这属 `to` 地址的自我攻击, 非合约漏洞.
  - 结论: underflow 不成立. ✅

### S-05 汇编算术溢出
- **适用** (`_extractRefundTo` + `_decodeRawData` 用 assembly).
- `_extractRefundTo` (JitAdapter.sol:228-235): 只用 `calldataload` / `sub(calldatasize(), 32)` / `and` / `eq`. 纯位运算, 无加减乘除. `sub(calldatasize(), 32)` 仅在 calldata 超短时 underflow — 但 `calldatasize` 至少为 4 (selector), 若 selector+args 后的 calldata < 32 bytes, underflow. 此时 `calldataload` 于负 offset = 未定义 (实际 EVM 会 wrap). 但 sellBase/sellQuote 至少要有 args (3 个 32-byte slot = 96 bytes 最少), 实际 calldata size >> 32. 现实中不会触发.
- `_decodeRawData` (JitAdapter.sol:218-223): 只用 `and` / `iszero`. 无算术.
- ✅ 合规.

### S-06 访问控制 onlyOwner
- **不适用**. 独立反验: `grep -E "onlyOwner|Ownable|_owner" contracts/8/jit-routing/JitAdapter.sol` = 0 命中. 无 admin 路径. ✅

### S-07 `_dryRun` 未授权调用
- **适用**. 防护: `if (msg.sender != address(this)) revert OnlySelf();` (JitAdapter.sol:95).
- Negative test: `test_AC21` + `test_I01`. 外部地址调 `_dryRun` → revert. ✅

### S-08 Signature 重放
- **不适用**. JitAdapter 不验证签名. 底层 PMM adapter 自己管理 nonce/domain. ✅

### S-09 Oracle 操纵
- **不适用**. JitAdapter 不读 oracle. ✅

### S-10 Flash loan
- **适用** (理论可用 flash loan 放大 dry-run 资金, 但无害).
- 防护: EVM revert 原子性保证 dry-run 状态 100% 回滚. JitAdapter 自身不借贷.
- Negative test: `test_I10_dryRun_atomic_rollback` 验证 spoof candidate 接收的 fromToken 在 dry-run 结束后为原值.
- 独立验证: Flash-loan 攻击者最多 "窥视" 报价, 等同静态路由下已有能力. 无新风险. ✅

### S-11 Magic 数据伪造 (核心攻击向量)
- **适用**. 防护: `_tryExeAdapter` (低层 call 不冒泡, JitAdapter.sol:179-192) + `_dryRun` 在外层自行写 MAGIC revert (JitAdapter.sol:102-110).
- **独立验证**:
  1. 恶意 adapter 直接 `revert(MAGIC + fakeAmount)` → `_tryExeAdapter` 得 `(ok=false, returndata=<MAGIC+fakeAmount>)`.
  2. `_dryRun` 读 balanceOf(to) 无变化 → `amountOut = 0`.
  3. `_dryRun` 构造 **外层** revert: `MAGIC + abi.encode(0, false, <MAGIC+fakeAmount>)`. 攻击者的 MAGIC 被塞进 `underlyingReason` 字段, 距离 amountOut 槽位相隔 1 个 bool 字段.
  4. `_dryRunSafe` 解码外层 MAGIC → amountOut=0, ok=false. 攻击失败, quote=0.
- Negative test: `test_AC19_magic_spoof_is_rejected` + `test_I03_magic_spoof_not_amountOut` — 明确断言 `toToken.balanceOf(recipient) == MOCK_QUOTE_A` (legit wins, spoof=0). ✅ 关键防御生效.

### S-12 MAGIC 值与 Solidity 标准 selector 冲突
- **适用**. 防护: `bytes4(keccak256("JIT_DRY_RUN_RESULT"))` 选取.
- Test assertions: `test_MAGIC_01/02/03` 验证 ≠ `Error(string)` (0x08c379a0) 和 `Panic(uint256)` (0x4e487b71) 和 `IAdapter.sellBase/sellQuote` selectors.
- **独立验证**: 计算 `bytes4(keccak256("JIT_DRY_RUN_RESULT"))`. 无公开 selector 数据库证明独特性, 但测试的断言是硬编码的, 静态可观察. 若未来某 adapter 新增同值 selector, 需更新测试. ✅ 当前通过.

### S-13 Calldata tail hijack
- **适用**. 防护: `_extractRefundTo` marker 校验 `(payerOrigin & ORIGIN_PAYER) == ORIGIN_PAYER` (JitAdapter.sol:231).
- **独立验证**:
  - ORIGIN_PAYER 高 48 bits 为 `0x3ca20afc2ccc`, 其余 208 bits 为 0.
  - 攻击者想让 marker 匹配需: 末 32 字节的 bits [208:256) 含 `0x3ca20afc2ccc` pattern.
  - 正常 ABI-encoded sellBase 调用的末 32 字节是 `bytes data` 尾部 (padding 或 content). 若攻击者构造 data 尾部恰好包含该 6 字节模式, 可绕过 marker 检查 → _extractRefundTo 返回该 32 字节的低 160 位作为伪 refundTo.
  - 但该攻击仅能 **转嫁** underlying 的 leftover 给伪 refundTo. JitAdapter 自身不做 leftover refund (transfer 完整 amount 给 adapter); leftover refund 依赖 underlying adapter 是否有此行为.
  - **JitAdapter 层面不受此攻击直接伤害**. 风险转移到 underlying adapter.
- Negative test: `test_AC22_refundTo_marker_absence` — **弱测试**: 用 MockSuccessAdapter, 该 adapter 根本不做 leftover refund, 所以测试无论 marker 校验是否生效都通过. 详见 §4.2 findings.
- ✅ 代码正确, 但测试质量 flag (Info finding).

### S-14 Approval 滥用
- **不适用**. JitAdapter 不调用 `TokenApproveProxy` / `approve()`. Token 由 DagRouter 预先 transfer 给 JIT (通过 `assetTo[i] = JitAdapter`). ✅

### S-15 Delegatecall 风险
- **不适用**. `grep delegatecall JitAdapter.sol` = 0. 所有 external call 走 `address(adapter).call(...)`. ✅

### S-16 Selfdestruct
- **不适用**. `grep selfdestruct JitAdapter.sol` = 0. ✅

### S-17 block.timestamp / blockhash 随机源
- **不适用**. `grep -E "block\.(timestamp|number|hash)|blockhash" JitAdapter.sol` = 0. ✅

### S-18 升级漏洞 (initializer / storage gap)
- **不适用**. 非 proxy, 无 initializer, 无 `__gap`. 使用非 Upgradeable `ReentrancyGuard`. ✅

### S-19 ERC777 hook 在 dry-run 中触发
- **适用** (低风险).
- 防护: revert 原子性回滚 hook 产生的 state + per-dryrun gas 上限 500K 限制 hook 消耗.
- 独立验证: 恶意 ERC777 token 在 `safeTransfer(fromToken, c.assetTo, amount)` 期间可触发 `tokensReceived` hook. 该 hook 如果修改了外部 state, 会被 `_dryRun` 末尾的 revert 原子回滚. hook 如果耗尽 500K gas, 该候选 quote=0 (_dryRunSafe 短 revert 路径). 不拖死其他候选.
- ✅ 防护生效.

### S-20 FOT token 测量偏差
- **适用**. 防护: `to` 透传 + `balanceOf(to)` before/after 测量.
- 代码: `JitAdapter.sol:100, 104` — prev 在 `_tryExeAdapter` 之前读取, amountOut 在之后计算. 且 `to` 传给 underlying 是同一个 `to` (JitAdapter.sol:102 的 4th arg), 非 `address(this)`.
- Negative test: `test_AC23_fot_accuracy` 验证 `fotToken.balanceOf(recipient) == MOCK_QUOTE_B * 9900 / 10_000` (99% of quote due to 1% fee).
- **独立验证**: 读 test 实际数值: `MOCK_QUOTE_B = 200 ether`, 期望 `200 * 9900 / 10000 = 198 ether`. FOT token 扣 1% 到 0xdead. Recipient 实收 99e18 * 2 = 198e18. dry-run 阶段也会测量到 198e18 (同 FOT 流程). 真实执行再次产生 198e18. 实际 delta (before vs after): 198e18 (dry-run 回滚) + 198e18 (real-exec) = 198e18 final delta. ✅ 匹配测试期望.
- 注意: dry-run 和 real-exec 各自扣 FOT fee, 但 dry-run fee 通过 revert 原子回滚, 所以真实 fee 只扣一次.

### S-21 Rebase token
- **适用** (低概率).
- 防护: balanceOf 差值测量对 rebase 天然兼容 (只要 token 在 tx 内不 rebase).
- 无独立 mock 测试, 由 AC-23 FOT 机制隐式覆盖.
- 独立验证: rebase token 若在 tx 内不重计算基数, balanceOf delta 反映真实变化. ✅

### S-22 Gas griefing (单候选烧光)
- **适用**. 防护: `try this._dryRun{gas: PER_DRYRUN_GAS_LIMIT=500_000}(...)`.
- Negative test: `test_AC16_gas_burner_isolated` + `test_AC24_gas_griefing_isolated`. 后者用 2 个 gas burner + 1 个 legit, 验证 legit 仍能赢.
- **独立验证**: gas burner 烧完 500K 后, `this._dryRun{gas: 500K}` 通过 EIP-150 (1/64 reserve) 自动终止, 外层剩余约 500K / 64 ≈ 7.8K gas 继续处理下一候选. 测试验证 3 候选 total 跑通. ✅

### S-23 Storage slot 冲突
- **不适用**. 非 proxy, JitAdapter 自身无 state. ReentrancyGuard._status 独占 slot 0 (OZ 固定). ✅

### S-24 Native ETH send
- **适用**. 防护: 无 `receive()` / `payable fallback()` + 入口 require.
- Negative test: `test_S24_native_ether_send_reverts`. `address(jit).call{value: 1 ether}("")` 返回 ok=false.
- **独立验证**: `grep -E "receive\s*\(|fallback\s*\(" JitAdapter.sol` — 仅在注释中命中, 无 function 定义. 合约无 payable 入口. ✅

### S-25 恶意 adapter (被注入候选)
- **适用**. 防护: 依赖 S-11 magic spoof defense. 合约层无 adapter whitelist (PRD §11 Anti-Scope).
- **独立验证**: 恶意 adapter 的 revert data 无法伪造 winner (S-11 已证). 恶意 adapter 的 `assetTo` 被标为 S-26 out-of-scope.
- 最坏情况: 恶意 adapter 能让 quote=0 (自毁), 不能胜出, 不能劫持其他候选. ✅

### S-26 Candidate.assetTo 被伪造
- **适用** (后端责任). 合约层无防御.
- 独立反验 dev 判断: PRD §11 Anti-Scope 第 7 条明确合约不做白名单. 属 SDK/后端校验职责. 与既有 DagRouter 对 RouterPath.assetTo 的处理方式一致 (两者都信任调用方传入的 assetTo). ✅ Dev 判断正确.

### Phase 2 小结
- **适用** 项 (13): 全部有代码防护 + Stage 3 测试 + 独立验证. **无 Critical/High finding**.
- **不适用** 项 (11): 独立反验均通过. 无 dev 单方面声明 "不适用" 而实际存在问题的情况.
- **外推** 项 (2 — S-26 assetTo, S-25 partial): 属上下游职责, 符合 PRD Anti-Scope.
- **Info finding**: AC-22 (S-13) 测试弱 — 用 MockSuccessAdapter 不会触发 leftover refund, 测试结果与 marker 校验是否生效无关. 代码正确, 但测试没真验证.

---

## Phase 3: 不变量交叉验证 (I-01..I-14)

> 每条不变量找到对应测试, 评估 falsification 能力. Invariant fuzz 优先于 unit test; 仅 unit 的提示风险.

| I | 测试 | 类型 | 是否真的 falsify | 备注 |
|---|------|------|------------------|------|
| I-01 `_dryRun` self-only | `test_I01_dryRun_self_only` (Invariant.t.sol:18), `test_AC21` | unit | ✅ 试图外部调用 → revert OnlySelf | — |
| I-02 nonReentrant | `test_I02_nonReentrant_active`, `test_AC20` | unit | ✅ 通过 MockReentrantAdapter 实际触发重入 → 被拦截 → legit 赢 | — |
| I-03 magic spoof 不进 amountOut | `test_I03_magic_spoof_not_amountOut`, `test_AC19` | unit | ✅ 伪造 MAGIC+fakeAmount → quote=0, legit 赢 | 核心 ACTUAL 攻击测试 |
| I-04 catch 严格校验 | `test_I04_catch_strict_validation` | unit | ✅ 4 种错误输入 (short / Error(string) / spoof / legit) 混合, 只有 legit 胜 | 覆盖边界全面 |
| I-05 单候选失败不拖死 tx | `test_I05_single_failure_isolated`, `test_AC16` | unit | ✅ 1 fail + 1 legit → legit 胜 | — |
| I-06 候选长度边界 | `test_I06_candidates_boundary_lower/upper`, `test_AC05/07/08/09` | unit | ✅ 1/2/255/256 全测 | — |
| I-07 all-dead revert | `test_I07_allDead_reverts`, `test_AC10` | unit | ✅ 两个 dead candidates → revert AllCandidatesDead | — |
| I-08 dry-run quote == real delta | `test_I08_dry_equals_real_unit`, `test_AC25` | unit | ⚠️ 用 MockSuccessAdapter 测量 — 因为 mock 是 deterministic, quote = real 永远成立. **真实 fork 环境下 adapter 的确定性需 PRD §9.3 adapter review 保证**. Stage 5 不再增负担 | Stage 6 MR 前可选补 fork 测试 |
| I-09 JIT 无 token 滞留 | `test_I09_no_leakage`, `test_AC06/26` | unit | ✅ assertEq(fromToken.balanceOf(jit), 0) | — |
| I-10 dry-run 原子回滚 | `test_I10_dryRun_atomic_rollback`, `test_AC27` | unit | ✅ spoof adapter 接收 fromToken 后, dry-run 结束后余额恢复 | 由 EVM revert 语义保证, 合约层额外验证 |
| I-11 `to` 透传 | `test_I11_to_passthrough`, `test_AC03` | unit | ✅ recipient 收到 toToken, JIT 余额为 0 | — |
| I-12 refundTo marker 校验 | `test_I12_refundTo_marker_absent_means_zero`, `test_AC22` | unit | ⚠️ 同 AC-22 弱测试, 详见 S-13 分析 | Info finding |
| I-13 event shape | `test_I13_event_shape`, `test_AC28` | unit | ✅ 验证 quotes.length, winnerIdx, winnerAdapter 匹配 | — |
| I-14 既有合约 bytecode 不变 | `test_I14_iadapter_interface_stable`, `test_AC29_AC30_weak_proxy` | unit (weak proxy) | ⚠️ 只断言 IAdapter selector 值, 不验证 bytecode diff. 真正验证靠 git diff / PR review | Stage 6 MR 必做 |

### Phase 3 小结
- 14 条不变量全覆盖. 11 条强测试, 3 条 (I-08, I-12, I-14) 有已知弱化.
- I-08 弱化 合理: Mock 下 dry-run=real 自然成立, 真实 adapter 偏差依赖 PRD §9.3 外部流程.
- I-12 弱化 = AC-22 弱测试 (Info finding, 见 §4.2).
- I-14 弱化 = 代码层无法自动 diff, 需 PR review 承担. 本 Stage 独立 git status 验证零 diff (§4.1).
- **无 invariant fuzz test**. JitAdapter 是无状态合约, 无 handler state mutation 循环基础, 所以 fuzz 场景有限. 现状可接受但 Stage 6/后续可考虑 property-based fuzz on `_findMax` / `_stripMagic`.

---

## Phase 4: 反验 dev 报告

### 4.1 Handoff 声明逐条反验

| Dev 声明 (handoff.md §) | 审计反验 | 结论 |
|------------------------|---------|------|
| §2.5 "未修改既有合约" (60+ adapter, CommonLib, DagRouter, foundry.toml 等) | `git status -s` 显示: 只有 `contracts/8/jit-routing/` (??), `src/tests/jit-routing/` (??), `.claude/` (??), `package.json` (M 仅新增 test script), `package-lock.json`/`yarn.lock` (M npm install 副作用). `git diff HEAD -- contracts/8/DexRouter.sol contracts/8/DagRouter.sol contracts/8/libraries contracts/8/interfaces contracts/8/adapter contracts/8/TokenApprove* contracts/8/utils foundry.toml .gitmodules` 空输出. | ✅ 真实 |
| §1.1 "npm test 通过" | 独立跑 `npm test -- --runInBand`: Ran 3 test suites, 48 passed, 0 failed, exit=0 | ✅ 真实 |
| §5.1 "AC-15 是 Stage 3 test bug" (dry-run 与 real-exec 共用 adapter 代码, 抽空余额同时让 dry-run 失败) | 独立跑 `FOUNDRY_TEST=src/tests/jit-routing forge test`: test_AC15_winner_exec_revert_bubbles FAIL. 读测试代码 `JitAdapter.t.sol:204-222`: 确实使用 MockSuccessAdapter + 单次 transfer drain, 场景不可达. Stage 3 report §3.5 原文: "Stage 4 必须补 stateful mock" 确认预知. | ✅ 真实 |
| §5.1 "AC-15 语义正确性: `_exeAdapter` 失败 → `_revert(res)` 冒泡, 无 try/catch 包裹" | 独立读 `JitAdapter.sol:140` (唯一 `_exeAdapter` 调用, 在 `_runJit` 中). 上下文无 try/catch. 读 `CommonLib.sol:18-57`: 失败走 `_revert(res)` 原始冒泡. `grep -E "try\|catch" contracts/8/jit-routing/JitAdapter.sol` 只在 `_dryRunSafe` 的 try/catch 块中命中, 未出现在 real-exec 路径. | ✅ 真实 (Info finding: 测试应强化) |
| §7 "baseline fail 两条 suffix 测试均因 ETH_RPC_URL 未设" | 独立跑 `forge test`: 2 个 suffix fail, 原因 `vm.envString: "ETH_RPC_URL" not found`. 读 `src/tests/common/TrimAndCommissionTestBase.t.sol:251` 确认 `vm.createSelectFork(vm.envString("ETH_RPC_URL"), 23293873)`. 源文件修改时间为 CoW base 原始状态, 非本期引入. | ✅ 真实 |
| §6.4 "A-R4 既有合约 git diff 空" | 同上独立验证 | ✅ |
| §6.1 重点 1-5 (magic spoof / refundTo marker / 重入 / winner bubble / uint8) | 逐条独立审查, 见 Phase 2 S-01/05/07/11/13 + §4.2 finding 5-1 | ✅ 声明准确 |

**无任何 dev 声明与事实不符**. 反验全绿.

### 4.2 `--no-match-test` 排除 AC-15 的独立评估
审计立场: 这是一个 **band-aid, 不是漏洞**. 接受需要同时满足:
1. 测试的确是 Stage 3 自我承认的 bug (Stage 3 report §3.5 原文写明) ✅
2. AC-15 语义由代码层独立 review 确认 (本审计 Phase 2 S-11/S-15 + §4.1 反验) ✅
3. 排除机制对人类可见, 不隐藏 (package.json 显式 `--no-match-test` 名字 + handoff §5.1 详细说明) ✅
4. 未来若新增 `MockFlakyAdapter` 或类似手段可把 AC-15 纳入, 现有代码不阻碍 ✅

综上: 接受排除. 标为 **Info finding (建议 Stage 6/后续补 stateful mock)**.

---

## Phase 5: EVM 通用反模式扫描

> 即使 TD 未列入, 仍逐条扫描.

| 模式 | 扫描 | 结果 |
|------|------|------|
| Checks-Effects-Interactions (CEI) | `_runJit:137-142` sequence: _decodeRawData (check) → safeTransfer (effect) → _exeAdapter (interaction) → emit (log) | ✅ CEI 遵守; 交互前状态变更完整 |
| `tx.origin` 滥用 | `grep tx.origin JitAdapter.sol` = 0 | ✅ N/A |
| `block.timestamp/blockhash` 随机源 | `grep -E "block\.|blockhash" JitAdapter.sol` = 0 | ✅ N/A |
| 浮点 / 精度丢失 (mulDiv / FixedPoint) | 无算术运算 | ✅ N/A |
| Delegatecall to untrusted | `grep delegatecall JitAdapter.sol` = 0 | ✅ N/A |
| Selfdestruct / suicide | `grep -E "selfdestruct\|suicide" JitAdapter.sol` = 0 | ✅ N/A |
| 默认 visibility 缺失 | 所有 function 显式 external/internal, 所有变量 constant 都显式 internal/public | ✅ |
| require 消息 / custom error | 全部用自定义 error (UnsupportedMode, CandidatesOutOfRange, NativeEthNotAllowed, ZeroInput, OnlySelf, AllCandidatesDead) | ✅ |
| ecrecover 返回 0 未检查 | `grep ecrecover JitAdapter.sol` = 0 | ✅ N/A |
| 数组无界增长 DoS | cs.length ≤ 255 硬限; quotes 数组与 cs 同长 | ✅ |
| 升级 storage layout | 非 proxy | ✅ N/A |
| Low-level call 无返回检查 | `_tryExeAdapter` 显式收取 (ok, returndata) | ✅ |
| Unchecked external transfer | 使用 `SafeERC20.safeTransfer` | ✅ |
| External 函数命名 `_`-prefix (`_dryRun`) | 习惯上 `_` 前缀表内部, 这里 `_dryRun` external. 语义已通过 `OnlySelf` 强制自 call, 命名保留但不是真"internal". 建议 audit 文档指出命名混淆但不阻断. | Info (naming) |

**扫描结果**: 无 Critical/High. 1 条 Info (命名).

---

## Phase 6: 发现项与最终判定

### 6.1 Findings

#### Finding F-01 [Info] — AC-15 test 场景不可达, 用 `--no-match-test` 排除, 语义由代码 review 独立确认
- **位置**: `src/tests/jit-routing/JitAdapter.t.sol:204-222` (test), `package.json:11` (exclusion), `contracts/8/jit-routing/JitAdapter.sol:140` (semantic under review)
- **危害**: 无合约层危害. 风险是 "测试未能 catch impl 中意外加入 fallback" — 若未来 dev 误加 try/catch 包裹 `_exeAdapter`, 本 skeleton 不会 fail.
- **复现路径**: 无 (已知 Stage 3 bug; impl 正确).
- **修复建议**: Stage 6 (MR) 或下个迭代新增 `MockFlakyAdapter` (首次调用成功报价, 二次调用 revert), 在 test_AC15 中用之, 并用 `vm.expectRevert("FLAKY_FAIL")` 收紧断言.
- **判定**: **接受** (Stage 3 明确自我标注, Stage 4 严格遵守 "don't modify tests" 规则; 代码层 AC-15 语义经 Phase 2 / §4.1 独立审查确认).

#### Finding F-02 [Info] — AC-22 / I-12 测试用 MockSuccessAdapter 无法 falsify marker 校验
- **位置**: `src/tests/jit-routing/JitAdapterAttack.t.sol:87-101`, `JitAdapterInvariant.t.sol:213-224`
- **危害**: 无合约层危害. 测试无论 marker 是否校验都会通过 (MockSuccessAdapter 不做 leftover refund).
- **复现路径**: 无 (测试不能 falsify).
- **修复建议**: 新增 `MockLeftoverRefundAdapter` — 在 sellBase 末尾调 `_extractRefundTo`-like 逻辑并 transfer `fromToken` 剩余给 `refundTo`. 测试断言 fakeRefund 地址依然为 0 余额.
- **判定**: **接受** (合约层 marker 校验 assembly 块逻辑已独立审查, 与 UniV3Adapter:36 同款模式).

#### Finding F-03 [Info] — 命名约定: `_dryRun` 是 external 但用 `_` 前缀
- **位置**: `contracts/8/jit-routing/JitAdapter.sol:87-94`
- **危害**: 无. 仅命名可能误导新读者.
- **修复建议**: 加明显 natspec `@dev external despite _-prefix, self-call only`. 已在 line 84-86 注释说明, 已足够.
- **判定**: **接受**.

#### Finding F-04 [Info] — `_stripMagic` O(n) byte loop, 大 revert data 下 gas 偏高
- **位置**: `contracts/8/jit-routing/JitAdapter.sol:209-215`
- **危害**: 无. 仅 gas 效率.
- **修复建议**: Stage 6 或后续可改用 assembly memcpy (`calldatacopy` / `mcopy`) 优化.
- **判定**: **接受**.

#### Finding F-05 [Info] — 255 候选 × 500K gas budget = 127.5M gas 理论总量, 可能超出部分 L1 block 限额
- **位置**: `contracts/8/jit-routing/JitAdapter.sol:22, 200` (constants + loop)
- **危害**: 操作性 (用户 tx 可能因 block limit 不足失败). 非安全.
- **修复建议**: 合约层不加业务上限 (PRD OPEN-1 拍板由后端控制); 后端 gas estimator 应实际测量, 现 AC-08 测试 30.5M gas 已接近 Ethereum mainnet 30M 限额. L2 可放开.
- **判定**: **接受** (Non-security; 后端职责).

### 6.2 Finding 分级汇总
| 级别 | 数量 | 说明 |
|------|------|------|
| Critical | 0 | — |
| High | 0 | — |
| Medium | 0 | — |
| Low | 0 | — |
| Info | 5 | F-01 AC-15 test bug (dev 已披露); F-02 AC-22 弱测试; F-03 命名; F-04 gas 优化; F-05 255-candidate 操作性 |

### 6.3 最终判定

**APPROVE** ✅

理由:
1. 0 Critical / 0 High / 0 Medium / 0 Low.
2. 5 个 Info finding 均非合约安全问题, 全部经 dev 披露或由外部流程承接.
3. Phase 2 (S-01..S-26) 全部经独立反验, 无 dev 自我说服被采纳的情况.
4. Phase 3 (I-01..I-14) 14/14 覆盖, 3 条弱化均经独立审查合理化.
5. Phase 4 反验 dev 报告: 所有声明与事实相符, 无 inflate.
6. Phase 5 EVM 通用反模式扫描: 全绿.
7. 对 AC-15 排除的接受基于: (a) Stage 3 自我披露; (b) 代码层独立 review 确认 `_exeAdapter` 无 try/catch 包裹, `CommonLib._revert` 确实冒泡; (c) 排除机制对人类可见, 不隐藏.
8. Slither 不可用 (env-capabilities `slither_available=false`), 本审计按 "manual review only" 走完 Phase 1-5 全套, **不视为 BLOCK**.

### 6.4 Stage 6 (MR) 前必做 checklist
1. `git diff --stat main...feat/oli-jit-routing -- contracts/8/DexRouter.sol contracts/8/DagRouter.sol contracts/8/libraries contracts/8/interfaces contracts/8/adapter contracts/8/TokenApprove* contracts/8/utils foundry.toml .gitmodules lib` 必须 = 0 字节 (本审计已验证当前工作树上为空; PR 基线也需一致).
2. 本审计 Finding F-01..F-05 在 MR description 中可选引用 (不阻断).
3. 后端/SDK 对接开始前确保 PRD §10 OPEN-1/2/3/6 拍板完成; 合约层不阻断.
4. 运营部署时按 PRD §9.3 adapter review checklist 做 adapter 白名单管理.
