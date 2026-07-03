---
squad: defi
domain: dex
sub_domain: token_approve_security
title: TokenApproveProxy Security Upgrade (SecurityManager)
source_docs: ["TokenApproveProxy安全升级方案"]
concept_keys: [SecurityManager, TokenApproveProxy, DefaultAdminRole, SecurityRole, WhitelistMirror, EscapeHatch, InitialWhitelistBaseline, SoftPause]
organized_at: 2026-06-30T14:09:53+08:00
---

# TokenApproveProxy Security Upgrade (SecurityManager)

> Business line: DeFi — DEX shared-approval infrastructure

> Decision note: of the two proposals in the source, **Option 1 (方案一: SecurityManager custody)** is the final adopted plan. **Option 2 (方案二: TokenApproveProxy V2 full redeploy)** was struck through / rejected and is recorded only as a decision record in Section 7. (Source: TokenApproveProxy安全升级方案, 2026-06-08)

## One-line Summary

A governance upgrade that splits the shared `TokenApproveProxy` whitelist into separate **add** (multisig) and **remove** (third-party security firm) roles and makes the whitelist on-chain enumerable — **without changing the transaction path** — by deploying a new `SecurityManager` contract that takes ownership of the existing `TokenApproveProxy`.

---

## 1. Business Background & Scope

- **Positioning**: The shared approval contract (`TokenApproveProxy`) holds approvals for a large number of users; business lines transfer user assets out of it via a whitelist mechanism. Two risks motivate the upgrade. (Source: TokenApproveProxy安全升级方案, 2026-06-08)
  - **Risk 1 — emergency-response window too long**: business contracts do not yet support `pause`; on a vulnerability, the only response is *remove from whitelist*, which needs a 3/4 multisig. The window is long enough for an attacker to drain already-approved user assets. (Source: TokenApproveProxy安全升级方案, 2026-06-08)
  - **Risk 2 — residual deprecated addresses**: the proxy still whitelists some deprecated addresses, and the contract cannot enumerate the whitelist on-chain, so it cannot be effectively audited. (Source: TokenApproveProxy安全升级方案, 2026-06-08)
- **Goals**: (Source: TokenApproveProxy安全升级方案, 2026-06-08)
  - **Permission split**: separate whitelist add and remove into different roles. Add stays on the existing multisig; remove can be opened to a third-party security firm so risky business lines can be cut off in the shortest time during an emergency.
  - **Whitelist queryable**: the contract layer supports reading the full current whitelist, for periodic audit and timely cleanup of deprecated addresses.
- **Boundary notes**:
  - `SecurityManager` (new): governance plane only — role separation + whitelist mirror + enumeration; executes real operations through the old proxy's admin functions. It does NOT touch the transaction path. (Source: TokenApproveProxy安全升级方案, 2026-06-08)
  - Transaction path (`DexRouter → TokenApproveProxy → TokenApprove → ERC20`): **completely unchanged**; only "who manages the whitelist" changes. (Source: TokenApproveProxy安全升级方案, 2026-06-08)

---

## 2. Core Content

### 2.1 Existing architecture & hard constraints (`TokenApproveProxy`)

**Call chain**: `User Swap → DexRouter/Earn/LimitOrder → TokenApproveProxy (whitelist check: require allowedApprove[msg.sender]) → TokenApprove (require msg.sender == tokenApproveProxy; safeTransferFrom) → ERC20`. (Source: TokenApproveProxy安全升级方案, 2026-06-08)

**Key constraints** (these are why Option 1 was chosen):
- `TokenApproveProxy` is **non-upgradeable** (deployed directly, no proxy pattern) → cannot upgrade in place; can only redeploy or change how it is managed. (Source: TokenApproveProxy安全升级方案, 2026-06-08)
- `DexRouter` is **non-upgradeable**, and `_APPROVE_PROXY` is a **hardcoded constant** → changing the proxy address would require redeploying business contracts. (Source: TokenApproveProxy安全升级方案, 2026-06-08)
- User approval is on **`TokenApprove`**, not the proxy → `TokenApprove` cannot be replaced, or users would have to re-approve. (Source: TokenApproveProxy安全升级方案, 2026-06-08)
- `TokenApprove` recognizes **only one proxy** (`require(msg.sender == tokenApproveProxy)`) → switching to a new proxy immediately disables the old proxy's direct path. (Source: TokenApproveProxy安全升级方案, 2026-06-08)

