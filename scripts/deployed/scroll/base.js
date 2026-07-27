module.exports = {
    owner: "0xAcE2B3E7c752d5deBca72210141d464371b3B9b1", // DexRouter owner (pause/transferOwnership/setReporter)
    wNativeToken: "0x5300000000000000000000000000000000000004",
    wNativeRelayer: "0xd2F0aC2012C8433F235c8e5e97F2368197DD06C7",
    tokenApprove: "0x57df6092665eb6058DE53939612413ff4B09114E",
    tokenApproveProxy: "0x1b5d39419C268b76Db06DE49e38B010fbFB5e226",
    securityManager: "0x222f8F2C9D29A20176cf24E7D0bc2A177deDE00d", // governs tokenApproveProxy whitelist; DEFAULT_ADMIN_ROLE = admin
    permit2: "0x000000000022D473030F116dDEE9F6B43aC78BA3",
    dexRouter: "0x6b2C0c7be2048Daa9b5527982C29f48062B34D58",
    xbridge: "0xf956D9FA19656D8e5219fd6fa8bA6cb198094138",
    investEntrance: "0x7251FEbEABB01eC9dE53ECe7a96f1C951F886Dd2",
    limitOrder: "",
    protocolAdmin: "0x06C95a3934d94d5ae5bf54731bD2840ceFee6F87",
    _FF_FACTORY: "0xff70C62C8b8e801124A4Aa81ce07b637A3e83cb9190000000000000000000000",
    // human checked wnative and wnative relayer and tokenApprove and _FF_FACTORY is correct
    _CACHED_DOMAIN_SEPARATOR: "",
    _HASHED_NAME: "",
    _HASHED_VERSION: "",
    _TYPE_HASH: "",
    _CACHED_CHAIN_ID: 534352,
    nftmarketplace: "0xa7FD99748cE527eAdC0bDAc60cba8a4eF4090f7c",
    proxyAdmin: "0xc6d8e2e0E5c25ACecff66BE60F257884D0e9DF50",

    newImpl: "0x6148d68ec192df0a7d36d97bdabbebb014c69938", // v1.0.10-rfq-anti-arbitrage; verified via Sourcify: https://repo.sourcify.dev/contracts/full_match/534352/0x6148d68ec192df0a7d36d97bdabbebb014c69938/
    constructorArg: "0xAcE2B3E7c752d5deBca72210141d464371b3B9b1",
    dagRouterLibrary: "0xcC82CeA621C522f99DdA2FaCF3d6e481810C4EaC", // v1.0.10-rfq-anti-arbitrage; verified via Sourcify: https://repo.sourcify.dev/contracts/full_match/534352/0xcC82CeA621C522f99DdA2FaCF3d6e481810C4EaC/
    smartSwapRouterLibrary: "0xF3Ab6dc96162A1F4427c0a0EC53a9AdfabA47955", // v1.0.10-rfq-anti-arbitrage; verified via Sourcify: https://repo.sourcify.dev/contracts/full_match/534352/0xF3Ab6dc96162A1F4427c0a0EC53a9AdfabA47955/
    swapWrapRouterLibrary: "0x13363D052939CC5Ec232343A3b5329351b5Cd555", // v1.0.10-rfq-anti-arbitrage; verified via Sourcify: https://repo.sourcify.dev/contracts/full_match/534352/0x13363D052939CC5Ec232343A3b5329351b5Cd555/
    unxswapRouterLibrary: "0x4c3C3aBfECcc43DaE067d56538F3F761d310cd21", // v1.0.10-rfq-anti-arbitrage; verified via Sourcify: https://repo.sourcify.dev/contracts/full_match/534352/0x4c3C3aBfECcc43DaE067d56538F3F761d310cd21/
    unxswapV3RouterLibrary: "0xc223a319Bb33a61EfeEd1A0249Acd713c91e6d81", // v1.0.10-rfq-anti-arbitrage; verified via Sourcify: https://repo.sourcify.dev/contracts/full_match/534352/0xc223a319Bb33a61EfeEd1A0249Acd713c91e6d81/
}