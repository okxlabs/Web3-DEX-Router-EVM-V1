module.exports = {
    _CACHED_CHAIN_ID: 9745,
    owner: "0xAcE2B3E7c752d5deBca72210141d464371b3B9b1", // DexRouter owner (pause/transferOwnership/setReporter)
    wNativeToken: "0x6100E367285b01F48D07953803A2d8dCA5D19873",
    wNativeRelayer: "0x6747BcaF9bD5a5F0758Cbe08903490E45DdfACB5",
    tokenApprove: "0x9FD43F5E4c24543b2eBC807321E58e6D350d6a5A",
    tokenApproveProxy: "0x9b9efa5Efa731EA9Bbb0369E91fA17Abf249CFD4",
    securityManager: "0x5a2868515746d7C8F6599909D2b6E590A34063E9", // governs tokenApproveProxy whitelist; DEFAULT_ADMIN_ROLE = admin
    permit2: "0x000000000022D473030F116dDEE9F6B43aC78BA3",
    _FF_FACTORY: "0xffcb2436774C3e191c85056d248EF4260ce5f27A9D0000000000000000000000",
    newImpl: "0xd72f9af181a0eb1b8550a00124ecdb71bb758c89", // v1.0.10-rfq-anti-arbitrage; verified: https://plasmascan.to/address/0xd72f9af181a0eb1b8550a00124ecdb71bb758c89#code
    constructorArg: "0xAcE2B3E7c752d5deBca72210141d464371b3B9b1",
    dagRouterLibrary: "0x822D3c48a0456deBA970a3d75bE9cAE62547727b", // v1.0.10-rfq-anti-arbitrage; verified: https://plasmascan.to/address/0x822d3c48a0456deba970a3d75be9cae62547727b#code
    smartSwapRouterLibrary: "0x0518B74f64d7620CaeE143853D242893769b5Fe8", // v1.0.10-rfq-anti-arbitrage; verified: https://plasmascan.to/address/0x0518b74f64d7620caee143853d242893769b5fe8#code
    swapWrapRouterLibrary: "0x1ed9b82E538e06BEB062910D4CE038d48fDC1582", // v1.0.10-rfq-anti-arbitrage; verified: https://plasmascan.to/address/0x1ed9b82e538e06beb062910d4ce038d48fdc1582#code
    unxswapRouterLibrary: "0x27c37625e92600C8c1EE8d3B3deB0286B5Bbb3D1", // v1.0.10-rfq-anti-arbitrage; verified: https://plasmascan.to/address/0x27c37625e92600c8c1ee8d3b3deb0286b5bbb3d1#code
    unxswapV3RouterLibrary: "0xFE6EC99722ba1467b276CBdC1A12D1450D7A469C", // v1.0.10-rfq-anti-arbitrage; verified: https://plasmascan.to/address/0xfe6ec99722ba1467b276cbdc1a12d1450d7a469c#code
}