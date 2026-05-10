# Technical Design: EVM JIT Routing (JitAdapter)

> 本 TD 基于 Stage 1 已审批 PRD (`prd.md`) 与 Stage 0 codemap (`codemap.md`).
> 立场: 安全 > 简洁 > 性能.
> 分支: `feat/oli-jit-routing`
> 下一 stage: Stage 3 (test skeleton) 基于本 TD + AC-xx 建立测试骨架.

---

## Phase 1: 合约清单

### 1.1 新增合约

#### `contracts/8/adapter/JitAdapter.sol`
- **继承**:
  1. `IAdapter` (from `contracts/8/interfaces/IAdapter.sol`) — 实现 `sellBase` / `sellQuote`
  2. `CommonLib` (from `contracts/8/libraries/CommonLib.sol`) — 复用 `_exeAdapter` + CommonUtils 常量 (ORIGIN_PAYER / _ETH / _ADDRESS_MASK / _REVERSE_MASK)
  3. `ReentrancyGuard` (from `@openzeppelin/contracts/security/ReentrancyGuard.sol`) — 非 Upgradeable 版本. 理由见 Phase 5 决策 D-1
- **关键属性**:
  - **Immutable**: 无 storage variable (除 ReentrancyGuard 的 `_status` slot, 由基类管理), 永久不升级
  - **No admin**: 无 owner / role / pausable / timelock
  - **No initializer**: 不使用 UUPS / Transparent proxy, 不需 `initialize()`; 构造函数为空 (或省略)
  - **No constructor args**: 不接收 WETH 等地址; native ETH 禁止, WETH 地址也无需持有 (走 CommonUtils `_WETH` 常量, 但本合约实际不调用)
- **部署特性**:
  - 各链独立部署一份 (因 CommonUtils 中 `_WETH` / `_APPROVE_PROXY` 是链相关 constant, 但 JitAdapter 不使用这些, 部署时编译产物跨链相同 — 除非未来引入常量)
  - 地址对后端白名单生效即可, 不影响其他合约

### 1.2 修改的既有合约
**无.** 本期严格零改动.

### 1.3 不动的既有合约 (锁定清单, 镜像 PRD §9.1)
- `contracts/8/DexRouter.sol`
- `contracts/8/DagRouter.sol`
- `contracts/8/libraries/CommonLib.sol`
- `contracts/8/libraries/CommonUtils.sol`
- `contracts/8/interfaces/IAdapter.sol`
- `contracts/8/interfaces/IDexRouter.sol`
- `contracts/8/adapter/*.sol` (60+ 现有 adapter)
- `contracts/8/TokenApproveProxy.sol`
- `contracts/8/TokenApprove.sol`
- `contracts/8/utils/WNativeRelayer.sol`
- `foundry.toml`, `.gitmodules`, `lib/`, `remappings.txt`

### 1.4 新增测试 (Stage 3/4 将落地)
- `src/tests/JitAdapter.t.sol` — 单元测试 (magic spoof / 边界 / OOG / reentrancy / refundTo marker / mode / native ETH / all-dead / winner 执行失败冒泡)
- `src/tests/JitAdapterFork.t.sol` — fork 集成测试 (UniV3 / UniV2 / mock PMM 场景, to 透传, FOT token)
- 可选 helper: `src/tests/adapter/common/MaliciousAdapter.sol` (mock magic spoof adapter), `src/tests/adapter/common/MockPmmAdapter.sol` (mock PMM 候选), `src/tests/adapter/common/GasBurnerAdapter.sol` (AC-24)
- 测试路径与 `foundry.toml` `test = "src/tests/suffix/"` 不冲突: 测试命令通过 `forge test --match-path "src/tests/JitAdapter*.t.sol"` 显式指定

---

## Phase 2: 接口与数据结构

> 本 Phase 仅定义签名 / struct / event / error. 函数体留空或写 `revert("NOT_IMPLEMENTED")`.
> Stage 4 实现时必须与本 Phase 完全一致.

### 2.1 依赖 imports (预期)
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;  // 与仓库 IDexRouter 一致; foundry.toml 不锁定具体版本
pragma abicoder v2;

import "../interfaces/IAdapter.sol";
import "../interfaces/IERC20.sol";
import "../libraries/CommonLib.sol";
import "../libraries/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
```

### 2.2 合约声明
```solidity
/// @title JitAdapter — Just-In-Time dynamic routing adapter
/// @notice 实现 IAdapter 接口, 在多候选之间通过 dry-run + revert 选出实测输出最大者, 再真实执行.
/// @dev Immutable, 无 admin. extraData 格式版本与本合约地址绑定.
contract JitAdapter is IAdapter, CommonLib, ReentrancyGuard {
    // (以下章节)
}
```

### 2.3 常量 (uint256 / bytes4)
```solidity
/// @dev 当前仅支持自动选优模式
uint8 internal constant MODE_AUTO = 0;

/// @dev 候选下限 (2): 单候选走静态路由更经济
uint256 internal constant MIN_CANDIDATES = 2;

/// @dev 候选上限 (255): uint8 winner type-safety
uint256 internal constant MAX_CANDIDATES = 255;

/// @dev 单候选 dry-run gas 硬上限 (PRD FR-16)
uint256 internal constant PER_DRYRUN_GAS_LIMIT = 500_000;

