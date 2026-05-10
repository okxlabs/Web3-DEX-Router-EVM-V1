# Codemap: JIT Routing (feat/oli-jit-routing)

> 扫描时间: 2026-05-10
> 分支: feat/oli-jit-routing (基于 main @ fef5a8be)
> 约定: 只列 file:line, 不读大文件全文; Stage 2 按需 Read

## 命名实体定位

### DexRouter (合约)
- 定义: `contracts/8/DexRouter.sol:23`
- 关键入口 (与 JIT 相关):
  - `smartSwapTo`: `contracts/8/DexRouter.sol:491`
  - `dagSwapTo`: `contracts/8/DexRouter.sol:914` (委派到 DagRouter)
- PRD 结论: 不改动

### DagRouter (抽象合约, extends CommonLib)
- 定义: `contracts/8/DagRouter.sol:8`
- 关键函数:
  - `_exeNode`: `contracts/8/DagRouter.sol:99`
  - `_exeEdge`: `contracts/8/DagRouter.sol:193`
  - path 长度一致性检查 (mixAdapters / rawData / extraData / assetTo): `contracts/8/DagRouter.sol:112-116`
  - 调 adapter 循环: `contracts/8/DagRouter.sol:127, 180`
- PRD 结论: 不改动. JitAdapter 对 DagRouter 透明

### CommonLib (库/抽象合约)
- 定义: `contracts/8/libraries/CommonLib.sol:15`
- `_exeAdapter` 函数: `contracts/8/libraries/CommonLib.sol:18`
  - ORIGIN_PAYER + refundTo 追加到 calldata 末尾: `contracts/8/libraries/CommonLib.sol:35, 50`
- PRD 结论: 不改动. JitAdapter 继承 CommonLib 复用 `_exeAdapter` + ORIGIN_PAYER 机制

### CommonUtils (抽象合约)
- 定义: `contracts/8/libraries/CommonUtils.sol:5`
- 关键常量:
  - `_ETH` (native sentinel): `contracts/8/libraries/CommonUtils.sol:6`
  - `_ADDRESS_MASK`: `contracts/8/libraries/CommonUtils.sol:8`
  - `_REVERSE_MASK`: `contracts/8/libraries/CommonUtils.sol:10`
  - `ORIGIN_PAYER`: `contracts/8/libraries/CommonUtils.sol:17`
  - `_ADDRESS_MASK` 在 bytes/assembly helper: `contracts/8/libraries/CommonUtils.sol:149`
- PRD 结论: 不改动. JitAdapter 间接继承 (through CommonLib)

### IAdapter (接口)
- 定义: `contracts/8/interfaces/IAdapter.sol:5`
- 接口签名: `sellBase(to, pool, data)` / `sellQuote(to, pool, data)` (均 external)
- 引用 (继承) 文件数: 见 `_exeAdapter|ORIGIN_PAYER` grep — 24 个 adapter / router 文件引用
- PRD 结论: 不改动. JitAdapter 同时实现 sellBase 和 sellQuote 但均走 `_runJit`

### IAdapterWithResult (接口)
- 定义: `contracts/8/interfaces/IAdapterWithResult.sol:5`
- PRD 结论: 不使用 (PRD 走 magic-prefixed revert, 非此接口)

### IDexRouter (struct 定义)
- 定义: `contracts/8/interfaces/IDexRouter.sol:4`
- `struct RouterPath`: `contracts/8/interfaces/IDexRouter.sol:12-18`
  - 字段: `address[] mixAdapters`, `address[] assetTo`, `uint256[] rawData`, `bytes[] extraData`, `uint256 fromToken`
- `struct BaseRequest`: `contracts/8/interfaces/IDexRouter.sol:5-11`
- PRD 结论: 不改动. 每个 JIT edge 后端将 `mixAdapters[i]=JitAdapter`, `assetTo[i]=JitAdapter`, `rawData[i].pool=JitAdapter`, `extraData[i]=abi.encode(fromToken,toToken,mode,candidates)`

### ISmartRouter (struct 定义, 备用)
- 定义: `contracts/8/interfaces/ISmartRouter.sol:7, 15`
- PRD 结论: 与 IDexRouter 同名结构, 不改动

