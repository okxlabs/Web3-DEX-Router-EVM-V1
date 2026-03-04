# ERC-8021 DexRouter 兼容性方案 — SPEC（技术规格文档）

> 日期: 2026-03-03
> 状态: 草案
> 作者: DexRouter Team
> 相关文档: [PRD](./PRD.md) | [PLAN](./PLAN.md)

---

### 2.1 当前架构（main 分支）

#### 2.1.1 Calldata 布局

DexRouter 在 ABI 编码的 swap 参数之后追加可选的 ExtraData：

```
Calldata 布局（当前）:
+--------------------+------------------+-----------------+
| 4B selector        | ABI 编码的        | ExtraData       |
| + swap 参数         | 参数              | (可选)          |
+--------------------+------------------+-----------------+
                                         <-- 从右向左解析
```

ExtraData 从 calldata 末尾**从右向左**解析：

```
ExtraData 布局（从右向左）:
+----------------+-------------------+
| trimInfo       | commissionInfo    |  <- calldatasize()
| 0/64/96 字节    | 0/64/96/N 字节    |
+----------------+-------------------+
```

以下是 CommissionInfo 和 TrimInfo 的字节级编码格式，展示每个 bytes32 word 的内部结构。图中**左侧为低地址，右侧为高地址**（靠近 `calldatasize()`）；**1st bytes32** 是解析时第一个读取的 word（最右侧），其高 6 字节为 flag 标识。

**CommissionInfo 编码格式**

单推荐人分佣（2 × bytes32 = 64 字节）：

```
┌──────────────────────────────────────────┬──────────────────────────────────────────┐
│            2nd bytes32                   │              1st bytes32                 │
│      (isToB + padding + token_addr)      │      (flag + rate + referer_addr)        │
├────────┬──────────────────┬──────────────┼─────────────┬─────────────┬──────────────┤
│ isToB  │     padding      │token_address │    flag     │    rate     │referer_addr  │
│ 1 byte │    11 bytes      │   20 bytes   │   6 bytes   │   6 bytes   │   20 bytes   │
├────────┼──────────────────┼──────────────┼─────────────┼─────────────┼──────────────┤
│ 0x80or │0x0000000000000000│    token     │0x3ca20afc   │    rate1    │  referrer1   │
│ 0x00   │       0000       │              │  2aaa/2bbb  │             │              │
└────────┴──────────────────┴──────────────┴─────────────┴─────────────┴──────────────┘
```

双推荐人分佣（3 × bytes32 = 96 字节）：

```
┌──────────────────────────────────────────┬──────────────────────────────────────────┬──────────────────────────────────────────┐
│            3rd bytes32                   │            2nd bytes32                   │             1st bytes32                  │
│      (flag + rate2 + referer_addr2)      │      (isToB + padding + token_addr)      │      (flag + rate1 + referer_addr1)      │
├─────────────┬─────────────┬──────────────┼────────┬──────────────────┬──────────────┼─────────────┬─────────────┬──────────────┤
│    flag     │   rate2     │referer_addr2 │ isToB  │     padding      │token_address │    flag     │   rate1     │referer_addr1 │
│   6 bytes   │   6 bytes   │   20 bytes   │ 1 byte │    11 bytes      │   20 bytes   │   6 bytes   │   6 bytes   │   20 bytes   │
├─────────────┼─────────────┼──────────────┼────────┼──────────────────┼──────────────┼─────────────┼─────────────┼──────────────┤
│0x22220afc   │   rate2     │   referer2   │ 0x80or │0x0000000000000000│    token     │0x22220afc   │   rate1     │   referer1   │
│  2aaa/2bbb  │             │              │ 0x00   │       0000       │              │  2aaa/2bbb  │             │              │
└─────────────┴─────────────┴──────────────┴────────┴──────────────────┴──────────────┴─────────────┴─────────────┴──────────────┘
```

多推荐人分佣（(1 + N) × bytes32，N = referrerNum ∈ [3, 8]）：

```
┌────────────┬──────────────────────────────────────────┬──────────────────────────────────────────┬───────────────────────────────────────────────┬──────────────────────────────────────────┐
│            │            (N+1)th bytes32               │            Nth bytes32                   │            2nd bytes32                        │             1st bytes32                  │
│            │      (flag + rateN + referer_addrN)      │    (flag + rate(N-1) + referer(N-1))     │   (isToB + referrer_num + pad + token)         │      (flag + rate1 + referer_addr1)      │
│ Maybe      ├─────────────┬─────────────┬──────────────┼─────────────┬─────────────┬──────────────┼────────┬────────────┬──────────┬──────────────┼─────────────┬─────────────┬──────────────┤
│ more       │    flag     │   rateN     │referer_addrN │    flag     │  rate(N-1)  │referer(N-1)  │ isToB  │referrer_num│  padding │token_address │    flag     │   rate1     │referer_addr1 │
│ commission │   6 bytes   │   6 bytes   │   20 bytes   │   6 bytes   │   6 bytes   │   20 bytes   │ 1 byte │   1 byte   │ 10 bytes │   20 bytes   │   6 bytes   │   6 bytes   │   20 bytes   │
│            ├─────────────┼─────────────┼──────────────┼─────────────┼─────────────┼──────────────┼────────┼────────────┼──────────┼──────────────┼─────────────┼─────────────┼──────────────┤
│            │0x88880afc   │   rateN     │   refererN   │0x88880afc   │  rate(N-1)  │ referer(N-1) │ 0x80or │ num >=3    │ 10 empty │    token     │0x88880afc   │   rate1     │   referer1   │
│            │  2aaa/2bbb  │             │              │  2aaa/2bbb  │             │              │ 0x00   │ && num <=8 │ bytes    │              │  2aaa/2bbb  │             │              │
└────────────┴─────────────┴─────────────┴──────────────┴─────────────┴─────────────┴──────────────┴────────┴────────────┴──────────┴──────────────┴─────────────┴─────────────┴──────────────┘
```

**TrimInfo 编码格式**

TrimInfo 位于 CommissionInfo 的左侧（低地址方向）。解析器在跳过分佣数据后（`offset = (referrerNum + 1) × 32`），继续向左读取正滑点数据。每个 word 的高 6 字节均包含 trim flag。