/// @dev dry-run 结果 magic 前缀; keccak256 输入字符串 "JIT_DRY_RUN_RESULT"
/// @dev Stage 3 / Stage 4 需在单元测试中 assert 具体 4-byte 值并验证与
///      Error(string) 0x08c379a0 / Panic(uint256) 0x4e487b71 / 常见 adapter selector 不冲突 (见 Phase 5 D-2)
bytes4 internal constant DRY_RUN_RESULT_MAGIC = bytes4(keccak256("JIT_DRY_RUN_RESULT"));
```

### 2.4 自定义 error (优于 require string)
```solidity
error UnsupportedMode(uint8 mode);
error CandidatesOutOfRange(uint256 length);      // length < 2 or > 255
error NativeEthNotAllowed();                      // fromToken == _ETH or toToken == _ETH
error ZeroInput();                                // balanceOf(address(this)) == 0
error OnlySelf();                                 // _dryRun 外部调用
error AllCandidatesDead();                        // max(quotes) == 0
error DryRunRevert(bytes data);                   // 内部用: _dryRun 主动 revert payload 构造错误 (仅防御, 正常路径不会触发)
```
> 注: revert reason 由 Solidity `error` 抛出, 带 selector. Stage 3 测试用 `vm.expectRevert(abi.encodeWithSelector(...))` 精确匹配.

### 2.5 struct
```solidity
/// @dev 单个候选. 字段与 RouterPath 的单 edge 切片镜像.
///      后端可复用静态路由 rawData[i] / extraData[i] 生成逻辑.
struct Candidate {
    address adapter;    // 现有 adapter 合约地址 (PmmRFQAdapter / UniV3Adapter / ...)
    address assetTo;    // token 转账目标; per-candidate 编码:
                        //   UniV2 类 → pool 地址
                        //   UniV3 / PMM 类 → adapter 地址
    uint256 rawData;    // packed: 低 160 bit = pool, bit 255 = reverse; 与 _ADDRESS_MASK / _REVERSE_MASK 同款
    bytes   extraData;  // 与静态路由调该 adapter 时 RouterPath.extraData[i] 完全一致
}
```

### 2.6 Events (字段冻结, 见 PRD FR-29/FR-30)
```solidity
/// @notice 当 winner 真实执行成功后 emit, 一次 tx 最多 1 次
event JitWinnerSelected(
    uint8 winnerIdx,
    uint256[] quotes,
    address winnerAdapter
);

/// @notice 单候选 dry-run 失败时 emit, 一次 tx 最多 candidates.length 次
event JitDryRunFailed(
    uint8 candidateIdx,
    address adapter,
    bytes reason
);
```

### 2.7 函数签名

#### 2.7.1 IAdapter 实现 (external)
```solidity
/// @inheritdoc IAdapter
/// @dev pool 参数被忽略 (设计约定, 仅为兼容 IAdapter 签名)
function sellBase(address to, address /* pool */, bytes calldata data)
    external
    override
    nonReentrant
{
    revert("NOT_IMPLEMENTED");  // Stage 4 填充
}

