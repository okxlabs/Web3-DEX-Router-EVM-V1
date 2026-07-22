// NOTE: dexRouter/newImpl below were built and deployed from feat/deploy-v1.0.8's legacy
// source (v1.0.8-suffix-compat) — a single monolithic contract with no constructor/owner and
// no separately-linked router libraries. This predates main's current DexRouter (v1.0.9,
// PausableModuleV2 owner + externally-linked DagRouter/SmartSwapRouter/UnxswapRouter/
// UnxswapV3Router/SwapWrapRouter libraries, deployed via src/deploy/DeployDexRouter.s.sol).
// This entry documents what's actually live on ink; it is NOT expected to satisfy
// check-impl (compiled main source won't byte-match this historical build), and there are
// no library addresses to record because this build doesn't have separately-deployed ones.
// `owner`/`constructorArg` are filled with the standard governance address for schema
// consistency only — this specific dexRouter has no Ownable/constructor and does not
// actually enforce it on-chain.
module.exports = {
    owner: "0xAcE2B3E7c752d5deBca72210141d464371b3B9b1", // NOT enforced on-chain by this dexRouter (no owner/pause here) - see note above
    wNativeToken: "0x4200000000000000000000000000000000000006", // WETH (OP-Stack predeploy)
    wNativeRelayer: "0xc1C76E784Db8D68585fb608ce68FC5DcFF14000E",
    tokenApprove: "0xd72f9Af181A0eB1B8550a00124ECdb71Bb758C89",
    tokenApproveProxy: "0xa8D102a83e1C9b19142EC857Cda5f2d2142Ea840", // owner: securityManager
    securityManager: "0xE23Ccd8D201e8dCd42e201E1Db7ba423EdC4c54b", // governs tokenApproveProxy whitelist; DEFAULT_ADMIN_ROLE = admin
    dexRouter: "0x9bf3f60252be1a2fd3ed38086ed3d02b25b4eead", // v1.0.8-suffix-compat (feat/deploy-v1.0.8), used directly - non-proxy
    xbridge: "",
    investEntrance: "",
    _FF_FACTORY: "",
    _CACHED_CHAIN_ID: 57073,
    commisson: "",
    newImpl: "0x9bf3f60252be1a2fd3ed38086ed3d02b25b4eead", // same as dexRouter, non-proxy
    proxyAdmin: "",
    constructorArg: "0xAcE2B3E7c752d5deBca72210141d464371b3B9b1", // not applicable - this build has no constructor
}
