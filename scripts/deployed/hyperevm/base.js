module.exports = {
    owner: "0xAcE2B3E7c752d5deBca72210141d464371b3B9b1", // DexRouter owner (pause/transferOwnership/setReporter)
    wNativeToken: "0x5555555555555555555555555555555555555555", // WHYPE
    wNativeRelayer: "0xEdBaB5dfAA165919Dfa94101c266e48c4e82D8Fd",
    tokenApprove: "0x56e6983D59bF472Ced0E63966A14d94A3A291589",
    tokenApproveProxy: "0xABC7f0BEf82C4BF6A131758bbd92bdAFa63797DB",
    securityManager: "0xd71E2588cFaB6482ECBB5b7d5f4406a79be15F7f", // governs tokenApproveProxy whitelist; DEFAULT_ADMIN_ROLE = admin
    permit2: "0x000000000022D473030F116dDEE9F6B43aC78BA3", // canonical Permit2, confirmed deployed on-chain (codesize 9152) — field was missing, causing _PERMIT2=0x0 in the prior newImpl below
    dexRouter: "0x9Ac7b1FFEE0f58c0a3c89AA54Afb62efD25DC9fd",
    investEntrance: "",
    _FF_FACTORY: "",
    _CACHED_CHAIN_ID: 999,
    commisson: "",
    // Redeployed 2026-07-27: original v1.0.10 impl above was missing `permit2` in base.js
    // (baked in _PERMIT2=0x0 despite Permit2 being genuinely deployed on-chain) — fixed and
    // redeployed. Confirmed via getsourcecode: _PERMIT2 = canonical address, chainId 999.
    newImpl: "0xb193874f0c77948d2bcfec2efaf8bc65b4c2ca89", // v1.0.10-rfq-anti-arbitrage; verified: https://hyperevmscan.io/address/0xb193874f0c77948d2bcfec2efaf8bc65b4c2ca89#code
    constructorArg: "0xAcE2B3E7c752d5deBca72210141d464371b3B9b1",
    dagRouterLibrary: "0x064d14f8CdA7A2F3BA3EF3469f26737Ea285Ef5B", // v1.0.10-rfq-anti-arbitrage; verified: https://hyperevmscan.io/address/0x064d14f8cda7a2f3ba3ef3469f26737ea285ef5b#code
    smartSwapRouterLibrary: "0x451b8D0a2c0854A1285b330D506ae346B6AE52DC", // v1.0.10-rfq-anti-arbitrage; verified: https://hyperevmscan.io/address/0x451b8d0a2c0854a1285b330d506ae346b6ae52dc#code
    swapWrapRouterLibrary: "0x14ba49772c60A4060245500463EeFD4B5f3cFC69", // v1.0.10-rfq-anti-arbitrage; verified: https://hyperevmscan.io/address/0x14ba49772c60a4060245500463eefd4b5f3cfc69#code
    unxswapRouterLibrary: "0xBeB1bae036E057074507A593DFa9e11AE4BF37eD", // v1.0.10-rfq-anti-arbitrage; verified: https://hyperevmscan.io/address/0xbeb1bae036e057074507a593dfa9e11ae4bf37ed#code
    unxswapV3RouterLibrary: "0xb4E94e46dbb1bf6B843D737f4bE5B46cc5e12327", // v1.0.10-rfq-anti-arbitrage; verified: https://hyperevmscan.io/address/0xb4e94e46dbb1bf6b843d737f4be5b46cc5e12327#code
}
