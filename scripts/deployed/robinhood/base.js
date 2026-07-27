module.exports = {
    owner: "0xAcE2B3E7c752d5deBca72210141d464371b3B9b1", // DexRouter owner (pause/transferOwnership/setReporter)
    wNativeToken: "0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73", // canonical WETH (aeWETH, Arbitrum bridge standard)
    wNativeRelayer: "0x5D796C6E479052Db44Ee6a45Dd72E57C800A4C1B", // owner: admin
    tokenApprove: "0x42170295F1173c9e5874ea9d00c6d137E1a4f53d", // owner: admin
    tokenApproveProxy: "0x3d60C4d60f4b804B258B07dFA79d44b2E01BB403", // owner: securityManager
    dexRouter: "0xE58b3089dF6667fBf99b75595a1671BaF6797D6d", // v1.0.8, non-proxy, no Ownable
    securityManager: "0x157ac191899680C7618da6A006c0C20c5b9973dB", // governs tokenApproveProxy whitelist; DEFAULT_ADMIN_ROLE = admin
    permit2: "0x000000000022D473030F116dDEE9F6B43aC78BA3", // canonical Permit2, confirmed deployed on-chain (codesize 9152) — field was missing, causing _PERMIT2=0x0 in the prior newImpl below
    xbridge: "",
    investEntrance: "",
    _FF_FACTORY: "0xff1f7d7550B1b028f7571E69A784071F0205FD2EfA0000000000000000000000", // official Uniswap V3 factory 0x1f7d…2EfA, standard pool init code hash
    _CACHED_CHAIN_ID: 4663,
    commisson: "",
    // Redeployed 2026-07-27: original v1.0.10 impl above was missing `permit2` in base.js
    // (baked in _PERMIT2=0x0 despite Permit2 being genuinely deployed on-chain) — fixed and
    // redeployed. Confirmed via Blockscout additional_sources: _PERMIT2 = canonical address,
    // chainId 4663.
    newImpl: "0x6e2a35a7ad683cf634d91492d73bb7ff774c6919", // v1.0.10-rfq-anti-arbitrage (pending go-live); verified: https://robinhoodchain.blockscout.com/address/0x6e2a35a7ad683cf634d91492d73bb7ff774c6919?tab=contract; replaces the v1.0.8 dexRouter above once securityManager whitelists it
    proxyAdmin: "",
    constructorArg: "0xAcE2B3E7c752d5deBca72210141d464371b3B9b1",
    dagRouterLibrary: "0xe24D500B3336027Ae5D854068B700E0591aF162C", // v1.0.10-rfq-anti-arbitrage; verified: https://robinhoodchain.blockscout.com/address/0xe24d500b3336027ae5d854068b700e0591af162c?tab=contract
    smartSwapRouterLibrary: "0xBE3e00662089757C276753783344d21d6224F37C", // v1.0.10-rfq-anti-arbitrage; verified: https://robinhoodchain.blockscout.com/address/0xbe3e00662089757c276753783344d21d6224f37c?tab=contract
    swapWrapRouterLibrary: "0xaA2c1CAF2A34dd067D218757E94295B10c3dD3F9", // v1.0.10-rfq-anti-arbitrage; verified: https://robinhoodchain.blockscout.com/address/0xaa2c1caf2a34dd067d218757e94295b10c3dd3f9?tab=contract
    unxswapRouterLibrary: "0x97a730EBfE3c2DC15B9a7060905bA744De3734a2", // v1.0.10-rfq-anti-arbitrage; verified: https://robinhoodchain.blockscout.com/address/0x97a730ebfe3c2dc15b9a7060905ba744de3734a2?tab=contract
    unxswapV3RouterLibrary: "0xb2208De572e4840ADe91596C6EEa5a860E2295A2", // v1.0.10-rfq-anti-arbitrage; verified: https://robinhoodchain.blockscout.com/address/0xb2208de572e4840ade91596c6eea5a860e2295a2?tab=contract
}
