# SecurityManager Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 部署一个 SecurityManager 合约，接管现有 TokenApproveProxy 的 ownership，实现白名单管理的角色拆分（多签可加可减、第三方安全公司只可减）以及链上可枚举白名单查询能力。交易链路完全不变。

**Architecture:** SecurityManager 是非可升级的独立合约，使用 OpenZeppelin AccessControl 实现 ADMIN_ROLE / SECURITY_ROLE 拆分，使用 EnumerableSet 镜像维护白名单。所有对老 Proxy 的 admin 操作都经过 SecurityManager 透传，老 Proxy 的代码、TokenApprove 的代码、DexRouter 等业务合约的代码都不动。

**Tech Stack:** Solidity 0.8.x，OpenZeppelin 4.9.6（contracts，非 contracts-upgradeable），Foundry 测试，Hardhat 部署脚本。

**Reference:** 完整设计文档：https://okg-block.sg.larksuite.com/wiki/WeM1w8z9xiftmBk59iXlbN2fg2d

---

## 测试策略

- **单元测试**：在 setUp 中部署一个真实的 `TokenApproveProxy` 实例（不用 mock），转移 ownership 给 SecurityManager，模拟生产环境的接入状态。这样测试覆盖 SecurityManager → 老 Proxy 的真实接口调用。
- **测试目录**：`src/tests/security-manager/SecurityManager.t.sol`
- **运行方式**：通过新增的 Foundry profile 隔离 — `FOUNDRY_PROFILE=security-manager forge test -vv`，避免和默认 adapter 测试目录冲突。

## 部署策略

- **合约部署**：Hardhat 脚本，构造函数一次性传入 `(oldProxy, admin, initialWhitelist[])`。
- **多链通用**：脚本读取一份每链配置文件（chain → {oldProxy, admin, initialWhitelist}），脚本本身链无关。
- **后续动作**：脚本仅完成部署。`oldProxy.transferOwnership(SecurityManager)` 和 `grantRole(SECURITY_ROLE, ...)` 由多签在合约管理平台手动发起，**不放入脚本**（避免脚本持有任何敏感权限）。

## 测试约定（适用于 Task 2 起所有测试）

在 Task 2 开发过程中遇到了几个 toolchain 相关的坑，统一在此说明，后续 Task 测试代码默认遵守这些约定。

**约定 1 — 文件级 solhint 关闭 `func-name-mixedcase`**

测试文件顶部（pragma 后）加一行：

```solidity
// solhint-disable func-name-mixedcase
```

理由：Foundry 标准测试命名 `test_Foo_Bar` 是 snake_case + 段内 camelCase 的混合，与 solhint:recommended 的 `func-name-mixedcase` 规则冲突。整个项目（包括 `src/tests/adapter/`）都是这个命名约定，文件级压制是统一做法。

**约定 2 — Event 在测试合约里本地声明**

不要使用 `emit ContractName.EventName(...)` 这种合约限定 emit。

```solidity
contract SecurityManagerTest is Test {
    event ProxyAdded(address indexed proxy);    // 本地声明
    event ProxyRemoved(address indexed proxy);  // 本地声明

    // ...

    function test_X_EmitsEvent() public {
        vm.expectEmit(true, false, false, true);
        emit ProxyAdded(addr);   // 不限定，直接用本地声明
        // 触发实际 emit 的调用
    }
}
```

理由：`emit ContractName.EventName(...)` 语法需要 solc ≥ 0.8.21，本项目 pinned 在 0.8.17。Foundry 的 `vm.expectEmit` 通过 topic hash 匹配，topic hash 由签名决定与声明位置无关，本地声明完全等价。

**约定 3 — `vm.expectEmit` 第四个 flag 设为 `true`**

```solidity
vm.expectEmit(true, false, false, true);
//            ↑                   ↑
//            check topic1        check non-indexed data
```

理由：即使 event 当前没有非索引字段，未来加字段时 `checkData=true` 让测试自动验证；`false` 会让回归静默通过。

**约定 4 — `vm.prank` 之前 cache 任何 view-getter 调用**

`vm.prank` 只覆盖**下一次外部调用**。如果下一次调用是 view getter（例如 `sm.SECURITY_ROLE()`），prank 会被 getter 消耗，真正想 prank 的目标函数会以默认 sender 运行。

**错误**：

```solidity
vm.prank(MULTISIG);
sm.grantRole(sm.SECURITY_ROLE(), SECURITY_CO);
//           └── 这次外部调用消耗掉 prank
//                 grantRole 实际以 test contract 身份运行 → 失败
```

**正确**：

```solidity
// Cache the role getter before vm.prank: the getter is the next external call
// and would otherwise consume the prank, leaving grantRole to run as the test contract.
bytes32 securityRole = sm.SECURITY_ROLE();
vm.prank(MULTISIG);
sm.grantRole(securityRole, SECURITY_CO);
```

如果 cache 不便（getter 返回 struct/array），用 `vm.startPrank/stopPrank` 包住整段。

---

## Task 0: 准备测试环境

**Files:**
- Modify: `foundry.toml`
- Create: `src/tests/security-manager/.gitkeep`

**Step 1: 创建测试目录**

```bash
mkdir -p src/tests/security-manager
touch src/tests/security-manager/.gitkeep
```

