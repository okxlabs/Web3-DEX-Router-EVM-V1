module.exports = {
    _CACHED_CHAIN_ID: 1088,
    owner: "0xAcE2B3E7c752d5deBca72210141d464371b3B9b1", // DexRouter owner (pause/transferOwnership/setReporter)
    wNativeToken: "0x75cb093E4D61d2A2e65D8e0BBb01DE8d89b53481",
    wNativeRelayer: "0xd2F0aC2012C8433F235c8e5e97F2368197DD06C7",
    tokenApprove: "0x57df6092665eb6058DE53939612413ff4B09114E",
    tokenApproveProxy: "0x1b5d39419C268b76Db06DE49e38B010fbFB5e226",
    securityManager: "0x11F7e77826B465c80A583882f5c54f5cE26EB7af", // governs tokenApproveProxy whitelist; DEFAULT_ADMIN_ROLE = admin
    permit2: "0x000000000022D473030F116dDEE9F6B43aC78BA3",
    dexRouter: "0x6b2C0c7be2048Daa9b5527982C29f48062B34D58",
    xbridge: "0xa50FD06d2b099a4B06d54177C7d3AB08D3D3F004",
    _FF_FACTORY: "",
    _POOL_INIT_CODE_HASH: "",
    investEntrance: "0x7251FEbEABB01eC9dE53ECe7a96f1C951F886Dd2",
    newImpl: "0x472fc4f7fd3c9f06f0b8637c5505815ac80938ad", // v1.0.10-rfq-anti-arbitrage; verified: https://andromeda-explorer.metis.io/address/0x472fc4f7fd3c9f06f0b8637c5505815ac80938ad?tab=contract
    proxyAdmin: "0xc6d8e2e0E5c25ACecff66BE60F257884D0e9DF50",
    constructorArg: "0xAcE2B3E7c752d5deBca72210141d464371b3B9b1",
    // Blockscout's forge-native verify path fails on these 5 (self-address-guard bytecode in
    // router libraries, same class of issue as scroll — see verify_via_foundry.js CHAINS note).
    // Verified via Sourcify's direct API instead (repo.sourcify.dev), independently confirmed exact_match.
    dagRouterLibrary: "0x4Af60d9e8fBbf02f55D16A4B364aA4281C698543", // v1.0.10-rfq-anti-arbitrage; verified via Sourcify: https://repo.sourcify.dev/contracts/full_match/1088/0x4Af60d9e8fBbf02f55D16A4B364aA4281C698543/
    smartSwapRouterLibrary: "0x92276ec9FbdFB82d64aAD348B75862a943A0655C", // v1.0.10-rfq-anti-arbitrage; verified via Sourcify: https://repo.sourcify.dev/contracts/full_match/1088/0x92276ec9FbdFB82d64aAD348B75862a943A0655C/
    swapWrapRouterLibrary: "0x6BbBaa9924d24bd71367D48874f76A52E9e649B9", // v1.0.10-rfq-anti-arbitrage; verified via Sourcify: https://repo.sourcify.dev/contracts/full_match/1088/0x6BbBaa9924d24bd71367D48874f76A52E9e649B9/
    unxswapRouterLibrary: "0x39E738Cf836e0735F578EaB04d10b5Ae518Ef808", // v1.0.10-rfq-anti-arbitrage; verified via Sourcify: https://repo.sourcify.dev/contracts/full_match/1088/0x39E738Cf836e0735F578EaB04d10b5Ae518Ef808/
    unxswapV3RouterLibrary: "0xD239cBE1366deaE4025206Ce57A24DAd2BB1fe02", // v1.0.10-rfq-anti-arbitrage; verified via Sourcify: https://repo.sourcify.dev/contracts/full_match/1088/0xD239cBE1366deaE4025206Ce57A24DAd2BB1fe02/
}
