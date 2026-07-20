module.exports = {
    owner: "0xAcE2B3E7c752d5deBca72210141d464371b3B9b1", // DexRouter owner (pause/transferOwnership/setReporter)
    wNativeToken: "0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83",
    wNativeRelayer: "0x40aA958dd87FC8305b97f2BA922CDdCa374bcD7f",
    tokenApprove: "0x70cBb871E8f30Fc8Ce23609E9E0Ea87B6b222F58",
    tokenApproveProxy: "0xE9BBD6eC0c9Ca71d3DcCD1282EE9de4F811E50aF",
    securityManager: "0x3EB49E5C975e1CE41Bffee52D9FdFa9793d75d3D", // governs tokenApproveProxy whitelist; DEFAULT_ADMIN_ROLE = admin
    permit2: "0x000000000022D473030F116dDEE9F6B43aC78BA3",
    dexRouter: "0xf332761c673b59B21fF6dfa8adA44d78c12dEF09",
    xbridge: "0xf956D9FA19656D8e5219fd6fa8bA6cb198094138",
    investEntrance: "0x7251FEbEABB01eC9dE53ECe7a96f1C951F886Dd2",
    limitOrder: "0xA6dA84219B1d5F419Ef959F1f2A7ec7E32f45CA6",
    limitOrderV2: "0x2ae8947FB81f0AAd5955Baeff9Dcc7779A3e49F2",
    protocolAdmin: "0x06C95a3934d94d5ae5bf54731bD2840ceFee6F87",
    commisson: "0x838A5832eB19CfCe692809f5b2DE44b15380CDA2",
    _FF_FACTORY: "",
    // p2pTrading: "0xe6C2820Ba3d14d97b9e9A371771ed7A2f28A9c40",
    p2pTrading: "0x0000000017D9a0231430ff2cc3467375a9Af76C7",
    // ⚠️ OKLink source verification: this impl's published source on OKLink is WRONG (shows eth's
    // ChainConfig — _WETH 0xC02a, chainid 1) due to a since-fixed verify tool bug that compiled
    // against a stale eth ChainConfig. On-chain bytecode is correct (fantom config, proven by
    // per-byte comparison). OKLink accepted the mismatched source (it does not strict-match) and
    // LOCKS verified contracts, so it cannot be overwritten via API/forge — needs OKLink-side
    // un-verify/re-verify. See verify_via_foundry.js OKLink note.
    newImpl: "0x61e7e4936e546910658f9458ddfd785b44ec91ae",
    constructorArg: "0xAcE2B3E7c752d5deBca72210141d464371b3B9b1",
    dagRouterLibrary: "0x58b9E5Eeb472DE5417BD8a290a6882b1F234Cdb2",
    smartSwapRouterLibrary: "0x5E9036c3474e6082Aa558e6EAc7ffBa4B34cDD29",
    swapWrapRouterLibrary: "0x08c887903334Ea8046C4280177BAf48DeEcE9dFB",
    unxswapRouterLibrary: "0xf8E622D3a1734b293C3936d03d48Ac3598e84f54",
    unxswapV3RouterLibrary: "0x063222d6e09e4c1607042D4afcEF87f907AEF09D",
}