**Step 2: 在 foundry.toml 末尾追加专用 profile**

```toml
[profile.security-manager]
src = "contracts/8"
out = "artifacts"
test = "src/tests/security-manager"
libs = ["node_modules", "lib"]
optimizer = true
optimizer_runs = 1
remappings = [
    "@openzeppelin/=node_modules/@openzeppelin/",
    "@dex/=contracts/8/",
]
evm_version = "london"
fs_permissions = [{access = "read-write", path = "./"}]
```

**Step 3: 验证 profile 可识别**

Run: `FOUNDRY_PROFILE=security-manager forge build`
Expected: 编译现有 `contracts/8/` 内合约成功，无报错。

**Step 4: 提交**

```bash
git add foundry.toml src/tests/security-manager/.gitkeep
git commit -m "chore(security-manager): add foundry profile and test dir"
```

---

## Task 1: 定义 ITokenApproveProxyAdmin 接口

**Files:**
- Create: `contracts/8/interfaces/ITokenApproveProxyAdmin.sol`

**Step 1: 写接口（包含 SecurityManager 需要调用的所有老 Proxy 函数）**

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ITokenApproveProxyAdmin {
    function addProxy(address _newProxy) external;
    function removeProxy(address _oldProxy) external;
    function setTokenApprove(address _tokenApprove) external;
    function transferOwnership(address newOwner) external;
    function isAllowedProxy(address _proxy) external view returns (bool);
    function tokenApprove() external view returns (address);
    function owner() external view returns (address);
}
```

**Step 2: 编译验证**

Run: `FOUNDRY_PROFILE=security-manager forge build`
Expected: 编译成功。

**Step 3: 提交**

```bash
git add contracts/8/interfaces/ITokenApproveProxyAdmin.sol
git commit -m "feat(security-manager): add ITokenApproveProxyAdmin interface"
```

---

## Task 2: SecurityManager 骨架 + 构造函数

**Files:**
- Create: `contracts/8/SecurityManager.sol`
- Create: `src/tests/security-manager/SecurityManager.t.sol`

**Step 1: 写测试 — constructor 行为**

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// solhint-disable func-name-mixedcase

import "forge-std/Test.sol";
import "@dex/SecurityManager.sol";
import "@dex/TokenApproveProxy.sol";

contract SecurityManagerTest is Test {
    TokenApproveProxy oldProxy;
    SecurityManager sm;

    address constant MULTISIG = address(0xA1);
    address constant SECURITY_CO = address(0xB1);
    address constant DEX_ROUTER = address(0xCAFE);
    address constant XBRIDGE = address(0xBEEF);

    function setUp() public virtual {
        oldProxy = new TokenApproveProxy();
        oldProxy.initialize();
        oldProxy.addProxy(DEX_ROUTER);
        oldProxy.addProxy(XBRIDGE);

        address[] memory initial = new address[](2);
        initial[0] = DEX_ROUTER;
        initial[1] = XBRIDGE;
        sm = new SecurityManager(address(oldProxy), MULTISIG, initial);

        oldProxy.transferOwnership(address(sm));
    }

    function test_Constructor_StoresProxyAddress() public {
        assertEq(address(sm.tokenApproveProxy()), address(oldProxy));
    }

    function test_Constructor_GrantsAdminRole() public {
        assertTrue(sm.hasRole(sm.DEFAULT_ADMIN_ROLE(), MULTISIG));
    }

    function test_Constructor_InitializesWhitelistMirror() public {
        assertEq(sm.whitelistLength(), 2);
        assertTrue(sm.whitelistContains(DEX_ROUTER));
        assertTrue(sm.whitelistContains(XBRIDGE));
    }

    function test_Constructor_RevertsOnZeroProxy() public {
        address[] memory empty = new address[](0);
        vm.expectRevert(bytes("SM: zero proxy"));
        new SecurityManager(address(0), MULTISIG, empty);
    }

    function test_Constructor_RevertsOnZeroAdmin() public {
        address[] memory empty = new address[](0);
        vm.expectRevert(bytes("SM: zero admin"));
        new SecurityManager(address(oldProxy), address(0), empty);
    }

    function test_Constructor_RevertsOnZeroInInitialWhitelist() public {
        address[] memory initial = new address[](2);
        initial[0] = DEX_ROUTER;
        initial[1] = address(0);
        vm.expectRevert(bytes("SM: zero in initial"));
        new SecurityManager(address(oldProxy), MULTISIG, initial);
    }

    function test_Constructor_RevertsIfNotAllowedOnProxy() public {
        // 0xCAFE is on the proxy (added in setUp); 0xDEAD is not.
        address[] memory initial = new address[](2);
        initial[0] = DEX_ROUTER;
        initial[1] = address(0xDEAD);
        vm.expectRevert(bytes("SM: not allowed on proxy"));
        new SecurityManager(address(oldProxy), MULTISIG, initial);
    }
}
```

**Step 2: 跑测试，确认全部失败（编译错误，SecurityManager 还不存在）**

Run: `FOUNDRY_PROFILE=security-manager forge test -vv`
Expected: 编译失败，`SecurityManager` not found。

**Step 3: 实现 SecurityManager 骨架**

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./interfaces/ITokenApproveProxyAdmin.sol";

