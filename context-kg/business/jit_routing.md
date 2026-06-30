---
squad: defi
domain: dex
sub_domain: jit_routing
title: EVM Dynamic Routing (JIT Routing)
source_docs: ["EVM 动态路由 JIT Routing 最终方案"]
concept_keys: [DynamicRoute, Candidate, DryRun, WinnerSelection, ProtocolAgnosticMetaAdapter, RefundTo, MagicPrefixedRevert, MinReturnGuard]
organized_at: 2026-06-30T14:09:53+08:00
---

# EVM Dynamic Routing (JIT Routing)

> Business line: DeFi — DEX Aggregator (DexRouter)

> Naming note: the PRD calls the new contract **`JitAdapter`**; in the actual codebase it was renamed to **`DynamicRoute`** (`contracts/8/adapter/DynamicRoute.sol`). This document uses `DynamicRoute` and notes the PRD alias where relevant.

## One-line Summary

At on-chain swap execution time, `DynamicRoute` dry-runs a set of pre-packaged candidate adapters one by one ("dry-run + revert-with-result"), picks the candidate with the highest *measured* output as the winner, then executes that winner for real — closing the quote-to-execution gap without relying on any view-quote or replicating protocol math.

---

## 1. Business Background & Scope

- **Positioning**: DEX aggregators suffer a "quote → execution gap": between the off-chain quote and on-chain execution, the optimal path may no longer be optimal, the trade may revert on slippage, or in PMM scenarios the market maker may give a degraded firm-order or let the signed quote expire. Mainstream EVM aggregators (1inch / ParaSwap / 0x) are all "off-chain compute + on-chain static execution" and can only protect users passively via `minReturn`. JIT Routing adds *active* on-chain candidate arbitration. (Source: EVM 动态路由 JIT Routing 最终方案, 2026-05-30)
- **MVP scope**: one new immutable `DynamicRoute` contract; first rollout as a small canary on L2; candidate pool covers PMM (OKX RFQ) + mainstream AMMs (UniV2/V3 etc.). (Source: EVM 动态路由 JIT Routing 最终方案, 2026-05-30)
- **Boundary notes (minimal intrusion)**:
  - `DexRouter` / `DagRouter` / `_exeNode` / `_exeEdge` / `CommonUtils` / `CommonLib._exeAdapter` / `IAdapter` interface / existing 60+ adapters / `ApproveProxy` / fee (ToB/ToC) logic: **all unchanged**. (Source: EVM 动态路由 JIT Routing 最终方案, 2026-05-30)
  - `DynamicRoute`: a protocol-agnostic *meta-adapter*. It selects among N equivalent edge-slices via dry-run; it does NOT decode any candidate's protocol-specific `extraData`, does NOT hold a real pool, and never needs redeployment when a new protocol is added. (Source: EVM 动态路由 JIT Routing 最终方案, 2026-05-30)
  - Adding a new protocol = an existing adapter passes the dry-run compatibility review and joins the candidate pool — **zero new contract deployment**. (Source: EVM 动态路由 JIT Routing 最终方案, 2026-05-30)

---

## 2. Core Content

### 2.1 Single-execution flow (`DryRun` → `WinnerSelection`)

**Main flow** (4 steps):
1. **Decode**: from the top-level `extraData` decode `(fromToken, toToken, mode, candidates[])`; extract `refundTo` from the tail of `msg.data` via `calldataload` + `ORIGIN_PAYER` marker validation. (Source: EVM 动态路由 JIT Routing 最终方案, 2026-05-30)
2. **Dry-run loop**: for each candidate, self-call `_dryRun` — `safeTransfer` `fromToken` to `c.assetTo`, decode `c.rawData` for pool/reverse, execute via `_tryExeAdapter` (low-level call, does not bubble the revert, anti magic-spoof), measure `IERC20(toToken).balanceOf(to)` before/after, then revert with a magic-prefixed `(amountOut, ok, underlyingReason)` payload. The outer `catch` strictly validates the magic prefix and decodes the structured payload into a `quotes` array. (Source: EVM 动态路由 JIT Routing 最终方案, 2026-05-30)
3. **Pick winner**: `winner = argmax(quotes)`, require `quotes[winner] > 0` (reject the all-dead case). (Source: EVM 动态路由 JIT Routing 最终方案, 2026-05-30)
4. **Real execution**: `safeTransfer` to `cs[winner].assetTo`, decode `cs[winner].rawData`, call `_exeAdapter` on the winner (`to` = the same downstream receiver as dry-run, `refundTo` passed through); then `emit JitWinnerSelected`. (Source: EVM 动态路由 JIT Routing 最终方案, 2026-05-30)