单正滑点（2 × bytes32 = 64 字节）：

```
┌─────────────┬─────────────┬─────────────┬─────────────────┬─────────────┬─────────────┬─────────────────┐
│ trim_flag   │ isToB       │ padding     │ expect_amount   │ trim_flag   │ trim_rate   │ trim_address    │
│ 6 bytes     │ 1 byte      │ 5 bytes     │ 20 bytes        │ 6 bytes     │ 6 bytes     │ 20 bytes        │
│0x777777771111│0x80 or 0x00│0x0000000000 │                 │0x777777771111│            │                 │
└─────────────┴─────────────┴─────────────┴─────────────────┴─────────────┴─────────────┴─────────────────┘
←──────────────────────── 2nd bytes32 ──────────────────────→←──────────────── 1st bytes32 ──────────────→
```

双正滑点（含 charge，3 × bytes32 = 96 字节）：

```
┌─────────────┬─────────────┬─────────────────┬─────────────┬─────────────┬─────────────┬─────────────────┬─────────────┬─────────────┬─────────────────┐
│ trim_flag   │ charge_rate │ charge_address  │ trim_flag   │ isToB       │ padding     │ expect_amount   │ trim_flag   │ trim_rate   │ trim_address    │
│ 6 bytes     │ 6 bytes     │ 20 bytes        │ 6 bytes     │ 1 byte      │ 5 bytes     │ 20 bytes        │ 6 bytes     │ 6 bytes     │ 20 bytes        │
│0x777777722222│            │                 │0x777777722222│0x80 or 0x00│0x0000000000 │                 │0x777777722222│            │                 │
└─────────────┴─────────────┴─────────────────┴─────────────┴─────────────┴─────────────┴─────────────────┴─────────────┴─────────────┴─────────────────┘
←──────────────── 3rd bytes32 ──────────────→ ←──────────────────────── 2nd bytes32 ───────────────────────→←──────────────── 1st bytes32 ──────────────→
```

**ExtraData 在 calldata 中的完整拼接示例**

以"单推荐人分佣 + 单正滑点"为例，ExtraData 共 128 字节（4 × bytes32），拼接在 ABI 编码参数之后：

```
完整 calldata 布局（单正滑点 + 单推荐人分佣）:

| 4B selector + ABI 编码参数 (32×A B) |          ExtraData (4 × bytes32 = 128B)             |
                                      |      TrimInfo (64B)       |   CommissionInfo (64B)   |
                                      | trim 2nd   | trim 1st    | comm 2nd   | comm 1st    |
                                      |(trimFlag   |(trimFlag     |(isToB+pad  |(commFlag    |
                                      | +isToB     | +trimRate    | +token)    | +rate       |
                                      | +expectAmt)| +trimAddr)   |            | +refAddr)   |
                                                                                              ^
                                                                                      calldatasize()

解析顺序（从右向左）:
  ① calldataload(end - 0x20)          → comm 1st  → 匹配分佣 flag → 解析 rate + referrerAddr
  ② calldataload(end - 0x40)          → comm 2nd  → 解析 isToB + token → offset = 0x40
  ③ calldataload(end - offset - 0x20) → trim 1st  → 匹配正滑点 flag → 解析 trimRate + trimAddr
  ④ calldataload(end - offset - 0x40) → trim 2nd  → 解析 expectAmountOut + isToB

  其中 end = calldatasize()（当前代码）或 effectiveEnd（兼容方案）
```

#### 2.1.2 解析入口

**文件：** `contracts/8/libraries/CommissionLib.sol`
**函数：** `_getCommissionAndTrimInfo()`（第 92-309 行）

该函数以 `calldatasize()` 作为锚点向前读取：

```solidity
// 第 111 行：读取最后 32 字节作为 commissionData
let commissionData := calldataload(sub(calldatasize(), 0x20))

// 第 162 行：读取倒数第二个 32 字节
commissionData := calldataload(sub(calldatasize(), 0x40))

// 第 198 行：多推荐人模式下继续向前读取
commissionData := calldataload(sub(calldatasize(), add(0x40, mul(i, 0x20))))

// 第 227 行：跳过分佣数据后读取正滑点数据
let trimData := calldataload(sub(calldatasize(), add(offset, 0x20)))

// 第 248、278 行：继续读取正滑点数据
trimData := calldataload(sub(calldatasize(), add(offset, 0x40)))
trimData := calldataload(sub(calldatasize(), add(offset, 0x60)))
```

`_getCommissionAndTrimInfo()` 中共有 **6 处** `calldatasize()` 作为倒序解析锚点。

#### 2.1.3 Flag 识别机制

每个 32 字节 word 的前 6 字节（48 位）用作 flag 来标识数据类型：

| Flag 常量                        | 值（前 6 字节）       | 含义                      |
| -------------------------------- | -------------------- | ------------------------- |
| `FROM_TOKEN_COMMISSION`          | `0x3ca20afc2aaa`     | 单推荐人，from-token 分佣  |
| `TO_TOKEN_COMMISSION`            | `0x3ca20afc2bbb`     | 单推荐人，to-token 分佣    |
| `FROM_TOKEN_COMMISSION_DUAL`     | `0x22220afc2aaa`     | 双推荐人，from-token 分佣  |
| `TO_TOKEN_COMMISSION_DUAL`       | `0x22220afc2bbb`     | 双推荐人，to-token 分佣    |
| `FROM_TOKEN_COMMISSION_MULTIPLE` | `0x88880afc2aaa`     | 3-8 推荐人，from-token 分佣 |
| `TO_TOKEN_COMMISSION_MULTIPLE`   | `0x88880afc2bbb`     | 3-8 推荐人，to-token 分佣   |
| `TRIM_FLAG`                      | `0x777777771111`     | 单正滑点                    |
| `TRIM_DUAL_FLAG`                 | `0x777777772222`     | 双正滑点（含 charge）       |

**Flag 的结构特征：**

- 所有分佣 flag 的字节 2-3 都是 `0afc`（6 个 flag 共享）
- 所有正滑点 flag 的字节 0-3 都是 `77777777`（2 个 flag 共享）
- 这些 flag 值具有高辨识度（48 位），随机数据匹配概率约 1/2^48 ≈ 3.5×10^-15

