# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Web3-DEX-EVM is a production DEX (Decentralized Exchange) router/aggregator supporting 80+ protocols across 30+ EVM chains. Built with Solidity 0.8.17 using Foundry and Hardhat.

## Build & Test Commands

```bash
# Build
forge build                                          # Foundry build
npx hardhat --config hardhat.config.js compile       # Hardhat build

# Test
forge test                                           # Run all tests
forge test --match-test testFunctionName            # Run specific test
forge test --match-contract ContractName            # Run tests in specific contract
forge test -vvv                                      # Verbose output with traces

# Format & Lint
npm run prettier:solidity                            # Format Solidity files
npm run size                                         # Check contract sizes

# Deploy (Foundry scripts in src/deploy/)
forge script src/deploy/DeployDexRouter.s.sol --rpc-url <chain> --broadcast
```

## Architecture

### Entry Point
**DexRouter.sol** (`contracts/8/DexRouter.sol`) - Main router contract that delegates to library-based routers:
- `smartSwapByOrderId()` / `smartSwapTo()` - Batch-based smart swaps
- `dagSwapByOrderId()` / `dagSwapTo()` - DAG-based routing swaps
- Uniswap V2/V3 specific functions via UnxswapRouter libraries

### Core Data Structures (IDexRouter.sol)
```solidity
struct BaseRequest {
  uint256 fromToken;      // Source token (uint256 for native ETH handling)
  address toToken;
  uint256 fromTokenAmount;
  uint256 minReturnAmount;
  uint256 deadLine;
}

struct RouterPath {
  address[] mixAdapters;  // Adapter contracts to use
  address[] assetTo;      // Intermediate destinations
  uint256[] rawData;      // Encoded swap parameters
  bytes[] extraData;      // Additional protocol-specific data
  uint256 fromToken;
}

struct ExtraData {
  CommissionInfo commissionInfo;
  TrimInfo trimInfo;
  Permit2Info permit2Info;
  address refundTo;
}
```

### Router Libraries (`contracts/8/router/`)
All routing logic lives in libraries (not contracts) for code reuse:
- **SmartSwapRouter** - Batch execution with split amounts across paths
- **DagRouter** - Directed Acyclic Graph routing for complex routes
- **UnxswapRouter** / **UnxswapV3Router** - Uniswap V2/V3 exact input
- **UnxswapExactOutRouter** / **UnxswapV3ExactOutRouter** - Exact output swaps

### Adapter System (`contracts/8/adapter/`)
190 adapter contracts implementing `IAdapter` interface. Each adapter wraps a specific DEX protocol (Uniswap, Curve, Balancer, PancakeSwap, etc.) with a standardized swap interface.

### Supporting Libraries (`contracts/8/libraries/`)
- **CommissionLib** - Referral commissions and fee handling
- **TransferLib** - Safe token transfers and native ETH
- **ExtraDataLib** - Decodes calldata for commissions, permits, refunds
- **SafeERC20** - Safe token operations

### Approval System
- **TokenApprove** / **TokenApproveProxy** - Centralized approval management

## Key Directories

```
contracts/8/           # Main Solidity contracts
  adapter/            # 190 DEX protocol adapters
  interfaces/         # Protocol interfaces (IDexRouter, IAdapter, etc.)
  libraries/          # Utility libraries
  router/             # Routing library implementations
src/
  deploy/             # Foundry deployment scripts (90+ scripts)
  tests/              # Foundry tests (.t.sol files)
lib/                  # Forge dependencies (forge-std, permit2)
```

## Multi-Chain Support

Foundry config (`foundry.toml`) has RPC endpoints for 30+ chains including Ethereum, Arbitrum, Base, BSC, Optimism, Polygon, Scroll, zkSync, Monad. Deployment scripts support all chains.

## Dependencies

- OpenZeppelin Contracts v4.5.0/v4.7.0 (upgradeable)
- Uniswap Permit2 for signature-based transfers
- Foundry (forge-std)
- ZkSync deployment tools (hardhat-zksync)