### UniV3Adapter (合约, 参考实现)
- 定义: `contracts/8/adapter/UniV3Adapter.sol:17`
- refundTo 提取 (`calldataload(sub(size, 32))`): `contracts/8/adapter/UniV3Adapter.sol:79, 96`
- PRD 参考: JitAdapter 复用同款 refundTo 提取模式
- 测试: `src/tests/UniV3Refund.t.sol`

### UniAdapter (UniV2 family, 参考实现)
- 定义: `contracts/8/adapter/UniAdapter.sol:11`
- PRD 参考: assetTo=pool 模式

### PmmRFQAdapter (合约, 参考候选)
- 定义: `contracts/8/adapter/PmmRFQAdapter.sol:12`
- PRD 参考: assetTo=adapter 模式

### TokenApproveProxy (合约)
- 定义: `contracts/8/TokenApproveProxy.sol:12`
- PRD 结论: 不改动

### WNativeRelayer (合约)
- 定义: `contracts/8/utils/WNativeRelayer.sol:10`
- 与 JIT 的关联: JitAdapter 禁止 native ETH; 后端自行 wrap. 无直接交互

### ReentrancyGuardUpgradeable (OpenZeppelin)
- 引入示例: `contracts/8/adapter/HashflowAdapter.sol:9` (`@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol`)
- PRD 参考: JitAdapter 加 `nonReentrant` (可选用 Upgradeable 或普通 ReentrancyGuard, Stage 2 决策)

### JitAdapter (新建目标)
- 当前仓库搜索 `JitAdapter` / `dry.?run` (`-i`) 结果: **0 命中** (待 Stage 4 新增)
- 目标位置 (建议, 待 Stage 2 确认): `contracts/8/adapter/JitAdapter.sol`
- 目标测试位置 (建议): `src/tests/JitAdapter.t.sol` 或 `src/tests/adapter/normal-test/JitAdapter.t.sol`

---

## 通用基础设施

### 构建配置
- `foundry.toml`: 仓库根
  - `src = "contracts/8"`, `test = "src/tests/suffix/"` (默认 test 路径只含 suffix, Stage 3/4 写测试需显式指定 `-- --match-path`)
  - `evm_version = "london"`
  - `optimizer = true`, `optimizer_runs = 1`
  - `remappings`: `@dex/=contracts/8/`, `@openzeppelin/=node_modules/@openzeppelin/`
  - `[rpc_endpoints]`: 含 arb / base / bsc / eth / polygon / op / linea / mantle / scroll 等 23 条; fork 测试引用这里
  - `[fmt]`: line_length=120, tab_width=4, quote_style=double, sort_imports=true
- `.gitmodules`: 只含 forge-std (lib/forge-std); solc 版本由 foundry.toml 决定, 禁止改动

### 仓库说明
- 仓库根 `README.md` 存在 (Stage 2 可 Read)

### contracts/8 顶层结构 (仅列 dirs/files, 不展开)
- `DagRouter.sol`, `DexRouter.sol`, `TokenApprove.sol`, `TokenApproveProxy.sol`, `UnxswapRouter.sol`, `UnxswapV3Router.sol`
- `adapter/` (60+ adapter)
- `interfaces/` (含 IAdapter.sol, IAdapterWithResult.sol, IDexRouter.sol, ISmartRouter.sol ...)
- `libraries/` (含 CommonLib.sol, CommonUtils.sol, Adapters.sol, SafeERC20.sol, PMMLib.sol, UniversalERC20.sol ...)
- `types/`, `utils/` (含 WNativeRelayer.sol)

### 公共抽象 (Stage 2 按需 Read)
- `contracts/8/libraries/CommonLib.sol` (含 `_exeAdapter`)
- `contracts/8/libraries/CommonUtils.sol` (含常量 `_ETH` / `_ADDRESS_MASK` / `_REVERSE_MASK` / `ORIGIN_PAYER`)
- `contracts/8/libraries/Adapters.sol`
- `contracts/8/libraries/SafeERC20.sol`
- `contracts/8/libraries/UniversalERC20.sol`
- `contracts/8/libraries/PMMLib.sol`