contract SecurityManager is AccessControl {
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 public constant SECURITY_ROLE = keccak256("SECURITY_ROLE");

    ITokenApproveProxyAdmin public immutable tokenApproveProxy;
    EnumerableSet.AddressSet private _whitelist;

    constructor(
        address _tokenApproveProxy,
        address _admin,
        address[] memory _initialWhitelist
    ) {
        require(_tokenApproveProxy != address(0), "SM: zero proxy");
        require(_admin != address(0), "SM: zero admin");
        tokenApproveProxy = ITokenApproveProxyAdmin(_tokenApproveProxy);
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        for (uint256 i = 0; i < _initialWhitelist.length; i++) {
            require(_initialWhitelist[i] != address(0), "SM: zero in initial");
            // Use the local parameter, not the immutable state var (immutables are not readable in constructor).
            require(
                ITokenApproveProxyAdmin(_tokenApproveProxy).isAllowedProxy(_initialWhitelist[i]),
                "SM: not allowed on proxy"
            );
            _whitelist.add(_initialWhitelist[i]);
        }
    }

    function whitelistLength() external view returns (uint256) {
        return _whitelist.length();
    }

    function whitelistContains(address _proxy) external view returns (bool) {
        return _whitelist.contains(_proxy);
    }
}
```

**Step 4: 跑测试，确认全部通过**

Run: `FOUNDRY_PROFILE=security-manager forge test -vv`
Expected: 7/7 PASS。

**Step 5: 提交**

```bash
git add contracts/8/SecurityManager.sol src/tests/security-manager/SecurityManager.t.sol
git commit -m "feat(security-manager): scaffold contract with constructor"
```

**关于构造函数 invariant 的设计决策**

构造函数对 `_initialWhitelist[]` 做两层校验：

1. `require(_initialWhitelist[i] != address(0), ...)` — 与 Task 3 `addProxy` 的零地址校验对称，避免运行时入口比构造函数更严格的不一致状态。
2. `require(ITokenApproveProxyAdmin(_tokenApproveProxy).isAllowedProxy(_initialWhitelist[i]), ...)` — 防止"幽灵镜像条目"：如果某个地址在 `_initialWhitelist` 但不在老 Proxy 上，SM 的 `removeProxy` 会因镜像存在而通过，但 `tokenApproveProxy.removeProxy()` 在老 Proxy 上是 no-op（mapping 本就是 false），导致 SM 的镜像与老 Proxy 实际状态分叉。

这两个校验意味着 `initialWhitelist` 必须是「老 Proxy 现有白名单的子集」，没有冗余/前瞻空间。这是有意识的取舍：构造函数 fail-fast，避免部署后才发现配置错误。

---

## Task 3: addProxy（仅 ADMIN）

**Files:**
- Modify: `contracts/8/SecurityManager.sol`
- Modify: `src/tests/security-manager/SecurityManager.t.sol`

**Step 1: 追加测试**

注意：在测试合约 (`SecurityManagerTest`) 顶部、state vars 前添加一行本地 event 声明：

```solidity
event ProxyAdded(address indexed proxy);
```

理由：`emit SomeContract.EventName(...)` 这种合约限定的 emit 语法需要 solc ≥ 0.8.21，本项目 pinned 在 0.8.17，因此采用 Foundry 标准做法 — 测试合约里本地声明同名 event，topic hash 由签名决定与声明位置无关，`vm.expectEmit` 能匹配。

追加在测试合约里的测试函数：

```solidity
function test_AddProxy_ByAdmin_AddsToMirrorAndProxy() public {
    address newProxy = address(0xD1);
    vm.prank(MULTISIG);
    sm.addProxy(newProxy);

    assertTrue(sm.whitelistContains(newProxy));
    assertTrue(oldProxy.isAllowedProxy(newProxy));
}

function test_AddProxy_EmitsEvent() public {
    address newProxy = address(0xD2);
    // checkData=true 防止未来给 ProxyAdded 加非索引字段时测试静默通过
    vm.expectEmit(true, false, false, true);
    emit ProxyAdded(newProxy);
    vm.prank(MULTISIG);
    sm.addProxy(newProxy);
}

function test_AddProxy_ByNonAdmin_Reverts() public {
    address attacker = address(0xDEAD);
    vm.expectRevert();
    vm.prank(attacker);
    sm.addProxy(address(0xD3));
}

function test_AddProxy_BySecurityRole_Reverts() public {
    // Cache the role getter before vm.prank: the getter is the next external call
    // and would otherwise consume the prank, leaving grantRole to run as the test contract.
    bytes32 securityRole = sm.SECURITY_ROLE();
    vm.prank(MULTISIG);
    sm.grantRole(securityRole, SECURITY_CO);

    vm.expectRevert();
    vm.prank(SECURITY_CO);
    sm.addProxy(address(0xD4));
}

function test_AddProxy_Duplicate_Reverts() public {
    vm.prank(MULTISIG);
    vm.expectRevert(bytes("SM: already in whitelist"));
    sm.addProxy(DEX_ROUTER);
}

function test_AddProxy_ZeroAddress_Reverts() public {
    vm.prank(MULTISIG);
    vm.expectRevert(bytes("SM: zero address"));
    sm.addProxy(address(0));
}
```

**Step 2: 跑测试，确认失败**

Run: `FOUNDRY_PROFILE=security-manager forge test -vv --match-test test_AddProxy`
Expected: 6 个失败（addProxy 函数不存在）。

**Step 3: 实现 addProxy + Event**

在 SecurityManager 中追加：

```solidity
event ProxyAdded(address indexed proxy);

