module.exports = {
    _CACHED_CHAIN_ID: 10001,
    owner: "0xAcE2B3E7c752d5deBca72210141d464371b3B9b1", // DexRouter owner (pause/transferOwnership/setReporter)
    wNativeToken: "0x7Bf88d2c0e32dE92CdaF2D43CcDc23e8Edfd5990",
    wNativeRelayer: "0x4D8d82F269A2704867b6cAf58d6e8389e3066eC9",
    tokenApprove: "0x40aA958dd87FC8305b97f2BA922CDdCa374bcD7f",
    tokenApproveProxy: "0x70cBb871E8f30Fc8Ce23609E9E0Ea87B6b222F58",
    _FF_FACTORY: "", // uniswap v3 factory not deployed on ETHW
    // human checked wnative and wnative relayer and tokenApprove and _FF_FACTORY is correct
    securityManager: "0xa990fb4a7A174D290259464C47ED7f5d7310f03D", // governs tokenApproveProxy whitelist; DEFAULT_ADMIN_ROLE = admin
    permit2: "0x000000000022D473030F116dDEE9F6B43aC78BA3",
    dexRouter: "0x51B6812B030a19cF801be8C4B41748488A7e1D60",
    xbridge: "0xFc99f58A8974A4bc36e60E2d490Bb8D72899ee9f",
    //nftmarket: "0x191b0e61ccBf3B26df76ca4321D9dEE4C960E91E",
    investEntrance: "0x7251FEbEABB01eC9dE53ECe7a96f1C951F886Dd2",
    marketMaker: "0x55b35bF627944396f9950dD6BDdaDb5218110c76",
    pmmAdapter: "0x19440199101Fb45882d06Ee432437eC89f406248",
    commisson: "0x838A5832eB19CfCe692809f5b2DE44b15380CDA2",
    // v1.0.10-rfq-anti-arbitrage redeploy (2026-07-26) confirmed via check-impl + on-chain
    // version(). DexRouter itself verified via OKLink; the 5 libraries below genuinely FAILED
    // OKLink verification ("No contract could be verified with provided data" — independently
    // confirmed via checkverifystatus, not just the pipeline's misleading "all verified" log) —
    // same self-address-guard-bytecode class of issue as scroll/metis's libraries, but ethw's
    // chainId (10001) is NOT Sourcify-supported ("unsupported_chain"), so there is currently no
    // working fallback verifier for these 5. check-impl already confirms bytecode correctness
    // independent of this open-source gap.
    newImpl: "0x472fc4f7fd3c9f06f0b8637c5505815ac80938ad", // v1.0.10-rfq-anti-arbitrage; verified via OKLink: https://www.oklink.com/ethw/address/0x472fc4f7fd3c9f06f0b8637c5505815ac80938ad
    constructorArg: "0xAcE2B3E7c752d5deBca72210141d464371b3B9b1",
    dagRouterLibrary: "0x2051FBAd256261E8C07F9617AbEE09704C229d10", // v1.0.10-rfq-anti-arbitrage; NOT verified — OKLink "Fail - Unable to verify", no Sourcify fallback for chainId 10001
    smartSwapRouterLibrary: "0x70FA171420227463810CB4533fBC3639b6b66980", // v1.0.10-rfq-anti-arbitrage; NOT verified — OKLink "Fail - Unable to verify", no Sourcify fallback for chainId 10001
    swapWrapRouterLibrary: "0x9D6756234b14F9ec5EafCa17Ceb07EbAA95a9bD7", // v1.0.10-rfq-anti-arbitrage; NOT verified — OKLink "Fail - Unable to verify", no Sourcify fallback for chainId 10001
    unxswapRouterLibrary: "0x9751cD06f5969DacF3e5Ab82BfE89519373967F9", // v1.0.10-rfq-anti-arbitrage; NOT verified — OKLink "Fail - Unable to verify", no Sourcify fallback for chainId 10001
    unxswapV3RouterLibrary: "0x387A458827F888fe5576DBD61502db59301C5b71", // v1.0.10-rfq-anti-arbitrage; NOT verified — OKLink "Fail - Unable to verify", no Sourcify fallback for chainId 10001
}
