# Test Skeleton Report (RED) — JIT Routing

> 分支: `feat/oli-jit-routing`
> 阶段: Stage 3 (TDD 红阶段)
> 判定: **RED — 符合预期** (49 tests: 7 trivial PASS / 42 logic FAIL)
> 下一阶段: Stage 4 (impl) 按 td.md Phase 2 替换 stub, 期望本 skeleton 全绿 (GREEN).

---

## 1. 文件清单

### 1.1 新增 stub 合约
- `contracts/8/jit-routing/JitAdapter.sol` — 最小骨架. 所有函数体 `revert("NOT_IMPLEMENTED")`; 声明了 TD Phase 2 的全部常量 / error / struct / event / 函数签名. `DRY_RUN_RESULT_MAGIC` 设为 `public constant` (对 TD "internal" 的微小偏离, 用于 Stage 3 单元测试直接 assert; Stage 4 可保留或收紧, 若收紧须改为测试端独立计算).

### 1.2 新增 mock adapter (都实现 IAdapter)
- `src/tests/jit-routing/mocks/MockSuccessAdapter.sol` — extraData 指定 (toToken, amountOut), 转 toToken 到 to (覆盖 happy path, AC-01..06, AC-25, AC-28)
- `src/tests/jit-routing/mocks/MockMagicSpoofAdapter.sol` — revert with MAGIC-prefixed 伪造 amountOut=uint256.max (AC-19, I-03, S-11)
- `src/tests/jit-routing/mocks/MockGasBurnerAdapter.sol` — 烧光 gas (AC-16, AC-24, I-05, S-22)
- `src/tests/jit-routing/mocks/MockReentrantAdapter.sol` — 回调 JitAdapter.sellBase (AC-20, I-02, S-01, S-02)
- `src/tests/jit-routing/mocks/MockFailAdapter.sol` — revert with Error(string) (AC-10, AC-15, AC-18, I-07)
- `src/tests/jit-routing/mocks/MockShortRevertAdapter.sol` — revert with 0-byte data (AC-17, I-04)
- `src/tests/jit-routing/mocks/MockFOTToken.sol` — 1% fee-on-transfer ERC20 (AC-23, S-20)

### 1.3 新增测试文件
- `src/tests/jit-routing/JitTestBase.t.sol` — 抽象测试基类 (无 test_ 函数, 不被 forge 收集)
- `src/tests/jit-routing/JitAdapter.t.sol` — AC-01..AC-18, AC-25, AC-26, AC-28 + MAGIC 冲突断言 (25 tests)
- `src/tests/jit-routing/JitAdapterAttack.t.sol` — AC-19..AC-24 + S-24 (7 tests)
- `src/tests/jit-routing/JitAdapterInvariant.t.sol` — I-01..I-14 + AC-27, AC-29, AC-30, AC-31 (17 tests)

**总计: 49 test functions + 7 mock 合约 + 1 stub 合约.**

---

## 2. 运行命令

默认 `forge test` 只扫 `foundry.toml` 指定的 `test = "src/tests/suffix/"`. 必须显式指定:

```bash
FOUNDRY_TEST=src/tests/jit-routing forge test
```

`forge test --match-path` 与该 toml 设定冲突 (被忽略), 故使用 env override. Stage 4 运行时同样用该命令.

---

## 3. RED 验证结果

### 3.1 Build
- `forge build`: **PASS** (只有既有代码的 lint 警告与 mixed_case / unsafe_typecast 提示, 无 error, 无 missing symbol, 无 dependency 缺失)
- 所有新增文件编译通过

### 3.2 Test (`FOUNDRY_TEST=src/tests/jit-routing forge test`)

| 套件 | Pass | Fail | 总计 |
|------|------|------|------|
| JitAdapter.t.sol | 4 | 21 | 25 |
| JitAdapterAttack.t.sol | 1 | 6 | 7 |
| JitAdapterInvariant.t.sol | 2 | 15 | 17 |
| **TOTAL** | **7** | **42** | **49** |