function addProxy(address _proxy) external onlyRole(DEFAULT_ADMIN_ROLE) {
    require(_proxy != address(0), "SM: zero address");
    // No isAllowedProxy() pre-check needed: this call is what causes the proxy entry.
    // Mirror-proxy parity holds by induction from the constructor's S4 invariant.
    require(_whitelist.add(_proxy), "SM: already in whitelist");
    tokenApproveProxy.addProxy(_proxy);
    emit ProxyAdded(_proxy);
}
```

**Step 4: 跑测试，确认通过**

Run: `FOUNDRY_PROFILE=security-manager forge test -vv --match-test test_AddProxy`
Expected: 6/6 PASS。

**Step 5: 提交**

```bash
git add contracts/8/SecurityManager.sol src/tests/security-manager/SecurityManager.t.sol
git commit -m "feat(security-manager): implement addProxy with admin-only access"
```

---

## Task 4: removeProxy（ADMIN 或 SECURITY）

**Files:**
- Modify: `contracts/8/SecurityManager.sol`
- Modify: `src/tests/security-manager/SecurityManager.t.sol`

**Step 1: 追加测试**

注意：在测试合约顶部 event 区，加 `event ProxyRemoved(address indexed proxy);` 本地声明（参考"测试约定 2"）。

```solidity
function _grantSecurityRole() internal {
    // Cache the role getter before vm.prank: the getter is the next external call
    // and would otherwise consume the prank, leaving grantRole to run as the test contract.
    bytes32 securityRole = sm.SECURITY_ROLE();
    vm.prank(MULTISIG);
    sm.grantRole(securityRole, SECURITY_CO);
}

function test_RemoveProxy_ByAdmin() public {
    vm.prank(MULTISIG);
    sm.removeProxy(DEX_ROUTER);
    assertFalse(sm.whitelistContains(DEX_ROUTER));
    assertFalse(oldProxy.isAllowedProxy(DEX_ROUTER));
}

function test_RemoveProxy_BySecurityRole() public {
    _grantSecurityRole();
    vm.prank(SECURITY_CO);
    sm.removeProxy(DEX_ROUTER);
    assertFalse(sm.whitelistContains(DEX_ROUTER));
    assertFalse(oldProxy.isAllowedProxy(DEX_ROUTER));
}

function test_RemoveProxy_EmitsEvent() public {
    vm.expectEmit(true, false, false, true);
    emit ProxyRemoved(DEX_ROUTER);
    vm.prank(MULTISIG);
    sm.removeProxy(DEX_ROUTER);
}

function test_RemoveProxy_ByRandomEOA_Reverts() public {
    vm.expectRevert(bytes("SM: unauthorized"));
    vm.prank(address(0xDEAD));
    sm.removeProxy(DEX_ROUTER);
}

function test_RemoveProxy_NotInWhitelist_Reverts() public {
    vm.prank(MULTISIG);
    vm.expectRevert(bytes("SM: not in whitelist"));
    sm.removeProxy(address(0xDEAD));
}

function test_RemoveProxy_AfterRevoke_Reverts() public {
    _grantSecurityRole();
    // Cache before vm.prank for the same reason as in _grantSecurityRole.
    bytes32 securityRole = sm.SECURITY_ROLE();
    vm.prank(MULTISIG);
    sm.revokeRole(securityRole, SECURITY_CO);

    vm.expectRevert(bytes("SM: unauthorized"));
    vm.prank(SECURITY_CO);
    sm.removeProxy(DEX_ROUTER);
}
```

**Step 2: 跑测试，确认失败**

Run: `FOUNDRY_PROFILE=security-manager forge test -vv --match-test test_RemoveProxy`
Expected: 6 个失败。

**Step 3: 实现 modifier + removeProxy**

```solidity
event ProxyRemoved(address indexed proxy);

modifier onlyAdminOrSecurity() {
    require(
        hasRole(DEFAULT_ADMIN_ROLE, msg.sender) || hasRole(SECURITY_ROLE, msg.sender),
        "SM: unauthorized"
    );
    _;
}

function removeProxy(address _proxy) external onlyAdminOrSecurity {
    require(_whitelist.remove(_proxy), "SM: not in whitelist");
    tokenApproveProxy.removeProxy(_proxy);
    emit ProxyRemoved(_proxy);
}
```

**Step 4: 跑测试**

Run: `FOUNDRY_PROFILE=security-manager forge test -vv --match-test test_RemoveProxy`
Expected: 6/6 PASS。

**Step 5: 提交**

```bash
git add contracts/8/SecurityManager.sol src/tests/security-manager/SecurityManager.t.sol
git commit -m "feat(security-manager): implement removeProxy with role-based access"
```

---

## Task 5: removeProxies（批量）

**Files:**
- Modify: `contracts/8/SecurityManager.sol`
- Modify: `src/tests/security-manager/SecurityManager.t.sol`

**Step 1: 追加测试**

```solidity
function test_RemoveProxies_ByAdmin_RemovesAll() public {
    address[] memory list = new address[](2);
    list[0] = DEX_ROUTER;
    list[1] = XBRIDGE;

    vm.prank(MULTISIG);
    sm.removeProxies(list);

    assertFalse(sm.whitelistContains(DEX_ROUTER));
    assertFalse(sm.whitelistContains(XBRIDGE));
    assertEq(sm.whitelistLength(), 0);
}

