module.exports = {
    owner: "0xAcE2B3E7c752d5deBca72210141d464371b3B9b1", // DexRouter owner (pause/transferOwnership/setReporter)
    wNativeToken: "0x78c1b0C915c4FAA5FffA6CAbf0219DA63d7f4cb8",
    wNativeRelayer: "0x693EDf0068c24743ad1f36122c8e6D9aCDFD349e",
    tokenApprove: "0x57df6092665eb6058DE53939612413ff4B09114E",
    tokenApproveProxy: "0x1b5d39419C268b76Db06DE49e38B010fbFB5e226",
    securityManager: "0x235f308f434D6451D8078Aa3A4D5D67559e72204", // governs tokenApproveProxy whitelist; DEFAULT_ADMIN_ROLE = admin
    permit2: "0x000000000022D473030F116dDEE9F6B43aC78BA3",
    dexRouter: "0x6b2C0c7be2048Daa9b5527982C29f48062B34D58",
    xbridge: "0xf956D9FA19656D8e5219fd6fa8bA6cb198094138",
    //nftmarket: "",
    investEntrance: "0x7251FEbEABB01eC9dE53ECe7a96f1C951F886Dd2",
    limitOrder: "",
    protocolAdmin: "0x06C95a3934d94d5ae5bf54731bD2840ceFee6F87",
    _FF_FACTORY: "",
    _CACHED_DOMAIN_SEPARATOR: "",
    _HASHED_NAME: "",
    _HASHED_VERSION: "",
    _TYPE_HASH: "",
    _CACHED_CHAIN_ID: 5000,
    commisson: "0x838A5832eB19CfCe692809f5b2DE44b15380CDA2",
    p2pTrading: "0x0000000017D9a0231430ff2cc3467375a9Af76C7",
    newImpl: "0x472fc4f7fd3c9f06f0b8637c5505815ac80938ad", // v1.0.10-rfq-anti-arbitrage; verified: https://mantlescan.xyz/address/0x472fc4f7fd3c9f06f0b8637c5505815ac80938ad#code
    constructorArg: "0xAcE2B3E7c752d5deBca72210141d464371b3B9b1",
    dagRouterLibrary: "0xE4D5acB71f826415803999D21283343779e516B4", // v1.0.10-rfq-anti-arbitrage; verified: https://mantlescan.xyz/address/0xe4d5acb71f826415803999d21283343779e516b4#code
    smartSwapRouterLibrary: "0x2F26F019BB721C5fd596b4A8ECDF53215D21F009", // v1.0.10-rfq-anti-arbitrage; verified: https://mantlescan.xyz/address/0x2f26f019bb721c5fd596b4a8ecdf53215d21f009#code
    swapWrapRouterLibrary: "0xFEEDe329fB7271b1572C2D7B86fc03d7D15c2c2D", // v1.0.10-rfq-anti-arbitrage; verified: https://mantlescan.xyz/address/0xfeede329fb7271b1572c2d7b86fc03d7d15c2c2d#code
    unxswapRouterLibrary: "0x097071E82BBEc4ae80F8a046FC2415bd3921c568", // v1.0.10-rfq-anti-arbitrage; verified: https://mantlescan.xyz/address/0x097071e82bbec4ae80f8a046fc2415bd3921c568#code
    unxswapV3RouterLibrary: "0x039Ce27633A8d8361096A21BA936e4a2D1AE6C2A", // v1.0.10-rfq-anti-arbitrage; verified: https://mantlescan.xyz/address/0x039ce27633a8d8361096a21ba936e4a2d1ae6c2a#code
}