如果最后 32 字节不匹配任何分佣 flag，则 `referrerNum = 0`，不解析分佣。随后正滑点解析直接从 `calldatasize()` 开始（offset = 0）。

#### 2.1.4 受影响文件汇总

| 文件                           | 如何使用 `calldatasize()`                  | 是否受 ERC-8021 影响？ |
| ------------------------------ | ------------------------------------------ | --------------------- |
| `libraries/CommissionLib.sol`  | 6 处作为倒序解析锚点                         | **是 - 主要影响**      |
| `libraries/Adapters.sol`       | `RefundLib.getPayerOrigin()` 读取最后 32 字节 | 否 - 通过内部调用，calldata 独立 |
| `adapter/*.sol`（30+ 个文件）   | 各种回调长度检查                              | 否 - 独立的调用上下文    |

### 2.2 冲突分析

#### 2.2.1 ERC-8021 后缀存在时的行为

```
带有 ERC-8021 的 Calldata:
+----------+-----------+--------------------+----------------------------+
| selector | ABI 参数   | DexRouter ExtraData| ERC-8021 后缀 (18+X 字节)   |
|          |           | (分佣, 正滑点)      | schemaData|schemaId|marker |
+----------+-----------+--------------------+----------------------------+
                                                                 ↑
                                             calldatasize() 指向这里
                                             DexRouter 从这里开始读 ← 错误
```

**逐步故障过程：**

1. `calldataload(sub(calldatasize(), 0x20))` 读取最后 32 字节
2. 这些字节包含 ERC-8021 ercMarker（`0x8021...8021`）的一部分以及可能的 schemaData
3. 提取高 6 字节与分佣 flag 比对
4. `0x802180218021` 不匹配任何已知 flag → `referrerNum = 0`
5. 正滑点解析从 `calldatasize()` 开始（offset 未偏移，因为分佣长度为 0）
6. 正滑点 flag 检查：同样是 ERC-8021 数据的高 6 字节 → 不匹配 `TRIM_FLAG` 或 `TRIM_DUAL_FLAG`
7. 结果：`hasTrim = false`，`commissionInfo` 全部为零

```
故障过程的逐步读取:

读取位置:   calldatasize()-0x20          calldatasize()
                 v                            v
  ... | TrimInfo | CommissionInfo |           | ercMarker (16B) |
       (正滑点)    (分佣)          ↑           ^~~~~~~~~~~~~~~~~~^
                              ExtraData 右边界
                             合约读到的 32 字节 = ercMarker 的一部分 + 其余后缀数据
                             高 6 字节 ≠ 任何已知 flag
                             → referrerNum = 0（分佣丢失）
                             → 正滑点检查同一位置 → 也不匹配
                             → hasTrim = false（正滑点丢失）
```

**后果：** calldata 中确实存在的分佣和正滑点数据被静默忽略。swap 正常执行，但：
- 推荐人收不到分佣
- 正滑点未被截留
- 不会 revert，但**资金分配错误**

这可能比 revert **更严重**，因为它静默丢失了分佣收入。

#### 2.2.2 边界情况

- 如果 ERC-8021 marker 字节恰好部分匹配某个分佣 flag（概率极低，约 2^-48），可能解析出错误的分佣数据
- 如果 `schemaData` 包含看起来像合法分佣+正滑点数据的字节，解析器可能将随机值解读为分佣费率和地址——可能将代币发送到任意地址

### 2.3 方案设计：基于已知 Flag 的后向扫描

#### 2.3.1 核心思路

不依赖 `calldatasize()` 作为 ExtraData 的终点锚点，也不要求调用方修改 calldata 编码（如添加 MARKER），而是利用**已有 flag 模式的高辨识度**，通过后向扫描主动定位 ExtraData 的实际位置。

```
核心变化:

  当前:  calldatasize() ──────────────────────> 直接用作锚点
  新方案: calldatasize() ──> 后向扫描找到 flag ──> effectiveEnd 用作锚点

无后缀时（effectiveEnd == calldatasize()，行为完全一致）:

  | selector | ABI 参数 | Trim | Commission |
                                              ^
                  calldatasize() == effectiveEnd（无差异）

有后缀时（effectiveEnd < calldatasize()，跳过后缀）:

  | selector | ABI 参数 | Trim | Commission | ERC-8021 后缀 |
                                              ^               ^
                                       effectiveEnd     calldatasize()
                                       (扫描定位)       (不再直接用)
```

**设计前提：**

1. **不假设后缀内容**：不关心 calldata 末尾追加了什么数据（ERC-8021 或其他任何协议），也不关心追加了多长
2. **完全向后兼容**：现有 calldata 格式无需任何修改，已有业务零影响
3. **精确识别**：依靠已有 flag 的 48 位高辨识度模式定位 ExtraData

#### 2.3.2 ExtraData 的定位原理

ExtraData 的每个 flag word 具有两个关键性质：

1. **高 6 字节是唯一的 flag 模式**：8 个已知 flag 值，每个 48 位，与随机数据碰撞概率 ~10^-15/位置
2. **始终位于 32 字节对齐位置**：calldata = `4B selector + ABI 参数(32 的倍数) + ExtraData(32 的倍数)`，因此每个 ExtraData word 的起始位置都满足 `(4 + 32*K)`

利用这两个性质，可以从 calldata 末尾向前扫描，跳过未知后缀，精确命中 flag word。

#### 2.3.3 方案 A：后向 bytes32 对齐扫描（推荐）

**算法伪代码：**

```
1. 将 calldatasize() 对齐到 (4 + 32*N) 边界
   aligned = calldatasize() - ((calldatasize() - 4) % 32)

2. 从 aligned 开始，按 32 字节步长向前扫描（直到 selector 边界）
   对每个位置 pos:
     读取 32 字节 word = calldataload(pos - 32)
     提取高 6 字节，与所有已知 flag 比对
     如果匹配 → effectiveEnd = pos，停止扫描

3. 未匹配 → effectiveEnd = calldatasize()（回退到当前行为）

4. 用 effectiveEnd 替换所有 calldatasize() 锚点
```