function test_RemoveProxies_BySecurityRole() public {
    _grantSecurityRole();
    address[] memory list = new address[](2);
    list[0] = DEX_ROUTER;
    list[1] = XBRIDGE;

    vm.prank(SECURITY_CO);
    sm.removeProxies(list);

    assertEq(sm.whitelistLength(), 0);
    assertFalse(oldProxy.isAllowedProxy(DEX_ROUTER));
    assertFalse(oldProxy.isAllowedProxy(XBRIDGE));
}

function test_RemoveProxies_SkipsNonExistent() public {
    address[] memory list = new address[](3);
    list[0] = DEX_ROUTER;
    list[1] = address(0xDEAD); // not in whitelist
    list[2] = XBRIDGE;

    vm.recordLogs();
    vm.prank(MULTISIG);
    sm.removeProxies(list); // should not revert

    assertEq(sm.whitelistLength(), 0);

    // 负断言：被跳过的地址不能产生 ProxyRemoved 事件
    Vm.Log[] memory entries = vm.getRecordedLogs();
    bytes32 sig = keccak256("ProxyRemoved(address)");
    uint256 emittedCount = 0;
    bool sawDexRouter = false;
    bool sawXbridge = false;
    bool sawDead = false;
    for (uint256 i = 0; i < entries.length; i++) {
        if (entries[i].topics.length > 0 && entries[i].topics[0] == sig) {
            emittedCount++;
            address indexedAddr = address(uint160(uint256(entries[i].topics[1])));
            if (indexedAddr == DEX_ROUTER) sawDexRouter = true;
            if (indexedAddr == XBRIDGE) sawXbridge = true;
            if (indexedAddr == address(0xDEAD)) sawDead = true;
        }
    }
    assertEq(emittedCount, 2, "expected exactly 2 ProxyRemoved events");
    assertTrue(sawDexRouter, "DEX_ROUTER event missing");
    assertTrue(sawXbridge, "XBRIDGE event missing");
    assertFalse(sawDead, "0xDEAD must not produce ProxyRemoved event");
}

function test_RemoveProxies_ByRandomEOA_Reverts() public {
    address[] memory list = new address[](1);
    list[0] = DEX_ROUTER;

    vm.expectRevert(bytes("SM: unauthorized"));
    vm.prank(address(0xDEAD));
    sm.removeProxies(list);
}

function test_RemoveProxies_EmitsEventPerRemoval() public {
    address[] memory list = new address[](2);
    list[0] = DEX_ROUTER;
    list[1] = XBRIDGE;

    // 锁定每个被移除的地址各发一条 ProxyRemoved 事件，
    // 防止未来重构合并成 batch event 而破坏 indexer。
    vm.expectEmit(true, false, false, true);
    emit ProxyRemoved(DEX_ROUTER);
    vm.expectEmit(true, false, false, true);
    emit ProxyRemoved(XBRIDGE);

    vm.prank(MULTISIG);
    sm.removeProxies(list);
}
```

**Step 2: 跑测试，确认失败**

Run: `FOUNDRY_PROFILE=security-manager forge test -vv --match-test test_RemoveProxies`
Expected: 5 个失败（`removeProxies` 函数不存在）。

**Step 3: 实现 removeProxies**

```solidity
function removeProxies(address[] calldata _proxies) external onlyAdminOrSecurity {
    for (uint256 i = 0; i < _proxies.length; i++) {
        if (_whitelist.remove(_proxies[i])) {
            tokenApproveProxy.removeProxy(_proxies[i]);
            emit ProxyRemoved(_proxies[i]);
        }
    }
}
```

**Step 4: 跑测试**

Run: `FOUNDRY_PROFILE=security-manager forge test -vv --match-test test_RemoveProxies`
Expected: 5/5 PASS。

**Step 5: 提交**

```bash
git add contracts/8/SecurityManager.sol src/tests/security-manager/SecurityManager.t.sol
git commit -m "feat(security-manager): implement removeProxies batch with skip-on-missing"
```

---

## Task 6: 白名单查询接口（getWhitelist / whitelistAt）

**Files:**
- Modify: `contracts/8/SecurityManager.sol`
- Modify: `src/tests/security-manager/SecurityManager.t.sol`

**Step 1: 追加测试**

```solidity
function test_GetWhitelist_ReturnsAll() public {
    address[] memory list = sm.getWhitelist();
    assertEq(list.length, 2);
    // EnumerableSet 不保证顺序，使用 contains 校验
    assertTrue(sm.whitelistContains(list[0]));
    assertTrue(sm.whitelistContains(list[1]));
}

function test_WhitelistAt_ReturnsAddressByIndex() public {
    address a0 = sm.whitelistAt(0);
    address a1 = sm.whitelistAt(1);
    assertTrue(a0 == DEX_ROUTER || a0 == XBRIDGE);
    assertTrue(a1 == DEX_ROUTER || a1 == XBRIDGE);
    assertTrue(a0 != a1);
}

