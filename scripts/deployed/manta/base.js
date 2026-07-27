module.exports = {
    _CACHED_CHAIN_ID: 169,
    owner: "0xAcE2B3E7c752d5deBca72210141d464371b3B9b1", // DexRouter owner (pause/transferOwnership/setReporter)
    wNativeToken: "0x0Dc808adcE2099A9F62AA87D9670745AbA741746",
    wNativeRelayer: "0xd2F0aC2012C8433F235c8e5e97F2368197DD06C7",
    tokenApprove: "0x57df6092665eb6058DE53939612413ff4B09114E",
    tokenApproveProxy: "0x1b5d39419C268b76Db06DE49e38B010fbFB5e226",
    securityManager: "0xCd910c2421aF23adE6Ad35cf5B1f246a9847CA83", // governs tokenApproveProxy whitelist; DEFAULT_ADMIN_ROLE = admin
    permit2: "0x000000000022D473030F116dDEE9F6B43aC78BA3",
    dexRouter: "0x6b2C0c7be2048Daa9b5527982C29f48062B34D58",
    xbridge: "0x91EcECC4F2363770c621a8a061A80d67cfEafEC7",
    investEntrance: "0x7251FEbEABB01eC9dE53ECe7a96f1C951F886Dd2",
    _FF_FACTORY: "0xff06d830e15081f65923674268121ff57cc54e4e230000000000000000000000",
    proxyAdmin: "0xc6d8e2e0E5c25ACecff66BE60F257884D0e9DF50",

    newImpl: "0xd72f9af181a0eb1b8550a00124ecdb71bb758c89", // v1.0.10-rfq-anti-arbitrage; verified via Sourcify: https://repo.sourcify.dev/contracts/full_match/169/0xd72f9af181a0eb1b8550a00124ecdb71bb758c89/
    constructorArg: "0xAcE2B3E7c752d5deBca72210141d464371b3B9b1",
    dagRouterLibrary: "0x7c7e2190234145C166758B187F9880eB4bFDa112", // v1.0.10-rfq-anti-arbitrage; verified via Sourcify: https://repo.sourcify.dev/contracts/full_match/169/0x7c7e2190234145C166758B187F9880eB4bFDa112/
    smartSwapRouterLibrary: "0x683A82B92344DEcA762B4934f027C442BAd8101F", // v1.0.10-rfq-anti-arbitrage; verified via Sourcify: https://repo.sourcify.dev/contracts/full_match/169/0x683A82B92344DEcA762B4934f027C442BAd8101F/
    swapWrapRouterLibrary: "0x120e8205e253403be353Ec511453FC4d1D4a1b88", // v1.0.10-rfq-anti-arbitrage; verified via Sourcify: https://repo.sourcify.dev/contracts/full_match/169/0x120e8205e253403be353Ec511453FC4d1D4a1b88/
    unxswapRouterLibrary: "0x7C8b2f549944a18135B8223175F1f624C2F8Cfc9", // v1.0.10-rfq-anti-arbitrage; verified via Sourcify: https://repo.sourcify.dev/contracts/full_match/169/0x7C8b2f549944a18135B8223175F1f624C2F8Cfc9/
    unxswapV3RouterLibrary: "0x0Fa40923A660fFD208F339F6fF0433A9B01D2fdb", // v1.0.10-rfq-anti-arbitrage; verified via Sourcify: https://repo.sourcify.dev/contracts/full_match/169/0x0Fa40923A660fFD208F339F6fF0433A9B01D2fdb/
}