**无固定上限（全量扫描）：** 扫描不设迭代上限，一直扫到 selector 边界（pos < 0x24）为止。这样无论后缀多长，都能找到 flag；无 ExtraData 时则遍历整个 calldata 确认不存在 flag。方案 A 的 bytes32 步长使全量扫描的 gas 开销可控（详见下文 Gas 分析）。

**对齐扫描示意：**

```
ExtraData + 后缀场景:

字节位置:  4       4+32     ...     M        M+32       calldataEnd
           |--------|--------|--..--|--------|==========|~~~~~~~~~~~|
           | word 0 | word 1 | ... | ExtraD | flagWord | 外部后缀   |
           |--------|--------|--..--|--------|==========|~~~~~~~~~~~|
                                    ^        ^          ^           ^
                                    |        |          ①aligned    calldatasize()
                                    |        ②命中flag!
                                    |        effectiveEnd = M+32
                                    |
                                    后续 ExtraData 在此之前

    扫描方向: ② ←← ① （从 aligned 开始，每次 -32B）

有 ExtraData 时: 扫描次数 = ceil(suffix_len / 32) + 1（只取决于后缀长度）
无 ExtraData 时: 扫描次数 = (calldatasize - 4) / 32（遍历整个 calldata）
```

**各场景行为：**

| 场景 | 扫描行为 | effectiveEnd | 结果 |
|------|---------|-------------|------|
| ExtraData + 无后缀 | 第 1 次即命中 flag | = calldatasize() | 与当前完全一致 |
| ExtraData + 短后缀（<32B） | 第 1 次即命中 flag（对齐跳过后缀） | = calldataEnd - remainder | 正确定位 |
| ExtraData + 任意长度后缀 | 扫描跳过后缀后命中 flag | 正确位置 | 正确定位（无后缀长度限制） |
| 无 ExtraData + 无后缀 | 遍历全部 ABI 参数，无匹配 | = calldatasize() | 与当前一致（无分佣/正滑点） |
| 无 ExtraData + 有后缀 | 遍历后缀+全部 ABI 参数，无匹配 | = calldatasize() | 正确（无分佣/正滑点） |

**扫描中的 flag 匹配逻辑（伪代码示意）：**

每次迭代需要将读取的 word 高 6 字节与所有 8 个已知 flag 值比对。可通过预过滤优化：

```
预过滤决策流程（每次迭代）:

   读取 word (32B)
        |
        v
   提取高 6 字节 (high6)
        |
        +---> 字节 2-3 == 0x0afc ?  ---YES--> 可能是分佣 flag ──+
        |         (分佣共同特征)                                  |
        |                                                        v
        +---> 字节 0-3 == 0x77777777 ? --YES--> 可能是正滑点 flag ──> 完整 8-way 匹配
                  (正滑点共同特征)                                     (命中概率 ~6/8)
                         |                                              |
                         NO (99.998% 的情况)                            v
                         |                                        匹配成功 → break
                         v                                        不匹配 → 继续
                    跳过（~27 gas）
```

以下 Yul 片段**仅为算法示意**，展示预过滤 + 完整匹配的思路，具体实现见 PLAN：

```solidity
// 伪代码 —— 预过滤（利用 flag 的共同特征，仅 2 次比较）
let high6 := shr(208, word)
let mid2 := and(shr(16, high6), 0xffff)       // 提取字节 2-3
let high4 := shr(16, high6)                    // 提取字节 0-3

// 99.999...% 的位置在预过滤就排除了（通过概率 ~1/2^16 ≈ 0.0015%）
// 只有通过预过滤才需要完整的 8-way 匹配
if or(eq(mid2, 0x0afc), eq(high4, 0x77777777)) {
    // 完整匹配 8 个已知 flag 值
    // → 匹配成功则设 effectiveEnd = pos 并 break
}
```

**扫描无优先级，解析有优先级：**

扫描的目的仅是找到 **最靠右（最接近 calldatasize()）的已知 flag word**，不区分分佣还是正滑点。找到后设置 `effectiveEnd`，后续解析代码不变——它先检查分佣 flag，再检查正滑点 flag，天然处理了优先级。

**与当前行为一致性的推演（仅有正滑点、无分佣场景）：**

```
布局: ... | ABI 参数 | trimWord2 | trimFlagWord |
                                                    ^ calldatasize()

当前代码:
  1. calldataload(calldatasize()-0x20) → trimFlagWord（最右侧 word）
  2. 检查分佣 flag → 不匹配 → referrerNum=0, offset=0
  3. calldataload(calldatasize()-0x20) → 同一个 word
  4. 检查正滑点 flag → 匹配 → 解析正滑点 ✓

扫描方案:
  1. 后向扫描 → 第1次命中 trimFlagWord → effectiveEnd = calldatasize()
  2. calldataload(effectiveEnd-0x20) → trimFlagWord（最右侧 word）
  3. 检查分佣 flag → 不匹配 → referrerNum=0, offset=0
  4. calldataload(effectiveEnd-0x20) → 同一个 word
  5. 检查正滑点 flag → 匹配 → 解析正滑点 ✓

结论: 路径完全相同。扫描只替换了锚点，优先级逻辑不变。
```

**Gas 开销（逐 opcode 精确计算）：**

每次迭代的实际操作（预过滤未命中时）：

```
calldataload(sub(scanPos, 0x20))   // 3 + 3 = 6 gas
shr(208, word)                     // 3 gas
shr(16, high6)                     // 3 gas
and(..., 0xffff)                   // 3 gas
eq(mid2, 0x0afc)                   // 3 gas
shr(16, high6)                     // 3 gas (high4, 可优化复用)
eq(high4, 0x77777777)              // 3 gas
or(isComm, isTrim)                 // 3 gas
sub(scanPos, 0x20)                 // 3 gas (步进)
loop overhead (lt + add)           // 6 gas
──────────────────────────────────
合计: ~33 gas/次迭代
```