### 2.2 Adopted: Option 1 — SecurityManager custody (`SecurityManager`)

**Main flow**:
1. Deploy a `SecurityManager` contract that takes over ownership of the old `TokenApproveProxy`. (Source: TokenApproveProxy安全升级方案, 2026-06-08)
2. `SecurityManager` implements role separation and whitelist enumeration internally, and performs real operations through the old proxy's admin functions. (Source: TokenApproveProxy安全升级方案, 2026-06-08)
3. Management plane becomes: `Multisig (ADMIN) / Security firm (SECURITY) → SecurityManager → old Proxy (admin functions)`; transaction plane stays `DexRouter → old TokenApproveProxy → TokenApprove`. (Source: TokenApproveProxy安全升级方案, 2026-06-08)

**Key constraints**:
- Transaction path MUST NOT change; this is the defining principle of Option 1. (Source: TokenApproveProxy安全升级方案, 2026-06-08)
- `SecurityManager` is the new high-privilege governance root and MUST follow the minimal-surface principle: **no arbitrary `call` / `execute` / `delegatecall`** — only the minimal interface this plan needs. (Source: TokenApproveProxy安全升级方案, 2026-06-08)
- `SecurityManager` is intentionally **not upgradeable**. (Source: TokenApproveProxy安全升级方案, 2026-06-08)

### 2.3 Whitelist management (`WhitelistMirror`)

- Use OpenZeppelin `EnumerableSet.AddressSet` inside `SecurityManager` to **mirror** the whitelist. (Source: TokenApproveProxy安全升级方案, 2026-06-08)
- All add/remove go through `SecurityManager` and update BOTH the `EnumerableSet` mirror and the old proxy's `mapping` in the same transaction. (Source: TokenApproveProxy安全升级方案, 2026-06-08)
- Query interface: `getWhitelist()` / `whitelistLength()` / `whitelistAt(index)` / `whitelistContains(addr)`. (Source: TokenApproveProxy安全升级方案, 2026-06-08)
- **Biggest implementation risk — `InitialWhitelistBaseline`**: deployment must manually initialize the existing whitelist so the mirror matches actual state. The old proxy has only a `mapping` and cannot enumerate, so `initialWhitelist[]` must be reconstructed off-chain from historical events + ops records + business inventory, with cross-check. `SecurityManager`'s query trust boundary starts from this baseline. (Source: TokenApproveProxy安全升级方案, 2026-06-08)

### 2.4 Escape hatch (`EscapeHatch`)

`SecurityManager` keeps `transferTokenApproveProxyOwnership(address)` (ADMIN only) to: (a) transfer old-proxy ownership back to the multisig if `SecurityManager` itself has a serious problem, or (b) hand over to a new management contract when `SecurityManager` needs replacing. (Source: TokenApproveProxy安全升级方案, 2026-06-08)

---

## 3. State Machine

### 3.1 Whitelist Entry Status (per proxy address, in SecurityManager view)

| State | Description |
|-------|-------------|
| `NotListed` | Neither in the SM mirror nor on the old proxy |
| `Listed` | In the SM mirror AND on the old proxy (normal parity state) |
| `Ghost` | On the old proxy but NOT in the SM mirror (e.g. seeded before SM, or baseline gap) — still removable by SECURITY_ROLE |

### 3.2 Whitelist Entry Transitions

```
NotListed → Listed     (ADMIN addProxy: writes mirror + old proxy)
Listed → NotListed     (ADMIN or SECURITY removeProxy/removeProxies: removes from both)
Ghost → NotListed      (ADMIN or SECURITY removeProxy: removes from old proxy; mirror had none)
(NotListed,NotListed) → revert   (removeProxy on an address in NEITHER side → "SM: not in whitelist")

Migration (one-time, per chain):
OldProxy owner = Multisig → OldProxy owner = SecurityManager   (multisig transferOwnership)
OldProxy owner = SecurityManager → OldProxy owner = NewOwner   (ADMIN transferTokenApproveProxyOwnership; IRREVERSIBLE from SM)
```

