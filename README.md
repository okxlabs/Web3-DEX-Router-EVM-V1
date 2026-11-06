# Dex Router EVM v1.0.10

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

This repository contains the public Solidity sources for DexRouter. The current router reports `v1.0.10-rfq-anti-arbitrage` from `version()`.

## Layout

- `contracts/8/DexRouter.sol`: the router entry point.
- `contracts/8/router/`: the five linked routing libraries.
- `contracts/8/libraries/` and `contracts/8/interfaces/`: supporting code and interfaces.
- `contracts/8/adapter/`: the public adapter sources.
- `DexRouterabi/DexRouter.json`: the compiled v1.0.10 contract artifact.
- `test/dexRouter/V110Smoke.t.sol`: a version and ownership smoke test.

The old root-level routing libraries and ExactOut contracts used the v1.0.7 router interface and are not part of this release. The current routing libraries live under `contracts/8/router/`.

## Build and test

Install the package dependencies and the `forge-std` submodule, then compile:

```bash
npm ci
git submodule update --init --recursive
forge build
forge test --match-path test/dexRouter/V110Smoke.t.sol
```

The committed `contracts/8/libraries/ChainConfig.sol` contains public Ethereum example addresses so the sources compile. Set the chain-specific wrapped native token, approval proxy, Permit2 address, V3 factory, owner, and expected chain ID before deploying to another network. `foundry.toml` uses Solidity 0.8.17, 200 optimizer runs, and the London EVM target for this router version.

## License

MIT. See [LICENSE](LICENSE).