| 场景 | 迭代次数 | 额外 gas | 说明 |
|------|---------|---------|------|
| ExtraData + 无后缀 | 1 次 | ~50 gas | 第 1 次命中 flag（含完整匹配 ~17 gas） |
| ExtraData + 短后缀（<32B） | 1 次 | ~50 gas | 对齐直接跳过后缀 |
| ExtraData + 273B 后缀 | ~9 次 | ~314 gas | 8 × 33(预过滤) + 1 × 50(命中) |
| 无 ExtraData，500B calldata | ~16 次 | ~528 gas | 遍历全部 word |
| 无 ExtraData，2KB calldata | ~64 次 | ~2,112 gas | 遍历全部 word |
| 无 ExtraData，5KB calldata | ~160 次 | ~5,280 gas | 遍历全部 word |
| **无 ExtraData，10KB calldata** | **~320 次** | **~10,560 gas** | **遍历全部 word** |

**无 ExtraData 是最坏路径，且 gas 与 calldata 长度成正比。** 不带分佣/正滑点的普通 swap 调用，扫描找不到任何 flag，必定遍历整个 calldata 的所有 32 字节位置。

但由于 bytes32 步长的优势，即使 10KB calldata 的 ~10,560 gas 相对于 swap 总 gas（通常 150K-500K）也仅占 2-7%，影响可控。

**为什么不设固定上限？** 设固定上限（如 32 次 = 1024 字节）会引入"假设后缀不超过 1024 字节"的限制，与"不假设后缀内容/长度"的设计前提矛盾。全量扫描消除了这个限制，代价是无 ExtraData 场景的 gas 与 calldata 长度正比——而方案 A 的 bytes32 步长使这个代价可接受。

**方案 A 的对齐假设：为什么截取到 `4 + 32*N` 长度？**

方案 A 的第一步是将 `calldatasize()` 对齐到 `(4 + 32*N)` 边界。这一对齐基于以下结构性假设：

```
calldata 的组成（所有部分均为 32 字节对齐）:

|<-- 4B -->|<---------- 32*A B ---------->|<-------- 32*B B -------->|
+----------+------------------------------+--------------------------+
| selector | ABI 编码参数                   | ExtraData                |
| (固定4B)  | (Solidity ABI 规范保证 32*A)  | (DexRouter 编码保证 32*B) |
+----------+------------------------------+--------------------------+

总长度 = 4 + 32*A + 32*B = 4 + 32*(A+B) = 4 + 32*N

→ 因此，每个 ExtraData flag word 的左边界一定位于 (4 + 32*K) 的位置
→ 扫描只需检查这些对齐位置即可，无需检查中间的字节
```

该假设由两个独立的保证支撑：

**保证 1：ABI 参数始终是 32 字节的倍数。** Solidity ABI 编码规范（ABI Specification）规定所有参数值占 32 字节或其倍数——包括动态类型（`bytes`、`string`、数组）的长度前缀和内容。外部函数调用的 calldata 始终是 `4 + 32*N` 格式。这是 Solidity 编译器和所有标准 ABI encoder 的硬性保证。

**保证 2：ExtraData 始终是 32 字节的倍数。** DexRouter 自身的编码约定要求 CommissionInfo 和 TrimInfo 均按 `bytes32` 打包——每项数据是 1 个 bytes32（flag + 打包数据）或连续多个 bytes32。所有 ExtraData 均以 `calldataload` 按 32 字节读取，天然 32 字节对齐。

```
对齐截取的具体计算:

示例: calldatasize() = 4 + 32*5 + 18 = 182  (18B = ERC-8021 后缀)

remainder = (182 - 4) % 32 = 178 % 32 = 18
aligned   = 182 - 18 = 164 = 4 + 32*5     ← ExtraData 的右边界

字节位置:   0    4    36   68   100  132  164  182
            |sel-|----|----|----|----|----||~~~~~~~~~|
            | 4B | ABI params + ExtraData || ERC后缀  |
                                          ^          ^
                                       aligned    calldatasize()

→ 截断掉的 18 字节正好是非 32 对齐的外部后缀
→ 扫描从 aligned(164) 开始，每次 -32，一定能命中 flag word
```

**该假设何时可能不成立？**

| 场景 | 可能性 | 影响 |
|------|--------|------|
| 非标准 ABI encoder 手动拼接 calldata，参数部分非 32 倍数 | 极低（所有主流编译器/SDK 遵守规范） | flag 不在对齐位置，方案 A 会漏过 |
| Solidity 引入 packed encoding 用于外部调用 | 无（ABI 规范不允许） | 不适用 |
| EVM 修改 selector 长度 | 无（EIP 极不可能改变） | 不适用 |
| DexRouter ExtraData 编码变更为非 32 倍数 | 可控（自身代码） | 需同步更新扫描逻辑 |

**结论：** 对齐假设基于 Solidity ABI 规范 + DexRouter 自身编码约定的双重保证，在实际中不会被打破。方案 B 的"无对齐假设"虽更通用，但在 DexRouter 场景下无实际意义，代价却是 32 倍的 gas 增长率。

#### 2.3.4 方案 B：逐字节偏移扫描

**算法伪代码：**

```
1. 从 calldatasize() - 6 开始（至少需要 6 字节来匹配 flag 模式）
   逐字节向前扫描（最多 MAX_BYTE_SCAN 次）

2. 对每个字节位置 pos:
     读取从 pos 开始的 6 字节（通过 calldataload(pos) + shift + mask）
     与所有已知 flag 的高 6 字节比对
     如果匹配 → 该位置是某个 flag word 的起始
     effectiveEnd = pos + 32（flag word 结尾）

3. 未匹配 → effectiveEnd = calldatasize()（回退到当前行为）
```

**逐字节扫描示意：**

```
方案 B: 每次移动 1 字节（方案 A 每次移动 32 字节）

字节位置:    ...  N-6  N-5  N-4  N-3  N-2  N-1   N  N+1 ... calldataEnd
              |    |    |    |    |    |    |    |    |
              v    v    v    v    v    v    v    v    v
扫描窗口:    [====6B====]                              ← 迭代 K+6
                  [====6B====]                         ← 迭代 K+5
                       [====6B====]                    ← 迭代 K+4
                            [====6B====]               ← 迭代 K+3
                                 [====6B====]          ← 迭代 K+2
                                      [====6B====]     ← 迭代 K+1
                                           [====6B====] ← 迭代 K

    每次提取 6 字节与已知 flag 的高 6 字节比对
    方案 A 只在 (4+32*K) 边界检查，方案 B 在每个字节位置都检查
    → 相同范围内，方案 B 迭代次数 = 方案 A × 32
```

