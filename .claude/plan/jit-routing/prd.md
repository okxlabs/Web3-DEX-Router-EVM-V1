# PRD: EVM JIT Routing (DexRouter 动态路由)

> 本 PRD 由 Stage 1 产品分析师基于 Lark 原稿 (`prd-source-raw.md`) + codemap 输出生成.
> 来源: https://okg-block.sg.larksuite.com/docx/H4tzd49ezofEMpxsgoNlee2AgUf
> 关联 Jira: SCDEX-868 · 分支 `feat/oli-jit-routing`
> 下一 stage: Stage 2 TD (技术方案). 本 PRD 不做架构决策, 仅定义产品语义 + 验收标准.

---

## 1. 背景

### 1.1 现状
OKX Web3 DEX 聚合器 (DexRouter / DagRouter) 当前采用「链下计算路由 + 链上静态执行」模式. SDK 提前把整条 RouterPath 的 mixAdapters / rawData / extraData 打包好, 合约按 path 顺序逐 edge 调用 adapter, 不做任何链上决策.

### 1.2 问题
链下报价到链上真实执行之间存在时延 (10s~1min 级), 这段时间里:
- PMM firm-order 的报价可能劣化或签名被取消
- AMM 池的 tick / 曲线位置因其他交易而偏移
- 签名类报价可能已过期
以上场景在现有模式下只能依赖 `minReturnAmount` 被动保护 (触发后 tx revert, 用户损失 gas 重试).

### 1.3 参考对象
- Solana 生态 DFlow (JIT Routing) / Jupiter DynamicV1 / Titan DART 已实现链上候选仲裁
- 业界同行 (1inch / ParaSwap / 0x / CoW / UniswapX / 1inch Fusion) 均未在 EVM 链上实现动态路由选择

### 1.4 为什么现在做
- PMM 在 OKX 聚合器中占比上升, 报价敏感
- L2 gas 成本已低至 JIT 成本可接受
- EVM revert 原子性天然支持「dry-run + revert 拿结果」, 不需要复刻协议数学

## 2. 目标

### 2.1 业务目标
用户在 DEX swap 执行瞬间, 合约自动在预打包的一组候选 (不同 PMM / 不同 AMM 池) 中选出 **实测输出最大** 的一个执行, 减少因报价-执行 gap 造成的用户收益损失.

### 2.2 技术目标
- 合约层以 **最小侵入** 方式实现, 不改动 DexRouter / DagRouter / CommonLib / CommonUtils / IAdapter / ApproveProxy / 现有 60+ adapter
- 新增 **单个** 合约 `JitAdapter` 实现 `IAdapter`, 对 DagRouter 透明
- 不依赖任何 view 报价, 不复刻协议数学 — 协议升级对 JIT 零关联, 新协议接入零新合约部署
- JIT 候选池内容对后端/SDK 可扩展

### 2.3 交付范围
单合约 `JitAdapter.sol` (Solidity, 放在 contracts/8/) + 对应单元测试与 fork 集成测试.

## 3. 范围 (Scope)

### 3.1 In-Scope (本期交付)
- `JitAdapter` 合约, 实现 `IAdapter.sellBase` 与 `sellBase`→`_runJit`, `sellQuote`→`_runJit` 两个入口
- `_runJit` 内部做: decode extraData → dry-run 全部候选 → 选 winner → 真实执行 winner → emit event
- `_dryRun` / `_dryRunSafe` / `_tryExeAdapter` / `_findMax` / `_stripMagic` / `_decodeRawData` / `_extractRefundTo` 内部函数
- `Candidate` struct, 顶层 extraData 结构 `(fromToken, toToken, mode, candidates)`
- 两个 event: `JitWinnerSelected`, `JitDryRunFailed`
- 入口约束: mode==MODE_AUTO (=0), candidates 数量 [2,255], fromToken/toToken != native ETH (_ETH sentinel)
- `nonReentrant` 防护; 继承 CommonLib 复用 `_exeAdapter` + ORIGIN_PAYER 机制
- 单元测试: magic spoof 防御 / candidates 边界 / native ETH reject / all-dead winner / per-dry-run OOG / mode 非 AUTO
- Fork 集成测试: UniV3 池 + UniV2 池 + mock PMM adapter, 验证 dry-run 与真实执行一致性

