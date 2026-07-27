// NOTE: `dexRouter` below (0x9bf3f6...) is the OLD legacy live implementation, built from
// feat/deploy-v1.0.8's source (v1.0.8-suffix-compat) — a single monolithic contract with no
// constructor/owner and no separately-linked router libraries. `newImpl` was superseded by a
// real v1.0.10 deploy (dexRouterCaller marker) via the standard src/deploy/DeployDexRouter.s.sol
// pipeline: proper PausableModuleV2 owner, externally-linked DagRouter/SmartSwapRouter/
// UnxswapRouter/UnxswapV3Router/SwapWrapRouter libraries, check-impl passes, on-chain
// version()/owner() confirmed. `dexRouter` stays the v1.0.8 address until go-live (Boss
// whitelists newImpl).
module.exports = {
    owner: "0xAcE2B3E7c752d5deBca72210141d464371b3B9b1", // DexRouter owner (pause/transferOwnership/setReporter) — enforced by newImpl; NOT enforced by the legacy dexRouter below
    wNativeToken: "0x4200000000000000000000000000000000000006", // WETH (OP-Stack predeploy)
    wNativeRelayer: "0xc1C76E784Db8D68585fb608ce68FC5DcFF14000E", // owner: admin
    tokenApprove: "0xd72f9Af181A0eB1B8550a00124ECdb71Bb758C89", // owner: admin
    tokenApproveProxy: "0xa8D102a83e1C9b19142EC857Cda5f2d2142Ea840", // owner: securityManager
    securityManager: "0xE23Ccd8D201e8dCd42e201E1Db7ba423EdC4c54b", // governs tokenApproveProxy whitelist; DEFAULT_ADMIN_ROLE = admin
    permit2: "0x000000000022D473030F116dDEE9F6B43aC78BA3", // canonical Permit2, confirmed deployed on-chain (codesize 9152) — field was missing, causing _PERMIT2=0x0 in the prior newImpl below
    dexRouter: "0x9bf3f60252be1a2fd3ed38086ed3d02b25b4eead", // v1.0.8-suffix-compat (feat/deploy-v1.0.8), used directly - non-proxy; live until newImpl is whitelisted
    xbridge: "",
    investEntrance: "",
    _FF_FACTORY: "",
    _CACHED_CHAIN_ID: 57073,
    commisson: "",
    // Redeployed 2026-07-27: original v1.0.10 impl above was missing `permit2` in base.js
    // (baked in _PERMIT2=0x0 despite Permit2 being genuinely deployed on-chain) — fixed and
    // redeployed. Confirmed via Blockscout additional_sources: _PERMIT2 = canonical address,
    // chainId 57073.
    newImpl: "0x8f98a825ac89501afe33299ddb561829a24c0cc4", // v1.0.10-rfq-anti-arbitrage; check-impl passed, on-chain version() confirmed; verified: https://explorer.inkonchain.com/address/0x8f98a825ac89501afe33299ddb561829a24c0cc4?tab=contract
    proxyAdmin: "",
    constructorArg: "0xAcE2B3E7c752d5deBca72210141d464371b3B9b1",
    dagRouterLibrary: "0xD55cC2074878E3B53C6F181D1d5b7DE7160AFc18", // v1.0.10-rfq-anti-arbitrage; verified: https://explorer.inkonchain.com/address/0xd55cc2074878e3b53c6f181d1d5b7de7160afc18?tab=contract
    smartSwapRouterLibrary: "0x4c1f99951bF093DE7E80e763AA43eacC06F806B4", // v1.0.10-rfq-anti-arbitrage; verified: https://explorer.inkonchain.com/address/0x4c1f99951bf093de7e80e763aa43eacc06f806b4?tab=contract
    swapWrapRouterLibrary: "0x012313255ED6EE17717be1edc22a39E25b9Cf186", // v1.0.10-rfq-anti-arbitrage; verified: https://explorer.inkonchain.com/address/0x012313255ed6ee17717be1edc22a39e25b9cf186?tab=contract
    unxswapRouterLibrary: "0x6e98522D966E8EBbb5C9A07c9EF4266BD1e41eF4", // v1.0.10-rfq-anti-arbitrage; verified: https://explorer.inkonchain.com/address/0x6e98522d966e8ebbb5c9a07c9ef4266bd1e41ef4?tab=contract
    unxswapV3RouterLibrary: "0xa1A4847CF2037D9d054b104c4626a6FE479a42dA", // v1.0.10-rfq-anti-arbitrage; verified: https://explorer.inkonchain.com/address/0xa1a4847cf2037d9d054b104c4626a6fe479a42da?tab=contract
}
