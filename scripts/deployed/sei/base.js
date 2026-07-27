module.exports = {
    owner: "0xAcE2B3E7c752d5deBca72210141d464371b3B9b1", // DexRouter owner (pause/transferOwnership/setReporter)
    wNativeToken: "0xE30feDd158A2e3b13e9badaeABaFc5516e95e8C7",
    wNativeRelayer: "0xE8c25c536550221a52472d50bBaBd2B88353DcE8",
    tokenApprove: "0x801D8ED849039007a7170830623180396492c7ED",
    tokenApproveProxy: "0x1Da57aFA94200d7D195aB7Bd1da5E6cBC147680d",
    securityManager: "0x1944e22E88040e70c2b37031bbF9fC4a0bad2921", // governs tokenApproveProxy whitelist; DEFAULT_ADMIN_ROLE = admin
    permit2: "0x000000000022D473030F116dDEE9F6B43aC78BA3",
    dexRouter: "0xdB3af8dF1cab8ae4159ED6a9b33dF5f8C3aD1485",
    xbridge: '',
    //nftmarket: "",
    investEntrance: "",
    protocolAdmin: "",
    _FACTORY: "",
    _CACHED_DOMAIN_SEPARATOR: '',
    _HASHED_NAME: '',
    _HASHED_VERSION: '',
    _TYPE_HASH: '',
    _CACHED_CHAIN_ID: 1329,
    _FF_FACTORY: "",
    commisson: "",
    p2pTrading: "",

    newImpl: "0xd72f9af181a0eb1b8550a00124ecdb71bb758c89", // v1.0.10-rfq-anti-arbitrage; verified: https://seiscan.io/address/0xd72f9af181a0eb1b8550a00124ecdb71bb758c89#code
    constructorArg: "0xAcE2B3E7c752d5deBca72210141d464371b3B9b1",
    dagRouterLibrary: "0x36672A36dF0A3B90D03A4B3a0458041b81eacB81", // v1.0.10-rfq-anti-arbitrage; verified: https://seiscan.io/address/0x36672a36df0a3b90d03a4b3a0458041b81eacb81#code
    smartSwapRouterLibrary: "0xF1De20fCF131b91d4b79a2cf679A1c4589EA4E02", // v1.0.10-rfq-anti-arbitrage; verified: https://seiscan.io/address/0xf1de20fcf131b91d4b79a2cf679a1c4589ea4e02#code
    swapWrapRouterLibrary: "0xb5Dc4eC7CB5F1C8e2f14cD3b83d8E4e002A04b57", // v1.0.10-rfq-anti-arbitrage; verified: https://seiscan.io/address/0xb5dc4ec7cb5f1c8e2f14cd3b83d8e4e002a04b57#code
    unxswapRouterLibrary: "0xefACeF9914302cDb92d526b7394165ec5931c748", // v1.0.10-rfq-anti-arbitrage; verified: https://seiscan.io/address/0xefacef9914302cdb92d526b7394165ec5931c748#code
    unxswapV3RouterLibrary: "0x75a6BAC2100227Bc445Cad6Fc50426B32Eb506a9", // v1.0.10-rfq-anti-arbitrage; verified: https://seiscan.io/address/0x75a6bac2100227bc445cad6fc50426b32eb506a9#code
}
