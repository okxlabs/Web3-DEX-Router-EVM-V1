---
name: "testing-patterns"
description: "测试约定——框架、文件组织、命名模式"
---

# 测试约定

## 测试框架

- [Rule] **must** 使用 Foundry（forge test）用于所有合约测试
- 测试文件: `src/tests/**/*.t.sol`
- Fork 测试: 使用主网/链 fork 进行集成测试

---

## 测试组织

```
src/tests/
  common/                    # 共享测试辅助工具
    BaseTestSetup.t.sol      # 基础设置，包含 WETH、代币、DexRouter
    CommissionHelper.t.sol   # 佣金测试工具
    TrimHelper.t.sol         # 正滑点测试工具
    Permit2Helper.t.sol      # Permit2 测试工具
  adapter/
    base/                    # 抽象适配器测试
    test/                    # 具体适配器测试（基于 fork）
  commission/                # 佣金专项测试
  multiCommission/           # 多推荐人佣金测试
  trim/                      # 正滑点专项测试
  exactout/                  # 精确输出交换测试
  extradata/                 # ExtraData 解析测试
  transferMode/              # 转账模式专项测试
  receiver/                  # 接收者地址处理测试
  fix/                       # 缺陷修复回归测试
  TemplateAdapter/           # 适配器模板测试
```

---

## 测试命名

- [Rule] 模式 **must** 为: `test_[功能]_[场景]_[变体]`
- 示例: `test_multiCommission_smartSwapTo_WETH2USDT_3toCommission_2trim`

---

## 部署约定

### Foundry 脚本

- 位置: `src/deploy/*.s.sol`
- 模式: `forge script src/deploy/DeployXxx.s.sol --rpc-url <chain> --broadcast`

### Hardhat 脚本

- 位置: `scripts/deploy/deploy_dex_imp.js`, `scripts/adapter/*.js`
- 链配置: `scripts/deployed/<chain>/base.js`
- 记录保存: `scripts/deployed_record/all_in_one_record.json`

### 多链部署

- [Rule] 30+ 条链在 `foundry.toml` 和 `hardhat.config.js` 中配置
- [Rule] zkSync **must** 使用 `hardhat-zksync` 部署
- [Rule] 部署前 **must** 验证 Constants.sol 中的链专属地址