### 3.2 Out-of-Scope (本期不做)
- **不修改** DexRouter / DagRouter / CommonLib / CommonUtils / IAdapter / ApproveProxy / TokenApproveProxy / 任何现有 adapter
- **不修改** foundry.toml 的 solc 版本 / .gitmodules / lib/ submodule
- **不引入** Quoter 合约或 view 报价路径
- **不实现** fallback (winner 失败直接冒泡 revert, 不执行 runnerUp)
- **不扩展** mode 字段以外的业务策略 (仅实现 MODE_AUTO = 0; mode 字段本期只接受 0)
- **不引入** 任何 admin / owner / upgrade 入口, JitAdapter 永久 immutable
- **不支持** native ETH 作为 fromToken / toToken (后端须先 wrap WETH)
- **不做** 后端/SDK 改造 (候选生成 / RouterPath 组装 / 监控消费 — 由后端团队独立承接)
- **不做** adapter dry-run 兼容性 review (§9.3, 属流程层, 合约不落地)
- **不做** 部署脚本 / 灰度发布策略 (由部署/运营团队承接)
- **不涉及** PMM 商务沟通 / L1 启用阈值策略 / candidates 上限业务限制 (拍板项, 合约层不硬约束)
- **不兼容** 旧 extraData 格式 (JitAdapter 地址即格式版本身份; 无 version 字段)

## 4. 核心用户/角色

| 角色 | 关心什么 | 在 JIT 中的位置 |
|------|---------|----------------|
| 终端用户 (swap 发起方) | 最大 output、最低 gas | 不直接感知; 通过 SDK/后端间接受益 |
| 后端路由引擎 | 何时生成 JIT edge、如何打包 candidates | 生成候选池 + 组装 RouterPath + 调 gas 估算 |
| SDK | 构造 calldata | 按合约约定编码 extraData |
| 合约开发 (本工程) | 实现 JitAdapter、保证安全与正确 | 核心责任 |
| QA | fork 测试一致性、边界用例覆盖 | 验证 AC |
| Audit / 安全团队 | 攻击向量分析 | 重点审查: magic spoof / reentrancy / refundTo 边界 / OOG / candidates 操纵 |
| 监控 / DataOps | 消费 JitWinnerSelected / JitDryRunFailed | 分析候选中选率、失败模式 |

## 5. 功能需求

### 5.1 入口 (sellBase / sellQuote)
- **FR-1**: `JitAdapter` 必须实现 `IAdapter.sellBase(address to, address pool, bytes data)` 与 `IAdapter.sellQuote(address to, address pool, bytes data)`, 两者内部均调用同一 `_runJit(to, data)`, 忽略 `pool` 参数
- **FR-2**: 外部 `pool` 参数在 DagRouter 调用路径中固定为 JitAdapter 自身地址 (由后端在 RouterPath.rawData 中填充), JitAdapter 不使用该参数
- **FR-3**: 两个入口函数都必须加 `nonReentrant` 修饰符

### 5.2 extraData 解码
- **FR-4**: 顶层 extraData 必须 decode 为 `(address fromToken, address toToken, uint8 mode, Candidate[] candidates)`
- **FR-5**: `Candidate` struct 字段固定为 `(address adapter, address assetTo, uint256 rawData, bytes extraData)`
- **FR-6**: `rawData` 内部 packed 编码: 低 160 bit = pool 地址, bit 255 = reverse 标志; 与 RouterPath.rawData[i] 使用同款 mask (`_ADDRESS_MASK`, `_REVERSE_MASK`)

### 5.3 入口约束 (同步 require)
- **FR-7**: `require(mode == MODE_AUTO)` 其中 `MODE_AUTO == 0`
- **FR-8**: `require(candidates.length >= 2 && candidates.length <= 255)` (合约级硬约束; 业务上限由后端决定)
- **FR-9**: `require(fromToken != _ETH && toToken != _ETH)` 其中 `_ETH` 取自 CommonUtils 常量 (`0xEeee...EEeE`)
- **FR-10**: `require(IERC20(fromToken).balanceOf(address(this)) > 0)` (JitAdapter 自身必须已收到 token)

