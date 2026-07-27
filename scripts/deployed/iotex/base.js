module.exports = {
    owner: "0xAcE2B3E7c752d5deBca72210141d464371b3B9b1", // DexRouter owner (pause/transferOwnership/setReporter)
    wNativeToken: "0xA00744882684C3e4747faEFD68D283eA44099D03",
    wNativeRelayer: "0xd2F0aC2012C8433F235c8e5e97F2368197DD06C7",
    tokenApprove: "0x57df6092665eb6058DE53939612413ff4B09114E",
    tokenApproveProxy: "0x1b5d39419C268b76Db06DE49e38B010fbFB5e226",
    securityManager: "0x4Db0c358844f75205DbBD57c2BD982145Ad2D530", // governs tokenApproveProxy whitelist; DEFAULT_ADMIN_ROLE = admin
    permit2: "0x000000000022D473030F116dDEE9F6B43aC78BA3",
    dexRouter: "0x6b2C0c7be2048Daa9b5527982C29f48062B34D58",
    xbridge: "",
    //nftmarket: "",
    investEntrance: "",
    limitOrder: "",
    protocolAdmin: "",
    _FF_FACTORY: "",
    _CACHED_DOMAIN_SEPARATOR: "",
    _HASHED_NAME: "",
    _HASHED_VERSION: "",
    _TYPE_HASH: "",
    _CACHED_CHAIN_ID: 4689,
    commisson: "",
    nftmarketplace: "",
    // p2pTrading: "",
    p2pTrading: "",

    // ROOT CAUSE FOUND (2026-07-27): the "partial match" was an artifact of forge's NATIVE
    // `--verifier sourcify` integration (used automatically because iotex's CHAINS entry says
    // verifier:'sourcify', not 'sourcify-api') — it submits via a legacy path that Sourcify's
    // matcher scores as partial even for byte-correct code. Resubmitting the exact same
    // standard-json directly to Sourcify's v2 API (scripts/deploy/sourcify.js's approach,
    // already used for scroll/manta/ftm/cro/pharos) flipped this to exact_match with zero
    // code changes — confirming it was purely a submission-protocol gap, not a real mismatch.
    newImpl: "0x8d44d0ab0eeba9923850a864d8c6f85b84fb02bb", // v1.0.10-rfq-anti-arbitrage; verified via Sourcify: https://repo.sourcify.dev/4689/0x8d44d0ab0eeba9923850a864d8c6f85b84fb02bb/
    constructorArg: "0xAcE2B3E7c752d5deBca72210141d464371b3B9b1",
    dagRouterLibrary: "0xd007141847c608D3a9FA904b674Ac8BE366F690f", // v1.0.10-rfq-anti-arbitrage; verified via Sourcify: https://repo.sourcify.dev/4689/0xd007141847c608D3a9FA904b674Ac8BE366F690f/
    smartSwapRouterLibrary: "0x83bD325318c832B8E70B77F2A65dC4d2c1D24476", // v1.0.10-rfq-anti-arbitrage; verified via Sourcify: https://repo.sourcify.dev/4689/0x83bD325318c832B8E70B77F2A65dC4d2c1D24476/
    swapWrapRouterLibrary: "0xC92779e260b6B3c164454764C17Ea07816790a8F", // v1.0.10-rfq-anti-arbitrage; verified via Sourcify: https://repo.sourcify.dev/4689/0xC92779e260b6B3c164454764C17Ea07816790a8F/
    unxswapRouterLibrary: "0x42581A9E5430Fd87D1EbfaB7d50b35988025e4E4", // v1.0.10-rfq-anti-arbitrage; verified via Sourcify: https://repo.sourcify.dev/4689/0x42581A9E5430Fd87D1EbfaB7d50b35988025e4E4/
    unxswapV3RouterLibrary: "0x5FF3B7e0e0A4F519c8bb602Cd089ae2C3Ff489B2", // v1.0.10-rfq-anti-arbitrage; verified via Sourcify: https://repo.sourcify.dev/4689/0x5FF3B7e0e0A4F519c8bb602Cd089ae2C3Ff489B2/
}