**Key constraints**:
- **Post-execution verification**: real-exec output delta MUST be `>= quotes[winner]`; otherwise the whole tx reverts. This binds the trust model to EVM-observed delivery, not to any candidate's promise. (Source: EVM 动态路由 JIT Routing 最终方案, 2026-05-30)
- **No fallback**: if the winner fails in real execution, the whole tx reverts — there is NO try-winner/catch-runnerUp fallback. Under deterministic EVM (same tx, same state), dry-run success ⇒ real-exec success (sole exception: gas-dependent adapter logic). Fallback would mask underlying bugs and is treated as tech debt. tx-revert + user-retry is the default DEX swap contract: the only loss is gas, no fund loss. (Source: EVM 动态路由 JIT Routing 最终方案, 2026-05-30)

### 2.2 Two key evolutions from the review draft (`ProtocolAgnosticMetaAdapter`)

- **Pricing mechanism**: Per-protocol Quoter / QuoterLib → **dry-run + revert**. Avoids replicating protocol math (UniV3 tick traversal, Balancer weighted curve, Curve stableswap iteration), gives zero coupling to protocol upgrades, and zero new contracts when onboarding a protocol. (Source: EVM 动态路由 JIT Routing 最终方案, 2026-05-30)
- **Failure handling**: try-winner/catch-runnerUp fallback → **no fallback** (see 2.1). (Source: EVM 动态路由 JIT Routing 最终方案, 2026-05-30)

### 2.3 Why `fromToken` and `toToken` are both required (`ProtocolAgnosticMetaAdapter`)

Because `DynamicRoute` is protocol-agnostic and cannot decode each candidate's protocol-specific `extraData`:
- `fromToken`: lets `DynamicRoute` read its own `balanceOf` and `safeTransfer` to `c.assetTo` (both dry-run and real exec). 
- `toToken`: lets dry-run measure the real receiver's balance change via `IERC20(toToken).balanceOf(to)` before/after (dry-run path only). (Source: EVM 动态路由 JIT Routing 最终方案, 2026-05-30)

Neither can be derived from pool / RouterPath / candidate `extraData`. All candidates of one JIT edge share the same `(fromToken, toToken)` pair (the definition of being mutually substitutable), so both are placed once at the top level of `extraData`, not repeated per candidate. (Source: EVM 动态路由 JIT Routing 最终方案, 2026-05-30)

### 2.4 `to` passthrough (`DryRun`)

In both dry-run and real execution, `DynamicRoute` passes the outer `to` through to the underlying adapter unchanged (does not substitute `self`). Measurement target is that same `to` address's `toToken` balance change. This makes the underlying adapter fully transparent and makes the dry-run and real-exec fund paths 100% isomorphic — so for fee-on-transfer (FOT) tokens the dry-run predicts the real output exactly (no over/under-estimate). The only side effect: in dry-run, if `to` is a contract with an ERC777 receive hook, the hook is triggered then rolled back with the revert (guarded by `nonReentrant` + revert atomicity). (Source: EVM 动态路由 JIT Routing 最终方案, 2026-05-30)

---

## 3. State Machine

> JIT execution is stateless on-chain (`DynamicRoute` holds no storage beyond the reentrancy guard). The relevant lifecycle is the *per-candidate* dry-run status and the *per-swap* execution phase.

### 3.1 Candidate / Execution Status Enum

| State | Description |
|-------|-------------|
| `Alive` | Candidate dry-run returned `ok == true` with `amountOut > 0` |
| `Dead` | Candidate dry-run failed (`ok == false`), or returned `amountOut == 0`, or returned a payload shorter than the minimum / wrong magic |
| `Winner` | The `Alive` candidate with the maximum quote (`argmax`) |
| `Executed` | Winner real execution succeeded AND `realDelta >= quotes[winner]` |
| `Reverted` | All candidates `Dead`, or winner real-exec failed, or post-exec output below quote |

### 3.2 Execution Transitions