### 5.4 refundTo 提取
- **FR-11**: `_extractRefundTo()` 必须从 `msg.data` 末尾 32 字节 `calldataload(sub(calldatasize(), 32))` 读取
- **FR-12**: 必须校验高位 `ORIGIN_PAYER` marker; marker 不匹配时 refundTo 保持 0 (防止 JitAdapter 被直接调用时误读)
- **FR-13**: JitAdapter 在调用 underlying adapter 时, 必须通过继承的 `_exeAdapter` / 内部 `_tryExeAdapter` 把 `refundTo` 以同款 `ORIGIN_PAYER + uint160(refundTo)` 方式追加到 calldata 末尾, 透传给 underlying

### 5.5 Dry-run 循环
- **FR-14**: 对 candidates 数组每个元素顺序调 `_dryRunSafe(c, to, fromToken, toToken, amount, refundTo, idx)`
- **FR-15**: `_dryRunSafe` 必须通过 `try this._dryRun{gas: PER_DRYRUN_GAS_LIMIT}(...)` 调用 (即 external self-call + gas 限额)
- **FR-16**: `PER_DRYRUN_GAS_LIMIT == 500_000` (uint256 constant)
- **FR-17**: `_dryRun` 必须 `require(msg.sender == address(this))`, 禁止外部直接调用
- **FR-18**: `_dryRun` 内部:
  1. `IERC20(fromToken).safeTransfer(c.assetTo, amount)` — 全额转给本候选的 assetTo
  2. `_decodeRawData(c.rawData)` 得 `(reverse, pool)`
  3. `uint256 prev = IERC20(toToken).balanceOf(to)` 记录 to 的 toToken 余额
  4. `_tryExeAdapter(reverse, c.adapter, to, pool, c.extraData, refundTo)` — **不冒泡** 的 low-level call, 返回 `(ok, underlyingReason)`
  5. `amountOut = ok ? IERC20(toToken).balanceOf(to) - prev : 0`
  6. 以 **magic-prefixed revert** 返回: `revert(abi.encodePacked(DRY_RUN_RESULT_MAGIC, abi.encode(amountOut, ok, ok ? bytes("") : underlyingReason)))`
- **FR-19**: `_tryExeAdapter` 为 JitAdapter 内部新增, **不得** 修改 CommonLib; 内部用 low-level `address(adapter).call(...)` 与 `_exeAdapter` 同款 ORIGIN_PAYER 追加, 但失败时 return (false, revertData) 而非冒泡
- **FR-20**: `_dryRunSafe` catch 分支严格校验: `data.length >= 4` AND `前 4 字节 == DRY_RUN_RESULT_MAGIC`; 任一不匹配返回 0 (视为失败)
- **FR-21**: `DRY_RUN_RESULT_MAGIC == bytes4(keccak256("JIT_DRY_RUN_RESULT"))`
- **FR-22**: `_dryRunSafe` 当 `ok == false` 时 emit `JitDryRunFailed(idx, c.adapter, underlyingReason)` 且返回 0; `ok == true` 时返回 amountOut

### 5.6 选 winner
- **FR-23**: `_findMax(quotes)` 返回 argmax 的下标 (uint8); 全零时返回 0
- **FR-24**: `require(quotes[winner] > 0)` 否则整 tx revert (所有候选 dead)

### 5.7 真实执行
- **FR-25**: `IERC20(fromToken).safeTransfer(cs[winner].assetTo, amount)` 转给 winner 的 assetTo
- **FR-26**: 调用 `_exeAdapter(reverse_winner, cs[winner].adapter, to, pool_winner, cs[winner].extraData, refundTo)` — 注意 **不是** `_tryExeAdapter`, 失败直接冒泡 revert (不做 fallback)
- **FR-27**: 真实执行中 `to` 必须与 dry-run 中 `to` **完全相同** (即外层 sellBase 收到的 to, 不替换为 self)
- **FR-28**: 真实执行后 emit `JitWinnerSelected(winnerIdx, quotes, winnerAdapter)`