### 3.3 PASS 分类 (必须全部是 "trivial setup test")
| Test | 类型 | 原因 |
|------|------|------|
| `test_MAGIC_01_value_matches_spec` | 常量 assert | 验证 `jit.DRY_RUN_RESULT_MAGIC()` == `bytes4(keccak256("JIT_DRY_RUN_RESULT"))`; stub 公开常量, 无业务逻辑 |
| `test_MAGIC_02_no_collision_with_std_errors` | 常量 assert | MAGIC ≠ `Error(string)` (0x08c379a0) / `Panic(uint256)` (0x4e487b71) |
| `test_MAGIC_03_no_collision_with_iadapter_selectors` | 常量 assert | MAGIC ≠ IAdapter.sellBase/sellQuote selectors |
| `test_AC15_winner_exec_revert_bubbles` | 通用 revert | `vm.expectRevert()` 无参, stub 任何 revert 都满足. Stage 4 必须 tighten 为 expect underlying 具体 revert (stateful mock) |
| `test_S24_native_ether_send_reverts` | 结构 assert | `(bool ok,) = jit.call{value: 1 ether}("")` 返回 ok=false 因为 stub 没 `receive()`/`fallback()` — 验证 **合约层面** 无 payable, 非业务 |
| `test_I14_iadapter_interface_stable` | 接口 selector assert | `IAdapter.sellBase.selector == keccak("sellBase(address,address,bytes)")[:4]` |
| `test_AC29_AC30_weak_proxy_iadapter_unchanged` | 接口 selector assert | 同上 (IAdapter 接口回归保护的弱代理) |

**所有 7 个 PASS 都不包含被测主逻辑**, 满足 stage task "PASS 必须是 trivial setup test, 不可包含被测主逻辑".

### 3.4 FAIL 分类 (全部必须是 "逻辑 assertion 不通过" 而非编译/符号错误)

| 失败原因 | 计数 | 是否合规 |
|---------|------|---------|
| `"Error != expected error: NOT_IMPLEMENTED != <specific>"` — 具体 error selector 不匹配 | 10 | ✅ 逻辑 |
| `"expected an emit, but no logs were emitted afterwards"` — 事件 emit 不发生 | 6 | ✅ 逻辑 |
| `assertTrue(ok, ...)` 失败 — call 返回 revert NOT_IMPLEMENTED | 15 | ✅ 逻辑 |
| `assertEq` 失败 — balance / delta / 数组长度 不匹配 | 11 | ✅ 逻辑 |
| **TOTAL** | **42** | **全部逻辑级** |

**0 个 FAIL 由编译错误 / missing symbol / dependency 缺失引起** → 满足 stage task 要求.

### 3.5 AC-15 补充说明
AC-15 ("winner 真实执行 revert 冒泡") 需要 "dry-run 成功 / 真实执行失败" 的有状态 mock. 当前 skeleton 使用了 FOT-style 预先抽空 mock adapter 余额的构造, 但因 stub 总是在 `sellBase` 入口 NOT_IMPLEMENTED, 真实执行阶段根本没跑到. 因此 `vm.expectRevert()` 无参版本接受任何 revert 并 PASS. **这不代表 AC-15 的语义已被验证**. Stage 4 必须:
- 添加 stateful mock (e.g. `MockFlakyAdapter` 首次调用成功报价, 再次调用 revert)
- 将 `vm.expectRevert()` 收紧为具体 underlying revert payload (比如 `vm.expectRevert("FLAKY_FAIL")`)
- 本 skeleton 里此 test 已在代码注释中标记该 TODO

---

## 4. AC / Invariant / Security 三向矩阵

### 4.1 AC-xx → Test

