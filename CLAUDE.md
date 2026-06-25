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

### 特权操作经 OKX Boss 系统托管(不在本地脚本执行)

**本仓库只负责"产出并校验实现"——所有触及链上权限/资金的特权操作都不在本地脚本完成,而是通过 OKX 内部的 Boss 系统托管执行(多签/审批/审计齐全)。** 包括但不限于:

- **代理升级**:`ProxyAdmin.upgrade` / `upgradeAndCall`(stg 挂载新 impl)。
- **白名单配置**:`TokenApproveProxy.addProxy` / `removeProxy`(prod 上线闸门)。
- **所有权与角色**:`transferOwnership`、`setReporter`、`pause`/`unpause` 等 `onlyOwner` 操作。
- **其它管理面**:approve-proxy 绑定、owner 迁移等(对应 `scripts/` 下 `03`–`23` 等运维脚本所代表的动作)。

**对仓库与协作的影响:**
- `scripts/` 下那些运维脚本(`23_upgrade.js`、`04_set_dex_approve_proxy.js`、`*_approve_proxy.js` 等)是**调用形态的参考实现 / 历史产物,不是当前的执行路径**。请勿假设"跑这个脚本"就能完成升级或配白名单;真正的执行入口在 Boss 系统。
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

### 安全闸门

- **prod**:部署的是**全新不可升级实现**,部署 ≠ 上线;真正生效靠把它加入 **`TokenApproveProxy` 白名单(`addProxy`)**——这才是资金闸门。该操作**经 Boss 系统托管执行**(见上方"特权操作"),务必复核后再操作。
- **stg**:生效靠 `ProxyAdmin.upgrade`/`upgradeAndCall` 挂载到既有 proxy(见上方"stg 与 prod 的架构差异"),不走 `addProxy` 白名单这条 prod 闸门;同样**经 Boss 系统执行**。
- 真实网络缺 `PRIVATE_KEY` 时 hardhat/zksync **fail-fast**(不回退公开测试私钥)——签名广播特权交易由 Boss 托管,本地无私钥。

## 依赖

- OpenZeppelin Contracts v4.5.0/v4.7.0（可升级版）
- Uniswap Permit2（基于签名的转账）
- Foundry (forge-std)
- ZkSync 部署工具 (hardhat-zksync)
