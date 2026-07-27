module.exports = {
    owner: "0xAcE2B3E7c752d5deBca72210141d464371b3B9b1", // DexRouter owner (pause/transferOwnership/setReporter)
    wNativeToken: "0x3bd359C1119dA7Da1D913D1C4D2B7c461115433A", // WMON
    wNativeRelayer: "0xbf71EBcfd56DcbAbb21d5da693F6dfecc9BDAe5E",
    tokenApprove: "0xf534A8a1CAD0543Cd6438f7534CA3486c01998d4",
    tokenApproveProxy: "0xdce40846CAbaED9064A3bf5A7445235dB8fF0fF3",
    securityManager: "0xBC7cACBC2527158e2C1c9C90796b3e2C35DDDc0c", // governs tokenApproveProxy whitelist; DEFAULT_ADMIN_ROLE = admin
    permit2: "0x000000000022D473030F116dDEE9F6B43aC78BA3",
    dexRouter: "0xb1E4E25b1938c78Ec0b21cCb2D6a0Be60aA7E63f",
    xbridge: "",
    investEntrance: "",
    _FF_FACTORY: "0xff204faca1764b154221e35c0d20abb3c5257104980000000000000000000000", // uniswap v3 fork, not the canonical UniV3 factory
    _CACHED_CHAIN_ID: 143,
    commisson: "",
    // ROOT CAUSE FOUND (2026-07-27): the "partial match" was an artifact of forge's NATIVE
    // `--verifier sourcify` integration (used automatically because monad's CHAINS entry says
    // verifier:'sourcify', not 'sourcify-api'). Resubmitting the exact same standard-json
    // directly to the v2 API (scripts/deploy/sourcify.js's approach) flipped this to
    // exact_match (both creation and runtime) with zero code changes. NOTE: monad's verifier
    // (sourcify-api-monad.blockvision.org) is its OWN separate Sourcify-compatible instance,
    // NOT the canonical sourcify.dev — the verified source is browsable on monadvision.com
    // (BlockVision's monad explorer), not repo.sourcify.dev (that domain has no record of it).
    newImpl: "0xc1c76e784db8d68585fb608ce68fc5dcff14000e", // v1.0.10-rfq-anti-arbitrage; verified (exact_match, both creation+runtime): https://monadvision.com/address/0xc1C76E784Db8D68585fb608ce68FC5DcFF14000E?tab=Contract
    proxyAdmin: "",
    constructorArg: "0xAcE2B3E7c752d5deBca72210141d464371b3B9b1",
    dagRouterLibrary: "0x6E6107E49eD64241D662554536859F02069581B8", // v1.0.10-rfq-anti-arbitrage; verified (exact_match): https://monadvision.com/address/0x6E6107E49eD64241D662554536859F02069581B8?tab=Contract
    smartSwapRouterLibrary: "0x9704641eF363C94c0b3BBC9Bf4aD2F4875B0567E", // v1.0.10-rfq-anti-arbitrage; verified (exact_match): https://monadvision.com/address/0x9704641eF363C94c0b3BBC9Bf4aD2F4875B0567E?tab=Contract
    swapWrapRouterLibrary: "0x72A4363E28783A0aa9FFC169390151DFCbAb62CB", // v1.0.10-rfq-anti-arbitrage; verified (exact_match): https://monadvision.com/address/0x72A4363E28783A0aa9FFC169390151DFCbAb62CB?tab=Contract
    unxswapRouterLibrary: "0x79C37c11b4Ba7ADA256930DF0B7fa38e8bA88f7e", // v1.0.10-rfq-anti-arbitrage; verified (exact_match): https://monadvision.com/address/0x79C37c11b4Ba7ADA256930DF0B7fa38e8bA88f7e?tab=Contract
    unxswapV3RouterLibrary: "0x3f515a7f0f5c59DDcBF3143266Fa8cfeCafEC431", // v1.0.10-rfq-anti-arbitrage; verified (exact_match): https://monadvision.com/address/0x3f515a7f0f5c59DDcBF3143266Fa8cfeCafEC431?tab=Contract
}