### 测试基础设施
- `src/tests/common/TrimAndCommissionTestBase.t.sol`: 通用测试基类
- `src/tests/adapter/common/AbstractAdapterTest.t.sol`: adapter 测试抽象基类
- `src/tests/common/mock/MockERC20.sol`, `MeMeERC20.sol` (FOT token mock)
- fork 测试示例: `src/tests/UniV3Refund.t.sol` (UniV3Adapter refund 测试), `src/tests/trim/DagSwapTrimTest.t.sol` (DagRouter 场景)
- fork RPC: 使用 `vm.createSelectFork(vm.envString("<chain>_RPC_URL"))` 或 `--fork-url <name>` (name 取自 foundry.toml `[rpc_endpoints]`)
- 既有 adapter normal-test 目录: `src/tests/adapter/normal-test/` (22 个 adapter 测试参考)

---

## 待 Stage 2 决策的设计点

以下为 PRD 中已定方向但仍需 Stage 2 细化的具体实现选择:

1. **JitAdapter 合约位置**
   - 建议 `contracts/8/adapter/JitAdapter.sol`. 其他位置 (e.g. 新目录 `contracts/8/jit/`) 属额外决策, 默认跟既有 adapter 同目录.

2. **ReentrancyGuard 实现选择**
   - 可选 A: `@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol` (仓库既有引入路径, 见 HashflowAdapter)
   - 可选 B: `@openzeppelin/contracts/security/ReentrancyGuard.sol` (JitAdapter 按 PRD 是 immutable, 无 upgrade 需求)
   - PRD 用词 "ReentrancyGuard" 建议倾向 B, 但需 Stage 2 验证 remappings 是否已支持.

3. **_tryExeAdapter 定义位置**
   - 可选 A: 新增为 CommonLib 的 internal 函数 (需修改 CommonLib, 违反 PRD "CommonLib 不改动")
   - 可选 B (推荐): 定义在 JitAdapter 内部, 私有 internal, 与 PRD 5.2 伪代码一致
   - Stage 2 必须采方案 B.

4. **DRY_RUN_RESULT_MAGIC 值**
   - PRD: `bytes4(keccak256("JIT_DRY_RUN_RESULT"))`. 选择能避开常见 error selector. Stage 2 需落地字符串, 并在测试中验证不冲突.

5. **PER_DRYRUN_GAS_LIMIT 是 constant 还是 immutable**
   - PRD 伪代码用 `uint256 constant = 500_000`; Stage 2 沿用.

6. **sellBase 与 sellQuote 是否共用 `_runJit`**
   - PRD 5.1 明确: 两者都走 `_runJit` (因为每个 candidate 自己 rawData 里已经有 reverse 标志). Stage 2 无需另行决策, 仅需在 TD 中显式重申.

7. **Events 放置位置 (JitWinnerSelected / JitDryRunFailed)**
   - 在 JitAdapter 内 declare 即可.

8. **candidates 上限常量**
   - PRD 9.1 拍板: **合约层不设业务硬上限**, 仅保留 `cs.length >= 2 && cs.length <= 255` (uint8 type-safety). Stage 2 不应引入额外 MAX_CANDIDATES 业务常量.

9. **native ETH 检测位置**
   - 合约入口 `require(fromToken != _ETH && toToken != _ETH)`. Stage 2 需使用 CommonUtils._ETH 以避免常量重复.

10. **测试覆盖范围**
    - Fork 测试最小集合: UniV3 (base/eth) + UniV2 (eth) + 1 个 PMM 候选场景 (mock PMM adapter 避免外部 RFQ 依赖);
    - 单元测试: magic spoof 防御, candidates length 边界 (1/2/255/256), native ETH reject, fromToken=0 revert, per-dryrun OOG.

11. **JitAdapter 是否继承 IAdapter**
    - 必须 (PRD 5.1). Stage 2 TD 中确认.

12. **Adapter dry-run 兼容性 review (§7.1, §9.3)**
    - 属流程层拍板, 合约不落地. Stage 2 记录为外部约束即可.

---

## 扫描统计
- 命名实体数: 14 (含 JitAdapter 新建目标)
- 涉及仓库文件 (adapter 层引用 _exeAdapter/ORIGIN_PAYER): 24
- 测试基础设施文件: 5 个关键基类 + 22 个同类 adapter 测试参考
