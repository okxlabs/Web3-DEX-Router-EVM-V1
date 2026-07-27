module.exports = {
    _CACHED_CHAIN_ID: 1030,
    owner: "0xAcE2B3E7c752d5deBca72210141d464371b3B9b1", // DexRouter owner (pause/transferOwnership/setReporter)
    wNativeToken: "0x14b2D3bC65e74DAE1030EAFd8ac30c533c976A9b",
    wNativeRelayer: "0x40aA958dd87FC8305b97f2BA922CDdCa374bcD7f",
    tokenApprove: "0x68D6B739D2020067D1e2F713b999dA97E4d54812",
    tokenApproveProxy: "0x100F3f74125C8c724C7C0eE81E4dd5626830dD9a",
    securityManager: "0x44C35d5BD862F3d96157B2C9A9B61a31B4e53905", // governs tokenApproveProxy whitelist; DEFAULT_ADMIN_ROLE = admin
    permit2: "0x000000000022D473030F116dDEE9F6B43aC78BA3",
    dexRouter: "0x0112bc6fDB78345e612B862a6B388FfeB00E2320",
    // dexRouter: "0x2957b32632281831a5F42eF9cd19cE3921F78514",
    xbridge: "",
    investEntrance: "0x7251FEbEABB01eC9dE53ECe7a96f1C951F886Dd2",
    commisson: "0xFF317b4E3041c1838BCfE189F0118aF8A5B5480F",
    p2pTrading: "0x0000000017D9a0231430ff2cc3467375a9Af76C7",

    newImpl: "0x7ae91b984da4795d9fd88419d051d0842f8d3677", // v1.0.10-rfq-anti-arbitrage; verified: https://evm.confluxscan.org/address/0x7ae91b984da4795d9fd88419d051d0842f8d3677#code
    constructorArg: "0xAcE2B3E7c752d5deBca72210141d464371b3B9b1",
    dagRouterLibrary: "0x262b0DEe6F60795b9E69538987F58E73E196b04A", // v1.0.10-rfq-anti-arbitrage; verified: https://evm.confluxscan.org/address/0x262b0dee6f60795b9e69538987f58e73e196b04a#code
    smartSwapRouterLibrary: "0x8Fcfc877879CCc753D09082cE1DcB9fa4e52Bb73", // v1.0.10-rfq-anti-arbitrage; verified: https://evm.confluxscan.org/address/0x8fcfc877879ccc753d09082ce1dcb9fa4e52bb73#code
    swapWrapRouterLibrary: "0x841f682868BA32589B13A4613A9DD6378Aa9be2A", // v1.0.10-rfq-anti-arbitrage; verified: https://evm.confluxscan.org/address/0x841f682868ba32589b13a4613a9dd6378aa9be2a#code
    unxswapRouterLibrary: "0xDd99b464B0E3DD11579F1360F8abB1ECa054d5a6", // v1.0.10-rfq-anti-arbitrage; verified: https://evm.confluxscan.org/address/0xdd99b464b0e3dd11579f1360f8abb1eca054d5a6#code
    unxswapV3RouterLibrary: "0xE80C91D1CF13Eca13F726A8dfCeb08390f2D241F", // v1.0.10-rfq-anti-arbitrage; verified: https://evm.confluxscan.org/address/0xe80c91d1cf13eca13f726a8dfceb08390f2d241f#code
}