**与方案 A 的区别：**

方案 B 不依赖 32 字节对齐假设，在每个字节位置都检查 flag 模式。这意味着即使 ExtraData 因为某种原因未处于 32 字节对齐位置，也能找到。

**Gas 开销（同样的逐 opcode 计算）：**

每次迭代与方案 A 结构相同（预过滤 + 条件完整匹配），单次迭代 ~33 gas。区别在于迭代次数。

| 场景 | 迭代次数 | 额外 gas | 说明 |
|------|---------|---------|------|
| ExtraData + 无后缀 | 1 次 | ~50 gas | 第 1 次命中 flag |
| ExtraData + 273B 后缀 | ~273 次 | ~9,059 gas | 272 × 33(预过滤) + 1 × 50(命中) |
| 无 ExtraData，500B calldata | ~496 次 | ~16,368 gas | 遍历全部字节 |
| 无 ExtraData，2KB calldata | ~2,044 次 | ~67,452 gas | 遍历全部字节 |
| **无 ExtraData，5KB calldata** | **~5,116 次** | **~168,828 gas** | **超过多数 swap 本身** |
| **无 ExtraData，10KB calldata** | **~10,236 次** | **~337,788 gas** | **远超 swap 本身** |

**方案 B 的致命问题：无 ExtraData 场景的 gas 随 calldata 长度线性增长，且增长率是方案 A 的 32 倍。** 对于 5KB 以上的复杂 swap calldata，仅扫描开销就可能超过 swap 本身的 gas 消耗，完全不可接受。

**方案 B 被迫使用固定上限以控制 gas，但这与"不假设后缀长度"的设计前提矛盾。** 如果设上限 1024 次（覆盖 1024 字节），无 ExtraData 场景 gas 为 ~33,792，对于短 calldata 仍然偏高。如果缩小上限以降低 gas，则后缀覆盖能力下降。这是一个无法调和的矛盾。

#### 2.3.5 方案对比

| 维度 | 方案 A：bytes32 对齐扫描 | 方案 B：逐字节扫描 |
|------|----------------------|-----------------|
| **向后兼容** | 完全兼容 | 完全兼容 |
| **对齐假设** | 假设 ExtraData 在 (4+32*N) 对齐位置 | 无对齐假设 |
| **对齐假设是否成立** | 是 — calldata = 4B selector + ABI(32倍数) + ExtraData(32倍数) | N/A |
| **是否可全量扫描（无固定上限）** | **可以** — gas 可控 | **不可以** — gas 过高，被迫设上限 |
| **后缀长度限制** | **无限制**（全量扫描） | 受固定上限约束（上限/gas 二选一） |
| **ExtraData + 无后缀 gas** | ~50 gas（1 次迭代） | ~50 gas（1 次迭代） |
| **ExtraData + 273B 后缀 gas** | ~314 gas（~9 次迭代） | ~9,059 gas（~273 次迭代） |
| **无 ExtraData，2KB calldata** | ~2,112 gas（~64 次） | ~67,452 gas（~2044 次） |
| **无 ExtraData，5KB calldata** | ~5,280 gas（~160 次） | ~168,828 gas（超过 swap 本身） |
| **无 ExtraData，10KB calldata** | ~10,560 gas（~320 次） | ~337,788 gas（远超 swap 本身） |
| **gas 增长率（每字节 calldata）** | ~0.033 gas/B（÷32 的步长优势） | ~1.03 gas/B |
| **gas 倍数差** | 1× | **~32×** |
| **误报概率/位置** | ~8/2^48 ≈ 2.8×10^-14 | 同左（相同 flag 模式） |
| **实现复杂度** | 低 — 对齐 + 循环 | 低 — 纯循环 |
| **代码改动范围** | 仅 CommissionLib.sol | 仅 CommissionLib.sol |
| **调用方改动** | **无** | **无** |
| **安全性（抗伪造 flag）** | 后向扫描天然免疫 | 同左（后向扫描） |

#### 2.3.6 后向扫描的安全分析

**为什么选择后向扫描而非前向扫描？**

Flag 值是公开的（写在合约代码中），攻击者可在 ABI 编码的 swap 参数中（如 `RouterPath.extraData` 的 `bytes` 字段）嵌入伪造的 flag 模式。

```
前向扫描攻击场景：
+----------+-----------------------------+-----+--------------------+
| selector | ABI 参数中嵌入伪造 flag 模式   | ... | 真实 ExtraData      |
|          | (RouterPath.extraData 内)    |     | (分佣, 正滑点)      |
+----------+-----------------------------+-----+--------------------+
            ↑ 前向扫描在此停下                                     ↑ 真实边界
            effectiveEnd 设在这里 → 分佣数据被跳过 → 逃避分佣
```

```
后向扫描免疫:
+----------+-----------------------------+-----+--------------------+----------+
| selector | ABI 参数中嵌入伪造 flag 模式   | ... | 真实 ExtraData      | 外部后缀  |
|          | (RouterPath.extraData 内)    |     | (flagWord在这里)    |          |
+----------+-----------------------------+-----+--------------------+----------+
                                                 ↑ 后向扫描首先命中    ↑ 扫描起点
                                                 effectiveEnd 正确
```

后向扫描从 calldata 末尾开始，**首先命中真实的 flag word**，永远不会触及 ABI 参数中嵌入的伪造 flag。

**误报风险评估：**

后向扫描中，误报只可能来自未知后缀（如 ERC-8021 数据）中恰好存在匹配 flag 模式的字节：

- 每个 32 字节位置误报概率：8 个 flag / 2^48 ≈ 2.8×10^-14
- 对于 9 个扫描位置（273B 后缀）：总误报概率 ≈ 2.5×10^-13
- 即使按每天 1M 笔交易计算，预期约 **10^7 年**出现一次误报

这与现有代码的 flag 碰撞风险相当（现有代码也假设最后 32 字节不会偶然匹配 flag）。

#### 2.3.7 部署策略

由于两个方案都**完全向后兼容**（不需要 MARKER、不修改 calldata 编码），部署策略非常简单：