---

## 4. Core Calculation Rules

> N/A (not covered in source documents) — this is a governance/access-control upgrade with no numeric formulas. Fund-movement amounts are unchanged from the existing `claimTokens` path.

---

## 5. Access Control

| Role | Permitted Actions | Constraints |
|------|-------------------|-------------|
| `DEFAULT_ADMIN_ROLE` (multisig wallet) | `addProxy`, `removeProxy` / `removeProxies`, grant/revoke roles, `setTokenApprove`, `transferTokenApproveProxyOwnership` | Add whitelist stays multisig-only; full governance power. (Source: TokenApproveProxy安全升级方案, 2026-06-08) |
| `SECURITY_ROLE` (third-party security firm) | `removeProxy`, `removeProxies` (single / batch) only | **Cannot** add whitelist; purpose is rapid emergency revocation without full admin power. (Source: TokenApproveProxy安全升级方案, 2026-06-08) |

- **Immutable roles**: the governed `tokenApproveProxy` is set at construction and cannot be retargeted; to replace it, deploy a new `SecurityManager`. (Source: TokenApproveProxy安全升级方案, 2026-06-08)
- **Zero-address validation**: constructor rejects zero proxy / zero admin / zero or duplicate initial-whitelist entries, and requires each initial entry to already be allowed on the old proxy; `addProxy` / `setTokenApprove` / `transferTokenApproveProxyOwnership` reject zero address. (Source: TokenApproveProxy安全升级方案, 2026-06-08)
- **`removeProxy` semantics**: reverts only if the address is in NEITHER the mirror nor the old proxy; `removeProxies` (batch) silently skips entries that are in neither side, so one bad input does not poison the batch. (Source: TokenApproveProxy安全升级方案, 2026-06-08)

---

## 6. Events

| Event Name | Trigger Condition | Key Parameters |
|------------|-------------------|----------------|
| `ProxyAdded` | A proxy is added to the whitelist (mirror + old proxy) | `proxy` (indexed), `operator` (indexed; always a DEFAULT_ADMIN_ROLE holder) |
| `ProxyRemoved` | A proxy is removed (from whichever side(s) held it) | `proxy` (indexed), `operator` (indexed; ADMIN = planned cleanup, SECURITY = emergency revocation) |

> The `operator` field makes the `SecurityManager` events strictly more informative than the old proxy's `AddNewProxy` event (which carries only the proxy address); audit dashboards subscribe to `operator` to attribute incident response. (Source: TokenApproveProxy安全升级方案, 2026-06-08)

---

## 7. Constraints & Risk Rules

- Whitelist **add** MUST stay on the multisig (`DEFAULT_ADMIN_ROLE`); **never** open add to the security firm. (Source: TokenApproveProxy安全升级方案, 2026-06-08)
- Whitelist **remove** is opened to `SECURITY_ROLE` for emergency response (single + batch). (Source: TokenApproveProxy安全升级方案, 2026-06-08)
- `SecurityManager` MUST NOT expose arbitrary `call` / `execute` / `delegatecall`; minimal interface only. (Source: TokenApproveProxy安全升级方案, 2026-06-08)
- The transaction path MUST remain unchanged (Option 1 core invariant). (Source: TokenApproveProxy安全升级方案, 2026-06-08)
- `initialWhitelist[]` baseline completeness is the primary risk: an incomplete baseline yields incomplete whitelist queries. A standalone whitelist baseline audit + cross-check MUST be done before deployment. (Source: TokenApproveProxy安全升级方案, 2026-06-08)
- Mirror–proxy parity MUST hold at all times (constructor invariants S3/S4/S5, preserved on every admin path). (Source: TokenApproveProxy安全升级方案, 2026-06-08)
- `transferTokenApproveProxyOwnership` is IRREVERSIBLE from `SecurityManager`: once ownership leaves SM, no SM admin function can affect the old proxy until ownership is returned by other means; it also does NOT clear the local mirror (which becomes stale). (Source: TokenApproveProxy安全升级方案, 2026-06-08)
- **Multi-chain**: deploy / transferOwnership / configure roles / verify independently per chain; canary on a low-risk chain first, then roll out in batches. (Source: TokenApproveProxy安全升级方案, 2026-06-08)

