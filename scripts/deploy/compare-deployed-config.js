/**
 * compare-deployed-config — diff the baked-in config constants of each chain's VERIFIED
 * deployed DexRouter (pulled via fetch-source's multi-provider resolver) against
 * scripts/deployed/<chain>/base.js.
 *
 * The constants (_WETH/_APPROVE_PROXY/_PERMIT2/_FF_FACTORY) are compile-time `constant`s
 * with no getters, so verified source is the only way to confirm what was deployed.
 *
 * Run: node scripts/deploy/compare-deployed-config.js [chain] [--env prod|stg]
 * Coverage is whatever fetch-source can reach from the current network (see that file).
 */
const { CHAINS, resolveChain } = require("./verify_via_foundry");
const { loadDeployed, normalizeEnv } = require("./deployedEnv");
const { fetchSource } = require("./fetch-source");

// Lark table "dexRouter" addresses (the contracts the user maintains). Target these so we
// compare the table's contract; also cross-checked against base.newImpl.
const LARK = {
  eth: "0x28b1Dc1a5E3699A428BC51d234DFab7C9CB2a183", arb: "0x7CF6b330b437E9fb432B1400DE17B03357Cf049A",
  base: "0xC8F6b8Ba0DC0f175B568B99440B0867F69A29265", bsc: "0x62cceF0b4545166f721cAa9fEe13c1d3767E27dc",
  avax: "0xa94Fcf9fc56a864f8DE51e6315aee5863AD63C91", op: "0xDd5E9B947c99Aa60bab00ca4631Dce63b49983E7",
  polygon: "0xF6E1B4b201e220FC3741bd7a75675ffEA25c02AD", scroll: "0x5e2F47bD7D4B357fCfd0Bb224Eb665773B1B9801",
  sonic: "0x79f7C6C6dc16Ed3154E85A8ef9c1Ef31CEFaEB19", unichain: "0x6733Eb2E75B1625F1Fe5f18aD2cB2BaBDA510d19",
  linea: "0x2E1Dee213BA8d7af0934C49a23187BabEACa8764", mantle: "0xcF76984119C7f6ae56fAfE680d39C08278b7eCF4",
  blast: "0x6F91349e4161068c1cA6BAAce1570621bb00FDeb", sei: "0xDd5E9B947c99Aa60bab00ca4631Dce63b49983E7",
  apechain: "0xcF76984119C7f6ae56fAfE680d39C08278b7eCF4", plasma: "0x19D345f95A80cc136d898f41b490E023cFF78658",
  manta: "0x69C236E021F5775B0D0328ded5EaC708E3B869DF", mode: "0xcF76984119C7f6ae56fAfE680d39C08278b7eCF4",
  zeta: "0xF5402CCC5fC3181B45D7571512999D3Eea0257B6", zksyncEra: "0x6f7c20464258c732577c87a9B467619e03e5C158",
  ftm: "0x25e7f77F33206d311A0130D4b5B881E5Db1181b1", cro: "0x25e7f77F33206d311A0130D4b5B881E5Db1181b1",
  conflux: "0x95418635f012fFd10eAFcDaF4137e90371f06917", polyzkevm: "0x6f7c20464258c732577c87a9B467619e03e5C158",
  metis: "0x25e7f77F33206d311A0130D4b5B881E5Db1181b1", merlin: "0x6f7c20464258c732577c87a9B467619e03e5C158",
  xlayer: "0x722db4f285F8bD91ef7AF6DA397e83f7fA4E80a7", ethw: "0xD1b8997AaC08c619d40Be2e4284c9C72cAB33954",
  iotex: "0x2E1Dee213BA8d7af0934C49a23187BabEACa8764", pharos: "0x75f21a97bd89a9a5683a9f46b5d5b4a080708dea",
  hyperevm: "0x9Ac7b1FFEE0f58c0a3c89AA54Afb62efD25DC9fd", monad: "0x7A7AD9aa93cd0A2D0255326E5Fb145CEc14997FF",
};

const eq = (a, b) => !!a && !!b && a.toLowerCase() === b.toLowerCase();
// "", undefined, all-zero collapse to one bucket: an empty base.js field and an on-chain
// zero constant both mean "disabled".
const norm = (x) => (!x || /^0x0+$/.test(x)) ? "ZERO" : x.toLowerCase();
const ex = (src, name, form) => { const m = src.match(new RegExp(name + "\\s*=\\s*(" + form + ")")); return m ? m[1] : null; };

(async () => {
  const only = process.argv.find((a, i) => i >= 2 && !a.startsWith("--") && process.argv[i - 1] !== "--env");
  const env = normalizeEnv(process.argv.includes("--env") ? process.argv[process.argv.indexOf("--env") + 1] : "prod");
  const chains = (only ? [resolveChain(only)] : Object.keys(CHAINS)).filter(Boolean).filter((c) => loadDeployed(c, env));
  console.log(`comparing ${chains.length} chains (env ${env})\n`);
  const rows = [];
  for (const c of chains) {
    const b = loadDeployed(c, env) || {};
    const target = LARK[c] || b.newImpl;
    const r = await fetchSource(c, target, { env });
    const src = r.ok ? r.sourceCode : "";
    const dW = ex(src, "_WETH", "0x[0-9a-fA-F]{40}"), dA = ex(src, "_APPROVE_PROXY", "0x[0-9a-fA-F]{40}");
    const dP = ex(src, "_PERMIT2", "0x[0-9a-fA-F]{40}"), dF = ex(src, "_FF_FACTORY", "0x[0-9a-fA-F]{2,64}");
    const cmp = (d, bv) => (!src ? "—" : d == null ? "n/a" : norm(d) === norm(bv) ? "OK" : "MISMATCH");
    rows.push({
      c, via: r.ok ? r.via : `unreached`, implMatchLark: eq(target, b.newImpl),
      W: cmp(dW, b.wNativeToken), A: cmp(dA, b.tokenApproveProxy), P: cmp(dP, b.permit2), F: cmp(dF, b._FF_FACTORY),
      dW, dA, dP, dF, bW: b.wNativeToken, bA: b.tokenApproveProxy, bP: b.permit2, bF: b._FF_FACTORY, reason: r.reason,
    });
  }
  const ic = (s) => ({ OK: "✓", MISMATCH: "✗", "n/a": "·", "—": "—" }[s] || s);
  console.log("chain        via                    Lark?  WETH APPROVE PERMIT2 FF");
  for (const r of rows) {
    console.log(r.c.padEnd(12), String(r.via).padEnd(22), (r.implMatchLark ? "yes" : "NO ").padEnd(6),
      ic(r.W).padEnd(4), ic(r.A).padEnd(7), ic(r.P).padEnd(7), ic(r.F));
  }
  console.log("\n=== MISMATCH / notes ===");
  let any = false;
  for (const r of rows) {
    if (!r.implMatchLark) { any = true; console.log(`${r.c}: base.newImpl != Lark table address`); }
    for (const [lab, st, d, bv] of [["WETH", r.W, r.dW, r.bW], ["APPROVE_PROXY", r.A, r.dA, r.bA], ["PERMIT2", r.P, r.dP, r.bP], ["FF_FACTORY", r.F, r.dF, r.bF]]) {
      if (st === "MISMATCH") { any = true; console.log(`${r.c} ${lab}: on-chain=${d}  base.js=${bv}`); }
    }
  }
  if (!any) console.log("(no mismatches among fetched chains)");
  const fetched = rows.filter((r) => r.W !== "—").length;
  console.log(`\nfetched ${fetched}/${rows.length} (unreached chains need open network egress — see fetch-source.js)`);
})();