| AC | Test Name | File:Line | 当前 PASS/FAIL | 备注 |
|----|-----------|-----------|----------------|------|
| AC-01 | `test_AC01_two_candidates_higher_wins` | `src/tests/jit-routing/JitAdapter.t.sol:16` | FAIL (logic) | PRD fork 场景在 Stage 4 fork 测试中补齐 |
| AC-02 | `test_AC02_winner_is_zero` + `test_AC02_winner_is_one` | `src/tests/jit-routing/JitAdapter.t.sol:30, 40` | FAIL (logic) | 覆盖两种 winner 顺序 |
| AC-03 | `test_AC03_sellQuote_path` | `src/tests/jit-routing/JitAdapter.t.sol:51` | FAIL (logic) | sellQuote 入口 |
| AC-04 | `test_AC04_three_candidates_pmm_wins` | `src/tests/jit-routing/JitAdapter.t.sol:62` | FAIL (logic) | 3 候选 |
| AC-05 | `test_AC05_boundary_two_candidates_ok` | `src/tests/jit-routing/JitAdapter.t.sol:80` | FAIL (logic) | 边界下界 |
| AC-06 | `test_AC06_no_token_leftover_in_jit` | `src/tests/jit-routing/JitAdapter.t.sol:90` | FAIL (logic) | 末态 balance=0 |
| AC-07 | `test_AC07_revert_candidates_len_one` | `src/tests/jit-routing/JitAdapter.t.sol:106` | FAIL (logic) | len=1 revert |
| AC-08 | `test_AC08_boundary_255_candidates_ok` | `src/tests/jit-routing/JitAdapter.t.sol:117` | FAIL (logic) | len=255 uint8 无溢出 |
| AC-09 | `test_AC09_revert_candidates_len_256` | `src/tests/jit-routing/JitAdapter.t.sol:132` | FAIL (logic) | len=256 revert |
| AC-10 | `test_AC10_all_dead_reverts` | `src/tests/jit-routing/JitAdapter.t.sol:145` | FAIL (logic) | AllCandidatesDead |
| AC-11 | `test_AC11_revert_mode_not_auto` | `src/tests/jit-routing/JitAdapter.t.sol:157` | FAIL (logic) | mode!=0 |
| AC-12 | `test_AC12_revert_native_fromToken` | `src/tests/jit-routing/JitAdapter.t.sol:167` | FAIL (logic) | fromToken=_ETH |
| AC-13 | `test_AC13_revert_native_toToken` | `src/tests/jit-routing/JitAdapter.t.sol:176` | FAIL (logic) | toToken=_ETH |
| AC-14 | `test_AC14_revert_zero_input` | `src/tests/jit-routing/JitAdapter.t.sol:186` | FAIL (logic) | balanceOf=0 |
| AC-15 | `test_AC15_winner_exec_revert_bubbles` | `src/tests/jit-routing/JitAdapter.t.sol:207` | PASS (trivial) | **注意**: Stage 4 必须补 stateful mock (见 §3.5) |
| AC-16 | `test_AC16_gas_burner_isolated` | `src/tests/jit-routing/JitAdapter.t.sol:228` | FAIL (logic) | 单 OOG 不影响其他 |
| AC-17 | `test_AC17_short_revert_is_zero_quote` | `src/tests/jit-routing/JitAdapter.t.sol:241` | FAIL (logic) | 短 revert data |
| AC-18 | `test_AC18_error_string_becomes_reason` | `src/tests/jit-routing/JitAdapter.t.sol:254` | FAIL (logic) | Error(string) as reason |
| AC-19 | `test_AC19_magic_spoof_is_rejected` | `src/tests/jit-routing/JitAdapterAttack.t.sol:19` | FAIL (logic) | magic spoof defense |
| AC-20 | `test_AC20_reentrancy_blocked` | `src/tests/jit-routing/JitAdapterAttack.t.sol:42` | FAIL (logic) | 重入 |
| AC-21 | `test_AC21_dryRun_external_caller_rejected` | `src/tests/jit-routing/JitAdapterAttack.t.sol:75` | FAIL (logic) | _dryRun self-only |
| AC-22 | `test_AC22_refundTo_marker_absence` | `src/tests/jit-routing/JitAdapterAttack.t.sol:90` | FAIL (logic) | marker 校验 |
| AC-23 | `test_AC23_fot_accuracy` | `src/tests/jit-routing/JitAdapterAttack.t.sol:112` | FAIL (logic) | FOT 0 偏差 |
| AC-24 | `test_AC24_gas_griefing_isolated` | `src/tests/jit-routing/JitAdapterAttack.t.sol:159` | FAIL (logic) | 多 gas burner 隔离 |
| AC-25 | `test_AC25_dry_equals_real_simple` | `src/tests/jit-routing/JitAdapter.t.sol:277` | FAIL (logic) | 单元 mirror; 完整 0 偏差看 Stage 4 fork |
| AC-26 | `test_AC26_no_leftover_on_jit` | `src/tests/jit-routing/JitAdapter.t.sol:291` | FAIL (logic) | 与 AC-06 等价 |
| AC-27 | `test_I10_dryRun_atomic_rollback` | `src/tests/jit-routing/JitAdapterInvariant.t.sol:182` | FAIL (logic) | 原子回滚 |
| AC-28 | `test_AC28_event_shape` | `src/tests/jit-routing/JitAdapter.t.sol:302` | FAIL (logic) | emit 形状 |
| AC-29 | `test_AC29_AC30_weak_proxy_iadapter_unchanged` | `src/tests/jit-routing/JitAdapterInvariant.t.sol:264` | PASS (trivial) | 弱代理; 真 diff 靠 PR pipeline |
| AC-30 | `test_AC29_AC30_weak_proxy_iadapter_unchanged` | 同上 | PASS (trivial) | 同上 |
| AC-31 | `test_AC31_underlying_sees_jit_as_msgsender` | `src/tests/jit-routing/JitAdapterInvariant.t.sol:271` | FAIL (logic) | underlying msg.sender 代理 |