function sellQuote(address to, address /* pool */, bytes calldata data)
    external
    override
    nonReentrant
{
    revert("NOT_IMPLEMENTED");  // Stage 4 填充
}
```
> 注意: PRD FR-5 `Candidate.extraData` 是 `bytes memory` (ABI decode 决定); 顶层 `data` 入口遵循 `IAdapter.sellBase` 原签名 `bytes memory`, 但读场景下 `bytes calldata` 更省 gas. Stage 4 决定二者; 本 TD 偏向 `bytes calldata` (不涉及 inner write).

#### 2.7.2 核心流程 (internal)
```solidity
function _runJit(address to, bytes calldata data) internal {
    revert("NOT_IMPLEMENTED");
}
```
预期职责:
1. decode `(address fromToken, address toToken, uint8 mode, Candidate[] candidates)`
2. validate: mode / candidates 长度 / native ETH / balanceOf > 0
3. 读 refundTo (调用 `_extractRefundTo()`)
4. 循环 dry-run 全部候选, 填充 `quotes[]`
5. `_findMax` → require quotes[winner] > 0
6. `_exeAdapter` 真实执行 winner (失败冒泡)
7. emit `JitWinnerSelected`

#### 2.7.3 Dry-run 内层 (external, self-only)
```solidity
/// @dev 必须声明为 external; 只能被 JitAdapter 自身通过 try/catch + gas 限额 self-call
/// @dev 内部总是以 magic-prefixed revert 结束 (正常路径不会走到 return)
function _dryRun(
    Candidate calldata c,
    address to,
    address fromToken,
    address toToken,
    uint256 amount,
    address refundTo
) external {
    revert("NOT_IMPLEMENTED");
}
```
预期职责 (PRD FR-17/FR-18):
1. `require(msg.sender == address(this))` 或 `revert OnlySelf()`
2. `SafeERC20.safeTransfer(IERC20(fromToken), c.assetTo, amount)`
3. `(bool reverse, address pool) = _decodeRawData(c.rawData)`
4. `uint256 prev = IERC20(toToken).balanceOf(to)`
5. `(bool ok, bytes memory underlyingReason) = _tryExeAdapter(reverse, c.adapter, to, pool, c.extraData, refundTo)`
6. `uint256 amountOut = ok ? IERC20(toToken).balanceOf(to) - prev : 0`
7. magic-prefixed `revert`: `abi.encodePacked(DRY_RUN_RESULT_MAGIC, abi.encode(amountOut, ok, ok ? bytes("") : underlyingReason))`

#### 2.7.4 Dry-run 外层包装 (internal)
```solidity
function _dryRunSafe(
    Candidate calldata c,
    address to,
    address fromToken,
    address toToken,
    uint256 amount,
    address refundTo,
    uint8 idx
) internal returns (uint256 amountOut) {
    revert("NOT_IMPLEMENTED");
}
```
预期职责 (PRD FR-15/FR-20/FR-22):
- `try this._dryRun{gas: PER_DRYRUN_GAS_LIMIT}(c, to, fromToken, toToken, amount, refundTo)` catch data:
  1. 若 `data.length < 4` 返回 0
  2. 读前 4 字节, 若 ≠ `DRY_RUN_RESULT_MAGIC` 返回 0
  3. `_stripMagic(data)` 拿 inner payload
  4. `abi.decode(inner, (uint256, bool, bytes))` → `(amountOut_, ok, reason)`
  5. 若 `!ok`: `emit JitDryRunFailed(idx, c.adapter, reason)` 返回 0
  6. 否则返回 `amountOut_`

#### 2.7.5 low-level call 包装 (internal)
```solidity
function _tryExeAdapter(
    bool reverse,
    address adapter,
    address to,
    address pool,
    bytes memory extraData,
    address refundTo
) internal returns (bool ok, bytes memory returndata) {
    revert("NOT_IMPLEMENTED");
}
```
预期职责 (PRD FR-19): 与 CommonLib `_exeAdapter` 同构, 但失败时 **不 bubble**, 返回 `(false, revertData)`.
```solidity
// 预期实现骨架:
// bytes4 selector = reverse ? IAdapter.sellQuote.selector : IAdapter.sellBase.selector;
// bytes memory callData = abi.encodePacked(
//     abi.encodeWithSelector(selector, to, pool, extraData),
//     ORIGIN_PAYER + uint256(uint160(refundTo))
// );
// (ok, returndata) = address(adapter).call(callData);
```

#### 2.7.6 辅助纯函数 (internal pure / private pure)
```solidity
/// @dev argmax; 全零时返回 0 (winner 之后 require(quotes[winner] > 0))
function _findMax(uint256[] memory quotes) internal pure returns (uint8 winner);

/// @dev 跳过 4-byte magic 前缀, 返回内层 abi-encoded payload
function _stripMagic(bytes memory data) internal pure returns (bytes memory inner);

/// @dev 与 DagRouter._exeEdge:200-205 同款解码
function _decodeRawData(uint256 rawData) internal pure returns (bool reverse, address pool);

