module.exports = {
    wNativeToken: "0x4F9A0e7FD2Bf6067db6994CF12E4495Df938E6e9",
    wNativeRelayer: "0xd2F0aC2012C8433F235c8e5e97F2368197DD06C7",
    tokenApprove: "0x57df6092665eb6058DE53939612413ff4B09114E",
    tokenApproveProxy: "0x1b5d39419C268b76Db06DE49e38B010fbFB5e226",
    permit2: "0x000000000022D473030F116dDEE9F6B43aC78BA3",
    dexRouter: "0x6b2C0c7be2048Daa9b5527982C29f48062B34D58",
    xbridge: "0x5965851f21DAE82eA7C62f87fb7C57172E9F2adD",
    //nftmarket: "",
    investEntrance: "0x7251FEbEABB01eC9dE53ECe7a96f1C951F886Dd2",
    limitOrder: "",
    protocolAdmin: "0x06C95a3934d94d5ae5bf54731bD2840ceFee6F87",
    // Disabled: the canonical UniV3 factory (0x1F98..984) is NOT deployed on Polygon zkEVM,
    // so the UnxswapV3 CREATE2 fast-path can never find pools here. zkEVM's actual UniV3 is a
    // GFX Labs deploy at 0xff83c3c800Fec21de45C5Ec30B69ddd5Ee60DFC2 (front-end DEPRECATED); not
    // wired in since the pool init code hash would also need verifying. Empty => zero bytes32.
    _FF_FACTORY: "",
    _CACHED_DOMAIN_SEPARATOR: "0xb37f5ff433f9eedcedff7b8ec82d49abd0e3102a3d97b7d7a645ce600f6919cb",
    _HASHED_NAME: "0x9569cad29571f225e7f2c73ecd677d78be383da74efd13f4af2bade05dc1a8de",
    _HASHED_VERSION: "0xe6bbd6277e1bf288eed5e8d1780f9a50b239e86b153736bceebccf4ea79d90b3",
    _TYPE_HASH: "0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f",
    _CACHED_CHAIN_ID: 1101,
    nftmarketplace: "0xa7FD99748cE527eAdC0bDAc60cba8a4eF4090f7c",
    p2pTrading: "0x0000000017D9a0231430ff2cc3467375a9Af76C7",
    proxyAdmin: "0xc6d8e2e0E5c25ACecff66BE60F257884D0e9DF50",
    // Recovered on-chain: prod deploy broadcast succeeded (ONCHAIN EXECUTION COMPLETE) but the
    // record step didn't run, so this was resolved via deployer CREATE nonce-5 address (code 13322,
    // matches sibling chains deployed at the same nonce). Libraries are at CREATE2 addresses.
    // ⚠️ OKLink source verification: published source on OKLink is WRONG (shows eth's ChainConfig —
    // _WETH 0xC02a, chainid 1) from a since-fixed verify tool bug. On-chain bytecode is correct
    // (polyzkevm config, proven: at all 60 config-differing byte positions on-chain matches
    // polyzkevm 60/60, eth 0/60). OKLink accepted the mismatched source (no strict match) and LOCKS
    // verified contracts, so it can't be overwritten via API/forge — needs OKLink-side re-verify.
    // See verify_via_foundry.js OKLink note.
    newImpl: "0x61e7E4936E546910658F9458Ddfd785B44EC91Ae",
}