**覆盖率: 31/31 AC → 100%**. 无 AC 未覆盖.

### 4.2 Invariant I-xx → Test

| I | Test Name | File:Line | 当前 PASS/FAIL |
|---|-----------|-----------|----------------|
| I-01 | `test_I01_dryRun_self_only` | `src/tests/jit-routing/JitAdapterInvariant.t.sol:18` | FAIL (logic) |
| I-02 | `test_I02_nonReentrant_active` | `src/tests/jit-routing/JitAdapterInvariant.t.sol:36` | FAIL (logic) |
| I-03 | `test_I03_magic_spoof_not_amountOut` | `src/tests/jit-routing/JitAdapterInvariant.t.sol:60` | FAIL (logic) |
| I-04 | `test_I04_catch_strict_validation` | `src/tests/jit-routing/JitAdapterInvariant.t.sol:78` | FAIL (logic) |
| I-05 | `test_I05_single_failure_isolated` | `src/tests/jit-routing/JitAdapterInvariant.t.sol:95` | FAIL (logic) |
| I-06 | `test_I06_candidates_boundary_lower` + `test_I06_candidates_boundary_upper` | `src/tests/jit-routing/JitAdapterInvariant.t.sol:107, 116` | FAIL (logic) |
| I-07 | `test_I07_allDead_reverts` | `src/tests/jit-routing/JitAdapterInvariant.t.sol:128` | FAIL (logic) |
| I-08 | `test_I08_dry_equals_real_unit` | `src/tests/jit-routing/JitAdapterInvariant.t.sol:140` | FAIL (logic) |
| I-09 | `test_I09_no_leakage` | `src/tests/jit-routing/JitAdapterInvariant.t.sol:168` | FAIL (logic) |
| I-10 | `test_I10_dryRun_atomic_rollback` | `src/tests/jit-routing/JitAdapterInvariant.t.sol:182` | FAIL (logic) |
| I-11 | `test_I11_to_passthrough` | `src/tests/jit-routing/JitAdapterInvariant.t.sol:201` | FAIL (logic) |
| I-12 | `test_I12_refundTo_marker_absent_means_zero` | `src/tests/jit-routing/JitAdapterInvariant.t.sol:213` | FAIL (logic) |
| I-13 | `test_I13_event_shape` | `src/tests/jit-routing/JitAdapterInvariant.t.sol:227` | FAIL (logic) |
| I-14 | `test_I14_iadapter_interface_stable` | `src/tests/jit-routing/JitAdapterInvariant.t.sol:252` | PASS (trivial) |

