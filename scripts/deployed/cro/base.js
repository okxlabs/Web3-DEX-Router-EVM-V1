module.exports = {
    owner: "0xAcE2B3E7c752d5deBca72210141d464371b3B9b1", // DexRouter owner (pause/transferOwnership/setReporter)
    wNativeToken: "0x5C7F8A570d578ED84E63fdFA7b1eE72dEae1AE23",
    wNativeRelayer: "0x40aA958dd87FC8305b97f2BA922CDdCa374bcD7f",
    tokenApprove: "0x70cbb871e8f30fc8ce23609e9e0ea87b6b222f58",
    tokenApproveProxy: "0xE9BBD6eC0c9Ca71d3DcCD1282EE9de4F811E50aF",
    securityManager: "0x4cFDD69FB22C986f398996d3D4896b1Ab7a6bE66", // governs tokenApproveProxy whitelist; DEFAULT_ADMIN_ROLE = admin
    permit2: "0x000000000022D473030F116dDEE9F6B43aC78BA3",
    // human checked wnative and wnative relayer and tokenApprove is correct
    // Disabled: the canonical UniV3 factory (0x1F98..984) is NOT deployed on Cro,
    // so the UnxswapV3 CREATE2 fast-path can never find pools here. not
    // wired in since the pool init code hash would also need verifying. Empty => zero bytes32.
    _FF_FACTORY: "",
    dexRouter: "0xf332761c673b59B21fF6dfa8adA44d78c12dEF09",
    xbridge: "0xf956D9FA19656D8e5219fd6fa8bA6cb198094138",
    commisson: "0x838A5832eB19CfCe692809f5b2DE44b15380CDA2",

    newImpl: "0xd72f9af181a0eb1b8550a00124ecdb71bb758c89",

    constructorArg: "0xAcE2B3E7c752d5deBca72210141d464371b3B9b1",
    dagRouterLibrary: "0x34dff2Edf043fCB34bBBb72d3E8C97c7eE1bE03e",
    smartSwapRouterLibrary: "0xfB9900ff1aF0cBD0c79eCe9d41C78142243f83b8",
    swapWrapRouterLibrary: "0xE005b21AA648Fe7E4fea7Da50371a7c3501E1cb2",
    unxswapRouterLibrary: "0xf339b4D079FCEA34414E60b6176f64980666d5f3",
    unxswapV3RouterLibrary: "0xd1FeA1A5eFE9C22050e8528a2545D73325484499",
}