```
DryRunLoop → WinnerSelection      (every candidate dry-run completed)
WinnerSelection → Reverted        (quotes[winner] == 0 → "JIT: all candidates dead")
WinnerSelection → RealExec        (quotes[winner] > 0)
RealExec → Executed               (winner succeeds AND realDelta >= quotes[winner])
RealExec → Reverted               (winner reverts → bubbles up, whole tx reverts; NO fallback)
Executed → Reverted               (post-exec check fails: realDelta < quotes[winner])

Path A (happy path): DryRunLoop → WinnerSelection → RealExec → Executed → emit JitWinnerSelected
Path B (all dead):   DryRunLoop → WinnerSelection → Reverted
Path C (winner dies): DryRunLoop → WinnerSelection → RealExec → Reverted
```

---

## 4. Core Calculation Rules

- **winner** = `argmax(quotes)`; on all-zero input returns index 0, then rejected by `require(quotes[winner] > 0)`. (Source: EVM 动态路由 JIT Routing 最终方案, 2026-05-30)
- **amountOut (per candidate dry-run)** = `IERC20(toToken).balanceOf(to)` after − before, or `0` if the underlying call failed. (Source: EVM 动态路由 JIT Routing 最终方案, 2026-05-30)
- **Post-exec acceptance** = `IERC20(toToken).balanceOf(to)` delta MUST be `>= quotes[winner]` (`>=` permits over-delivery, blocks promise-more-than-deliver). (Source: EVM 动态路由 JIT Routing 最终方案, 2026-05-30)
- **Backend gas budget** = `base_overhead + N × per_dryrun_gas + winner_real_gas + safety_buffer (+20%)`. (Source: EVM 动态路由 JIT Routing 最终方案, 2026-05-30)

---

## 5. Access Control

| Role | Permitted Actions | Constraints |
|------|-------------------|-------------|
| (none — no admin) | — | `DynamicRoute` is permanently immutable: no admin, no upgrade, no owner. (Source: EVM 动态路由 JIT Routing 最终方案, 2026-05-30) |
| Backend routing layer | Supplies the candidate list (adapter / assetTo / rawData / extraData) | Candidates are **trusted** — `DynamicRoute` is NOT a permissionless entry point for arbitrary adapter dispatch. (Source: EVM 动态路由 JIT Routing 最终方案, 2026-05-30) |
| Self (`address(this)`) | `_dryRun` self-call only | `require(msg.sender == address(this))` guards the dry-run entry. (Source: EVM 动态路由 JIT Routing 最终方案, 2026-05-30) |

- **Immutable roles**: no roles; contract is immutable by design (no admin trust assumption).
- **Reentrancy**: `sellBase` / `sellQuote` are `nonReentrant` to prevent cross-candidate malicious reentrancy. (Source: EVM 动态路由 JIT Routing 最终方案, 2026-05-30)

---

## 6. Events

| Event Name | Trigger Condition | Key Parameters |
|------------|-------------------|----------------|
| `JitWinnerSelected` | Winner selected and executed | `winnerIdx` (uint8), `quotes` (uint256[], dead candidates count as 0), `winnerAdapter` (address) |
| `JitDryRunFailed` | A candidate's dry-run failed (`ok == false`) | `candidateIdx` (uint8), `adapter` (address), `reason` (bytes; magic-mismatch = a real error) |

> Off-chain consumption: `JitWinnerSelected` feeds win-rate analysis (PMM vs AMM, inter-PMM competition); `JitDryRunFailed` feeds failure-mode analysis (PMM expiry, pool depth, deadline) → routing strategy (down-weight or drop high-failure PMMs). No `JitFallbackTriggered` event (no fallback). (Source: EVM 动态路由 JIT Routing 最终方案, 2026-05-30)

---

## 7. Constraints & Risk Rules

