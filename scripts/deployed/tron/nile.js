// Nile TESTNET rehearsal record for the TRON deploy flow (deploy_dexrouter_tron.js --nile).
// Not a deploy environment (prod = base.js); these contracts exist only to prove the
// pipeline and measure energy costs. Safe to reset by emptying the fields.
module.exports = {
    owner: "0xd491C007D2B6250c3a6aa4415914346e035a3944", // TVMArd5cm9piDca8T6TsWdDHK4C3BjES1b (TRON governance owner) — matches base.js
    dagRouterLibrary: "TPS7TWKGzfsALWczpT8M99ENmfqX1iqTaU",
    smartSwapRouterLibrary: "TEPSzorGgeBc45vmqH74fPnUXamBzH1NGQ",
    swapWrapRouterLibrary: "TPo2vkdq92XksotcohNAJV4BdEDWkcxDqZ",
    unxswapRouterLibrary: "TDQYyasfm3zHh1sbZTFgfDcDssLX3isSjk",
    unxswapV3RouterLibrary: "TTqG86Rw8DndW2RCzANubs9ayQq3kn383z",
    newImpl: "TDikUyY85FF9Gg8M73BWEPEPmVzsnFCFi4",
    constructorArg: "0xAcE2B3E7c752d5deBca72210141d464371b3B9b1",
}
