---
name: "solidity-patterns"
description: "Solidity 编码模式——assembly 使用、位操作、代币转账模式"
---

# Solidity 编码模式

## Assembly 使用规范

### 何时使用 Assembly

- **ExtraData 解析**（ExtraDataLib, CommissionLib）: 从右到左读取 calldata 所必需
- **热路径 swap 逻辑**（UnxswapRouter._unxswapInternal）: V2 交换的 Gas 优化
- **事件发出**（CommissionLib）: Gas 高效的事件日志记录
- **余额检查**（CommonLib.getBalanceOf）: 避免不必要的内存分配

### Assembly 安全性

- [Rule] 在适用处 **must** 使用 `assembly ("memory-safe")` 注解
- [Rule] **must** 为每个 assembly 块用注释说明用途
- [Rule] **never** 向任意内存地址 `mstore`，**must** 使用 Solidity 内存分配
- [Rule] **must** 使用有意义的错误信息 revert（assembly 中使用十六进制编码）
- [Rule] Assembly Permit2 调用后 **must** 恢复空闲内存指针

---

## 位操作模式

```solidity
// [Reuse] 从 uint256 中提取地址（低 160 位）
address addr = address(uint160(param & _ADDRESS_MASK));

// [Reuse] 提取转账模式（比特位 [251:249]）
uint256 mode = param & _TRANSFER_MODE_MASK;

// [Reuse] 检查方向标志位（比特位 255）
bool reverse = (param & _REVERSE_MASK) != 0;

// [Reuse] 提取权重（比特位 [175:160]），assembly 中使用 shr
// weight := shr(160, and(rawData, _WEIGHT_MASK))
```

- [Rule] 位操作 **must** 使用预定义的 mask 常量，**never** 使用魔术数字

### Compact Receiver 地址提取

- [Rule] 从 compact 格式的 `uint256 receiver` 参数中提取地址时，**must** 先 `& _ADDRESS_MASK` 取低 160 位，**never** 直接强转 `address(uint160(receiver))`
- 原因：receiver 参数的高位可能携带标志位信息，不 mask 会导致标志位污染地址，产生错误的目标地址

```solidity
// [Reuse] 正确：先 mask 再判断是否为零地址
address receiverAddr = (receiver & _ADDRESS_MASK) == 0
    ? msg.sender
    : _bytes32ToAddress(receiver);

// ❌ 错误：直接强转，高位标志位会污染地址
address receiverAddr = address(uint160(receiver));
```

- [Pitfall] 如果 receiver 高位含有标志位（如转账模式位），不 mask 会导致转账到错误地址，造成**资金永久丢失**

---

## 命名约定

### 常量
- 以下划线为前缀: `_ETH`, `_WETH`, `_PERMIT2`, `_ADDRESS_MASK`
- 全大写加下划线: `COMMISSION_RATE_LIMIT`, `DENOMINATOR`
- 标志位常量: 描述性名称匹配用途: `FROM_TOKEN_COMMISSION_DUAL`

### 函数
- 内部/私有: 以 `_` 为前缀（`_unxswapInternal`）
- 公共入口点: 驼峰命名无前缀（`smartSwapTo`）
- 验证函数: `validate` 前缀（`validateCommissionInfo`）

### 事件
- 帕斯卡命名法: `OrderRecord`, `SwapOrderId`

### 结构体
- 帕斯卡命名法: `BaseRequest`, `RouterPath`, `ExtraData`
- 缓存结构体: `SwapCache`, `ExactOutSwapCache`, `AfterSwapParams`

---

## 代币转账模式

### 原生 ETH

- [Rule] **must** 通过 `receive() external payable`（EthReceiver）接收
- [Rule] **must** 通过 `call{value: amount, gas: NATIVE_TOKEN_TRANSFER_GAS_LIMIT}("")` 发送并检查 success
- [Reuse] WETH 包装/解包通过 `IWETH.deposit()` / `IWETH.withdraw()`

### ERC20

- [Rule] **must** 使用 `SafeERC20.safeTransfer()` / `safeTransferFrom()`
- [Rule] 授权采用先置零再设值模式
- [Rule] 转账收费代币 **must** 检查余额变化（而非返回值）

### 转账模式分发

```solidity
switch (mode) {
    case _MODE_DIRECT:             SafeERC20.safeTransferFrom(token, from, to, amount)
    case _MODE_PERMIT2_ALLOWANCE:  IPermit2.transferFrom(from, to, amount, token)
    case _MODE_LEGACY:             IApproveProxy.claimTokens(token, from, to, amount)
    case _MODE_NO_TRANSFER:        // 无操作
    case _MODE_BY_INVEST:          // token 已在路由合约中
    case _MODE_PERMIT2_SIGNATURE:  // 在 TransferLib 中单独处理
}
```