> **Decision record — Option 2 (rejected, struck through in source)**: "TokenApproveProxy V2 full redeploy" would build governance natively into a new proxy but requires redeploying the proxy + DexRouter + business contracts and switching `TokenApprove.setApproveProxy(V2)` — high migration cost/risk. Rejected in favor of Option 1's minimal intrusion. Not extracted as live rules. (Source: TokenApproveProxy安全升级方案, 2026-06-08)

> **Deferred — Pause mechanism (out of scope for now)**: `removeProxy` / `removeProxies` already gives per-business-line blocking; global pause is an enhancement, not a core requirement. Option 1's pause would be a "soft pause" via `setTokenApprove(pauseGuard)` pointing at an always-reverting `PauseGuard` contract — emergency-only, NOT standard `Pausable`. Treated as future work. (Source: TokenApproveProxy安全升级方案, 2026-06-08)

---

## 8. Test Focus

### Happy Path
- [ ] Deploy `SecurityManager(oldProxy, multisig, initialWhitelist)` → mirror equals the seeded baseline.
- [ ] Multisig `transferOwnership(SecurityManager)` → ADMIN `addProxy` / `removeProxy` work through SM and reflect on the old proxy.
- [ ] Grant `SECURITY_ROLE` to the security firm → firm can `removeProxy` / `removeProxies` but cannot `addProxy`.
- [ ] `getWhitelist()` / `whitelistLength()` / `whitelistAt()` / `whitelistContains()` return correct state.

### Unhappy Path
- [ ] Constructor with zero proxy / zero admin / zero or duplicate initial entry / entry not allowed on old proxy → revert.
- [ ] `SECURITY_ROLE` attempts `addProxy` → revert "unauthorized" / role check.
- [ ] `addProxy` an already-listed address → revert "already in whitelist".
- [ ] `removeProxy` an address in neither mirror nor old proxy → revert "not in whitelist".
- [ ] Any caller without ADMIN/SECURITY calls a guarded function → revert.

### High-Risk Scenarios
- [ ] **Initial whitelist baseline gap**: an address allowed on the old proxy but missing from `initialWhitelist` becomes a `Ghost` — verify `SECURITY_ROLE` can still remove it (emergency revocation of ghosts).
- [ ] `removeProxies` batch with mixed valid / ghost / non-existent entries → valid+ghost removed, non-existent skipped, batch not reverted.
- [ ] `transferTokenApproveProxyOwnership` then attempt SM admin op → no longer affects old proxy (irreversible); mirror left stale.
- [ ] Emergency timing: `removeProxy` by `SECURITY_ROLE` is a single tx (no multisig) → blocks a compromised business line immediately.
- [ ] Multi-chain rollout: each chain independently deployed/owned/configured; rollback via escape hatch verified on canary chain.

---

## 9. Terminology

| Term | Definition |
|------|------------|
| `SecurityManager` | Governance wrapper that owns the old `TokenApproveProxy` and splits add/remove roles + mirrors the whitelist |
| `TokenApproveProxy` (统一授权合约) | Existing shared whitelist-check layer in front of `TokenApprove`; non-upgradeable, hardcoded into `DexRouter` |
| `DefaultAdminRole` (DEFAULT_ADMIN_ROLE) | Multisig role: add/remove whitelist, manage roles, setTokenApprove, escape hatch |
| `SecurityRole` (SECURITY_ROLE) | Third-party security firm role: remove whitelist only (emergency revocation) |
| `WhitelistMirror` | `EnumerableSet.AddressSet` in SecurityManager mirroring the old proxy's whitelist for enumeration |
| `EscapeHatch` | `transferTokenApproveProxyOwnership` — returns/hands off old-proxy ownership; irreversible from SM |
| `InitialWhitelistBaseline` | The off-chain-reconstructed `initialWhitelist[]` seeded at deployment; defines the query trust boundary |
| `SoftPause` | Deferred emergency-only pause via `setTokenApprove(pauseGuard)`; not standard `Pausable` |
