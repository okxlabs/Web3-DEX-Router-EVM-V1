module.exports = {
    wNativeToken: "0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73", // canonical WETH (aeWETH, Arbitrum bridge standard)
    wNativeRelayer: "0x5D796C6E479052Db44Ee6a45Dd72E57C800A4C1B", // owner: admin
    tokenApprove: "0x42170295F1173c9e5874ea9d00c6d137E1a4f53d", // owner: admin
    tokenApproveProxy: "0x3d60C4d60f4b804B258B07dFA79d44b2E01BB403", // owner: securityManager
    dexRouter: "0xE58b3089dF6667fBf99b75595a1671BaF6797D6d", // v1.0.8, non-proxy, no Ownable
    securityManager: "0x157ac191899680C7618da6A006c0C20c5b9973dB", // governs tokenApproveProxy whitelist; DEFAULT_ADMIN_ROLE = admin
    xbridge: "",
    investEntrance: "",
    _FF_FACTORY: "0xff1f7d7550B1b028f7571E69A784071F0205FD2EfA0000000000000000000000", // official Uniswap V3 factory 0x1f7d…2EfA, standard pool init code hash
    _CACHED_CHAIN_ID: 4663,
    commisson: "",
    newImpl: "0x61e7e4936e546910658f9458ddfd785b44ec91ae", // v1.0.9 (pending go-live); replaces the v1.0.8 dexRouter above once securityManager whitelists it
    proxyAdmin: "",
    constructorArg: "0xAcE2B3E7c752d5deBca72210141d464371b3B9b1",
    dagRouterLibrary: "0x715c6CeB29F2b74Cd38963eeCA7D7feECCA9f9E2",
    smartSwapRouterLibrary: "0xDbe5Daf3500930A6284543ca8a7047cF5739918d",
    swapWrapRouterLibrary: "0x88dDcDf7407b6F756D65Af5719d0001c29Bb474E",
    unxswapRouterLibrary: "0x3261f4082641c758A7aA6dc1AA14094373Bf1d02",
    unxswapV3RouterLibrary: "0x7d4530532F4bCec7F826d6C893af8942C01FcB34",
}