```
部署流程:

  +-----------------------+     +-----------------+     +------------------+
  | 1. 修改               |     | 2. 测试         |     | 3. 部署           |
  | CommissionLib.sol     | --> | forge test      | --> | 代理升级          |
  | + effectiveEnd 扫描    |     | + fuzz + 回归   |     | (单次升级即完成)   |
  +-----------------------+     +-----------------+     +------------------+

  调用方视角:
  +------------------+                       +------------------+
  | SDK / 前端       |  无需任何修改          | SDK / 前端        |
  | (升级前)         |  ==================>  | (升级后)          |
  | calldata 编码不变 |                       | calldata 编码不变  |
  +------------------+                       +------------------+
```

**零调用方变更**是此方案相比早期 MARKER 方案的核心优势。

#### 2.3.8 安全风险分析（合约安全视角）

以下从合约安全审计的视角，系统分析两个方案可能面临的安全风险。

##### 风险 1：后缀数据中的 Flag 误匹配（False Positive）

**威胁模型：** 外部后缀（ERC-8021 或其他协议）数据中的某些字节恰好匹配已知 flag 模式，导致扫描提前停止，将后缀的一部分错误地解释为 ExtraData 边界。

```
误匹配攻击路径:

正常:  | ABI 参数 | 真实 ExtraData(flagWord) | ERC-8021 后缀 |
                   ^                                          ^
                   扫描应停在这里                           calldatasize()

误匹配: | ABI 参数 | 真实 ExtraData | ERC-8021 后缀(...恰好匹配flag...) |
                                     ^                                  ^
                                     扫描错误停在这里               calldatasize()
                                     ↓
                     effectiveEnd 错误 → 后续 calldataload 读到后缀数据
                     → 分佣费率/地址被解析为随机值 → 资金可能发到错误地址
```

**概率评估：**
- 每个 32 字节对齐位置误匹配概率：8 个 flag / 2^48 ≈ 2.8×10^-14
- ERC-8021 Schema 0 后缀最长 273 字节 ≈ 8-9 个对齐位置，总误匹配概率 ≈ 2.5×10^-13
- 即使每天 1M 笔交易，预期 ~10^7 年出现一次

**方案 A 风险：** 极低。仅检查 32 字节对齐位置，减少了误匹配窗口。
**方案 B 风险：** 略高。每字节都检查，误匹配窗口扩大 32 倍（每字节位置概率仍然极低 ~2.8×10^-14，但总检查次数多 32 倍）。

**影响严重性：高。** 误匹配导致 effectiveEnd 偏移后，后续解析可能将后缀字节解读为分佣费率和推荐人地址。最坏情况下：代币可能被发送到后缀数据中"编码"出的任意地址。但考虑到 2.8×10^-14 的概率，这是一个理论风险而非实际威胁。

**缓解措施：** 可在解析后增加合理性校验（如分佣费率上限检查），但这属于现有代码就应有的防护，不是扫描机制引入的新风险。

##### 风险 2：Flag 逃逸 / 分佣绕过（False Negative）

**威胁模型：** 攻击者利用某种手段使扫描无法找到真实的 ExtraData flag，导致 `effectiveEnd = calldatasize()`，分佣数据被后缀覆盖，推荐人收不到佣金。

```
逃逸场景分析:

方案 A (全量扫描):
  | ABI 参数 | ExtraData(flagWord) | 超长后缀 (>1KB) |
                ^                                     ^
                即使后缀很长，全量扫描仍能找到 flag     calldatasize()
  → 无逃逸风险（扫描没有上限）

方案 B (固定上限):
  | ABI 参数 | ExtraData(flagWord) | 超长后缀 (>1024B) |
                ^                   |<-- 超出扫描范围 -->|
                扫描到不了这里        ^                   ^
                                    上限边界           calldatasize()
  → 逃逸成功！flag 在扫描范围外，effectiveEnd = calldatasize()
  → 分佣被静默跳过
```

**方案 A 风险：无。** 全量扫描没有固定上限，无论后缀多长都会扫描到 selector 边界。
**方案 B 风险：存在。** 如果未来出现超过固定上限的后缀协议（或攻击者人为构造超长后缀），真实 flag 会落在扫描范围之外。

**影响严重性：中。** 分佣被静默跳过，推荐人损失佣金收入。Swap 本身正常执行，用户不受影响。

##### 风险 3：ABI 参数中的伪造 Flag 注入

**威胁模型：** 攻击者在 `RouterPath.extraData`（`bytes` 类型，用户可控）等字段中嵌入伪造的 flag 模式，试图让扫描错误停止在 ABI 参数内部，从而跳过真实的分佣数据。

```
伪造 flag 注入（后向扫描免疫）:

  | selector | ABI(...伪造flag...ABI...) | 真实 ExtraData(flagWord) | 后缀 |
                 ^                         ^                              ^
                 伪造 flag                 真实 flag               calldatasize()
                 (ABI 编码内部)
                                           ↑
                              后向扫描从右向左，首先命中真实 flag
                              永远不会到达伪造 flag → 免疫
```

**方案 A 风险：无（后向扫描免疫）。** 后向扫描从 calldata 末尾开始，首先遇到真实 ExtraData 的 flag，不会越过 ExtraData 区域到达 ABI 参数内部。

**方案 B 风险：无（后向扫描免疫）。** 同理。

**注意：** 如果改为前向扫描（从 selector 向后），此风险会成为真实漏洞——伪造 flag 会被优先命中，导致分佣被绕过。这是选择后向扫描的核心安全理由。

##### 风险 4：Gas 耗尽攻击（DoS）

**威胁模型：** 攻击者构造带有超长 calldata（无 ExtraData）的交易，迫使扫描遍历整个 calldata，消耗大量 gas。

```
Gas 耗尽场景:

攻击者发送: | selector | 10KB ABI 参数（无 ExtraData）|
            扫描需遍历整个 calldata 才能确认无 flag

方案 A: ~320 次迭代 × ~33 gas = ~10,560 gas   ← swap 总 gas 的 2-7%
方案 B: ~10,236 次迭代 × ~33 gas = ~337,788 gas ← 可能超过 swap 本身

但注意：攻击者自己需要支付这些 gas，且长 calldata 本身也消耗
大量的 calldata gas（每非零字节 16 gas → 10KB ≈ 160,000 gas）。
```

