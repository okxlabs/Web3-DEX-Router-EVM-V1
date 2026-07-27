# CLAUDE.md

本文件为 Claude Code (claude.ai/code) 在本仓库中工作时提供指引。

## 项目概览

Web3-DEX-EVM 是一个生产级 DEX（去中心化交易所）路由/聚合器，在 30+ 条 EVM 链上支持 80+ 协议。使用 Solidity 0.8.17，基于 Foundry 和 Hardhat 构建。

## 构建与测试命令

```bash
# 构建
forge build                                          # Foundry 构建
npx hardhat --config hardhat.config.js compile       # Hardhat 构建

# 测试
forge test                                           # 运行全部测试
forge test --match-test testFunctionName            # 运行指定测试
forge test --match-contract ContractName            # 运行指定合约的测试
forge test -vvv                                      # 详细输出（含调用栈）

# 格式化与检查
npm run prettier:solidity                            # 格式化 Solidity 文件
npm run size                                         # 检查合约大小

# 部署（唯一入口是 hardhat task deploy-and-verify，详见“部署”章节）
npx hardhat deploy-and-verify --network <chain>                 # 模拟（不广播）
npx hardhat deploy-and-verify --network <chain> --broadcast     # prod 部署
npx hardhat deploy-and-verify --network <chain> --env stg --broadcast  # staging 部署
```

## 架构

### 入口
**DexRouter.sol** (`contracts/8/DexRouter.sol`) —— 主路由合约，委托给基于库（library）的各路由器：
- `smartSwapByOrderId()` / `smartSwapTo()` —— 基于批次（batch）的智能 swap
- `dagSwapByOrderId()` / `dagSwapTo()` —— 基于 DAG 的路由 swap
- 通过 UnxswapRouter 系列库实现的 Uniswap V2/V3 专用函数

### 核心数据结构 (IDexRouter.sol)
```solidity
struct BaseRequest {
  uint256 fromToken;      // 源 token（用 uint256 以处理原生 ETH）
  address toToken;
  uint256 fromTokenAmount;
  uint256 minReturnAmount;
  uint256 deadLine;
}

struct RouterPath {
  address[] mixAdapters;  // 使用的适配器合约
  address[] assetTo;      // 中间目标地址
  uint256[] rawData;      // 编码后的 swap 参数
  bytes[] extraData;      // 协议相关的附加数据
  uint256 fromToken;
}

struct ExtraData {
  CommissionInfo commissionInfo;
  TrimInfo trimInfo;
  Permit2Info permit2Info;
  address refundTo;
}
```

### 路由库 (`contracts/8/router/`)
全部路由逻辑都放在库（library）而非合约中，以便复用：
- **SmartSwapRouter** —— 在多条路径间拆分金额的批量执行
- **DagRouter** —— 用于复杂路由的有向无环图（DAG）路由
- **UnxswapRouter** / **UnxswapV3Router** —— Uniswap V2/V3 精确输入（exact input）
- **UnxswapExactOutRouter** / **UnxswapV3ExactOutRouter** —— 精确输出（exact output）swap

### 适配器系统 (`contracts/8/adapter/`)
190 个实现 `IAdapter` 接口的适配器合约。每个适配器以标准化的 swap 接口封装一个特定的 DEX 协议（Uniswap、Curve、Balancer、PancakeSwap 等）。

### 支撑库 (`contracts/8/libraries/`)
- **CommissionLib** —— 推荐返佣与手续费处理
- **TransferLib** —— 安全的 token 转账与原生 ETH 处理
- **ExtraDataLib** —— 解码 calldata 中的返佣、permit、退款信息
- **SafeERC20** —— 安全的 token 操作

### 授权系统
- **TokenApprove** / **TokenApproveProxy** —— 集中式授权管理

## 关键目录

```
contracts/8/           # 主 Solidity 合约
  adapter/            # 190 个 DEX 协议适配器
  interfaces/         # 协议接口 (IDexRouter, IAdapter 等)
  libraries/          # 工具库
  router/             # 路由库实现
src/
  deploy/             # Foundry 部署脚本（90+ 个）
  tests/              # Foundry 测试 (.t.sol 文件)
lib/                  # Forge 依赖 (forge-std, permit2)
```

## 多链支持

两个引擎都覆盖 30+ 条链（Ethereum、Arbitrum、Base、BSC、Optimism、Polygon、Scroll、zkSync、Monad 等）。Foundry（`foundry.toml`）负责编译/部署/测试；Hardhat（`hardhat.config.js networks`）负责 `scripts/` 下约 50 个 ethers 运维脚本（代理升级、所有权转移、approve-proxy 配置）。

