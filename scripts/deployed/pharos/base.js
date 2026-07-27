module.exports = {
    owner: "0xAcE2B3E7c752d5deBca72210141d464371b3B9b1", // DexRouter owner (pause/transferOwnership/setReporter)
    wNativeToken: "0x52C48d4213107b20bC583832b0d951FB9CA8F0B0", // WPROS
    wNativeRelayer: "0xCa3104720E994DCB266B235A45D8eC49DEd88638",
    tokenApprove: "0x78466A1488f1883d71cFddd1c621351572dE0a1C",
    tokenApproveProxy: "0x7DA6cDe2354dD295554aa2127D8ec3d31f6D91AA",
    securityManager: "0xa826Ca3eb9CF749f02a34B80291F7515740eae66", // governs tokenApproveProxy whitelist; DEFAULT_ADMIN_ROLE = admin
    permit2: "0x000000000022D473030F116dDEE9F6B43aC78BA3", // canonical Permit2, confirmed deployed on-chain (codesize 9152) — field was missing, causing _PERMIT2=0x0 in the prior newImpl below
    dexRouter: "0x75f21a97Bd89A9A5683A9f46b5D5B4a080708DEa",
    _FF_FACTORY: "", // uniswap v3 factory not deployed on Pharos
    // human checked wnative and wnative relayer and tokenApprove and _FF_FACTORY is correct
    _CACHED_CHAIN_ID: 1672,
    commisson: "",
    // Redeployed 2026-07-27: original v1.0.10 impl above was missing `permit2` in base.js
    // (baked in _PERMIT2=0x0 despite Permit2 being genuinely deployed on-chain) — fixed and
    // redeployed. pharos's designated verifier (api.socialscan.io) is network-blocked from
    // this dev environment (see verify_via_foundry.js note) — verified instead via Sourcify's
    // direct API (chainId 1672 is Sourcify-supported even though not in the CHAINS config),
    // all 6 independently confirmed exact_match (both creation and runtime).
    newImpl: "0x974d1cf6ffa4fce5a4d62955afc02f45aac29f35", // v1.0.10-rfq-anti-arbitrage; verified via Sourcify: https://repo.sourcify.dev/contracts/full_match/1672/0x974d1cf6ffa4fce5a4d62955afc02f45aac29f35/
    constructorArg: "0xAcE2B3E7c752d5deBca72210141d464371b3B9b1",
    dagRouterLibrary: "0xB245b057DeAe6981b810D05D6D5292480ae9d242", // v1.0.10-rfq-anti-arbitrage; verified via Sourcify: https://repo.sourcify.dev/contracts/full_match/1672/0xB245b057DeAe6981b810D05D6D5292480ae9d242/
    smartSwapRouterLibrary: "0xCD1a76D661FeF3ADEc56A16735C2A9BA16efCfC4", // v1.0.10-rfq-anti-arbitrage; verified via Sourcify: https://repo.sourcify.dev/contracts/full_match/1672/0xCD1a76D661FeF3ADEc56A16735C2A9BA16efCfC4/
    swapWrapRouterLibrary: "0xafAB76af7FF2Ced8468A208E08C35eE1a85066B1", // v1.0.10-rfq-anti-arbitrage; verified via Sourcify: https://repo.sourcify.dev/contracts/full_match/1672/0xafAB76af7FF2Ced8468A208E08C35eE1a85066B1/
    unxswapRouterLibrary: "0xa06aF6DE91c4Bc0faAa32B6129d9826488DD431f", // v1.0.10-rfq-anti-arbitrage; verified via Sourcify: https://repo.sourcify.dev/contracts/full_match/1672/0xa06aF6DE91c4Bc0faAa32B6129d9826488DD431f/
    unxswapV3RouterLibrary: "0xF4A3D8e0F28e743F9CAaCe63FE3DBEbf492b261d", // v1.0.10-rfq-anti-arbitrage; verified via Sourcify: https://repo.sourcify.dev/contracts/full_match/1672/0xF4A3D8e0F28e743F9CAaCe63FE3DBEbf492b261d/
}