**方案 A 风险：低。** 全量扫描最坏开销与 calldata 长度正比，但因 bytes32 步长，开销仅占 swap 总 gas 的一小部分。攻击者需自行承担 calldata gas 和 swap gas，无法对他人造成 DoS。

**方案 B 风险：中。** 如果不设上限，长 calldata 的扫描 gas 可能超过 swap 本身，使交易变得异常昂贵。即使设了上限，固定的 1024 次扫描也会额外消耗 ~33K gas。攻击者仍需自行承担成本，但 gas 比例失调可能影响用户体验。

##### 风险 5：对齐截取的整数运算安全

**威胁模型：** 方案 A 的对齐计算 `sub(calldataEnd, remainder)` 可能产生下溢或异常值。

```
边界值分析:

calldatasize() = 4 (仅 selector，无参数):
  remainder = (4 - 4) % 32 = 0
  scanPos = 4 - 0 = 4
  循环条件 gt(scanPos, 0x23) → gt(4, 35) = false → 不进入循环 ✓

calldatasize() = 0 (理论上不可能，至少有 selector):
  sub(0, 4) → EVM 下溢到极大值
  但实际不会发生：Solidity 函数调用至少有 4 字节 selector

calldatasize() = 36 (selector + 1 个 bytes32):
  remainder = (36 - 4) % 32 = 0
  scanPos = 36
  循环: gt(36, 35) = true → 读取 calldataload(4) → 正常 ✓
```

**方案 A 风险：无（已覆盖边界情况）。** `calldatasize() >= 4` 由 Solidity 函数路由保证。

**方案 B 风险：无。** 同样由 `calldatasize() >= 4` 保证。

##### 风险 6：方案 B 特有 — 非对齐位置的偏移误报

**威胁模型：** 方案 B 在每个字节位置检查 flag，可能在非 32 字节对齐的位置匹配到 flag 模式。由于后续代码假设 flag word 从 `effectiveEnd - 32` 开始读取，非对齐的 effectiveEnd 会导致整个解析帧偏移。

```
方案 B 非对齐误报:

字节位置:  100  101  102  103  104  105  ...  131  132
           |----|----|----|----|----|----|--..--|----|----|
           | 正常 ABI 数据 ...   [flag 模式恰好从 103 开始]

方案 B 在位置 103 命中 → effectiveEnd = 103 + 32 = 135
但 135 不是 (4 + 32*K) 的合法 ExtraData 边界
→ 后续 calldataload(sub(135, 0x20)) = calldataload(103)
→ 读到的 word 从 103 开始，跨越了两个正常 ABI word 的边界
→ 解析出的分佣费率/地址是两个 ABI 参数的拼接 → 完全错误

方案 A 不会在位置 103 检查 → 免疫此风险
```

**方案 A 风险：无。** 仅检查对齐位置，不会产生非对齐误报。

**方案 B 风险：理论上存在。** 虽然概率极低（每字节位置 ~2.8×10^-14），但一旦在非对齐位置误报，后果比对齐位置误报更严重——因为后续所有 `calldataload` 都会在错误的偏移上读取数据。

##### 风险汇总

| 风险 | 方案 A | 方案 B | 说明 |
|------|--------|--------|------|
| 后缀 flag 误匹配 | 极低（~10^-13/次） | 极低（但检查窗口 ×32） | 理论风险，非实际威胁 |
| 分佣绕过（flag 逃逸） | **无**（全量扫描） | **存在**（固定上限） | 方案 B 的结构性缺陷 |
| ABI 参数伪造 flag | **无**（后向扫描） | **无**（后向扫描） | 两者都免疫 |
| Gas 耗尽 DoS | 低（可控开销） | 中（开销可能过高） | 攻击者需自付 gas |
| 整数运算安全 | 无 | 无 | 边界已覆盖 |
| 非对齐偏移误报 | **无**（仅对齐位置） | 极低但后果更严重 | 方案 B 特有风险 |

**安全结论：** 方案 A 在所有安全维度上都优于或等于方案 B。方案 A 的主要安全优势在于：(1) 全量扫描消除了 flag 逃逸风险；(2) 对齐扫描消除了非对齐误报风险。两个方案都通过后向扫描免疫了 ABI 参数中的伪造 flag 注入。

#### 2.3.9 方案决策与 TODO

**决策：采用方案 A（后向 bytes32 对齐扫描）。**

理由：
1. **可以全量扫描**：无需设固定上限，不假设后缀长度，完全满足"不假设后缀内容/长度"的设计前提
2. **Gas 可控**：bytes32 步长使全量扫描开销仅为方案 B 的 1/32，即使 10KB calldata 也在可接受范围
3. **方案 B 存在不可调和的矛盾**：全量扫描 gas 过高 → 被迫设固定上限 → 又回到假设后缀长度的问题
4. **安全优势**：全量扫描消除 flag 逃逸风险，对齐扫描消除非对齐误报风险

**TODO 清单（指导 PLAN 编写）：**

| # | TODO | 范围 | 说明 |
|---|------|------|------|
| 1 | CommissionLib.sol — 添加 effectiveEnd 后向扫描逻辑 | `_getCommissionAndTrimInfo()` assembly 块内，`_revertWithReason` 之后、首次 `calldataload` 之前 | 实现对齐计算 + 后向 bytes32 步长扫描 + 预过滤 + 完整 8-way flag 匹配 |
| 2 | CommissionLib.sol — 替换 6 处 `calldatasize()` 锚点为 `effectiveEnd` | 第 111、162、198、227、248、278 行 | 纯文本替换，不改变解析逻辑 |
| 3 | 新增后缀容忍度单元测试 | 新测试文件 | 覆盖：有/无 ExtraData × 有/无后缀 × 各种后缀长度 |
| 4 | 新增 Fuzz 测试 | 新测试文件 | 随机后缀长度和内容，验证解析结果不变 |
| 5 | 回归验证 | 全部现有测试 | `forge test` 全部通过，确认向后兼容 |
| 6 | 合约体积验证 | 编译产物 | 体积增量 < 500 字节（PRD 成功指标 #6） |