> ⚠️ **`polyzkevm`(Polygon zkEVM)已于 2026-07-27 确认关闭停运,禁止再向该链部署或升级**。`deploy.config.js`/`verify_via_foundry.js` 里仍保留其配置条目,仅为了让 `deployed/polyzkevm/base.js` 里的历史地址记录保持可读,不代表该链仍可用。

### RPC 管理 —— 以 `.env` 为单一真相源

RPC 节点 URL **不再硬编码**在 `foundry.toml` 或 `hardhat.config.js` 中。两者都从名为 `<CHAIN>_RPC_URL` 的环境变量读取，统一来自 gitignore 的 `.env`：

- `foundry.toml [rpc_endpoints]` 使用 `"${<CHAIN>_RPC_URL}"` 占位替换（forge 会自动加载 `.env`）。供 `forge script --rpc-url <chain>` 和 `forge test` 使用。
- `hardhat.config.js networks` 使用 `process.env.<CHAIN>_RPC_URL || '<公共默认值>'`。回退值保证变量未设置时网络仍可用；含密钥的 `monad` 没有回退，必须来自 `.env`。
- 重叠链（eth、base、bsc、arb、op、polygon 等）在两个引擎间**共用同一个** `<CHAIN>_RPC_URL` 变量，因此改一处 `.env` 即同时生效。Hardhat 独有网络（测试网、`*_dev`、tron、zeta 等）使用各自独立变量。**注意：staging 不是独立链/网络**——它是部署"环境"维度（见下方"部署"章节),复用基链的 RPC,没有 `*_STG_RPC_URL`。

**规则：**
- 修改 RPC 只编辑 `.env` —— 切勿把字面 URL（尤其是带节点商 API key 的）重新写回 `foundry.toml` 或 `hardhat.config.js`。
- `.env` 已被 gitignore，存放含 key 的完整 URL。**禁止提交真实节点商 key** —— `.env.sample` 是提交进仓库的模板，只能放公共 endpoint / 空占位符。
- 新增一条链：在 `.env` 和 `.env.sample` 添加 `<CHAIN>_RPC_URL`，并在 `foundry.toml [rpc_endpoints]` 和/或 `hardhat.config.js networks` 引用它。（chainId 与浏览器 verifier 配置仍单独维护在 `scripts/deploy/verify_via_foundry.js` 的 `CHAINS` 中。）

## 部署 (Deployment)

部署生态集中在 `scripts/deploy/`(引擎、配置、记录、验证、ChainConfig 生成)。**唯一入口是 hardhat task `deploy-and-verify`**（注册于 `hardhat.config.js`，实现于 `tasks/deploy-and-verify.js`）。

### 两类部署:新链引导 vs DexRouter 版本部署(先分清楚再看以下细则)

本仓库的"部署"覆盖两类不同的工作,评估风险/读代码时不要混为一谈:

1. **新链部署(新链 onboarding)**:某条链**第一次**上线,需要部署全部基础设施(TokenApprove、TokenApproveProxy、WNativeRelayer、DexRouter 等)。引导期间部署者临时持有这些合约的 owner 权限用来跑通配置——这正是 `scripts/` 下 `03`–`23` 等编号运维脚本(`04_set_dex_approve_proxy.js`、`16_update_owner_tokenapprove.js`、`17_update_owner_approveproxy.js`、`18_change_owner.js`、`23_upgrade.js`、`41_transfer_owner.js` 等)**当前仍在用**的场景,不是历史遗留、无人使用的参考实现。配置完成后,ownership 转移给 OKX Boss 系统托管。真实例子:`0c42e825`(记录 ink 链地址)紧跟着 `dcad7d42`(转移 ink 链 TokenApprove/TokenApproveProxy/WNativeRelayer ownership)这一对提交。
2. **DexRouter 版本部署**:链**已完成引导**,只是发布一个新的 DexRouter 实现——即本章节下文描述的标准 `deploy-and-verify` 流程(prod/stg 正交)。

一旦某条链完成引导、ownership 转移给 Boss,这些编号运维脚本对该链就会失效(`onlyOwner` 因调用者不再是 owner 而 revert)——风险窗口只在"新链引导中、尚未转移 ownership"这段时间内,不是对已上线 prod/stg 链的持续性威胁。判断某条链是否还在引导窗口:看 `deployed/<chain>/` 下"记录地址"的提交之后是否紧跟着对应的"转移 ownership"提交。

