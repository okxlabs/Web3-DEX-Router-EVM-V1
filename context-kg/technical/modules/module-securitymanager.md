---
name: "module-securitymanager"
description: "SecurityManager 模块设计——TokenApproveProxy 的治理封装与白名单镜像"
---

# Module: SecurityManager

> 来源: `contracts/8/SecurityManager.sol`、`contracts/8/interfaces/ITokenApproveProxyAdmin.sol`

## 职责

`SecurityManager` 是 `TokenApproveProxy` 的**治理封装合约**：它持有底层 `TokenApproveProxy` 的 owner 权限，并在其上的每一个特权操作前置一层访问控制。核心设计是把白名单的**新增**(仅管理员)与**移除**(管理员或安全应急角色)拆开,使应急响应角色能在不掌握完整管理员权限的情况下快速吊销被攻破的 proxy。

不负责:运行时用户代币的实际划转(那是 `TokenApprove` / `TokenApproveProxy` 的 claim 平面职责)。

- [Rule] `SecurityManager` **must** 通过 `ITokenApproveProxyAdmin`(管理平面接口)与底层 proxy 交互,**never** 引入 `IApproveProxy`(运行时 claim 平面),以防误授其运行时取币能力。

## 角色与权限

| 角色 | 能力 | 不能做 |
|------|------|--------|
| `DEFAULT_ADMIN_ROLE` | 新增/移除 proxy、`setTokenApprove`、转移底层 proxy 所有权、授予/吊销 `SECURITY_ROLE` | — |
| `SECURITY_ROLE` (`keccak256("SECURITY_ROLE")`) | **仅移除** proxy(应急吊销),含批量移除 | **never** 新增 proxy |

- `SECURITY_ROLE` 通过 AccessControl 的 `grantRole`/`revokeRole` 授予,二者本身要求 `DEFAULT_ADMIN_ROLE`。
- `onlyAdminOrSecurity` 修饰符 = `hasRole(DEFAULT_ADMIN_ROLE) || hasRole(SECURITY_ROLE)`(逻辑或)。

## 状态与不变量

- `tokenApproveProxy`(`immutable`):构造时绑定,**never** 可重定向;需替换时部署新的 `SecurityManager`。
- `_whitelist`(`EnumerableSet.AddressSet`):底层 proxy allow-list 的**链上镜像**,供审计团队链下枚举。
- [Rule] 每条管理路径 **must** 在同一笔交易内同时写入镜像与底层 proxy,保持二者一致(parity)。
- 构造函数不变量:
  - **S3** `_tokenApproveProxy != 0` 且 `_admin != 0`,初始白名单每项非零。
  - **S4** 初始白名单每项 **must** 已在底层 proxy 上 `isAllowedProxy`(无需回查外部即可自举镜像一致性)。
  - **S5** 初始白名单 **never** 含重复项。

## 接口

```solidity
// Views
function whitelistLength() external view returns (uint256);
function whitelistContains(address _proxy) external view returns (bool);
function getWhitelist() external view returns (address[] memory); // 链下枚举专用,白名单过大时勿在链上调用
function whitelistAt(uint256 _index) external view returns (address); // 顺序在 remove 后不稳定

// Admin (DEFAULT_ADMIN_ROLE)
function addProxy(address _proxy) external;
function setTokenApprove(address _tokenApprove) external;
function transferTokenApproveProxyOwnership(address _newOwner) external;

// Admin OR Security
function removeProxy(address _proxy) external;
function removeProxies(address[] calldata _proxies) external;
```

## 关键行为

- `addProxy`:要求非零且不在镜像中;同时写镜像 + 调 `tokenApproveProxy.addProxy`。无需 `isAllowedProxy` 预检——本次调用即是使其上链的动作,镜像-proxy 一致性由构造函数 S4 归纳保证。
- `removeProxy`:同时检查镜像(`inMirror`)与底层(`onProxy`),**只有两侧都不含时才 revert**;接受 "ghost" 地址(在底层但从未进镜像),使 `SECURITY_ROLE` 仍能应急吊销。
- `removeProxies`(批量):语义同 `removeProxy`,但两侧都不含的条目**静默跳过(不 revert)**,单条坏输入不会污染整批,可在部分失败后重试。
- `setTokenApprove`:透传到底层 proxy,改变其拉取用户代币的来源。**高敏感**——改变所有经底层 proxy 路由的用户代币转账的真值源。
- `transferTokenApproveProxyOwnership`:逃生舱口。**从本合约视角不可逆**——所有权一旦离开 `SecurityManager`,本合约任何管理函数都无法再影响底层 proxy(除非所有权被其他途径交回)。仅用于:(a) 用新治理合约替换本合约,或 (b) 本合约发现 bug 时应急恢复。

## 事件

| 事件 | 触发 | 说明 |
|------|------|------|
| `ProxyAdded(proxy, operator)` | 新增 proxy | `operator` 恒为某个 `DEFAULT_ADMIN_ROLE` 持有者 |
| `ProxyRemoved(proxy, operator)` | 移除 proxy | `operator` 为管理员(计划清理)或 `SECURITY_ROLE`(应急吊销),审计看板据此归因事件响应 |

> SecurityManager 事件携带 `operator`,比底层 `TokenApproveProxy` 仅携带 proxy 地址的 `AddNewProxy` 事件信息更丰富。

## 依赖关系

- 参考 [arch/dependency.md](../arch/dependency.md)

## 踩坑点

- [Pitfall] `transferTokenApproveProxyOwnership` **不会**清空本地镜像,所有权转走后镜像即变陈旧,链下审计 **must** 知悉。
- [Pitfall] 本合约**有效**的前提是它(已经或将要)成为底层 `TokenApproveProxy` 的 owner;否则所有管理路径在下游不生效。
- [Pitfall] `getWhitelist()` 返回全量数组,白名单无界时 **never** 在链上逻辑中调用。
- [Rule] 本合约**故意不可升级**(`AccessControlEnumerable`,无代理),需替换时走 `transferTokenApproveProxyOwnership` 逃生舱口。
