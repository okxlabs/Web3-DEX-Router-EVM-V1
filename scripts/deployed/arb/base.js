module.exports = {
    _CACHED_CHAIN_ID: 42161,
    owner: "0xAcE2B3E7c752d5deBca72210141d464371b3B9b1", // DexRouter owner (pause/transferOwnership/setReporter)
    wNativeToken: "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1",
    wNativeRelayer: "0xd99cAE3FAC551f6b6Ba7B9f19bDD316951eeEE98",
    tokenApprove: "0x70cBb871E8f30Fc8Ce23609E9E0Ea87B6b222F58",
    tokenApproveProxy: "0xE9BBD6eC0c9Ca71d3DcCD1282EE9de4F811E50aF",
    securityManager: "0xC77D196CC9B33e3340948412e8Ec1c4E04E9b7Df", // governs tokenApproveProxy whitelist; DEFAULT_ADMIN_ROLE = admin
    permit2: "0x000000000022D473030F116dDEE9F6B43aC78BA3",
    dexRouter: "0xf332761c673b59B21fF6dfa8adA44d78c12dEF09",
    xbridge: "0xFc99f58A8974A4bc36e60E2d490Bb8D72899ee9f",
    investEntrance: "0x7251FEbEABB01eC9dE53ECe7a96f1C951F886Dd2",
    limitOrder: "0xae2818653aA8a64c4205d04ccd693e23949ad447",
    limitOrderV2: "0x2ae8947FB81f0AAd5955Baeff9Dcc7779A3e49F2",
    protocolAdmin: "0x06C95a3934d94d5ae5bf54731bD2840ceFee6F87",
    _FF_FACTORY: "0xff1F98431c8aD98523631AE4a59f267346ea31F9840000000000000000000000",
    commisson: "0x838A5832eB19CfCe692809f5b2DE44b15380CDA2",
    //p2pTrading: "0xe6C2820Ba3d14d97b9e9A371771ed7A2f28A9c40",
    p2pTrading: "0x0000000017D9a0231430ff2cc3467375a9Af76C7",
    nftmarketplace: "0xa7FD99748cE527eAdC0bDAc60cba8a4eF4090f7c",
    newImpl: "0x09f94b5fc68e227c323a6fbae3bd98c97fd8c849", // v1.0.10-rfq-anti-arbitrage; verified: https://arbiscan.io/address/0x09f94b5fc68e227c323a6fbae3bd98c97fd8c849#code
    newExactOutImpl: "0x9736d9a45115E33411390EbD54e5A5C3A6E25aA6",
    feeVaultUs: "0x2059839AA4408122A708c6B086ACe5cc5eCeAd72",
    feeVaultNonUs: "0xFAca0D13796498Ab33faa2557F4badDA949a2706",
    constructorArg: "0xAcE2B3E7c752d5deBca72210141d464371b3B9b1",
    dagRouterLibrary: "0x85379C25378FD67EC21962b0B351D56A62E76e8F", // v1.0.10-rfq-anti-arbitrage; verified: https://arbiscan.io/address/0x85379c25378fd67ec21962b0b351d56a62e76e8f#code
    smartSwapRouterLibrary: "0x22ACb84465E251ea5706Fc88b9D5f6ED81B3b0Cc", // v1.0.10-rfq-anti-arbitrage; verified: https://arbiscan.io/address/0x22acb84465e251ea5706fc88b9d5f6ed81b3b0cc#code
    swapWrapRouterLibrary: "0x523E74e69c71c4a69D4683b39356Ff5b56960902", // v1.0.10-rfq-anti-arbitrage; verified: https://arbiscan.io/address/0x523e74e69c71c4a69d4683b39356ff5b56960902#code
    unxswapRouterLibrary: "0x0587488d2c9184B1F7108fB5064A4aA85688EFDb", // v1.0.10-rfq-anti-arbitrage; verified: https://arbiscan.io/address/0x0587488d2c9184b1f7108fb5064a4aa85688efdb#code
    unxswapV3RouterLibrary: "0xce0462f0a179310D4b27E3Ed8ee13A77339391d9", // v1.0.10-rfq-anti-arbitrage; verified: https://arbiscan.io/address/0xce0462f0a179310d4b27e3ed8ee13a77339391d9#code
}