```bash
npx hardhat deploy-and-verify --network arb                       # 模拟(不广播)
npx hardhat deploy-and-verify --network arb --broadcast           # prod 部署
npx hardhat deploy-and-verify --network arb --env stg --broadcast # staging 部署
```

编排 4 步:① 生成 ChainConfig → ② 部署(engine 分发)→ ③ 记录地址 → ④ 验证。**不改任何被跟踪的源码**,故无 save/restore。

### 链 × 环境(env)正交

部署目标 = **链 + 环境**,两者正交:
- **链**(`--network arb`):提供 chainId / rpc / verifier(`CHAINS` + `foundry.toml` + `.env`,定义一次)。
- **环境**(`--env prod|stg`,默认 prod):只决定用哪套地址。
- 地址文件:prod = `deployed/<chain>/base.js`,stg = `deployed/<chain>/stg.js`。
- staging 与 prod 是**同一条链**(同 chainId/rpc),只是不同的 DexRouter 实例/地址。**没有** `*_stg` 链、`*_STG_RPC_URL` 或 `_stg` rpc 别名。
- **为某条链加 staging = 新建 `deployed/<chain>/stg.js` 一个文件**,零配置复制。
- 解析器:`scripts/deploy/deployedEnv.js`(`ENV_FILE = {prod: base.js, stg: stg.js}`,大小写无关目录解析)。

### stg 与 prod 的架构差异(重要)

`deploy-and-verify` 的**部署流程对 stg/prod 完全相同**(同样 4 步、同样 engine,只换地址集),但**链上合约架构刻意不同**:

- **stg —— 可升级(代理)架构,为方便后端调试**:stg 跑的是 `Proxy + ProxyAdmin + impl` 的可升级结构。部署 `deploy-and-verify` 只产出**新的 impl**;让它生效是用 `ProxyAdmin.upgradeAndCall`/`upgrade` 把 impl **挂载到既有 DexRouter proxy**(`scripts/23_upgrade.js` 仅示意调用形态,**实际由 Boss 系统执行**,见下方"特权操作")。**proxy 地址不变**,后端无需换地址即可迭代。stg 的 `deployed/<chain>/stg.js` 里因此带有 `dexRouter`(proxy)、`newImpl`、`proxyAdmin` 等代理相关字段。
- **prod —— 不可升级架构,为合规**:prod 出于合规考量**不使用代理**,DexRouter 就是 impl 本身,调用方**直接与 impl 交互**。因此每次升级都是一个**全新地址的新实现**,生效方式不是 proxy upgrade,而是把新 impl **加入 `TokenApproveProxy` 白名单(`addProxy`)**(见下方"安全闸门")。

> 一句话:**stg 换实现靠升级 proxy(地址不变);prod 换实现靠新地址 + 白名单(无 proxy)。**