- **Candidate count**: contract enforces a hard range `[2, 8]` (`MIN_CANDIDATES = 2`, `MAX_CANDIDATES = 8`). `< 2` → static routing is cheaper; the business upper bound is 8 per §9.1. (Source: EVM 动态路由 JIT Routing 最终方案, 2026-05-30) — *Note: the PRD pseudocode shows `[2, 255]` (uint8 type-safety ceiling), but §9.1's conclusion converged the contract-level hard range to `[2, 8]`, which the implementation adopts.*
- **Native ETH not allowed**: `require(fromToken != _ETH && toToken != _ETH)` — JIT measures via `IERC20.balanceOf`, so tokens MUST be ERC20; native ETH must be wrapped to WETH by the backend first. (Source: EVM 动态路由 JIT Routing 最终方案, 2026-05-30)
- **`fromToken != toToken`** and **`amount > 0`** are required at entry. (Source: EVM 动态路由 JIT Routing 最终方案, 2026-05-30)
- **Mode**: `require(mode == MODE_AUTO)` (V1 supports only `MODE_AUTO = 0`); the field is reserved for future selection-strategy variants. (Source: EVM 动态路由 JIT Routing 最终方案, 2026-05-30)
- **Anti magic-spoof**: dry-run MUST use `_tryExeAdapter` (low-level call, does not bubble) so a malicious adapter cannot forge the outer magic-prefixed revert to hijack winner selection; its forged bytes land only in the `underlyingReason` slot. The outer `catch` requires payload length `>= 132` and an exact `DRY_RUN_RESULT_MAGIC` match before decoding. (Source: EVM 动态路由 JIT Routing 最终方案, 2026-05-30)
- **`c.assetTo` must be per-candidate**: UniV2-family → pool address; UniV3 / PMM → adapter address. An implementation-layer hard constraint that cannot be bypassed. (Source: EVM 动态路由 JIT Routing 最终方案, 2026-05-30)
- **`refundTo`**: passed via `CommonLib._exeAdapter`'s `ORIGIN_PAYER` mechanism (tail of `msg.data`), with marker validation; not placed in `extraData`. Marker mismatch → `refundTo == 0`. (Source: EVM 动态路由 JIT Routing 最终方案, 2026-05-30)
- **Final guard**: DexRouter's overall `minReturn` check still applies as the last backstop even if dry-run / real-exec behaves unexpectedly. (Source: EVM 动态路由 JIT Routing 最终方案, 2026-05-30)
- **No native ETH send**: `DynamicRoute` deliberately has no `receive()` / payable `fallback()` — sending native ETH reverts. (Source: EVM 动态路由 JIT Routing 最终方案, 2026-05-30)

---

## 8. Test Focus

### Happy Path
- [ ] 2–8 candidates, all dry-run alive → highest-output winner selected, executed, `realDelta >= quote`, `JitWinnerSelected` emitted.
- [ ] PMM + AMM mixed candidate pool → correct argmax winner.

### Unhappy Path
- [ ] `candidates.length < 2` or `> 8` → revert "candidates len out of range".
- [ ] `fromToken == _ETH` or `toToken == _ETH` → revert "native ETH not allowed".
- [ ] `fromToken == toToken` → revert.
- [ ] `amount == 0` → revert "zero input".
- [ ] `mode != MODE_AUTO` → revert "unsupported mode".
- [ ] All candidates dead (quotes all 0) → revert "all candidates dead".
- [ ] Winner reverts in real exec → whole tx reverts (no fallback).

### High-Risk Scenarios
- [ ] Malicious adapter reverts `MAGIC + fakeAmount` → must NOT be read as a quote (lands in `underlyingReason`).
- [ ] dry-run payload `< 132` bytes (e.g. OOG) → candidate treated as dead, swap not poisoned.
- [ ] FOT token: dry-run measured `amountOut` exactly equals real-exec output (`to` passthrough).
- [ ] Adapter dry-run review: no `gasleft()` conditional, no `msg.sender`-specific branch; fork consistency = 0 deviation across regular / FOT / native-ETH paths and across N amounts × N pool states. (Source: EVM 动态路由 JIT Routing 最终方案, 2026-05-30 §9.3)
- [ ] Post-exec `realDelta < quote` → revert "real exec below quote".

---

## 9. Terminology

| Term | Definition |
|------|------------|
| `DynamicRoute` (PRD: JitAdapter) | Protocol-agnostic JIT meta-adapter; dry-runs candidates and executes the best |
| `Candidate` | One edge-slice: `{adapter, assetTo, rawData, extraData}`, mirrors a RouterPath single edge |
| `DryRun` | Sandbox trial execution of a candidate that ends by reverting with a magic-prefixed result |
| `WinnerSelection` | `argmax(quotes)` over all candidates, requiring the winner quote `> 0` |
| `ProtocolAgnosticMetaAdapter` | The design property: JIT decodes no protocol-specific data; new protocols need no new contract |
| `RefundTo` | Leftover-refund address, carried via the `ORIGIN_PAYER` calldata-tail mechanism |
| `MagicPrefixedRevert` | `DRY_RUN_RESULT_MAGIC ‖ abi.encode(amountOut, ok, reason)` revert payload format |
| `MinReturnGuard` | DexRouter's overall `minReturn` check, the final fund-safety backstop |
| `MODE_AUTO` | The only V1 mode (`0`); selects winner by full dry-run comparison |
