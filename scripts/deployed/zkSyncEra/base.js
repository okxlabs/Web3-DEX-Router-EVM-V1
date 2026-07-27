module.exports = {
    wNativeToken: "0x5AEa5775959fBC2557Cc8789bC1bf90A239D9a91",
    wNativeRelayer: "0xD637B1C601Aa80456268707d172E7b141B404c6f",
    tokenApprove: "0xc67879F4065d3B9fe1C09EE990B891Aa8E3a4c2f",
    tokenApproveProxy: "0xE7483a8A506B20872e6F19852B85815cBa24e47d",
    // DexRouter owner (constructor arg): privileged pause / transferOwnership / setReporter.
    // Read by deploy_dexrouter_zksync.js; fleet EVM prod owner (same as other EVM chains).
    owner: "0xAcE2B3E7c752d5deBca72210141d464371b3B9b1",
    securityManager: "0x2cD92272CdB28aa681b89D512846185914261674", // governs tokenApproveProxy whitelist; DEFAULT_ADMIN_ROLE = admin
    permit2: "0x000000000022D473030F116dDEE9F6B43aC78BA3",
    dexRouter: "0xb9061E38FeE7d30134F56aEf7117E2F6d1580666",
    xbridge: "0x4040bEC373F6e8be2F913324de94A7b9242E5E92",
    investEntrance: "",
    limitOrder: "",
    limitOrderV2: "",
    protocolAdmin: "",
    _FF_FACTORY: "0xff8FdA5a7a8dCA67BBcDd10F02Fa0649A9372154220000000000000000000000",
    commisson: "",
    p2pTrading: "",
    nftmarketplace: "",
    // Redeployed 2026-07-27 after discovering the first v1.0.10 attempt was compiled with eth
    // mainnet's ChainConfig.sol (_EXPECTED_CHAIN_ID=1, eth _WETH/_APPROVE_PROXY) instead of
    // zkSync's own — deploy_dexrouter_zksync.js never calls gen-chainconfig.js and has no
    // runtime chainId guard (unlike DeployDexRouter.s.sol's require(block.chainid ==
    // _EXPECTED_CHAIN_ID)), so it silently compiled against whatever ChainConfig.sol happened
    // to be on disk. That bad build never went live (no addProxy), so no funds were at risk.
    // This build's ChainConfig was regenerated correctly (chainId 324) immediately before both
    // Phase A and Phase B, with no other gen-chainconfig/check-impl calls in between — confirmed
    // by reading the verified DexRouter source back from the zkSync explorer API afterward
    // (_EXPECTED_CHAIN_ID=324, real zkSync _WETH/_APPROVE_PROXY).
    newImpl: "0x46eDEcEa0228f04Ab88dC34BE98314863bA40bE0", // v1.0.10-rfq-anti-arbitrage; verified (correct chainId 324 ChainConfig): https://explorer.zksync.io/address/0x46eDEcEa0228f04Ab88dC34BE98314863bA40bE0#contract
    _CACHED_CHAIN_ID: 324,
    // Same as before: bytecode confirmed byte-identical to compiled source except the trailing
    // zksolc metadata hash (eth_getCode vs local artifact deployedBytecode); hardhat-zksync-verify's
    // local pre-check rejects the mismatch before submission for libraries specifically (DexRouter
    // has an automatic full-solc-input retry fallback that libraries lack — see
    // hardhat.zksync.config.js's ZKSYNC_LIBS_SENTINEL note for a manual verify workaround).
    dagRouterLibrary: "0x0777ef68d22E8401FBD2C811902a398CaD7229A1",
    smartSwapRouterLibrary: "0x47021E9b3ed60773a77020449406a1F78d7eC6bD",
    swapWrapRouterLibrary: "0xD5De23953E1D388F5685D22B97cc1AC2EEca26d0",
    unxswapRouterLibrary: "0xCeC9430e8323C801a1EC9760199400Ca10DB8273",
    unxswapV3RouterLibrary: "0xE73C06F22C47496EdFab22dc2963428Bd8022F1d",
    constructorArg: "0xAcE2B3E7c752d5deBca72210141d464371b3B9b1",
}