**覆盖率: 14/14 Invariant → 100%**.

### 4.3 Security S-xx → Negative Test

| S | 适用? | Test Name | File:Line | 当前 PASS/FAIL |
|---|-------|-----------|-----------|----------------|
| S-01 (Reentrancy 跨函数) | 适用 | `test_AC20_reentrancy_blocked` / `test_I02_nonReentrant_active` | `Attack.t.sol:42` / `Invariant.t.sol:36` | FAIL (logic) |
| S-02 (Reentrancy 同函数) | 适用 | 同 S-01 | 同上 | FAIL (logic) |
| S-03 (只读重入) | 不适用 | — | — | — (TD 声明无 state view, 无需测试) |
| S-04 (0.8 checked 算术) | 不适用 | — | — | — |
| S-05 (汇编算术) | 适用 | `test_AC22_refundTo_marker_absence` / `test_I12_refundTo_marker_absent_means_zero` | `Attack.t.sol:90` / `Invariant.t.sol:213` | FAIL (logic) |
| S-06 (onlyOwner) | 不适用 | — | — | — |
| S-07 (_dryRun 未授权) | 适用 | `test_AC21_dryRun_external_caller_rejected` / `test_I01_dryRun_self_only` | `Attack.t.sol:75` / `Invariant.t.sol:18` | FAIL (logic) |
| S-08 (sig 重放) | 不适用 | — | — | — |
| S-09 (Oracle 操纵) | 不适用 | — | — | — |
| S-10 (Flash loan) | 适用 | `test_I10_dryRun_atomic_rollback` | `Invariant.t.sol:182` | FAIL (logic) |
| S-11 (Magic spoof) | 适用 | `test_AC19_magic_spoof_is_rejected` / `test_I03_magic_spoof_not_amountOut` | `Attack.t.sol:19` / `Invariant.t.sol:60` | FAIL (logic) |
| S-12 (MAGIC selector 冲突) | 适用 | `test_MAGIC_01/02/03_*` | `JitAdapter.t.sol:320/326/333` | **PASS (trivial)** — D-2 核心断言 |
| S-13 (calldata tail hijack) | 适用 | `test_AC22_refundTo_marker_absence` / `test_I12_refundTo_marker_absent_means_zero` | 同 S-05 | FAIL (logic) |
| S-14 (ApproveProxy 滥用) | 不适用 | — | — | — |
| S-15 (delegatecall) | 不适用 | — | — | — |
| S-16 (selfdestruct) | 不适用 | — | — | — |
| S-17 (timestamp 随机) | 不适用 | — | — | — |
| S-18 (upgrade) | 不适用 | — | — | — |
| S-19 (ERC777 hook) | 适用 (低风险) | `test_AC24_gas_griefing_isolated` (gas 上限作为代理) | `Attack.t.sol:159` | FAIL (logic) |
| S-20 (FOT 偏差) | 适用 | `test_AC23_fot_accuracy` | `Attack.t.sol:112` | FAIL (logic) |
| S-21 (Rebase) | 适用 (低) | 未显式建测试. 由 AC-23 FOT 测量机制隐式覆盖. **Stage 4 可选择性补充.** | — | — |
| S-22 (Gas griefing) | 适用 | `test_AC24_gas_griefing_isolated` / `test_AC16_gas_burner_isolated` | `Attack.t.sol:159` / `JitAdapter.t.sol:228` | FAIL (logic) |
| S-23 (Storage slot 冲突) | 不适用 | — | — | — |
| S-24 (Native ETH send) | 适用 | `test_S24_native_ether_send_reverts` | `Attack.t.sol:177` | **PASS (trivial)** — stub 已无 receive |
| S-25 (恶意 adapter) | 适用 | `test_AC19_magic_spoof_is_rejected` | 同 S-11 | FAIL (logic) |
| S-26 (assetTo 伪造) | 适用 (后端责任) | — (合约层无防御, 测试不可行) | — | — (标注为 out-of-scope) |

