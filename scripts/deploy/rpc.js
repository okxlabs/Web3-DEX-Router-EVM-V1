// Shared RPC-url resolver for a chain.
//
// Resolution order (matches the .env-as-single-source-of-truth convention):
//   1) env var <CHAIN>_RPC_URL (also tries each CHAINS alias, e.g. zksync for zksyncEra)
//   2) the hardhat network config url (hre.config.networks[chain].url)
// Returns null if none is configured.
//
// Extracted from tasks/check-impl.js so the deploy gate, the standalone
// verify-chainconfig task, and check-impl all share one implementation.
function rpcUrlFor(chain, hre, CHAINS) {
  const aliases = (CHAINS && CHAINS[chain] && CHAINS[chain].aliases) || [];
  for (const c of [chain, ...aliases]) {
    const env = process.env[`${c.toUpperCase()}_RPC_URL`];
    if (env) return env;
  }
  if (hre && hre.config && hre.config.networks) {
    for (const c of [chain, ...aliases]) {
      const net = hre.config.networks[c];
      if (net && net.url) return net.url;
    }
  }
  return null;
}

module.exports = { rpcUrlFor };
