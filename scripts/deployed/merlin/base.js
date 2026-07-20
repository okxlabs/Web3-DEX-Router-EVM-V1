module.exports = {
    owner: "0xAcE2B3E7c752d5deBca72210141d464371b3B9b1", // DexRouter owner (pause/transferOwnership/setReporter)
    wNativeToken: "0xF6D226f9Dc15d9bB51182815b320D3fBE324e1bA",
    wNativeRelayer: "0x38a342664aBE254Fc2Ca4A98d85eaB7C5aE63c85",
    tokenApprove: "0x8b773D83bc66Be128c60e07E17C8901f7a64F000",
    tokenApproveProxy: "0xfAd6a9eEe5b32E9B81bb217BaeF37742B2ca5B83",
    _FF_FACTORY: "", // uniswap v3 factory not deployed on Merlin
    // human checked wnative and wnative relayer and tokenApprove and _FF_FACTORY is correct
    securityManager: "0xbF94a31025C5eA080892f6176681492b62547d4d", // governs tokenApproveProxy whitelist; DEFAULT_ADMIN_ROLE = admin
    permit2: "0x000000000022D473030F116dDEE9F6B43aC78BA3",
    dexRouter: "0x127a986cE31AA2ea8E1a6a0F0D5b7E5dbaD7b0bE",
    xbridge: "0xf956D9FA19656D8e5219fd6fa8bA6cb198094138",
    _POOL_INIT_CODE_HASH: "",
    investEntrance: "",
    proxyAdmin: "0x3a1078eF3B6E36D1560B15f6e0BFa715567A96bA",
    newImpl: "0x61e7e4936e546910658f9458ddfd785b44ec91ae",
    constructorArg: "0xAcE2B3E7c752d5deBca72210141d464371b3B9b1",
    dagRouterLibrary: "0x4814e39840F5a14acf2010B0902151Ba1993b91f",
    smartSwapRouterLibrary: "0x8746df25c800E58B3131A621f1B9099aa5552eB1",
    swapWrapRouterLibrary: "0x179E743999CC80De438f1fbEE1bA8Ab4fFC629dF",
    unxswapRouterLibrary: "0xd45de789297289Fab994b673CBBB4809bc4cA90B",
    unxswapV3RouterLibrary: "0x758F66951bE222469634c185f06cB01FDC6510AF",
}
