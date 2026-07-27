module.exports = {
    _CACHED_CHAIN_ID: 137,
    owner: "0xAcE2B3E7c752d5deBca72210141d464371b3B9b1", // DexRouter owner (pause/transferOwnership/setReporter)
    wNativeToken: "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270",
    wNativeRelayer: "0xf332761c673b59B21fF6dfa8adA44d78c12dEF09",
    tokenApprove: "0x3B86917369B83a6892f553609F3c2F439C184e31",
    tokenApproveProxy: "0x40aA958dd87FC8305b97f2BA922CDdCa374bcD7f",
    securityManager: "0xf535C7E73364D882d45C0fAB62BdAFcb3C5f17F4", // governs tokenApproveProxy whitelist; DEFAULT_ADMIN_ROLE = admin
    permit2: "0x000000000022D473030F116dDEE9F6B43aC78BA3",
    dexRouter: "0xA748D6573acA135aF68F2635BE60CB80278bd855",
    xbridge: "0x89f423567c2648BB828c3997f60c47b54f57Fa6e",
    //nftmarket: "0x6236f99fc0a37D7063a9892ee432aEcC320f5d9A",
    investEntrance: "0x7251FEbEABB01eC9dE53ECe7a96f1C951F886Dd2",
    limitOrder: "0xA6dA84219B1d5F419Ef959F1f2A7ec7E32f45CA6",
    //limitOrderV2: "0x88D6067D21Bb69198E081FE7FF270E94975065C7",
    limitOrderV2: "0x2ae8947FB81f0AAd5955Baeff9Dcc7779A3e49F2",
    protocolAdmin: "0x06C95a3934d94d5ae5bf54731bD2840ceFee6F87",
    _FF_FACTORY: "0xff1F98431c8aD98523631AE4a59f267346ea31F9840000000000000000000000",
    commisson: "0x838A5832eB19CfCe692809f5b2DE44b15380CDA2",
    // p2pTrading: "0xe6C2820Ba3d14d97b9e9A371771ed7A2f28A9c40",
    p2pTrading: "0x0000000017D9a0231430ff2cc3467375a9Af76C7",
    nftmarketplace: "0xa7FD99748cE527eAdC0bDAc60cba8a4eF4090f7c",

    newImpl: "0x3c4829196bfadff4394726b45159aeaac6fcd41c", // v1.0.10-rfq-anti-arbitrage; verified: https://polygonscan.com/address/0x3c4829196bfadff4394726b45159aeaac6fcd41c#code
    constructorArg: "0xAcE2B3E7c752d5deBca72210141d464371b3B9b1",
    dagRouterLibrary: "0xEbd3fd3e6aa2B29f4B749756c42B50c59E09CB81", // v1.0.10-rfq-anti-arbitrage; verified: https://polygonscan.com/address/0xebd3fd3e6aa2b29f4b749756c42b50c59e09cb81#code
    smartSwapRouterLibrary: "0xa6D9e17184e4a738eb6E3Ee9dC14768e9B86C157", // v1.0.10-rfq-anti-arbitrage; verified: https://polygonscan.com/address/0xa6d9e17184e4a738eb6e3ee9dc14768e9b86c157#code
    swapWrapRouterLibrary: "0x72a3719f24C1127Bf35C1C57575E2ab1086CB4Fb", // v1.0.10-rfq-anti-arbitrage; verified: https://polygonscan.com/address/0x72a3719f24c1127bf35c1c57575e2ab1086cb4fb#code
    unxswapRouterLibrary: "0x18A366f68E3723a72E9725AffBe8D2442d253423", // v1.0.10-rfq-anti-arbitrage; verified: https://polygonscan.com/address/0x18a366f68e3723a72e9725affbe8d2442d253423#code
    unxswapV3RouterLibrary: "0x23B0359660f87c509852Fb75B59033800c434361", // v1.0.10-rfq-anti-arbitrage; verified: https://polygonscan.com/address/0x23b0359660f87c509852fb75b59033800c434361#code
}