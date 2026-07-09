module.exports = {
    owner: "0xAcE2B3E7c752d5deBca72210141d464371b3B9b1", // DexRouter owner (pause/transferOwnership/setReporter)
    wNativeToken: "0x7Bf88d2c0e32dE92CdaF2D43CcDc23e8Edfd5990",
    wNativeRelayer: "0x4D8d82F269A2704867b6cAf58d6e8389e3066eC9",
    tokenApprove: "0x40aA958dd87FC8305b97f2BA922CDdCa374bcD7f",
    tokenApproveProxy: "0x70cBb871E8f30Fc8Ce23609E9E0Ea87B6b222F58",
    _FF_FACTORY: "", // uniswap v3 factory not deployed on ETHW
    // human checked wnative and wnative relayer and tokenApprove and _FF_FACTORY is correct
    permit2: "0x000000000022D473030F116dDEE9F6B43aC78BA3",
    dexRouter: "0x51B6812B030a19cF801be8C4B41748488A7e1D60",
    xbridge: "0xFc99f58A8974A4bc36e60E2d490Bb8D72899ee9f",
    //nftmarket: "0x191b0e61ccBf3B26df76ca4321D9dEE4C960E91E",
    investEntrance: "0x7251FEbEABB01eC9dE53ECe7a96f1C951F886Dd2",
    marketMaker: "0x55b35bF627944396f9950dD6BDdaDb5218110c76",
    pmmAdapter: "0x19440199101Fb45882d06Ee432437eC89f406248",
    commisson: "0x838A5832eB19CfCe692809f5b2DE44b15380CDA2",
    // Recovered on-chain: prod deploy (new RPC) succeeded but record step didn't run.
    // newImpl = deployer CREATE nonce-6 address (code 13322). NOTE: a prior killed run left a
    // stale impl at nonce-5 (0x61e7E4936E546910658F9458Ddfd785B44EC91Ae) — use THIS (nonce-6) for go-live.
    newImpl: "0x9A93a99ae01e1907dF6cb94dac122ae29E02f095",
    constructorArg: "0xAcE2B3E7c752d5deBca72210141d464371b3B9b1",
    // Recovered from newImpl's on-chain bytecode (linkReferences positions), 2026-07. The
    // deploy record step never ran, so these were missing. Each library confirmed present
    // on-chain (code sizes match sibling chains); owner() on newImpl == constructorArg.
    dagRouterLibrary: "0xdfd1b9d16b58dc0ec2d38776e129260eda2bf483",
    smartSwapRouterLibrary: "0xf767e28e699ba6d48a3a590b38c8b34b5106f0f2",
    swapWrapRouterLibrary: "0x2d85e3433ac95cace9ed42351d4885c832e57586",
    unxswapRouterLibrary: "0x7b92eb7c6af7178a95eba4b12b0dcfcecaf3198f",
    unxswapV3RouterLibrary: "0x1b154ecdf409ecd652a32951c30214780700094a",
}
