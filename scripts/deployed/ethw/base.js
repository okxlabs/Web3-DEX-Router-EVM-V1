module.exports = {
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
    newImpl: "0x9A93a99ae01e1907dF6cb94dac122ae29E02f095"
}