### 5.8 Events
- **FR-29**: `event JitWinnerSelected(uint8 winnerIdx, uint256[] quotes, address winnerAdapter)`
- **FR-30**: `event JitDryRunFailed(uint8 candidateIdx, address adapter, bytes reason)`

### 5.9 JIT edge 在 RouterPath 中的约定 (仅描述后端合约契约, 本期合约不实现)
- `mixAdapters[i] = JitAdapter 地址`
- `assetTo[i] = JitAdapter 地址` (DagRouter 把 token 转给 JitAdapter)
- `rawData[i].pool = JitAdapter 地址` (占位, JitAdapter 忽略)
- `extraData[i] = abi.encode(fromToken, toToken, mode, candidates[])`
- refundTo **不** 进 extraData, 走 DagRouter 经 CommonLib 自动追加到 calldata 末尾的机制

---

## 6. 验收标准 (AC-xx)

> 以下 AC 单一职责, 可测试 (forge test 形态).
> 覆盖: 正常路径 / 边界 / 异常 / 攻击向量 / 不变量.
> Stage 3 (test skeleton) 必须为每条 AC 建立一个或多个测试用例.

### 6.1 正常路径 (Happy Path)

- **AC-01** 两候选 UniV2 + UniV3 (真实 fork), UniV3 报价更高时, winner == UniV3; emit JitWinnerSelected(winnerIdx=UniV3 idx, quotes 长度 2, winnerAdapter=UniV3Adapter 地址); to 地址的 toToken 余额增量 == quotes[winner]
- **AC-02** 两候选同类 AMM (如 UniV3 0.3% + 0.05% fee tier), 选 argmax; winner 覆盖候选顺序的两种情况 (winner=0 / winner=1) 都能正确选中
- **AC-03** sellBase 路径 (reverse=false) 与 sellQuote 路径 (reverse=true) 在对偶交易对上均能正确 dry-run + execute
- **AC-04** 3 候选 (UniV3 + UniV2 + mock PMM), mock PMM 报价最高时 winner = PMM, to 收到的 toToken 额 == PMM 的 mock 报价
- **AC-05** candidates 数量 == 2 (下界) 时正常执行
- **AC-06** winner 真实执行后, JitAdapter 自身的 fromToken / toToken 余额为 0 (无 token 滞留)

### 6.2 边界 (Boundary)

- **AC-07** candidates 数量 == 1 时 revert (require cs.length >= 2 失败), revert reason 包含 "candidates len out of range" 或等价 tag
- **AC-08** candidates 数量 == 255 时能执行完成 (不要求全部有效报价, 但不得因 uint8 winner 溢出失败); 全部 dead 时走 AC-10 路径
- **AC-09** candidates 数量 == 256 时 revert (require cs.length <= 255 失败)
- **AC-10** 所有候选 dry-run 均失败 (全员 dead, 全部 quote=0) 时整 tx revert, reason 包含 "all candidates dead" 或等价 tag; 不得真实执行任何候选
- **AC-11** mode != 0 时 revert, reason 包含 "unsupported mode"
- **AC-12** fromToken == _ETH (native sentinel) 时 revert, reason 包含 "native ETH not allowed"
- **AC-13** toToken == _ETH 时 revert, reason 同 AC-12
- **AC-14** JitAdapter 自身 fromToken 余额 == 0 时 revert, reason 包含 "zero input"

### 6.3 异常 / Revert 路径

- **AC-15** winner 真实执行 revert 时, 整 tx revert 并冒泡 underlying 的 revert data (不做 fallback)
- **AC-16** 单个候选 dry-run 耗尽 PER_DRYRUN_GAS_LIMIT (500K) 时, 该候选被视为失败 (quote=0) 但其他候选仍能继续 dry-run; **整 tx 不 revert**
- **AC-17** 单个候选 dry-run 返回的 revert data 长度 < 4 字节 (如 OOG) 时, 视为失败 (quote=0), 不触发 magic 解码
- **AC-18** 单个候选 dry-run 返回非 MAGIC 前缀的 revert data (underlying 真实 revert, 经 _tryExeAdapter 包装后 MAGIC 仍匹配) 时, 正确解码到 ok=false, underlyingReason 包含原 revert data, emit JitDryRunFailed

