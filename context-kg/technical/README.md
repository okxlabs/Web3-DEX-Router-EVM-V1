---
name: "technical"
description: "DexRouter 技术知识域索引"
---

# 技术知识域

## 目录索引

| 文件/目录 | 说明 |
|---|---|
| knowledge-base.md | 主规则和全局约束（最高权威，冲突时以此为准） |
| terminology.md | 领域术语表（统一命名映射） |
| arch/ | 架构设计、分层规则、依赖方向 |
| modules/ | 各核心模块设计文档 |
| pitfalls/ | 线上踩坑经验（价值密度最高） |
| core-flows/ | 核心业务流程与状态流转 |
| apis/ | 智能合约接口规范 |
| conventions/ | 编码约定与可复用模式 |

## 技术栈

- **语言**: Solidity 0.8.17
- **框架**: Foundry (forge) + Hardhat
- **EVM 目标**: paris（合并后、上海升级前——无 PUSH0）
- **架构模式**: 基于库的入口点（非代理/delegatecall）
- **部署**: 30+ 条 EVM 链
