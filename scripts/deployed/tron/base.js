module.exports = {
    // DexRouter owner (privileged: pause / transferOwnership / setReporter). Read by
    // deploy_dexrouter_tron.js and passed as the constructor arg. TRON-SPECIFIC owner — NOT
    // the EVM prod owner 0xAcE2B3E7… (that address is controllable on EVM but is the wrong
    // governance key for TRON).
    // newImpl below was (re)deployed 2026-07-10 with THIS owner (confirmed on-chain via
    // owner() == 0xd491C007…). The earlier impl TYUDG8… (0xf6Cf0c…), deployed with the wrong
    // EVM owner, is abandoned on-chain and must NOT be whitelisted.
    owner: "0xd491C007D2B6250c3a6aa4415914346e035a3944", // TVMArd5cm9piDca8T6TsWdDHK4C3BjES1b
    wNativeToken: "0x891cdb91d149f23B1a45D9c5Ca78a88d0cB44C18",
    wNativeRelayer: "0xE2c927B0B939AadB945668b012ec3BB6cdD722EA",
    tokenApprove: "0x51b160bb02261c822b33e61c6b947f275144545e",
    tokenApproveProxy: "0xEbEE8FAa7909dFB1dF0bC4B797672D30eA30b568",
    securityManager: "TAfXazrE92d7BDQPLRAQefTMXrsnGDRqdr", // governs tokenApproveProxy whitelist; DEFAULT_ADMIN_ROLE = admin
    permit2: "0xBE365314f2E77FD1257d60C346Bb32DbDa369403", // TRON Permit2 (TTJxU3P8rHycAyFY4kVtGNfmnMH4ezcuM9), verified full Permit2 interface; NOT the EVM-canonical 0x00..78BA3 (which has no contract on TRON)
    // Intentionally empty (-> zero _FF_FACTORY): no UniswapV3-compatible factory for the
    // UnxswapV3 CREATE2 fast-path on TRON. v1.0.8 hardcoded the ETH UniV3 factory
    // (0x1F98..F984), but that address has no contract on TRON, so that path was already
    // dead. Set this only if a real UniV3-compatible DEX (+ matching pool init code hash)
    // exists on TRON and should be reachable via uniswapV3SwapTo.
    _FF_FACTORY: "",
    dexRouter: "0x24B3471Ff199D4E23F286a541e9dde82dFa5C5Ab",
    xbridge: "0xd716521da2c3993F46F4eD7Cf3566C59e59BB20F",
    //nftmarket: "",
    investEntrance: "",
    marketMaker: "",
    pmmAdapter: "",
    protocolAdmin: "",
    // Deployed contract addresses recorded in EVM hex (0x) form for cross-chain consistency;
    // the // comment is the TRON-native base58 (T…) address as shown on TronScan. Both are the
    // same 20-byte account (base58 = Base58Check of 0x41 ++ hex).
    //
    // v1.0.10 redeploy, executed 2026-07-27: DagRouter/SmartSwapRouter/DexRouter deployed fresh
    // (only these call/are affected by CommonLib.exeAdapter's DEX_ROUTER_CALLER_MARKER
    // injection); SwapWrapRouter/UnxswapRouter/UnxswapV3Router reused unchanged. Post-deploy
    // verified: on-chain code byte-identical (metadata-normalized) to local tron-solc compile
    // for all 3 new addresses. Boss addProxy still pending.
    newImpl: "0xc06b174251d965b91afd70021cac19d62e966bc1", // TTWd2hBKmEmYiCXtm4TiZ1FjzVQJaVm8N4 — v1.0.10-rfq-anti-arbitrage; verified: https://tronscan.org/contract/TTWd2hBKmEmYiCXtm4TiZ1FjzVQJaVm8N4/code
    dagRouterLibrary: "0xfc803d5d2773a09163972251f0efe7456d94fa6b", // TYzJueiGFzJFosQ9jaibze2oB5aHCwgene
    smartSwapRouterLibrary: "0xe5e84208ceb58e3fc5883929f460a5e021a91ff5", // TWvqyZ3JhDL73ifdcaQwHY21nUXzttfKvn
    swapWrapRouterLibrary: "0xD0f82e338dE0d95A85846651de993Ea4d1768Dc7", // TV28rqkeKDzTbiXyg5uLPaFaiUqvLETUun — reused, byte-identical to v1.0.9
    unxswapRouterLibrary: "0xE4C7CECCc16ECE0b0B124d85Ea44315b4A6247D2", // TWptRgmaujPUHxdjCCwnhckfRHERZxXHwZ — reused, byte-identical to v1.0.9
    unxswapV3RouterLibrary: "0x537630758D5F540f7F00FAF28f546631386C3930", // THaWfv96SHuwY1h1fmp7fBRNdGYWKhxLZ1 — reused, byte-identical to v1.0.9
    constructorArg: "0xd491C007D2B6250c3a6aa4415914346e035a3944",
}