### 6.4 攻击向量

- **AC-19 (magic spoof 防御)** 恶意 adapter 直接 `revert(abi.encodePacked(MAGIC, fakeAmount))` 时, JitAdapter 在 dry-run 中 quote=0 (不被误判为合法报价). 因为 JitAdapter 在 _dryRun 中用 _tryExeAdapter (不冒泡), 底层 revert data 被放进 underlyingReason 字段, MAGIC 只由 JitAdapter 自己最外层写出, 攻击 fakeAmount 永远进 underlyingReason 而非 amountOut 槽位
- **AC-20 (reentrancy 防御)** 恶意 adapter 在 sellBase 中尝试重入 JitAdapter.sellBase, 因 `nonReentrant` 触发 revert
- **AC-21 (_dryRun 直接调用防御)** 外部地址 (任意 EOA 或合约, 非 JitAdapter 自身) 直接调 `_dryRun` 时 revert "JIT: only self"
- **AC-22 (refundTo marker 防御)** JitAdapter 被无 ORIGIN_PAYER marker 的直接调用 (无 DagRouter 介入) 时, 提取到的 refundTo == 0, underlying adapter 按 0 处理不退 leftover; 不得误读末 32 字节为任意地址
- **AC-23 (fee-on-transfer 准确性)** 使用 FOT token (mock) 作为 toToken 时, dry-run 返回的 amountOut 与真实执行后 to 实际收到的 toToken 金额相等 (0 偏差, 因 to 透传机制保证 dry-run 与真实执行 FOT 链路 100% 同构)
- **AC-24 (gas griefing 防御)** 单个恶意候选的 dry-run 烧满 500K gas, 其余候选仍能正常 dry-run; 整 tx 不因单候选被拖死

### 6.5 不变量 (Invariant)

- **AC-25** 在 AC-01 / AC-02 / AC-04 场景下: `dryRunAmountOut[winner] == realExecutionAmountOut` (0 偏差, 前提为 underlying adapter 通过兼容性 review — 见 §9.3 流程层保证)
- **AC-26** 在所有 AC 场景下: 若 winner 真实执行成功, JitAdapter 合约自身的 fromToken 余额为 0 (token 不滞留)
- **AC-27** 在所有 AC 场景下: dry-run 过程中 candidate 对任何协议的 state 变更 (PMM signature consume / AMM swap / FOT fee 扣除) 均因 revert 被原子回滚, 不对链上状态留下可被外部观察到的痕迹 (除 gas 消耗外)
- **AC-28** 在所有 AC 场景下: emit 的 `quotes` 数组长度 == candidates.length; 未成功候选位置为 0; winnerAdapter == cs[winnerIdx].adapter

### 6.6 对既有系统的不变量 (回归保护)

- **AC-29** DexRouter.smartSwap / DexRouter.dagSwapTo 在不含 JIT edge 的原有路径下行为不变 (跑现有回归测试套件)
- **AC-30** CommonLib._exeAdapter / CommonUtils 常量 / IAdapter 接口 bytecode 不变 (不得修改这些文件)
- **AC-31** 在 JIT edge 中, 调到的 underlying adapter 看到的 msg.sender == JitAdapter 地址; 这是 JIT 对 underlying 的唯一 "可见差异" (与静态路由下 underlying 看到的 DexRouter 地址不同). 这是设计如此, 不是缺陷

---

## 7. 非功能需求

### 7.1 安全
- 无 admin / owner, 永久 immutable
- `nonReentrant` 保护所有 external 入口
- `_dryRun` 通过 `require(msg.sender == address(this))` 禁止直接外部调用
- magic spoof / fake refundTo 防御参见 AC-19 / AC-22
- 不得存储任何用户资金 (每次调用末态余额为 0, AC-26)

