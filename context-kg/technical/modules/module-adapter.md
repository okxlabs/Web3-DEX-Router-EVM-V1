---
name: "module-adapter"
description: "适配器层模块设计——190+ 个 DEX 协议集成"
---

# Module: Adapter Layer

## 职责

实现具体 DEX 协议（UniswapV2/V3/V4、Curve、Balancer、PancakeSwap 等）的代币交换逻辑。

不负责：路由策略（路由库）、佣金/正滑点（CommissionLib）、calldata 解析（ExtraDataLib）。

## 核心接口

```solidity
interface IAdapter {
    function sellBase(address to, address pool, bytes memory data) external;
    function sellQuote(address to, address pool, bytes memory data) external;
}
```

- `sellBase()` = 正向交换
- `sellQuote()` = 反向交换
- 通过 `CommonLib.exeAdapter()` 调用，该函数在 calldata 后追加 `ORIGIN_PAYER + refundTo`

## 适配器范围

190+ 个适配器，覆盖：Uniswap V2/V3/V4、Curve、Balancer、PancakeSwap、SushiSwap、DODO、TraderJoe、GMX、Aave、Compound 等。

## 依赖关系

- 参考 [arch/dependency.md](../arch/dependency.md)

## 踩坑点

- [Pitfall] UniV3 池流动性耗尽时未消耗的输入滞留在 DexRouter 中，**must** 添加退款逻辑
- [Pitfall] LaunchPad（FourMeme、Aspecta、Virtuals）有购买上限，超出部分滞留在 DexRouter 中
- [Pitfall] FourMeme 8004 代币需要两步交易（铸造 NFT + 购买），单次 DexRouter 调用无法覆盖
- [Pitfall] 转账收费代币（SafeMoon 等）**must** 使用余额差异检查，**never** 信任返回值
