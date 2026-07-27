module.exports = {
    _CACHED_CHAIN_ID: 10,
    owner: "0xAcE2B3E7c752d5deBca72210141d464371b3B9b1", // DexRouter owner (pause/transferOwnership/setReporter)
    wNativeToken: "0x4200000000000000000000000000000000000006",
    wNativeRelayer: "0x40aA958dd87FC8305b97f2BA922CDdCa374bcD7f",
    tokenApprove: "0x68D6B739D2020067D1e2F713b999dA97E4d54812",
    tokenApproveProxy: "0x100F3f74125C8c724C7C0eE81E4dd5626830dD9a",
    securityManager: "0x5bF77A19fd2AC8496c7f0Af7B83bC762CEF16D4A", // governs tokenApproveProxy whitelist; DEFAULT_ADMIN_ROLE = admin
    permit2: "0x000000000022D473030F116dDEE9F6B43aC78BA3",
    dexRouter: "0xf332761c673b59B21fF6dfa8adA44d78c12dEF09",
    xbridge: "0xf956D9FA19656D8e5219fd6fa8bA6cb198094138",
    investEntrance: "0x7251FEbEABB01eC9dE53ECe7a96f1C951F886Dd2",
    limitOrder: "0xA6dA84219B1d5F419Ef959F1f2A7ec7E32f45CA6",
    limitOrderV2: "0x2ae8947FB81f0AAd5955Baeff9Dcc7779A3e49F2",
    protocolAdmin: "0x06C95a3934d94d5ae5bf54731bD2840ceFee6F87",
    _FF_FACTORY: "0xff1F98431c8aD98523631AE4a59f267346ea31F9840000000000000000000000",
    commisson: "0x838A5832eB19CfCe692809f5b2DE44b15380CDA2",
    // p2pTrading: "0xe6C2820Ba3d14d97b9e9A371771ed7A2f28A9c40",
    p2pTrading: "0x0000000017D9a0231430ff2cc3467375a9Af76C7",
    nftmarketplace: "0xa7FD99748cE527eAdC0bDAc60cba8a4eF4090f7c",

    newImpl: "0x1f5b43127414e36c31ecb5ff5567262997cd24d0", // v1.0.10-rfq-anti-arbitrage; verified: https://optimistic.etherscan.io/address/0x1f5b43127414e36c31ecb5ff5567262997cd24d0#code
    constructorArg: "0xAcE2B3E7c752d5deBca72210141d464371b3B9b1",
    dagRouterLibrary: "0xAC0c536743c6170d51C4440d954FD0ba9F9ed043", // v1.0.10-rfq-anti-arbitrage; verified: https://optimistic.etherscan.io/address/0xac0c536743c6170d51c4440d954fd0ba9f9ed043#code
    smartSwapRouterLibrary: "0x57B610C9a2245Bdf84B6EF08f92E8EaC0A4151b1", // v1.0.10-rfq-anti-arbitrage; verified: https://optimistic.etherscan.io/address/0x57b610c9a2245bdf84b6ef08f92e8eac0a4151b1#code
    swapWrapRouterLibrary: "0x364ca60085CE246342aD9309910AcD8D338E1d95", // v1.0.10-rfq-anti-arbitrage; verified: https://optimistic.etherscan.io/address/0x364ca60085ce246342ad9309910acd8d338e1d95#code
    unxswapRouterLibrary: "0x28a7d9c6988d696d5e4d1830De4D5502Ff669062", // v1.0.10-rfq-anti-arbitrage; verified: https://optimistic.etherscan.io/address/0x28a7d9c6988d696d5e4d1830de4d5502ff669062#code
    unxswapV3RouterLibrary: "0x3b7359b3ee891661e8879A31DF8984646137e684", // v1.0.10-rfq-anti-arbitrage; verified: https://optimistic.etherscan.io/address/0x3b7359b3ee891661e8879a31df8984646137e684#code
}
