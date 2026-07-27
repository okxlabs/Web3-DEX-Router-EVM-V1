module.exports = {
    _CACHED_CHAIN_ID: 4200,
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
    // Deployed 2026-07-26/27 across two broadcasts (ran out of BTC mid-run, topped up and
    // resumed) — Foundry's own CREATE2 library auto-deploy skipped the 4 libraries already
    // confirmed from the first attempt, so no gas was wasted re-sending them. check-impl passed,
    // all 6 independently confirmed verified (manual browser check, scan.merlinchain.io's own
    // API was persistently rate-limited from this environment).
    newImpl: "0xd72f9af181a0eb1b8550a00124ecdb71bb758c89", // v1.0.10-rfq-anti-arbitrage; verified: https://scan.merlinchain.io/address/0xd72f9Af181A0eB1B8550a00124ECdb71Bb758C89
    constructorArg: "0xAcE2B3E7c752d5deBca72210141d464371b3B9b1",
    dagRouterLibrary: "0x90eD8133a6970195a8dD85c094fd432063d282aa", // v1.0.10-rfq-anti-arbitrage; verified: https://scan.merlinchain.io/address/0x90eD8133a6970195a8dD85c094fd432063d282aa
    smartSwapRouterLibrary: "0x5c841f16fe2d6890bFa574a5F1574A6bE5F365cB", // v1.0.10-rfq-anti-arbitrage; verified: https://scan.merlinchain.io/address/0x5c841f16fe2d6890bFa574a5F1574A6bE5F365cB
    swapWrapRouterLibrary: "0x2A6A1Eed3D845E42EED5f6F33652C98eb5d3508C", // v1.0.10-rfq-anti-arbitrage; verified: https://scan.merlinchain.io/address/0x2A6A1Eed3D845E42EED5f6F33652C98eb5d3508C
    unxswapRouterLibrary: "0x95038A9119C1B5056f4361Ede8c26C193fBdDAAD", // v1.0.10-rfq-anti-arbitrage; verified: https://scan.merlinchain.io/address/0x95038A9119C1B5056f4361Ede8c26C193fBdDAAD
    unxswapV3RouterLibrary: "0x1df00ba9755983403095737773B88561a351E988", // v1.0.10-rfq-anti-arbitrage; verified: https://scan.merlinchain.io/address/0x1df00ba9755983403095737773B88561a351E988
}