function test_WhitelistAt_OutOfBounds_Reverts() public {
    vm.expectRevert();
    sm.whitelistAt(99);
}
```

**Step 2: 跑测试**

Run: `FOUNDRY_PROFILE=security-manager forge test -vv --match-test test_GetWhitelist`
Run: `FOUNDRY_PROFILE=security-manager forge test -vv --match-test test_WhitelistAt`
Expected: getWhitelist 失败（函数不存在），whitelistAt 失败（函数不存在）。

**Step 3: 实现查询函数**

```solidity
function getWhitelist() external view returns (address[] memory) {
    return _whitelist.values();
}

function whitelistAt(uint256 _index) external view returns (address) {
    return _whitelist.at(_index);
}
```

**Step 4: 跑测试**

Run: `FOUNDRY_PROFILE=security-manager forge test -vv`
Expected: 全部 PASS。

**Step 5: 提交**

```bash
git add contracts/8/SecurityManager.sol src/tests/security-manager/SecurityManager.t.sol
git commit -m "feat(security-manager): add getWhitelist and whitelistAt query"
```

---

## Task 7: setTokenApprove（ADMIN）

**Files:**
- Modify: `contracts/8/SecurityManager.sol`
- Modify: `src/tests/security-manager/SecurityManager.t.sol`

**Step 1: 追加测试**

注意：在测试合约顶部 event 声明区，加 `event TokenApproveChanged(address newTokenApprove);` 本地声明（参考"测试约定 2"）。该 event 的真实声明在 TokenApproveProxy.sol 上 — 本地声明是为了用 5-arg 形式的 `vm.expectEmit` 校验事件来自老 Proxy 而非 SM。

```solidity
function test_SetTokenApprove_ByAdmin() public {
    address newTokenApprove = address(0xE1);
    vm.prank(MULTISIG);
    sm.setTokenApprove(newTokenApprove);
    assertEq(oldProxy.tokenApprove(), newTokenApprove);
}

function test_SetTokenApprove_BySecurityRole_Reverts() public {
    _grantSecurityRole();
    vm.expectRevert();
    vm.prank(SECURITY_CO);
    sm.setTokenApprove(address(0xE2));
}

function test_SetTokenApprove_ByRandomEOA_Reverts() public {
    vm.expectRevert();
    vm.prank(address(0xDEAD));
    sm.setTokenApprove(address(0xE3));
}

function test_SetTokenApprove_ZeroAddress_Reverts() public {
    vm.prank(MULTISIG);
    vm.expectRevert(bytes("SM: zero address"));
    sm.setTokenApprove(address(0));
}

function test_SetTokenApprove_EmitsUnderlyingEvent() public {
    address newTokenApprove = address(0xE9);
    // SM 不发自己的 event，依赖底层 TokenApproveProxy 的 TokenApproveChanged。
    // 5-arg expectEmit 锁定事件来自 oldProxy 而非 sm。
    vm.expectEmit(false, false, false, true, address(oldProxy));
    emit TokenApproveChanged(newTokenApprove);
    vm.prank(MULTISIG);
    sm.setTokenApprove(newTokenApprove);
}
```

**Step 2: 跑测试，确认失败**

Run: `FOUNDRY_PROFILE=security-manager forge test -vv --match-test test_SetTokenApprove`
Expected: 5 失败。

**Step 3: 实现**

```solidity
function setTokenApprove(address _tokenApprove) external onlyRole(DEFAULT_ADMIN_ROLE) {
    require(_tokenApprove != address(0), "SM: zero address");
    tokenApproveProxy.setTokenApprove(_tokenApprove);
}
```

零地址保护原因：与 constructor S3、addProxy、transferTokenApproveProxyOwnership 的零地址校验保持对称；`setTokenApprove` 是改 claimTokens 转发目标的关键路径，多签误填 0 会直接 brick 整条转账链路。

**Step 4: 跑测试**

Run: `FOUNDRY_PROFILE=security-manager forge test -vv --match-test test_SetTokenApprove`
Expected: 5/5 PASS。

**Step 5: 提交**

```bash
git add contracts/8/SecurityManager.sol src/tests/security-manager/SecurityManager.t.sol
git commit -m "feat(security-manager): implement setTokenApprove pass-through"
```

---

## Task 8: 逃生舱 transferTokenApproveProxyOwnership

**Files:**
- Modify: `contracts/8/SecurityManager.sol`
- Modify: `src/tests/security-manager/SecurityManager.t.sol`

**Step 1: 追加测试**

```solidity
function test_TransferProxyOwnership_ByAdmin() public {
    address newOwner = address(0xF1);
    vm.prank(MULTISIG);
    sm.transferTokenApproveProxyOwnership(newOwner);
    assertEq(oldProxy.owner(), newOwner);
}

function test_TransferProxyOwnership_BySecurityRole_Reverts() public {
    _grantSecurityRole();
    vm.expectRevert();
    vm.prank(SECURITY_CO);
    sm.transferTokenApproveProxyOwnership(address(0xF2));
}

function test_TransferProxyOwnership_ZeroAddress_Reverts() public {
    vm.prank(MULTISIG);
    vm.expectRevert(bytes("SM: zero address"));
    sm.transferTokenApproveProxyOwnership(address(0));
}