### 7.2 Gas
- 单次 dry-run 硬上限 500_000 gas (`PER_DRYRUN_GAS_LIMIT`)
- 合约层不对 candidates 总数做业务上限, 总 gas 开销由后端在调用侧做预估 (§9.1 拍板项)
- JIT edge 的 base overhead + N × per_dryrun + winner_real_gas + 20% buffer 由后端 gas 估算器承担

### 7.3 兼容性
- 仅在 Solidity ^0.8.x (按 foundry.toml 版本) 编译通过
- evm_version = "london" (继承 foundry.toml)
- 不引入新 solc 版本 / 新 submodule / 新 remapping

### 7.4 可观测性
- 两个 event (JitWinnerSelected / JitDryRunFailed) 必须在每次 JIT swap 中精确 emit
- event 字段与 PRD §4 完全一致, 不得增减

---

## 8. 风险分析

### 8.1 技术风险
| # | 风险 | 概率 | 影响 | 缓解 |
|---|------|------|------|------|
| R-1 | 某个 underlying adapter 存在 gasleft 条件分支 / msg.sender 特定地址依赖, 导致 dry-run 与真实执行结果不一致 | 中 | 高 (用户资金损失: winner 估算不准可能触发 minReturn revert, 或罕见情况下 real < dry-run 但仍 > minReturn, 用户实收少于预期) | §7.1 / §9.3 adapter 兼容性 review 流程层拍板; 合约层由 AC-25 约束保证, 若违反则属 adapter 未通过 review, 不是 JitAdapter bug |
| R-2 | 恶意 adapter 通过 magic spoof 伪造 fakeAmount 被选为 winner | 低 (有 AC-19 防御) | 极高 (资金劫持) | AC-19 防御 + audit 强 review |
| R-3 | reentrancy 攻击 | 低 | 高 | AC-20 nonReentrant + 无 state 存储 |
| R-4 | 单候选 OOG 拖慢 / 拖死 tx | 中 | 中 (用户多付 gas) | AC-16 / AC-24 per-dryrun gas 硬上限 |
| R-5 | underlying adapter 返回 token 未全部转给 to, 而是滞留在 adapter/pool | 低 (adapter review 流程保证) | 中 | AC-25 dry-run 输出 == 真实输出的不变量必须成立; 否则该 adapter 不得进候选池 |
| R-6 | FOT token 场景下 dry-run 测量偏差 | 低 (AC-23 防御) | 中 | to 透传设计 + AC-23 验证 |
| R-7 | ERC777 类 token 的 hook 在 dry-run 中被触发, 浪费 gas | 低 | 低 (只多付 gas, 无安全问题) | 用户可接受; 文档提示 |
| R-8 | PMM 商务方误判 "同签名多次调用" 为异常行为 | 中 | 中 (PMM 侧可能限流) | §7.2 PMM 商务沟通拍板项; 合约层无改动 |

### 8.2 合约风险
| # | 风险 | 缓解 |
|---|------|------|
| R-9 | DRY_RUN_RESULT_MAGIC 与常见 Solidity error selector (如 `Panic(uint256)` 0x4e487b71, `Error(string)` 0x08c379a0) 冲突, 导致 underlying 真实 revert 被误读为合法 dry-run 结果 | `MAGIC = bytes4(keccak256("JIT_DRY_RUN_RESULT"))`, Stage 2 必须落地该 4 字节值并在测试中 explicit 断言 ≠ 0x08c379a0 / 0x4e487b71 / 其他常见 selector |
| R-10 | refundTo marker 被 DagRouter 以外的调用绕过 | AC-22 marker 校验; 合约入口 nonReentrant + 无直接调用路径保护 |

### 8.3 运营风险
| # | 风险 | 缓解 |
|---|------|------|
| R-11 | 候选池外部监控不到位, 高失败率 PMM 未及时剔除 | 后端消费 JitDryRunFailed 事件; 本 PRD 合约侧保证 emit 完整 |
| R-12 | L1 gas 成本过高导致 JIT 变成亏本操作 | §9.2 拍板项: L1 启用阈值由 PM + 后端决定; 合约层不控 |