> ⚠️ **已知问题:stg 现存代理的管理面(owner/pause)已损坏,暂不修复(见 issue #220)。** 这些 stg 代理曾从旧 OZ 布局(`owner`@slot51)原地升级到 `PausableModuleV2` 布局(`owner`@slot0),`owner` 被旧存储残留错位污染成 `0x000…0001`(xlayer 为 0)。后果:**所有 `onlyOwner`(`transferOwnership`/`setReporter`/`pause`/`unpause`)失效、合约无法暂停(fail-open)**;swap 不受影响,故功能正常。**不要在这些 stg 代理上验证 owner/pause 流程**——要测管理函数请另部一个非代理实例(`new DexRouter(owner)`,构造函数正确设 owner)或用 Foundry 测试。**prod 不受影响**(非代理、构造函数直设 owner)。

### 特权操作经 OKX Boss 系统托管(不在本地脚本执行)

**本仓库只负责"产出并校验实现"——所有触及链上权限/资金的特权操作都不在本地脚本完成,而是通过 OKX 内部的 Boss 系统托管执行(多签/审批/审计齐全)。** 包括但不限于:

- **代理升级**:`ProxyAdmin.upgrade` / `upgradeAndCall`(stg 挂载新 impl)。
- **白名单配置**:`TokenApproveProxy.addProxy` / `removeProxy`(prod 上线闸门)。
- **所有权与角色**:`transferOwnership`、`setReporter`、`pause`/`unpause` 等 `onlyOwner` 操作。
- **其它管理面**:approve-proxy 绑定、owner 迁移等(对应 `scripts/` 下 `03`–`23` 等运维脚本所代表的动作)。

**对仓库与协作的影响:**
- `scripts/` 下那些运维脚本(`23_upgrade.js`、`04_set_dex_approve_proxy.js`、`*_approve_proxy.js` 等)**对已完成引导、ownership 已转移给 Boss 的链**而言,只是调用形态的参考实现,不是当前的执行路径。请勿假设"跑这个脚本"就能对这些链完成升级或配白名单;真正的执行入口在 Boss 系统。**但对尚在引导中的新链**,这些脚本就是实际在用的一次性配置工具(见上文"两类部署"),此时部署者仍持有 owner 权限。
- 因此 **不要在 MR 里附带"代跑特权操作"的脚本**作为落地手段;落地步骤应描述为"在 Boss 系统对 `<proxy>` 执行 `<调用>`,签名者为 ProxyAdmin owner",并给出调用所需参数(目标地址、selector、calldata、目标 owner 等)。
- 真实网络私钥也不在本地——本地缺 `PRIVATE_KEY` 时 `deploy-and-verify` 仅能做 impl 部署/校验,签名广播特权交易由 Boss 托管。

### 部署引擎(engine)抽象

`deploy_dex_imp.js` 是薄分发器:按链查 `scripts/deploy/deploy.config.js` 选 engine。
- **foundry**(默认):`forge script DeployDexRouter.s.sol --rpc-url <chain>`;`record`/`verify` 由它实现(`scripts/deploy/engines/foundryEngine.js`)。
- **hardhat-zksync**:zkSync 专用(标准 forge 不支持 zksolc);`capabilities.orchestrated=false`,`deploy-and-verify` 在部署前直接拒绝,zkSync 走独立流程。
- 加新部署工具 = 在 `engines/` 加一个 engine 文件 + 在 `deploy.config.js` 给目标链指过去。

### 按链常量与 ChainConfig

per-chain 常量(`_WETH`/`_APPROVE_PROXY`/`_PERMIT2`/`_FF_FACTORY`/gas limit)**不在被跟踪源码里硬编码**,而是由 `scripts/deploy/gen-chainconfig.js` 的 `generate(chain, env)` **生成**到 gitignored 的 `contracts/8/libraries/ChainConfig.sol`;`Constants.sol` import 并透传给所有使用者。
- 值来源:`deployed/<chain>/<env>.js`(地址)+ `CHAINS[chain].chainId` + `gas_limit/`。
- `chainConfigGen.js` 校验:必填项(`_WETH`/`_APPROVE_PROXY`)缺失或格式错**直接 fail-fast**,绝不静默注入零地址。
- 生成的 `_EXPECTED_CHAIN_ID` 在 `DeployDexRouter.s.sol` 里 `require(block.chainid == …)` **防串链**。
- 裸 checkout 由 `ensure-chainconfig.js`(npm `postinstall`)用默认值种子化,保证 `forge build` 可用。
- **新增一个 per-chain 常量**:在 `chainConfigGen.js` 加字段 + 各链 `base.js`/`stg.js` 填值 + 合约里使用。

### 校验已部署实现

`npx hardhat check-impl --chain <name|all> [--env stg]` —— 注入该(链,环境)常量 → 编译 → 与链上字节码逐字节对比(归一化掉链接库地址、immutable owner、尾部 metadata)。这是当前 DexRouter **唯一有效**的 impl 校验(常量是编译期 `constant`、非外部 getter,无法 eth_call)。

### 校验 ChainConfig 地址正确性(部署前)

`npx hardhat verify-chainconfig --chain <name|all> [--env stg]` —— 校验 per-chain 地址不只是"形状对",而是"真指向正确合约"。**根因**:`_WETH/_APPROVE_PROXY/_PERMIT2/_FF_FACTORY` 是烧进字节码的编译期 `constant`、无 getter,一个**笔误但合法**的地址会静默通过 `chainConfigGen.validateValues()`(只验非零/20字节)、部署后也无法 eth_call 复核 —— 错了"无感"。本命令补上身份层:

- **离线层(永远跑)**:`CHAINS[chain].chainId` 与 `base._CACHED_CHAIN_ID` 双源一致、EIP-55 校验和 → **硬失败**;permit2 是否规范地址、WETH 跨链复用 → 告警。
- **链上层(RPC 可达才跑)**:地址有无 code、**`tokenApproveProxy.tokenApprove()` == `base.tokenApprove`**(资金闸门交叉校验)、WETH `decimals/symbol`、Permit2 `DOMAIN_SEPARATOR`、RPC 上报 chainId 匹配 → 身份矛盾**硬失败**;**RPC 拒绝/连不上 → 降级告警(不阻断,不误杀)**。

实现:`scripts/deploy/verify-chainconfig.js`(核心)、`scripts/deploy/rpc.js`(共享 `rpcUrlFor`,check-impl 复用)。**已接入部署流水线**:`deploy-and-verify` 的 **Step 1b**(gen ChainConfig 之后、forge 部署之前)自动跑此校验,有 error 则**部署前 abort**;RPC 不可达只告警放行。

> 注:`_CACHED_CHAIN_ID` 仅为 `base.js` 记录字段、不被 gen/deploy 消费(链 ID 真相源是 `CHAINS`);它存在的价值就是给本校验做**双源交叉核对**——不一致通常意味着 `base.js` 是从别的链拷贝来的(其它地址也可能是错拷贝),故硬失败强制人工复核。

### 安全闸门

- **prod**:部署的是**全新不可升级实现**,部署 ≠ 上线;真正生效靠把它加入 **`TokenApproveProxy` 白名单(`addProxy`)**——这才是资金闸门。该操作**经 Boss 系统托管执行**(见上方"特权操作"),务必复核后再操作。
- **stg**:生效靠 `ProxyAdmin.upgrade`/`upgradeAndCall` 挂载到既有 proxy(见上方"stg 与 prod 的架构差异"),不走 `addProxy` 白名单这条 prod 闸门;同样**经 Boss 系统执行**。
- 真实网络缺 `PRIVATE_KEY` 时 hardhat/zksync **fail-fast**(不回退公开测试私钥)——签名广播特权交易由 Boss 托管,本地无私钥。

### exact-out 模块当前禁止部署(硬性要求)

**`contracts/exactout/`(`DexRouterExactOut` 及其 `router/`、`libraries/`)当前禁止任何新部署或升级**,不论 prod 还是 stg、不论是否 `--broadcast`。已上线的历史实例保持现状、不做变更,但**严禁再新增部署到任何链**,直到以下缺口被修复。这些缺口是 2026-07-24 对比 `1f2098b9`(审计修复完成的 v1.0.9 版本)与 `HEAD` 时发现的,发生在 `contracts/exactout/` 从 `DexRouter.sol` 拆分出来独立成模块之后,不属于原先审计范围内已修复的问题:

1. **无 ChainConfig 覆盖,链相关地址手工硬编码**:`contracts/exactout/libraries/Constants.sol` 的 `_WETH`/`_APPROVE_PROXY` 是硬编码的 Ethereum 主网地址(`_PERMIT2` 是跨链确定性地址,不受影响),完全没有接入 `gen-chainconfig.js`/生成的 `ChainConfig.sol`。每次向非-eth 链部署都依赖有人在本地手工改这个文件再编译部署,且从未把改动提交回仓库——已用链上字节码核实(比对 Arbitrum 已部署的 `newExactOutImpl`),证实确实存在"改了但没提交"的情况,git 里的源码与链上实际字节码对不上。
2. **无 check-impl 覆盖**:`tasks/check-impl.js` 明确写明"DexRouter only (ExactOut is a separate flow)"——exact-out 完全没有自动化字节码等价性校验,笔误/漏改地址不会被任何工具发现。
3. **与主模块 v1.0.10 安全特性不同步**:`contracts/exactout/libraries/CommonLib.sol` 的 `exeAdapter` 没有注入主模块(`contracts/8/libraries/CommonLib.sol`)v1.0.10 新增的 `DEX_ROUTER_CALLER_MARKER`(RFQ 反套利/防毒流的基础);`DexRouterExactOut.sol` 的 `version` 常量仍停留在 `"v1.0.9-multi-funding-mode"`,未跟进主模块的 `"v1.0.10-rfq-anti-arbitrage"`。
4. **部署路径本身脱离唯一入口**:exact-out 走独立的旧式脚本(`scripts/deploy/deploy_dex_exactout_imp.js` + `05_deploy_dex_exactout_proxy.js`/`30_check_const_exactout_impl.js`/`31_check_bytecode_exactout_Impl.js`/`43_check_status_exactout.js`/`44_transfer_exactout_owner.js`),不在 `deploy-and-verify` 的编排、`verify-chainconfig`、`check-impl` 校验范围内。

**解除本条禁令需全部满足**(由负责人核实后更新/移除本节):
- exact-out 接入 `gen-chainconfig.js`/`ChainConfig.sol` 生成流程,消灭手工改址;
- `check-impl` 扩展覆盖 exact-out 实现,或建立等价的字节码校验机制;
- 明确 `DEX_ROUTER_CALLER_MARKER` 是否需要补齐到 exact-out(或有明确的产品/安全评审记录说明为何不需要),版本号与主模块保持同步。

### 开源与地址记录规范(硬性要求)

**任何新部署的合约(dexRouter/newImpl,以及新引入的 library、proxy、proxyAdmin 等)都必须完成开源验证,不允许部署后停留在未开源状态。** 开源方式不限于浏览器原生 verifier(Etherscan 系列,参见 `scripts/deploy/verify_via_foundry.js` 的 `CHAINS` 配置)——**走 Sourcify 验证的场景同样视为开源完成的一种,不能因为走的是 Sourcify 而免于记录**(个别不支持标准 verifier/Sourcify 的链有各自的开源方式,例如 Tron 走 TronScan)。

开源完成后,必须把浏览器(或 Sourcify)上该地址的验证/详情链接,以行内注释形式记录在 `deployed/<chain>/<env>.js` 对应地址字段之后,例如:
```js
dexRouter: "0x...", // v1.0.10-rfq-anti-arbitrage; verified: https://arbiscan.io/address/0x...#code
newImpl: "0x...",   // verified via Sourcify: https://repo.sourcify.dev/contracts/full_match/<chainId>/0x.../
```
未记录验证链接的地址视为**部署未完成**,不得进入下一步(例如提交给 Boss 系统执行 `upgrade`/`addProxy`)。

## 开发约定 (Development Conventions)

### 可升级兼容性 —— 引入有状态组件的硬性要求

stg 的 DexRouter/ExactOut 是**可升级代理**(prod 非代理,见"部署"章节)。可升级代理的存储是持久且跨实现共享的,而实现的存储布局是一份**没有编译期/部署期强制校验的隐式契约**——升级即"用新 struct 重新解释旧字节"。一旦布局错位,新代码会**静默误读**旧存储(真实案例:`owner` 从 OZ slot51 挪到 slot0 后读到残留 `0x01`,管理面全废,见 issue #220)。

因此,**任何要进入可升级合约(proxy 后端)的有状态组件——尤其是被继承的 base 模块/mixin——在引入时必须证明可升级兼容,作为合并前的硬性评审项**。三条漂移轴各有对应要求:

- **来源(provenance)**:凡 proxy 场景需设置的状态,**必须用带守护的 `initialize()` 写入,严禁只依赖构造函数**(构造函数只写 impl 存储,proxy 永远读不到)。组件要么有 initializer,要么完全无状态(仅 `constant`)。
- **位置(position)**:布局必须 **append-only**。优先 **命名空间存储(ERC-7201,`keccak` 派生独立 slot)**,使存储与继承顺序解耦、天生抗碰撞;若用顺序布局,必须预留 `__gap` 且**禁止重排/改类型/换基类继承顺序**。
- **位置域(locus)**:**价值/路由相关配置一律 `constant`/`immutable`,不得放进可变存储**。这维持核心不变量——swap 价值/路由路径只读 calldata + 常量 + 外部调用、**零依赖可变存储**,从而保证任何布局漂移最多只伤控制面(owner/pause/reporter/重入锁),**绝不改变资金去向**(最坏是阻断/DoS/锁死管理面,可再升级恢复)。

### 升级闸门(防复发)

- 每个可升级合约提交 `forge inspect <contract> storageLayout` 快照入库,PR 自动 diff。
- 闸门校验的**不是**"布局是否相同",而是上述**核心不变量是否仍成立**(swap 入口除受控重入锁外不触碰可变存储、价值配置保持常量)。布局可漂移,爆炸半径必须锁在控制面。
- **storage layout 视为接口**,与 ABI 同等纳入评审/审计;新组件准入清单不满足则不得用于可升级合约(可改走 prod 的非代理直部署模式)。
- 一句话:**"能不能放进可升级合约"必须在引入时回答清楚,而不是部署后靠运气。**

## 依赖

- OpenZeppelin Contracts v4.5.0/v4.7.0（可升级版）
- Uniswap Permit2（基于签名的转账）
- Foundry (forge-std)
- ZkSync 部署工具 (hardhat-zksync)