function test_TransferProxyOwnership_PreventsLaterAdminCalls() public {
    address newOwner = address(0xF9);
    vm.prank(MULTISIG);
    sm.transferTokenApproveProxyOwnership(newOwner);

    // 转移完所有权后，SM 不再是老 Proxy 的 owner，
    // 任何透传 admin 调用必须在底层 onlyOwner 检查处 revert。
    // 锁定 escape hatch 的不可逆语义。
    vm.prank(MULTISIG);
    vm.expectRevert(bytes("Ownable: caller is not the owner"));
    sm.addProxy(address(0xAB));
}
```

**Step 2: 跑测试，确认失败**

Run: `FOUNDRY_PROFILE=security-manager forge test -vv --match-test test_TransferProxyOwnership`
Expected: 4 失败。

**Step 3: 实现**

```solidity
function transferTokenApproveProxyOwnership(address _newOwner) external onlyRole(DEFAULT_ADMIN_ROLE) {
    require(_newOwner != address(0), "SM: zero address");
    tokenApproveProxy.transferOwnership(_newOwner);
}
```

**Step 4: 跑测试**

Run: `FOUNDRY_PROFILE=security-manager forge test -vv --match-test test_TransferProxyOwnership`
Expected: 4/4 PASS。

**Step 5: 提交**

```bash
git add contracts/8/SecurityManager.sol src/tests/security-manager/SecurityManager.t.sol
git commit -m "feat(security-manager): add transferTokenApproveProxyOwnership escape hatch"
```

---

## Task 9: 全量回归 + 边界场景补充

**Files:**
- Modify: `src/tests/security-manager/SecurityManager.t.sol`

**Step 1: 追加边界与回归测试**

```solidity
function test_Integration_AddRemoveAddSequence() public {
    address proxyAddr = address(0xAA);

    vm.prank(MULTISIG);
    sm.addProxy(proxyAddr);
    assertTrue(oldProxy.isAllowedProxy(proxyAddr));

    vm.prank(MULTISIG);
    sm.removeProxy(proxyAddr);
    assertFalse(oldProxy.isAllowedProxy(proxyAddr));

    vm.prank(MULTISIG);
    sm.addProxy(proxyAddr); // should succeed again
    assertTrue(oldProxy.isAllowedProxy(proxyAddr));
}

function test_Integration_MirrorAndProxyStayInSync() public {
    // 任意一组操作后，镜像与老 Proxy 状态都必须一致
    address[] memory pool = new address[](3);
    pool[0] = address(0xA1A1);
    pool[1] = address(0xA2A2);
    pool[2] = address(0xA3A3);

    vm.startPrank(MULTISIG);
    sm.addProxy(pool[0]);
    sm.addProxy(pool[1]);
    sm.addProxy(pool[2]);

    address[] memory removeList = new address[](2);
    removeList[0] = pool[0];
    removeList[1] = DEX_ROUTER;
    sm.removeProxies(removeList);
    vm.stopPrank();

    address[] memory mirror = sm.getWhitelist();
    for (uint256 i = 0; i < mirror.length; i++) {
        assertTrue(oldProxy.isAllowedProxy(mirror[i]), "mirror leak");
    }
    // 镜像之外应不在老 Proxy
    assertFalse(oldProxy.isAllowedProxy(pool[0]));
    assertFalse(oldProxy.isAllowedProxy(DEX_ROUTER));

    // Length invariant: 起始 {DEX_ROUTER, XBRIDGE} = 2，加 pool[0..2] = +3 → 5，
    // 然后 removeProxies 移除 {pool[0], DEX_ROUTER} = -2 → 3。
    assertEq(mirror.length, 3);

    // 反方向 parity: 已知幸存者必须既在老 Proxy 上又在镜像里。
    assertTrue(oldProxy.isAllowedProxy(XBRIDGE));
    assertTrue(oldProxy.isAllowedProxy(pool[1]));
    assertTrue(oldProxy.isAllowedProxy(pool[2]));
    assertTrue(sm.whitelistContains(XBRIDGE));
    assertTrue(sm.whitelistContains(pool[1]));
    assertTrue(sm.whitelistContains(pool[2]));
}

function test_Empty_InitialWhitelist_Works() public {
    TokenApproveProxy freshProxy = new TokenApproveProxy();
    freshProxy.initialize();
    address[] memory empty = new address[](0);
    SecurityManager freshSm = new SecurityManager(address(freshProxy), MULTISIG, empty);
    assertEq(freshSm.whitelistLength(), 0);
}