---

## 9. 依赖 & 影响面

### 9.1 对既有代码的改动面
| 文件/模块 | 改动类型 |
|----------|---------|
| `contracts/8/adapter/JitAdapter.sol` | **新增** |
| `contracts/8/libraries/CommonLib.sol` | **不改** |
| `contracts/8/libraries/CommonUtils.sol` | **不改** |
| `contracts/8/DagRouter.sol` | **不改** |
| `contracts/8/DexRouter.sol` | **不改** |
| `contracts/8/interfaces/IAdapter.sol` | **不改** |
| `contracts/8/adapter/*.sol` (60+ 现有) | **不改** |
| `contracts/8/TokenApproveProxy.sol` | **不改** |
| `foundry.toml` / `.gitmodules` / `lib/` | **不改** |
| 部署脚本 (deploy/*) | **本期不交付** |
| 测试 | **新增** `src/tests/adapter/normal-test/JitAdapter.t.sol` + fork 场景测试 (具体路径 Stage 2 决定) |

### 9.2 对外部系统的依赖
| 外部系统 | 依赖关系 |
|---------|---------|
| 后端路由引擎 | 生成 JIT edge / 打包 candidates / gas 估算 — **独立项目**, 本期合约不涉及 |
| SDK | extraData 编码 — **独立项目**, 本期合约不涉及 |
| PMM 商务方 | §7.2 拍板项 (同签名多次调用兼容性) — **流程层**, 合约不涉及 |
| 前端 | 无直接依赖 |
| 监控系统 | 消费 JitWinnerSelected / JitDryRunFailed — **下游独立项目** |

### 9.3 部署影响
- JitAdapter 需要在各目标链单独部署, 地址由运营团队维护
- 部署后后端白名单内才能生效 (不影响现有 swap 路径, 渐进式启用)
- 不涉及任何代理升级 / storage slot 变更

### 9.4 storage 布局
JitAdapter 不声明任何 storage variable (除 ReentrancyGuard 的 `_status`); 不存在 storage 冲突风险.

---

## 10. 团队拍板项 (OPEN, 必须人工确认)

> 以下各项在本 PRD 保持 OPEN, 等待人工拍板. Stage 2 TD 允许引用 "拍板后值", 但 Stage 4 实现必须在拍板项确定后才继续.

### 10.1 OPEN-1: candidates 数量业务上限 (§9.1 of raw PRD)
- 背景: 合约层保留 `[2, 255]` 硬约束; 业务层建议 ≤ 8 (raw PRD §9.1)
- 待确认: 后端是否需要在本期 SDK/后端处再加一层业务上限?
- **本 PRD 不预设默认值**; 合约侧按 PRD 不设业务限制. 后端侧决策不影响本期合约交付
- 责任方: 产品 + 后端 + 合约联合

### 10.2 OPEN-2: L1 启用金额阈值 (§9.2 of raw PRD)
- 背景: L2 默认启用 JIT; L1 需订单金额阈值筛选
- 待确认: $5K / $50K / $500K 分级阈值的具体值
- **本 PRD 不预设默认值**; 合约层不实现金额门槛, 由后端路由决策层控制
- 责任方: 产品 + 后端

### 10.3 OPEN-3: Adapter dry-run 兼容性 review 通过标准 (§9.3 of raw PRD)
- 背景: 并非所有 60+ adapter 都能直接进 JIT 候选池
- 已列入 raw PRD §9.3 的通过标准:
  - 不使用 `gasleft()` 做条件判断
  - 不依赖 `msg.sender` 是特定地址
  - Fork 一致性测试: 常规 token / FOT token / native ETH 路径, 多金额多池状态, dry-run 返回量 == 真实执行量 (0 偏差)
- 待确认: 首批进候选池的 adapter 白名单; review 主责人 / CR sign-off 流程
- **本 PRD 不预设具体 adapter 列表**; 合约层不做 adapter whitelist (由后端决策)
- 责任方: 合约 owner review + QA fork 测试 + 后端白名单维护

### 10.4 OPEN-4: MAGIC 常量值锁定与冲突验证
- 背景: `bytes4(keccak256("JIT_DRY_RUN_RESULT"))` 的具体 4 字节值需落地并验证与 `Panic(uint256)` / `Error(string)` / 常见 adapter revert selector 不冲突
- 待确认: Stage 2 TD 落地具体 4 字节值, 单元测试断言不冲突
- **本 PRD 明确 keccak256 输入字符串为 "JIT_DRY_RUN_RESULT"**; Stage 2 必须落地该字符串并在测试中断言 MAGIC 值
- 责任方: Stage 2 TD + Stage 3 test skeleton

### 10.5 OPEN-5: ReentrancyGuard 实现来源
- 背景: 仓库现有两种引入路径 (ReentrancyGuardUpgradeable vs 非 Upgradeable); PRD 用词 "ReentrancyGuard" 不区分
- 待确认: JitAdapter 为 immutable, 偏向非 Upgradeable; 但需验证 remappings 支持情况
- **本 PRD 不指定**; 属 Stage 2 TD 范围
- 责任方: Stage 2

### 10.6 OPEN-6: PMM 商务方沟通结果 (§7.2 of raw PRD)
- 背景: 需确认 OKX RFQ 对「同一签名多次调用 (dry-run + 真实执行) 」是否会触发风控
- **本 PRD 不涉及**; 属业务流程拍板项. 结果出来后可能影响 candidates 组合策略, 不影响本期合约
- 责任方: 产品 + PMM 商务

---

## 11. 非目标澄清 (Anti-Scope 保护)

为防止 dev stage 范围漂移, 以下内容 **明确不在本期交付**:

1. Quoter 合约 — 本期永不实现, 整个比价机制是 dry-run + revert
2. Fallback 路径 — winner 失败整 tx revert, 不执行 runnerUp
3. Mode != 0 的任何扩展 (MODE_MANUAL / MODE_PARTIAL / ...) — 仅接受 MODE_AUTO
4. Version 字段 / 多版本 extraData 兼容 — JitAdapter 地址即版本身份
5. Admin / owner / upgrade proxy — JitAdapter 永久 immutable, 无 admin
6. Native ETH 直接支持 — 必须后端 wrap 成 WETH
7. 候选池动态增删 API — 本期 JitAdapter 对 candidates 完全无状态, 不维护白名单
8. 对 DexRouter / DagRouter / CommonLib 的任何改动 — 一行都不动
9. 部署脚本 / 灰度配置 / 监控 Dashboard / 后端路由引擎 — 分别由部署 / 后端 / 监控团队独立承接

---

## 12. 附录

### 12.1 关键术语
- **JIT Routing** (Just-In-Time Routing): 链上 swap 瞬间的动态路由决策
- **Dry-run + Revert**: 合约内部通过 `try/catch + revert with data` 模拟执行并回收结果, 利用 EVM revert 原子性保证状态零残留
- **Candidate**: 一组等效的单条 swap 路径, 由后端预打包
- **Winner**: dry-run 中实测输出最大的 candidate
- **Magic-prefixed revert**: 用 4 字节固定前缀 + abi-encoded payload 的方式构造 revert data, 供外层 catch 识别
- **ORIGIN_PAYER marker**: CommonLib 在 calldata 末尾追加的 refundTo 标记, 用于 adapter 识别真实 payer

### 12.2 参考文件
- raw PRD: `.claude/plan/jit-routing/prd-source-raw.md`
- Codemap: `.claude/plan/jit-routing/codemap.md`
- Env capabilities: `.claude/plan/jit-routing/env-capabilities.json`
- Foundry.toml: 仓库根
- CommonLib._exeAdapter: `contracts/8/libraries/CommonLib.sol:18-57`
- CommonUtils._ETH / ORIGIN_PAYER: `contracts/8/libraries/CommonUtils.sol:6, 17`
- UniV3Adapter refund 提取参考: `contracts/8/adapter/UniV3Adapter.sol:79, 96`