**覆盖率:**
- 适用的 13 项安全 (S-01, S-02, S-05, S-07, S-10, S-11, S-12, S-13, S-19, S-20, S-22, S-24, S-25) → **全部 ≥1 test 覆盖**
- **S-21 (Rebase)** 未显式测试, TD Phase 4 原本也标 "本 TD 不额外增 AC". 记为 **有意不覆盖**, 不 BLOCK.
- **S-26 (assetTo 伪造)** 属 SDK/后端职责, PRD §11 Anti-Scope 第 7 条明确合约不做白名单 → **out-of-scope**, 不 BLOCK.

---

## 5. 覆盖率总汇

| 维度 | 总计 | 覆盖 | 覆盖率 | BLOCK? |
|------|------|------|-------|--------|
| AC-xx (PRD) | 31 | 31 | 100% | 否 |
| Invariant I-xx (TD) | 14 | 14 | 100% | 否 |
| Security S-xx (适用) | 13 | 13 | 100% | 否 |
| Security S-xx (不适用 + 有意不测) | 13 | — | N/A | 否 (每条有原因) |

---

## 6. 合规检查清单 (stage task 禁止项)

- [x] 所有函数体都是 `revert("NOT_IMPLEMENTED")` 或等效 (stub 未含任何实现)
- [x] 无 `assertTrue(true)` 占位
- [x] 无空测试
- [x] 无 `vm.skip` / 注释掉的测试
- [x] 未删除或修改既有测试
- [x] 未改 foundry.toml / .gitmodules / lib/ submodule
- [x] 未改 DexRouter / DagRouter / CommonLib / CommonUtils / IAdapter 与 60+ 既有 adapter
- [x] 7 个 PASS 全部是 trivial (常量 assert / selector assert / 结构 assert), 无被测主逻辑
- [x] 42 个 FAIL 全部是逻辑 assertion 失败, 无编译/符号错误

---

## 7. 交给 Stage 4 的清单

1. 按 td.md Phase 2 规格实现 JitAdapter (替换 `revert("NOT_IMPLEMENTED")` for 全部函数体)
2. 运行 `FOUNDRY_TEST=src/tests/jit-routing forge test` 期望全部 49 tests PASS (GREEN)
3. AC-15 必须补 stateful mock, 再把 `vm.expectRevert()` 收紧为具体 underlying revert payload
4. 决定是否保留 `DRY_RUN_RESULT_MAGIC` 为 public 或收紧为 internal; 若收紧, 测试需改为独立计算比对
5. AC-01..AC-04 的 PRD 定义 (UniV3 / UniV2 / PMM fork) 可在 Stage 4 独立写 fork 测试文件 (例: `JitAdapterFork.t.sol`), 单元 mirror 已覆盖.
6. 若希望 default `forge test` 自动收集 jit-routing 测试, **不要** 改 foundry.toml (PRD §3.2 禁止); 维持 `FOUNDRY_TEST=src/tests/jit-routing forge test` 作为 CI 命令.

---

## 8. 已知限制 (skeleton 固有)

- **AC-01, AC-02, AC-04 Fork 层覆盖**: 本 skeleton 用 mock adapter 替代真实 UniV3/UniV2/PMM; 真正的 "0 偏差" 断言需 Stage 4 fork 测试配合 `foundry.toml` `[rpc_endpoints]` 中的链 RPC.
- **AC-29 / AC-30 bytecode 不变**: 测试级只能断言 IAdapter 接口 selector, 完整字节码不变由 PR diff pipeline + audit 人工 review 承担.
- **I-14 规范字段**: 不变量是 "既有合约字节码不变" — forge test 内无法直接对比 PR base 与 HEAD 的字节码, 仅做接口 selector 代理断言.
- **S-21 Rebase**: 未显式构造 rebase token mock. 由 AC-23 FOT 机制隐式保证 (balanceOf 差值测量对 rebase 天然兼容).

以上限制均明示到本报告, **不计入 BLOCK**, 也不掩盖.