function test_GetWhitelist_EmptyAfterRemoveAll() public {
    address[] memory list = new address[](2);
    list[0] = DEX_ROUTER;
    list[1] = XBRIDGE;
    vm.prank(MULTISIG);
    sm.removeProxies(list);

    assertEq(sm.whitelistLength(), 0);
    assertEq(sm.getWhitelist().length, 0);
    vm.expectRevert();
    sm.whitelistAt(0);
}
```

**Step 2: 跑全部测试**

Run: `FOUNDRY_PROFILE=security-manager forge test -vv`
Expected: 全部 PASS（应该 25+ 用例）。

**Step 3: 提交**

```bash
git add src/tests/security-manager/SecurityManager.t.sol
git commit -m "test(security-manager): add integration and edge-case tests"
```

---

## Task 10: Hardhat 部署脚本 + 多链配置

**Files:**
- Create: `scripts/32_deploy_security_manager.js`
- Create: `scripts/security-manager-config.json`

**Step 1: 创建多链配置文件**

```json
{
  "_comment": "每条链独立填写。initialWhitelist 必须基于链下基线审计的结果填入；initialWhitelist 与该链上老 Proxy 实际白名单必须一致。",
  "eth": {
    "tokenApproveProxy": "0x70cBb871E8f30Fc8Ce23609E9E0Ea87B6b222F58",
    "admin": "<填多签地址>",
    "initialWhitelist": []
  },
  "bsc": {
    "tokenApproveProxy": "<填该链老 Proxy 地址>",
    "admin": "<填多签地址>",
    "initialWhitelist": []
  }
}
```

**Step 2: 写部署脚本**

```javascript
const { ethers, network } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  const configPath = path.join(__dirname, "security-manager-config.json");
  const config = JSON.parse(fs.readFileSync(configPath, "utf8"));

  const chainConfig = config[network.name];
  if (!chainConfig) {
    throw new Error(`No config for network: ${network.name}`);
  }

  const { tokenApproveProxy, admin, initialWhitelist } = chainConfig;
  if (!tokenApproveProxy || tokenApproveProxy.startsWith("<")) {
    throw new Error(`tokenApproveProxy not configured for ${network.name}`);
  }
  if (!admin || admin.startsWith("<")) {
    throw new Error(`admin not configured for ${network.name}`);
  }
  if (!Array.isArray(initialWhitelist) || initialWhitelist.length === 0) {
    throw new Error(`initialWhitelist empty for ${network.name}; baseline audit required`);
  }

  console.log(`Deploying SecurityManager on ${network.name}`);
  console.log(`  tokenApproveProxy: ${tokenApproveProxy}`);
  console.log(`  admin (multisig):  ${admin}`);
  console.log(`  initialWhitelist:  ${initialWhitelist.length} addresses`);

  const SecurityManager = await ethers.getContractFactory("SecurityManager");
  const sm = await SecurityManager.deploy(tokenApproveProxy, admin, initialWhitelist);
  await sm.deployed();

  console.log(`SecurityManager deployed at: ${sm.address}`);
  console.log("");
  console.log("=== Manual follow-up actions (via multisig) ===");
  console.log(`1. ${tokenApproveProxy}.transferOwnership(${sm.address})`);
  console.log(`2. ${sm.address}.grantRole(SECURITY_ROLE, <安全公司地址>)`);
  console.log("");
  console.log("=== Verification ===");
  console.log(`Length:    ${(await sm.whitelistLength()).toString()}`);
  console.log(`Whitelist: ${JSON.stringify(await sm.getWhitelist())}`);
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
```

**Step 3: 编译验证**

Run: `npx hardhat compile`
Expected: 编译成功，artifacts 中能找到 SecurityManager。

**Step 4: 在测试网（如果有）做 dry-run（可选）**

如有 hardhat fork / local node，可以验证脚本能跑通。否则跳过。

**Step 5: 提交**

```bash
git add scripts/32_deploy_security_manager.js scripts/security-manager-config.json
git commit -m "feat(security-manager): add hardhat deploy script and per-chain config"
```

---

## Task 11: NatSpec 文档 + 最终回归

**Files:**
- Modify: `contracts/8/SecurityManager.sol`
- Modify: `contracts/8/interfaces/ITokenApproveProxyAdmin.sol`

**Step 1: 给所有 external/public 函数加 NatSpec 注释**

参考 `contracts/8/TokenApproveProxy.sol` 的注释风格（`/// @notice`、`/// @param`、`/// @dev`）。重点说明：
- 角色权限（哪个角色可以调）
- 副作用（同时操作镜像和老 Proxy）
- 逃生舱使用场景

**Step 2: 跑全套测试做最终回归**

Run: `FOUNDRY_PROFILE=security-manager forge test -vv`
Expected: 全部 PASS。

**Step 3: 跑 forge build 确认无 warning**

Run: `FOUNDRY_PROFILE=security-manager forge build`
Expected: 编译成功，无未处理 warning。

**Step 4: 提交**

```bash
git add contracts/8/SecurityManager.sol contracts/8/interfaces/ITokenApproveProxyAdmin.sol
git commit -m "docs(security-manager): add NatSpec documentation"
```

---

## 完成标准

- [ ] SecurityManager.sol 实现所有功能：addProxy / removeProxy / removeProxies / setTokenApprove / 查询接口 / 逃生舱
- [ ] 所有函数有完整 NatSpec
- [ ] Foundry 测试覆盖：constructor / 权限分离 / 镜像一致性 / 边界条件 / 角色管理
- [ ] 所有测试 PASS
- [ ] Hardhat 部署脚本可运行，配置文件留出 `initialWhitelist` 待白名单基线审计完成后填入
- [ ] 部署脚本不持有任何敏感操作（transferOwnership / grantRole 由多签手动执行）
- [ ] 每个 Task 单独提交，commit 信息描述清晰

## 后续（不在本计划范围内）

- 链下白名单基线审计（Dune SQL + 浏览器爬取 + 业务方校对）
- 多链 rollout runbook
- 安全公司接入流程
- TokenApprove ownership 是否纳管（独立讨论）