/// @dev 从 msg.data 末尾 32 字节读 refundTo, 带 ORIGIN_PAYER marker 校验
/// @dev marker 不匹配时返回 0 (underlying adapter 按 0 处理不退 leftover)
function _extractRefundTo() internal pure returns (address refundTo);
```

### 2.8 state 变量 (slot 布局)

| slot | 变量 | 来源 | 说明 |
|------|------|------|------|
| 0 | `_status` (uint256) | ReentrancyGuard | 0=NOT_ENTERED / 1=ENTERED / 2=ENTERED (OZ 4.x); JitAdapter 不访问 |

JitAdapter 自身 **不声明任何 state 变量**. 无 `owner` / `paused` / whitelist / reentrancy guard (后者由基类提供).

因无升级路径, 不需 `__gap` storage gap.

### 2.9 与既有合约的交互点

| 交互 | 方向 | 触发点 | 备注 |
|------|------|-------|------|
| DagRouter → JitAdapter.sellBase / sellQuote | in | DagRouter._exeEdge 通过 CommonLib._exeAdapter 调用 | JitAdapter 作为 adapter 被调用 |
| DagRouter → JitAdapter 的 token 转账 | in | DagRouter 按 RouterPath.assetTo[i] (=JitAdapter 地址) 把 fromToken 转入 | JitAdapter 在入口靠 `balanceOf(this) > 0` 确认 |
| JitAdapter → underlying adapter (dry-run) | out | `_tryExeAdapter` low-level call | 失败不冒泡; MAGIC 由 JitAdapter 自身在 _dryRun 末尾 revert 写入 |
| JitAdapter → underlying adapter (真实执行) | out | 继承自 CommonLib 的 `_exeAdapter` | 失败冒泡 → 整 tx revert (不做 fallback) |
| JitAdapter → IERC20(fromToken).safeTransfer | out | dry-run / 真实执行分支 | SafeERC20.safeTransfer |
| JitAdapter → IERC20(toToken).balanceOf | out | dry-run measure | 量 `to` 地址的余额变化 |
| JitAdapter 不调 ApproveProxy | - | - | 不涉及用户 allowance; token 已在 JitAdapter 余额上 |
| JitAdapter 不调 WNativeRelayer | - | - | 禁止 native ETH |

---

## Phase 3: 不变量列表 (Invariants)

> 每条不变量对应若干 AC-xx. 这是 Stage 3 测试骨架 / Stage 5 audit 的核心输入.
> 共 **14 条不变量** (I-01…I-14), 覆盖 31 条 AC 中的 27 条; 其余 4 条 AC (AC-07/AC-09/AC-11/AC-12/AC-13/AC-14) 是 `require` 边界断言, 不构成跨场景不变量, 但作为 "入口约束断言" 仍在 Stage 3 逐一测试 (见末尾说明).

| # | 不变量描述 | 必须成立的时机 | 违反后果 | 对应 AC-xx |
|---|------------|---------------|---------|-----------|
| I-01 | `msg.sender` 为 JitAdapter 自身是 `_dryRun` 可进入的必要条件 | `_dryRun` 函数入口 | 外部绕过 self-only 约束 → dry-run 可被任意构造, 有可能污染 FOT 测量逻辑、触发非预期 transfer | AC-21 |
| I-02 | sellBase / sellQuote / `_runJit` 的 `nonReentrant` 修饰符必须启用 | 每次外部入口调用 | 跨 candidate 或跨 tx 重入, winner 判定可能被操纵 | AC-20 |
| I-03 | dry-run 调用 underlying 时, 底层 revert data (含 MAGIC-like 伪造) 永远进入 payload 的 `underlyingReason` 字段, 不可落到 `amountOut` | `_dryRun` 最外层 revert 构造时 | magic spoof 成功, 伪造 amount 被选为 winner → 资金劫持 | AC-19 |
| I-04 | `_dryRunSafe` catch 严格校验 `data.length >= 4 && data[0..4] == DRY_RUN_RESULT_MAGIC`; 任一不匹配 → 返回 0 | 每次 catch 分支 | underlying 真实 revert / OOG 被误读为合法报价 | AC-17, AC-18 |
| I-05 | 单候选 dry-run 失败不影响其他候选, 整 tx 仅在 winner 真实执行失败或 all-dead 时 revert | 整个 dry-run 循环 | 单 adapter 故障 → 整 tx 崩溃, 用户多付 gas 且无选择 | AC-16, AC-24 |
| I-06 | 候选长度硬边界 `[2, 255]`, 任一越界 → revert (`CandidatesOutOfRange`) | sellBase/sellQuote 入口 | uint8 winner 截断 / 无意义的 JIT 调用 | AC-07, AC-09, (边界 OK: AC-05, AC-08) |
| I-07 | `winner = argmax(quotes)`; `quotes[winner] > 0` 是 invoking 真实执行的必要条件; 否则 revert `AllCandidatesDead` | `_runJit` 选 winner 阶段 | 误选 quote=0 的候选 → underlying 真实执行意义不明 | AC-10, AC-23 (间接) |
| I-08 | **dry-run amountOut == 真实执行 amountOut (0 偏差)**; 对通过 §9.3 兼容性 review 的 adapter 必须成立 | winner 真实执行完成时 | 后端 gas 估算失效 / 用户滑点保护误触发 | AC-25, AC-23, AC-01, AC-02, AC-04 |
| I-09 | winner 真实执行后 JitAdapter 自身的 fromToken balance == 0 (token 不滞留) | 真实执行返回前 | 用户资金遗留在 JitAdapter → 下一笔 swap 可被套利者夹带 | AC-26, AC-06 |
| I-10 | dry-run 过程中对 PMM signature / AMM state / FOT fee / ERC777 hook 的所有副作用 **被 revert 原子回滚**, 链上不留痕 (除 gas 外) | dry-run 返回后 | 同一签名被链下消费 / 池余额被恶意者观察 | AC-27 |
| I-11 | 真实执行中 `to` 参数 == dry-run 中 `to` 参数 == 外层 sellBase 收到的 `to` (不替换为 self) | dry-run 与真实执行两条路径 | FOT 测量偏差, 真实执行与预测不一致 | AC-03, AC-23, I-08 间接依赖 |
| I-12 | refundTo 提取: marker 不匹配 → refundTo == 0, 不得误读任意 calldata 末 32 字节为合法地址 | 入口 `_extractRefundTo` 调用时 | JitAdapter 被直接调 (无 DagRouter 介入) 时, 未识别的 calldata 尾被当成 refundTo 向任意地址退款 | AC-22 |
| I-13 | emit 的 `quotes.length == candidates.length`; `quotes[winnerIdx] == max`; `winnerAdapter == cs[winnerIdx].adapter` | `JitWinnerSelected` emit 时 | 监控数据错位, 上游无法判断真实 winner | AC-28 |
| I-14 | 既有文件字节码不变: CommonLib / CommonUtils / IAdapter / DexRouter / DagRouter / 60+ adapter / ApproveProxy / foundry.toml / .gitmodules | PR diff 检查时 | 违反 PRD 最小侵入承诺, 回归风险不可控 | AC-29, AC-30, AC-31 |

### 3.1 AC 到不变量映射总表
| AC | 对应不变量 | 类型 |
|----|-----------|------|
| AC-01 | I-08, I-09, I-11, I-13 | 正常路径 (隐式覆盖全部主不变量) |
| AC-02 | I-07, I-08, I-13 | 正常路径 |
| AC-03 | I-11, I-08 | 正常路径 (sellBase / sellQuote 镜像) |
| AC-04 | I-08, I-11, I-13 | 正常路径 (3 候选含 PMM) |
| AC-05 | I-06 (下界 OK) | 边界 (下界不 revert) |
| AC-06 | I-09 | 正常路径 (末态余额为 0) |
| AC-07 | I-06 (长度 1 revert) | 边界 (require 断言) |
| AC-08 | I-06 (上界 OK), I-07 (uint8 winner) | 边界 (255 不溢出) |
| AC-09 | I-06 (长度 256 revert) | 边界 (require 断言) |
| AC-10 | I-07 (all-dead revert) | 边界 / 异常 |
| AC-11 | — (`mode != 0` 直接 require 断言, 不跨场景) | 边界 (入口约束断言) |
| AC-12 | — (native ETH 入口 require) | 边界 (入口约束断言) |
| AC-13 | — (native ETH 入口 require) | 边界 (入口约束断言) |
| AC-14 | — (`balanceOf > 0` 入口 require) | 边界 (入口约束断言) |
| AC-15 | — (冒泡 revert 行为断言; I-05 仅约束单 dry-run 不互相拖死, 不覆盖 winner 真实执行失败) | 异常 (冒泡验证) |
| AC-16 | I-05 | 异常 |
| AC-17 | I-04 | 异常 |
| AC-18 | I-04, I-05 | 异常 |
| AC-19 | I-03 | 攻击 |
| AC-20 | I-02 | 攻击 |
| AC-21 | I-01 | 攻击 |
| AC-22 | I-12 | 攻击 |
| AC-23 | I-08, I-11 | 攻击 / 正确性 (FOT) |
| AC-24 | I-05 | 攻击 (gas griefing) |
| AC-25 | I-08 | 不变量断言 |
| AC-26 | I-09 | 不变量断言 |
| AC-27 | I-10 | 不变量断言 |
| AC-28 | I-13 | 不变量断言 |
| AC-29 | I-14 | 回归 |
| AC-30 | I-14 | 回归 |
| AC-31 | — (设计现象的声明; 不会破坏的断言) | 回归 / 文档 |

### 3.2 不对应不变量的 AC 澄清
以下 AC 仅构成 **入口约束断言** 或 **设计现象声明**, 并非跨场景不变量:
- AC-11 / AC-12 / AC-13 / AC-14: 单一 `require` 路径, 覆盖由 Stage 3 逐一独立测试, 不升格为不变量 (不变量应至少跨多个输入组合成立)
- AC-15: 单向冒泡行为 (winner 失败 → tx revert), 属 "行为契约" 而非 "可被破坏的不变性"
- AC-31: 描述设计现象 (underlying adapter 看到 msg.sender == JitAdapter), 不是行为断言

---

## Phase 4: 安全考量清单 (audit 反验对照表)

> 立场: 安全 > 简洁 > 性能.
> 列格式: 向量 / 适用性 / 防护方案 / 实现位置预期 / negative test AC.

| # | 攻击向量 | 适用 | 防护方案 | 实现位置预期 | Negative test AC |
|---|---------|------|---------|-------------|-------------------|
| S-01 | **Reentrancy (跨函数)** | 适用 | `ReentrancyGuard.nonReentrant` 修饰 sellBase / sellQuote | JitAdapter 两个 external 入口 | AC-20 (I-02) |
| S-02 | **Reentrancy (同函数, 跨 candidate)** | 适用 | 同 S-01; dry-run 内部无 state 写 | sellBase/sellQuote | AC-20 |
| S-03 | **Reentrancy (只读 / view)** | 不适用 | JitAdapter 无 state 变量, 无 view 可被误用 | — | — |
| S-04 | **整数溢出 (Solidity 0.8 checked)** | 不适用 (默认 checked) | 不使用 `unchecked` 块; balanceOf 差值不会下溢 (revert 前 prev 已读) | `_dryRun` step 6 (measure) | 隐式由 AC-01/02/04 覆盖 |
| S-05 | **汇编块算术溢出** | 适用 (refundTo 提取用 assembly) | 使用 `and(param, _ADDRESS_MASK)` 纯位运算, 不做加减 | `_extractRefundTo` | AC-22 (I-12) |
| S-06 | **访问控制 (onlyOwner / role)** | 不适用 | 永久 immutable, 无 admin / role / pausable; 合约层无任何 "仅 owner" 入口 | JitAdapter 无 owner 字段 | — (文档断言) |
| S-07 | **`_dryRun` 未授权调用** | 适用 | `require(msg.sender == address(this))` → `revert OnlySelf()` | `_dryRun` 第一行 | AC-21 (I-01) |
| S-08 | **Signature 重放 (chainId / nonce / domain)** | 不适用 (JitAdapter 不签名) | PMM 签名由 underlying PmmRFQAdapter 自己校验; JitAdapter 不接受、不存储、不验证签名 | — | — |
| S-09 | **Oracle 操纵 / TWAP 价差操纵** | 不适用 (JitAdapter 无 oracle) | 不读任何 oracle; 报价即链上 dry-run 结果 | — | — |
| S-10 | **Flash loan 放大 dry-run 影响** | 适用 (理论) / 缓解充分 | revert 原子性保证 dry-run state 零残留 (I-10 / AC-27); JitAdapter 本身不借贷; 攻击者最多 "窥视" 链上 state 变化, 但这在静态 swap 中也存在 | 全局 revert 原子性 | AC-27 (I-10) |
| S-11 | **Magic 数据伪造 (revert data spoof)** | 适用 (核心攻击向量) | `_dryRun` 用 `_tryExeAdapter` (low-level call, 不冒泡) 捕获 underlying revert data, 放入 `underlyingReason` 字段; JitAdapter 自己在最外层 revert 写 MAGIC + `abi.encode(amountOut, ok, underlyingReason)`. 攻击者伪造的 MAGIC 永远进不了 amountOut 槽位 | `_dryRun` / `_tryExeAdapter` / `_dryRunSafe` | AC-19 (I-03, I-04) |
| S-12 | **MAGIC 值与 Solidity 标准 error selector 冲突** | 适用 | `bytes4(keccak256("JIT_DRY_RUN_RESULT"))`. Stage 3/4 单元测试断言 MAGIC ≠ `bytes4(0x08c379a0)` (Error(string)) / `bytes4(0x4e487b71)` (Panic(uint256)) / 其他常见 adapter revert selector | DRY_RUN_RESULT_MAGIC 常量 + 单元测试 | 新 AC 建议 (Stage 3 测试层落地, 本 TD 不新增 PRD-level AC) |
| S-13 | **calldata 末尾追加约定劫持 (msg.data tail)** | 适用 | `_extractRefundTo` 通过 `(payerOrigin & ORIGIN_PAYER) == ORIGIN_PAYER` marker 校验; 不匹配返回 0, 不向任意地址退款 | `_extractRefundTo` assembly 块 | AC-22 (I-12) |
| S-14 | **Approval 滥用 (TokenApproveProxy)** | 不适用 | JitAdapter 不调 ApproveProxy; token 已在自身 balance 上 (由 DagRouter 转入) | — | — |
| S-15 | **Delegatecall 风险** | 不适用 | JitAdapter 不使用 `delegatecall`; 所有 external call 走 `address(adapter).call(...)` | — | — |
| S-16 | **selfdestruct** | 不适用 | 不使用 `selfdestruct`; 无升级路径 | — | — |
| S-17 | **block.timestamp / blockhash 用作随机源** | 不适用 | JitAdapter 不使用随机源; winner 选择由 dry-run 确定性结果决定 | — | — |
| S-18 | **升级漏洞 (initializer / storage gap)** | 不适用 | 非 proxy, 无 initializer, 无升级; `ReentrancyGuard` 非 Upgradeable 版 (Phase 5 D-1) | — | — |
| S-19 | **ERC777 hook 在 dry-run 中触发** | 适用 (低风险) | dry-run revert 原子性保证 hook 产生的 state 变化被回滚; 仅代价是消耗 gas 但被 `PER_DRYRUN_GAS_LIMIT` 约束 | 全局 revert 原子性 + per-dryrun gas 限额 | AC-24 (I-05, gas 上限) |
| S-20 | **FOT (fee-on-transfer) token 测量偏差** | 适用 | `to` 透传 (`I-11`) + `balanceOf(to)` before/after 测量 → dry-run 链路与真实执行链路 100% 同构, FOT fee 被 revert 原子回滚 | `_dryRun` step 3-6 + `_runJit` 真实执行 | AC-23 (I-08, I-11) |
| S-21 | **Rebase token** | 适用 (低概率) | balanceOf 差值测量天然兼容 rebase, 只要 fromToken / toToken 在 tx 内不 rebase | 测量逻辑 | 覆盖由 AC-23 扩展验证 (可选; 本 TD 不额外增 AC) |
| S-22 | **Gas griefing (单候选烧光)** | 适用 | `try this._dryRun{gas: PER_DRYRUN_GAS_LIMIT}(...)` 硬上限 500K; 1/64 残留 gas 规则保证外层能继续 | `_dryRunSafe` | AC-16, AC-24 (I-05) |
| S-23 | **Storage slot 冲突 (升级相关)** | 不适用 | 非 proxy, JitAdapter 自身无 state | — | — |
| S-24 | **Native ETH sent to JitAdapter** | 适用 | 无 `receive` / `payable fallback`; 任何 native ETH 直接 send → revert; 入口 `require fromToken != _ETH && toToken != _ETH` 双重防护 | JitAdapter 合约层 (无 payable) + `_runJit` 入口 require | AC-12, AC-13 |
| S-25 | **Candidate.adapter 被伪造 (恶意地址)** | 适用 (完全信任后端打包) | 合约层不做 whitelist (PRD §3.2 明确 "候选池动态增删 API 本期不做"); 流程层依靠 §9.3 adapter 兼容性 review 保证; 即使恶意 adapter 进 candidates, S-11 magic spoof 防御生效, 最多 quote=0 不可伪造赢 | — (流程层) | AC-19 (I-03) |
| S-26 | **Candidate.assetTo 被伪造指向任意地址** | 适用 | 合约层无防御: assetTo 由 SDK 打包, token 会被转到伪造地址. 但这只在 candidates 整个被篡改时才成立, 属于 "后端被入侵" 场景, 不是合约层责任; SDK/后端需校验 assetTo ∈ {adapter, pool} | — (SDK/后端层) | — (out-of-scope) |

### 4.1 不适用项复盘
- S-03 / S-04 / S-06 / S-08 / S-09 / S-14 / S-15 / S-16 / S-17 / S-18 / S-23: 合约不引入对应特性, 从根本上消除向量.
- S-26: 属 SDK/后端责任链, PRD §11 Anti-Scope 第 7 条已明确合约不做白名单.

### 4.2 审计额外断言 (audit 反验请求)
Audit (Stage 5) 除 AC-01…AC-31 外, 请额外确认:
- A-R1: 源码无 `selfdestruct` / `delegatecall` / `assembly` 中的写 storage 操作
- A-R2: JitAdapter bytecode 展开后不含 `receive()` / `fallback() payable`
- A-R3: MAGIC 4 字节值与 `Error(string)` / `Panic(uint256)` 及仓库内所有其他 adapter 的主要 revert selector 无冲突 (静态断言)
- A-R4: CommonLib / CommonUtils / IAdapter / DexRouter / DagRouter 文件的 git diff 为空 (执行 `git diff --stat main...feat/oli-jit-routing -- <file>` 验证)
- A-R5: JitAdapter 无任何 state 写入 (非 ReentrancyGuard `_status` 外, 静态分析确认)

---

## Phase 5: 团队拍板项落地

### D-1: OPEN-5 ReentrancyGuard 实现来源 → **落地**
- **决策**: 使用 `@openzeppelin/contracts/security/ReentrancyGuard.sol` (非 Upgradeable 版本)
- **理由**:
  1. JitAdapter 永久 immutable, 无 proxy 需求 (PRD §7.1, §11.5)
  2. 非 Upgradeable 版更省 gas (无 `__gap`, 无 initializer)
  3. 仓库 `remappings.txt:2` 已配置 `@openzeppelin/=node_modules/@openzeppelin/`, 同 package 下 `contracts/security/ReentrancyGuard.sol` 直接可用
  4. 仓库现有三处引用均为 Upgradeable 版, 但均服务 proxy 合约 (DexRouterExactOut / WNativeRelayer / HashflowAdapter), JitAdapter 场景不同
- **落地**: `import "@openzeppelin/contracts/security/ReentrancyGuard.sol";` 并 `contract JitAdapter is IAdapter, CommonLib, ReentrancyGuard`
- **Stage 4 验证**: 编译通过即可; 若 node_modules 中不存在该文件 (历史上仅依赖 Upgradeable 版), Stage 4 须先验证 node_modules 实际内容, 如缺失则改用 `ReentrancyGuardUpgradeable` + 空 initializer (在构造函数中调 `_disableInitializers()` 或直接手动初始化 `_status`). **本 TD 以非 Upgradeable 为首选方案**

### D-2: OPEN-4 MAGIC 常量值锁定 → **落地 (字符串)**
- **决策**: `DRY_RUN_RESULT_MAGIC = bytes4(keccak256("JIT_DRY_RUN_RESULT"))`
- **具体 4 字节值**: Stage 4 编译后由工具 (如 `cast keccak "JIT_DRY_RUN_RESULT"`) 取得, 在 Stage 3 单元测试中 hardcode 并 assert
- **冲突验证** (Stage 3 测试骨架必须新增):
  - assert MAGIC ≠ `bytes4(0x08c379a0)` (Error(string))
  - assert MAGIC ≠ `bytes4(0x4e487b71)` (Panic(uint256))
  - Stage 3 测试也要 assert MAGIC ≠ IAdapter.sellBase.selector / IAdapter.sellQuote.selector (以排除 self-call bytecode 误匹配)
- **上线后可调**: 否. MAGIC 一旦部署无法变更 (constant + immutable 合约)

### D-3: OPEN-1 candidates 数量业务上限 → **合约层不落地, 保持 OPEN**
- **合约层决策**: 仅保留 `MIN_CANDIDATES = 2` / `MAX_CANDIDATES = 255` 硬约束, 不引入业务常量 (如 8)
- **理由**: PRD OPEN-1 明确由后端承接; 合约层强加业务上限等于把后端策略写死, 违反 PRD 意图
- **若 OPEN-1 落定为 "合约层也加一层业务门槛"**: 需回 Stage 1 修 PRD; Stage 2 目前不预支此变更

### D-4: OPEN-2 L1 启用金额阈值 → **合约层不落地**
- **合约层决策**: 不做金额门槛
- **理由**: PRD OPEN-2 指派后端路由层

### D-5: OPEN-3 Adapter dry-run 兼容性 review → **合约层不落地**
- **合约层决策**: 无 whitelist
- **责任**: 流程层 (合约 owner review + QA fork 测试 + 后端 whitelist)

### D-6: OPEN-6 PMM 商务方沟通结果 → **合约层不落地**
- 纯业务, 不影响合约

### D-7 (新增, Stage 2 自发拍板): `bytes calldata` vs `bytes memory` 顶层入口
- **决策**: 顶层 sellBase / sellQuote 签名为 `bytes calldata data` (与 IAdapter 接口 `bytes memory` 兼容 — Solidity 自动转换; 事实上 IAdapter 定义为 `bytes memory` 但实现可用 `bytes calldata`, 编译通过)
- **理由**: 省一次内存拷贝
- **上线后可调**: 否

### D-8 (新增): pragma solidity 版本
- **决策**: `pragma solidity ^0.8.17`
- **理由**: 与 IDexRouter 的 `pragma solidity >=0.8.17` 一致; IAdapter 用 `^0.8.0` 但向上兼容
- **foundry.toml** 不锁定具体版本, 走 solc-select 自动发现

### D-9 (新增): Stage 4 实现应使用 `calldata` 还是 `memory` 传递 Candidate
- **决策**: internal 函数签名使用 `Candidate calldata c` (在 `_dryRunSafe` / `_dryRun` 都用 calldata)
- **理由**: candidates 数组从 `bytes calldata data` abi.decode 出来后, 数组元素仍然可以以 calldata 引用传递 (Solidity 0.8 支持); 避免 memory 拷贝

### 5.1 所有决策是否上线后可调
| ID | 上线后可调? |
|----|-----------|
| D-1 (ReentrancyGuard 版本) | 否 (immutable) |
| D-2 (MAGIC 值) | 否 (constant) |
| D-3 (candidates 上限) | 后端可调 (不在合约) |
| D-4 (L1 金额阈值) | 后端可调 (不在合约) |
| D-5 (adapter whitelist) | 后端可调 (不在合约) |
| D-6 (PMM 商务) | 不在合约 |
| D-7 (calldata 签名) | 否 |
| D-8 (pragma) | 否 |
| D-9 (Candidate calldata) | 否 |

### 5.2 开放拍板项状态表
| OPEN | PRD 状态 | Stage 2 TD 处置 |
|------|---------|----------------|
| OPEN-1 candidates 业务上限 | 开 | 合约层不落地, 后端决策 (D-3) |
| OPEN-2 L1 金额阈值 | 开 | 合约层不落地, 后端决策 (D-4) |
| OPEN-3 adapter 兼容性 review | 开 | 合约层不落地, 流程层 (D-5) |
| OPEN-4 MAGIC 值锁定 | 开 | **Stage 2 落定字符串 + Stage 3 测试 assert 具体 4 字节值** (D-2) |
| OPEN-5 ReentrancyGuard 版本 | 开 | **Stage 2 落定非 Upgradeable** (D-1), Stage 4 若 node_modules 缺失则回退 Upgradeable |
| OPEN-6 PMM 商务 | 开 | 合约层不落地 (D-6) |

---

## 附录

### A. 关键文件参考 (codemap 复用)
- CommonLib._exeAdapter: `contracts/8/libraries/CommonLib.sol:18-57`
- CommonUtils 常量 (_ETH / _ADDRESS_MASK / _REVERSE_MASK / ORIGIN_PAYER): `contracts/8/libraries/CommonUtils.sol:6, 8, 10, 17`
- IAdapter 接口: `contracts/8/interfaces/IAdapter.sol:5`
- UniV3Adapter refundTo 提取示范: `contracts/8/adapter/UniV3Adapter.sol:77-80, 93-97` (marker 校验: `(payerOrigin & ORIGIN_PAYER) == ORIGIN_PAYER`)
- DagRouter._exeEdge rawData 解码: `contracts/8/DagRouter.sol:193-205`
- RouterPath struct: `contracts/8/interfaces/IDexRouter.sol:12-18`
- ReentrancyGuard (OZ): `@openzeppelin/contracts/security/ReentrancyGuard.sol` (通过 remappings.txt:2)

### B. Stage 3 test skeleton 必须覆盖的额外测试 (TD 追加)
- T-MAGIC-01: assert `bytes4(keccak256("JIT_DRY_RUN_RESULT"))` 具体 4 字节值 (hardcode 后 assert)
- T-MAGIC-02: assert MAGIC 与 `Error(string)` / `Panic(uint256)` selector 不冲突
- T-MAGIC-03: assert MAGIC 与 `IAdapter.sellBase.selector` / `IAdapter.sellQuote.selector` 不冲突
- T-BYTECODE-01: git diff stat 验证 CommonLib.sol / CommonUtils.sol / IAdapter.sol / DexRouter.sol / DagRouter.sol / 60+ adapter / TokenApproveProxy.sol / foundry.toml / .gitmodules 无改动 (I-14)
- T-GAS-01: dry-run budget 基准 (非决策, 仅 baseline, 供后端参考)

### C. Stage 4 实现 checklist (给 dev)
- [ ] 严格按 Phase 2 函数签名 / struct / event / error 落地
- [ ] `_dryRun` 第一行 `if (msg.sender != address(this)) revert OnlySelf();`
- [ ] sellBase / sellQuote **都** 加 `nonReentrant`
- [ ] 真实执行用 CommonLib 的 `_exeAdapter` (继承得到), **不** 是 `_tryExeAdapter`
- [ ] dry-run 用本合约内部 `_tryExeAdapter`, low-level call, **不** 冒泡
- [ ] MAGIC 用 constant; Stage 3 测试必须 hardcode assert 具体 4 字节值
- [ ] 入口 4 个 require 都通过自定义 error 表达 (UnsupportedMode / CandidatesOutOfRange / NativeEthNotAllowed / ZeroInput)
- [ ] JitAdapter 无 `receive()` / `fallback()` / `payable` 方法
- [ ] `_extractRefundTo` 使用 `(payerOrigin & ORIGIN_PAYER) == ORIGIN_PAYER` marker 校验, 与 UniV3Adapter:36 同款
- [ ] `_decodeRawData` 使用 `_ADDRESS_MASK` / `_REVERSE_MASK` (继承自 CommonUtils)
- [ ] emit event 顺序: `JitDryRunFailed` 在每个失败 candidate 处 emit; `JitWinnerSelected` 在真实执行之后 emit
