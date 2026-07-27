const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const { deployedPath, normalizeEnv } = require('./deployedEnv');
// NB: gen-chainconfig is required lazily inside verifyContracts, not here — it require()s this
// module back (for CHAINS/resolveChain), so a top-level require hits the circular-dependency
// partial-exports trap and `generate` comes back undefined.

const PROJECT_ROOT = path.join(__dirname, '..', '..');
const ENV_FILE = path.join(PROJECT_ROOT, '.env');

// Chain configurations (with optional aliases field for alternative names)
const CHAINS = {
  // verifier: etherscan, see https://docs.etherscan.io/supported-chains
  eth: { chainId: 1, verifierUrl: 'https://api.etherscan.io/v2/api?chainid=1', verifier: 'etherscan' },
  arb: { chainId: 42161, verifierUrl: 'https://api.etherscan.io/v2/api?chainid=42161', verifier: 'etherscan' },
  base: { chainId: 8453, verifierUrl: 'https://api.etherscan.io/v2/api?chainid=8453', verifier: 'etherscan' },
  bsc: { chainId: 56, verifierUrl: 'https://api.etherscan.io/v2/api?chainid=56', verifier: 'etherscan' },
  avax: { chainId: 43114, verifierUrl: 'https://api.etherscan.io/v2/api?chainid=43114', verifier: 'etherscan' },
  op: { chainId: 10, verifierUrl: 'https://api.etherscan.io/v2/api?chainid=10', verifier: 'etherscan' },
  polygon: { chainId: 137, verifierUrl: 'https://api.etherscan.io/v2/api?chainid=137', verifier: 'etherscan' },
  // scroll: Blockscout verified DexRouter but failed the 5 router libraries (library
  // self-address-guard bytecode). Scroll (534352) is Sourcify-supported, which auto-detects
  // the linked libraries and matches all 6 — moved to sourcify-api for reliable full coverage.
  scroll: { chainId: 534352, verifierUrl: 'https://sourcify.dev/server', verifier: 'sourcify-api' },
  sonic: { chainId: 146, verifierUrl: 'https://api.etherscan.io/v2/api?chainid=146', verifier: 'etherscan' },
  unichain: { chainId: 130, verifierUrl: 'https://api.etherscan.io/v2/api?chainid=130', verifier: 'etherscan' },
  linea: { chainId: 59144, verifierUrl: 'https://api.etherscan.io/v2/api?chainid=59144', verifier: 'etherscan' },
  mantle: { chainId: 5000, verifierUrl: 'https://api.etherscan.io/v2/api?chainid=5000', verifier: 'etherscan' },
  blast: { chainId: 81457, verifierUrl: 'https://api.etherscan.io/v2/api?chainid=81457', verifier: 'etherscan' },
  sei: { chainId: 1329, verifierUrl: 'https://api.etherscan.io/v2/api?chainid=1329', verifier: 'etherscan' },
  apechain: { chainId: 33139, verifierUrl: 'https://api.etherscan.io/v2/api?chainid=33139', verifier: 'etherscan' },
  plasma: { chainId: 9745, verifierUrl: 'https://api.etherscan.io/v2/api?chainid=9745', verifier: 'etherscan' },
  // verifier: sourcify or custom
  // verifier is 'sourcify-api' (not forge's native 'sourcify'): confirmed 2026-07-27 that
  // forge's native --verifier sourcify integration lands DexRouter as a Sourcify "partial
  // match" even for byte-correct code (same issue as iotex) — the direct v2 API submission
  // (scripts/deploy/sourcify.js) achieves full exact_match (both creation and runtime).
  monad: { chainId: 143, verifierUrl: 'https://sourcify-api-monad.blockvision.org/', verifier: 'sourcify-api' },
  zksyncEra: { chainId: 324, verifierUrl: 'https://block-explorer-api.mainnet.zksync.io/api', verifier: 'custom', aliases: ['zksync'] },
  // verifier: oklink
  // ⚠️ OKLink is a LENIENT verifier: it does NOT recompile-and-bytecode-match the submitted source
  // (proven — it published eth-config source for a polyzkevm contract whose on-chain bytecode
  // differs at 60 config positions), and it LOCKS a contract once verified (re-submission, even with
  // forge --skip-is-verified-check, returns success but does NOT overwrite the stored source).
  // Consequences: (1) correctness relies entirely on submitting the RIGHT source — always let this
  // script regenerate ChainConfig per-chain first (it now does); (2) a wrong source already published
  // can only be corrected OKLink-side (un-verify/re-verify), not via this tool. OKLink chain slug
  // must match OKLink's naming (e.g. Polygon zkEVM is `polygon_zkevm`, not the repo key `polyzkevm`).
  // NOTE: ftm & polyzkevm were moved OFF OKLink onto sourcify-api (see their entries below) — the
  // stale OKLink source there is superseded by correct, bytecode-matched source on Sourcify.
  // manta is the only chain still on OKLink.
  // manta: moved OFF OKLink onto SOURCIFY (Manta Pacific chainId 169 is Sourcify-supported) —
  // same rationale as ftm/polyzkevm: OKLink is lenient and locks stored source. Sourcify does a
  // fresh bytecode match. Verified 6/6 (2026-07).
  manta: { chainId: 169, verifierUrl: 'https://sourcify.dev/server', verifier: 'sourcify-api' },
  // ftm & polyzkevm: moved OFF OKLink onto SOURCIFY. OKLink is lenient (no bytecode match) and
  // had published wrong source that it then LOCKS (can't overwrite via API). Sourcify does a
  // fresh recompile-and-match on its own host and is unaffected by OKLink's stored copy — both
  // exact_match against the current per-chain ChainConfig (verified 2026-07). The OKLink pages
  // remain wrong until corrected OKLink-side, but the source is now correctly public on Sourcify.
  ftm: { chainId: 250, verifierUrl: 'https://sourcify.dev/server', verifier: 'sourcify-api' },
  polyzkevm: { chainId: 1101, verifierUrl: 'https://sourcify.dev/server', verifier: 'sourcify-api' },
  xlayer: { chainId: 196, verifierUrl: 'https://www.oklink.com/api/v5/explorer/contract/verify-source-code-plugin/xlayer', verifier: 'oklink' },
  ethw: { chainId: 10001, verifierUrl: 'https://www.oklink.com/api/v5/explorer/contract/verify-source-code-plugin/ethw', verifier: 'oklink' },
  // verifier: blockscout (no API key required)
  // cro: Cronos's own explorer API (explorer-api.cronos.org) sits behind Cloudflare, whose WAF
  // deterministically blocks the verifysourcecode POST once real source pushes the body past
  // ~90 KB (content + size — confirmed 2026-07 by bisection; browser headers/multipart/retries
  // don't help). So verify via SOURCIFY instead: Cronos (chainId 25) is Sourcify-supported.
  // The sourcify-api verifier talks to sourcify.dev directly (a different host → no CF block)
  // and auto-detects DexRouter's linked libraries. Verified 6/6 this way (2026-07).
  // ⚠️ The source is public/verified on SOURCIFY (sourcify.dev/#/lookup/<addr>), but Cronoscan
  // does NOT back-read Sourcify, so its own contract page still shows unverified. To make the
  // Cronoscan page show source, verify against .../mainnet/api/v2 (verifier 'etherscan' +
  // apiKeyEnv CROSCAN_API_KEY) — but that's the CF-blocked path, so it needs the web UI.
  cro: { chainId: 25, verifierUrl: 'https://sourcify.dev/server', verifier: 'sourcify-api' },
  metis: { chainId: 1088, verifierUrl: 'https://andromeda-explorer.metis.io/api/', verifier: 'blockscout' },
  // zeta: the native explorer (zetascan.com) was network-blocked from the local dev environment,
  // so verify via SOURCIFY instead — ZetaChain (chainId 7000) is Sourcify-supported. Verified
  // 6/6 this way (source public at sourcify.dev/#/lookup/<addr>). As with cro, an Etherscan-style
  // zeta explorer would not back-read Sourcify; switch to a blockscout/etherscan verifier against
  // the native explorer if its own page must show source.
  zeta: { chainId: 7000, verifierUrl: 'https://sourcify.dev/server', verifier: 'sourcify-api' },
  mode: { chainId: 34443, verifierUrl: 'https://explorer.mode.network/api/', verifier: 'blockscout' },
  // robinhood: RobinHood Chain (chainId 4663) — Blockscout explorer, Etherscan-compatible /api,
  // no API key required (mirrors the hardhat.config customChain). Not on Sourcify's chain list,
  // so blockscout is the path. (RPC/explorer are network-blocked from the local dev env — run
  // deploy/verify from an unblocked network; prod go-live is the securityManager addProxy gate.)
  robinhood: { chainId: 4663, verifierUrl: 'https://robinhoodchain.blockscout.com/api', verifier: 'blockscout' },
  // ink: Ink L2 (chainId 57073) — Blockscout explorer, Etherscan-compatible /api, no API key
  // required (mirrors the hardhat.config customChain).
  ink: { chainId: 57073, verifierUrl: 'https://explorer.inkonchain.com/api', verifier: 'blockscout' },
  // verifier: custom — ConfluxScan eSpace is Etherscan-compatible; per Conflux docs any
  // ETHERSCAN_API_KEY value works as a dummy key.
  conflux: { chainId: 1030, verifierUrl: 'https://evmapi.confluxscan.org/api/', verifier: 'custom' },
  // hyperevm: HyperEVMScan is an Etherscan-family explorer on the Etherscan V2 multichain API.
  hyperevm: { chainId: 999, verifierUrl: 'https://api.etherscan.io/v2/api?chainid=999', verifier: 'etherscan' },
  // verifier: manual (flatten contracts for web verification)
  // merlin: L2scan explorer — Etherscan-style verification API (POST /api, solidity-standard-json-input),
  // no API key required. Docs: https://unifra.readme.io/reference/contract-verification-api
  merlin: { chainId: 4200, verifierUrl: 'https://scan.merlinchain.io/api', verifier: 'custom' },
  // iotex: verified via Sourcify (officially supports chainId 4689). IoTeXscan's own APIs are
  // dead ends (2026-07-02): the documented https://iotexscan.io/api → 404 + Cloudflare 403 to
  // non-browser clients; the sample repo's index.iotexscan.io no longer resolves in DNS.
  // IoTeXscan imports Sourcify matches, and manual UI upload (verify/iotex/ flattened sources)
  // remains the fallback.
  // verifier is 'sourcify-api' (not forge's native 'sourcify'): confirmed 2026-07-27 that
  // forge's native --verifier sourcify integration lands DexRouter as Sourcify "partial match"
  // (runtimeMatch only) even for byte-correct code — resubmitting the identical standard-json
  // via scripts/deploy/sourcify.js's direct v2 API call flips it to exact_match with zero code
  // changes. Router libraries were unaffected either way (always exact_match).
  iotex: { chainId: 4689, verifierUrl: 'https://sourcify.dev/server', verifier: 'sourcify-api' },
  // pharos (Pharos Network mainnet): verified via SocialScan's Foundry-compatible endpoint
  // (etherscan mode). chain_name is `pharos-mainnet`; the key is SOCIALSCAN_API_KEY.
  // ⚠️ api.socialscan.io is network-blocked from the local dev environment (000) — run this
  // verification from an unblocked network / CI (same as the old zeta zetascan situation).
  pharos: {
    chainId: 1672,
    verifierUrl: 'https://api.socialscan.io/pharos-mainnet/v1/explorer/command_api/contract',
    verifier: 'etherscan',
    apiKeyEnv: 'SOCIALSCAN_API_KEY',
  },
  // NOTE: staging is an environment (--env stg), NOT a separate chain. stg deploys to the
  // same chain (same chainId/rpc/verifier) and only uses a different address set
  // (deployed/<chain>/stg.js). So there are no *_stg entries here.
};

/**
 * Resolve chain name from argument (supports aliases and case-insensitive lookup)
 * @param {string} chainArg - Chain name or alias
 * @returns {string|null} - Resolved chain name or null if not found
 */
function resolveChain(chainArg) {
  const lowerArg = chainArg.toLowerCase();
  
  // First try direct match (case-insensitive)
  for (const chainName of Object.keys(CHAINS)) {
    if (chainName.toLowerCase() === lowerArg) {
      return chainName;
    }
  }
  
  // Then try aliases (case-insensitive)
  for (const [chainName, config] of Object.entries(CHAINS)) {
    if (config.aliases) {
      for (const alias of config.aliases) {
        if (alias.toLowerCase() === lowerArg) {
          return chainName;
        }
      }
    }
  }
  
  return null;
}

/**
 * Read .env file and return environment variables as object
 * @returns {Object} - Environment variables
 */
function readEnvFile() {
  if (!fs.existsSync(ENV_FILE)) {
    return {};
  }
  
  const envContent = fs.readFileSync(ENV_FILE, 'utf8');
  const envVars = {};
  
  for (const line of envContent.split('\n')) {
    const trimmed = line.trim();
    // Skip empty lines and comments
    if (!trimmed || trimmed.startsWith('#')) {
      continue;
    }
    
    const match = trimmed.match(/^([^=]+)=(.*)$/);
    if (match) {
      const key = match[1].trim();
      let value = match[2].trim();
      // Remove surrounding quotes if present
      if ((value.startsWith('"') && value.endsWith('"')) || 
          (value.startsWith("'") && value.endsWith("'"))) {
        value = value.slice(1, -1);
      }
      envVars[key] = value;
    }
  }
  
  return envVars;
}

// Load environment variables from .env
const ENV_VARS = readEnvFile();

// Router library contract names
// Router libraries linked into the contracts/8 DexRouter (and recorded/verified with it).
// NOTE: UnxswapExactOutRouter / UnxswapV3ExactOutRouter are NOT here — they belong to the
// separate DexRouterExactOut deploy under contracts/exactout/ (different module/flow). Listing
// them caused verify to look for contracts/8/router/UnxswapExactOutRouter.sol (which doesn't
// exist) and fail. The exactout flow maintains its own list.
const ROUTER_LIBRARIES = [
  'SmartSwapRouter',
  'DagRouter',
  'UnxswapRouter',
  'UnxswapV3Router',
  'SwapWrapRouter',
];

/**
 * Convert contract name to field name in camelCase with Library suffix
 * e.g., "DagRouter" -> "dagRouterLibrary"
 * @param {string} contractName - Contract name
 * @returns {string} - Field name in camelCase
 */
function contractNameToFieldName(contractName) {
  return contractName.charAt(0).toLowerCase() + contractName.slice(1) + 'Library';
}

/**
 * Convert field name to contract name
 * e.g., "dagRouterLibrary" -> "DagRouter"
 * @param {string} fieldName - Field name in camelCase
 * @returns {string} - Contract name
 */
function fieldNameToContractName(fieldName) {
  const withoutSuffix = fieldName.replace(/Library$/, '');
  return withoutSuffix.charAt(0).toUpperCase() + withoutSuffix.slice(1);
}

/**
 * Read base.js and extract contract addresses
 * @param {string} chain - Chain name
 * @returns {Object} - Object containing addresses
 */
function readBaseJs(chain, env) {
  const basePath = deployedPath(chain, env);

  if (!fs.existsSync(basePath)) {
    throw new Error(`addresses file not found for ${chain}/${normalizeEnv(env)}`);
  }
  
  // Clear require cache to ensure fresh read
  delete require.cache[require.resolve(basePath)];
  const baseConfig = require(basePath);
  
  const addresses = {
    newImpl: baseConfig.newImpl || '',
    constructorArg: baseConfig.constructorArg || '',
    libraries: {},
  };
  
  // Extract library addresses using camelCase field names
  for (const contractName of ROUTER_LIBRARIES) {
    const fieldName = contractNameToFieldName(contractName);
    if (baseConfig[fieldName]) {
      addresses.libraries[fieldName] = baseConfig[fieldName];
    }
  }
  
  return addresses;
}

/**
 * Generate verify command for a contract
 * @param {string} contractAddress - Contract address
 * @param {string} contractPath - Contract path (e.g., "contracts/8/DexRouter.sol:DexRouter")
 * @param {Object} chainConfig - Chain configuration
 * @param {Object} options - Additional options
 * @returns {string} - Verify command
 */
function generateVerifyCommand(contractAddress, contractPath, chainConfig, chain, options = {}) {
  const { constructorArgs, libraries, force } = options;

  let cmd = 'forge verify-contract';
  
  if (chainConfig.verifier === 'sourcify' || chainConfig.verifier === 'custom') {
    const rpcChain = chain === 'zksyncEra' ? 'zksync' : chain;
    cmd += ` \\\n  --rpc-url ${rpcChain}`;
    cmd += ` \\\n  --verifier ${chainConfig.verifier}`;
    cmd += ` \\\n  --verifier-url '${chainConfig.verifierUrl}'`;
    cmd += ` \\\n  --compiler-version 0.8.17`;
    cmd += ` \\\n  --num-of-optimizations 200`;
    
    if (constructorArgs) {
      cmd += ` \\\n  --constructor-args $(cast abi-encode "constructor(address)" ${constructorArgs})`;
    }
    
    if (libraries && Object.keys(libraries).length > 0) {
      for (const [libField, libAddr] of Object.entries(libraries)) {
        const contractName = fieldNameToContractName(libField);
        cmd += ` \\\n  --libraries contracts/8/router/${contractName}.sol:${contractName}:${libAddr}`;
      }
    }
    
    // custom (etherscan-compatible) explorers like merlin's L2scan answer the "already
    // verified?" pre-check (getabi) for UNVERIFIED contracts with status=1 + empty result,
    // which forge fails to parse and aborts before ever submitting. Always skip the pre-check.
    if (chainConfig.verifier === 'custom') {
      cmd += ` \\\n  --skip-is-verified-check`;
    }

    cmd += ` \\\n  ${contractAddress}`;
    cmd += ` \\\n  ${contractPath}`;
  } else if (chainConfig.verifier === 'blockscout') {
    // Blockscout needs no API key; it uses the host's /api/ endpoint. Like sourcify, forge
    // will hijack this to etherscan if ETHERSCAN_API_KEY is set — executeCommand blanks it.
    cmd += ` \\\n  ${contractAddress}`;
    cmd += ` \\\n  ${contractPath}`;
    cmd += ` \\\n  --verifier blockscout`;
    cmd += ` \\\n  --verifier-url "${chainConfig.verifierUrl}"`;
    cmd += ` \\\n  --num-of-optimizations 200`;
    cmd += ` \\\n  --compiler-version v0.8.17+commit.8df45f5f`;
    // Some Blockscout instances are key-gated (e.g. Cronos explorer-api). If the chain config names
    // an API-key env var and it's set, pass it — forge includes it in the requests. executeCommand
    // still blanks the ambient ETHERSCAN_API_KEY so forge honors `--verifier blockscout`.
    if (chainConfig.apiKeyEnv) {
      const k = ENV_VARS[chainConfig.apiKeyEnv] || process.env[chainConfig.apiKeyEnv] || '';
      // Shell env reference, not the literal key — executeCommand injects the value into the
      // child env, so the secret never appears in logs, saved files, or `ps` output.
      if (k) cmd += ` \\\n  --etherscan-api-key "$${chainConfig.apiKeyEnv}"`;
    }

    if (constructorArgs) {
      cmd += ` \\\n  --constructor-args $(cast abi-encode "constructor(address)" ${constructorArgs})`;
    }

    if (libraries && Object.keys(libraries).length > 0) {
      for (const [libField, libAddr] of Object.entries(libraries)) {
        const contractName = fieldNameToContractName(libField);
        cmd += ` \\\n  --libraries contracts/8/router/${contractName}.sol:${contractName}:${libAddr}`;
      }
    }

    cmd += ` \\\n  --watch`;
  } else if (chainConfig.verifier === 'oklink') {
    cmd += ` \\\n  ${contractAddress}`;
    cmd += ` \\\n  ${contractPath}`;
    cmd += ` \\\n  --verifier oklink`;
    cmd += ` \\\n  --verifier-url "${chainConfig.verifierUrl}"`;
    cmd += ` \\\n  --num-of-optimizations 200`;
    cmd += ` \\\n  --compiler-version v0.8.17+commit.8df45f5f`;
    
    if (constructorArgs) {
      cmd += ` \\\n  --constructor-args $(cast abi-encode "constructor(address)" ${constructorArgs})`;
    }
    
    if (libraries && Object.keys(libraries).length > 0) {
      for (const [libField, libAddr] of Object.entries(libraries)) {
        const contractName = fieldNameToContractName(libField);
        cmd += ` \\\n  --libraries contracts/8/router/${contractName}.sol:${contractName}:${libAddr}`;
      }
    }
    
    cmd += ` \\\n  --watch`;
  } else {
    // etherscan
    cmd += ` \\\n  ${contractAddress}`;
    cmd += ` \\\n  ${contractPath}`;
    cmd += ` \\\n  --verifier etherscan`;
    cmd += ` \\\n  --verifier-url "${chainConfig.verifierUrl}"`;
    // Most etherscan-family explorers share the unified ETHERSCAN_API_KEY; a few key-gated ones
    // (e.g. Cronos explorer-api) need their own key — chainConfig.apiKeyEnv names that env var.
    const keyVar = chainConfig.apiKeyEnv || 'ETHERSCAN_API_KEY';
    const apiKey = ENV_VARS[keyVar] || process.env[keyVar] || '';
    if (!apiKey) {
      console.warn(`⚠️  Warning: ${keyVar} not found in .env file or environment`);
    }
    // Shell env reference, not the literal key — executeCommand injects the value into the
    // child env, so the secret never appears in logs, saved files, or `ps` output.
    cmd += ` \\\n  --etherscan-api-key "$${keyVar}"`;
    cmd += ` \\\n  --num-of-optimizations 200`;
    cmd += ` \\\n  --compiler-version v0.8.17+commit.8df45f5f`;
    
    if (constructorArgs) {
      cmd += ` \\\n  --constructor-args $(cast abi-encode "constructor(address)" ${constructorArgs})`;
    }
    
    if (libraries && Object.keys(libraries).length > 0) {
      for (const [libField, libAddr] of Object.entries(libraries)) {
        const contractName = fieldNameToContractName(libField);
        cmd += ` \\\n  --libraries contracts/8/router/${contractName}.sol:${contractName}:${libAddr}`;
      }
    }
    
    cmd += ` \\\n  --watch`;
  }

  // --force: re-submit even if the explorer already reports the contract verified. Needed to
  // OVERWRITE a previously-published wrong source (e.g. a lenient verifier like OKLink that
  // accepted mismatched source), which forge would otherwise skip via its is-verified pre-check.
  if (force) {
    cmd += ` \\\n  --skip-is-verified-check`;
  }

  return cmd;
}

/**
 * Generate all verify commands for a chain
 * @param {string} chain - Chain name
 * @param {Object} addresses - Extracted addresses
 * @param {Object} chainConfig - Chain configuration
 * @returns {Array} - Array of command objects {name, command}
 */
function generateVerifyCommands(chain, addresses, chainConfig, opts = {}) {
  const commands = [];
  const { force = false } = opts;

  // sourcify-api: submitted over HTTP to the Sourcify v2 API (bypasses Cloudflare-guarded
  // explorers and forge's legacy-sourcify pre-check), not as a shell command. Carry the
  // address + contract identifier; the loop calls verifyViaSourcify() for these.
  const isSourcifyApi = chainConfig.verifier === 'sourcify-api';
  const sourcifyEntry = (name, address, contractId) => ({
    name,
    sourcify: { address, contractId, chainId: chainConfig.chainId, serverUrl: chainConfig.verifierUrl },
  });

  // Verify DexRouter
  if (addresses.newImpl) {
    const id = 'contracts/8/DexRouter.sol:DexRouter';
    commands.push(
      isSourcifyApi
        ? sourcifyEntry('DexRouter', addresses.newImpl, id)
        : {
            name: 'DexRouter',
            command: generateVerifyCommand(addresses.newImpl, id, chainConfig, chain, {
              constructorArgs: addresses.constructorArg,
              libraries: addresses.libraries,
              force,
            }),
          }
    );
  }

  // Verify each library contract
  for (const [libField, libAddr] of Object.entries(addresses.libraries)) {
    const contractName = fieldNameToContractName(libField);
    const contractPath = `contracts/8/router/${contractName}.sol:${contractName}`;

    commands.push(
      isSourcifyApi
        ? sourcifyEntry(contractName, libAddr, contractPath)
        : { name: contractName, command: generateVerifyCommand(libAddr, contractPath, chainConfig, chain, { force }) }
    );
  }

  return commands;
}

// Secrets must never reach logs or generated files: mask explorer API key values wherever a
// constructed forge command is printed or persisted (the key still goes to forge unmasked).
const API_KEY_ARG_RE = /(--etherscan-api-key[=\s]+)(\S+)/g;
// forge's etherscan verifier appends the resolved key to its request URL (?apikey=… / &apikey=…)
// and echoes that URL in error output — mask it too, else the secret leaks into captured logs
// and the saved verify_commands.sh on failure.
const API_KEY_QUERY_RE = /([?&]apikey=)([^&\s"']+)/gi;
function maskApiKeys(text) {
  // "$VAR" env references carry no secret — leave them readable; mask only literal values.
  return text == null ? text : String(text)
    .replace(API_KEY_ARG_RE, (m, pre, val) => (/^["']?\$/.test(val) ? m : `${pre}***`))
    .replace(API_KEY_QUERY_RE, (m, pre) => `${pre}***`);
}

/**
 * Execute a command and return the result
 * @param {string} command - Command to execute
 * @param {string} name - Name of the contract being verified
 * @returns {Object} - {success, output}
 */
function executeCommand(command, name) {
  console.log(`\n${'='.repeat(60)}`);
  console.log(`Verifying ${name}...`);
  console.log(`${'='.repeat(60)}`);
  console.log(`Command:\n${maskApiKeys(command)}\n`);
  
  // Convert multiline command to single line for execution
  const singleLineCmd = command.replace(/\s*\\\n\s*/g, ' ');

  // forge auto-selects the etherscan verifier whenever ETHERSCAN_API_KEY is present — this
  // silently overrides an explicit `--verifier sourcify|blockscout` and then fails because the
  // host-only URL isn't a valid etherscan API endpoint (e.g. monad sourcify, cronos blockscout).
  // Blank the key for those verifications so forge honors the requested verifier.
  // NB: must set to '' (not delete) — forge auto-loads .env from the project root, so a deleted
  // var is re-populated from .env; an explicit empty value in the child env is NOT overridden.
  const env = { ...process.env };
  // Commands reference explorer keys as "$<VAR>" shell expansions (never literals) — inject
  // the values from .env into the child env so the shell resolves them at exec time.
  for (const [k, v] of Object.entries(ENV_VARS)) {
    if (/_API_KEY$/.test(k) && env[k] === undefined) env[k] = v;
  }
  if (/--verifier\s+(sourcify|blockscout)\b/.test(singleLineCmd)) {
    env.ETHERSCAN_API_KEY = '';
  }

  try {
    const output = execSync(singleLineCmd, {
      cwd: PROJECT_ROOT,
      encoding: 'utf8',
      stdio: ['pipe', 'pipe', 'pipe'],
      env,
      // Standard-json verifications (e.g. Cronos) echo the whole source; the default 1MB capture
      // buffer overflows with `spawnSync /bin/sh ENOBUFS`. Give it plenty of room.
      maxBuffer: 256 * 1024 * 1024,
      // `forge verify-contract --watch` polls until a terminal state and can hang forever when
      // the explorer's indexer lags behind a fresh deploy (observed: 37min silent hang on
      // hyperevm). Cap each contract; a timeout surfaces as a normal failure and the loop
      // moves on — re-run verification later once the explorer has indexed the deploy.
      timeout: 10 * 60 * 1000,
      killSignal: 'SIGKILL',
    });
    
    console.log(`✅ ${name} verification submitted successfully`);
    console.log('Output:', maskApiKeys(output));
    return { success: true, output: maskApiKeys(output) };
  } catch (error) {
    // execSync error.message embeds the full failed command line — mask before it can leak.
    console.log(`❌ ${name} verification failed`);
    console.log('Error:', maskApiKeys(error.message));
    if (error.stdout) console.log('stdout:', maskApiKeys(error.stdout));
    if (error.stderr) console.log('stderr:', maskApiKeys(error.stderr));
    // Include stdout/stderr in the returned output — the retry loop classifies transient
    // failures (indexing lag, rate limits) by signatures that only appear there.
    return {
      success: false,
      output: maskApiKeys([error.message, error.stdout, error.stderr].filter(Boolean).join('\n')),
    };
  }
}

/**
 * Flatten contracts for manual verification
 * @param {string} chain - Chain name
 * @param {Object} addresses - Extracted addresses
 * @returns {boolean} - Success status
 */
function flattenContracts(chain, addresses) {
  const outputDir = path.join(PROJECT_ROOT, 'verify', chain);
  
  // Create output directory
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }
  
  console.log(`\n${'='.repeat(60)}`);
  console.log(`Flattening contracts for ${chain} (manual verification)`);
  console.log(`Output directory: ${outputDir}`);
  console.log(`${'='.repeat(60)}\n`);
  
  // Always flatten DexRouter and all known router libraries
  const contractsToFlatten = [
    { name: 'DexRouter', path: 'contracts/8/DexRouter.sol', address: addresses.newImpl },
  ];
  
  // Add all known library contracts (flatten all, not just those with addresses)
  for (const contractName of ROUTER_LIBRARIES) {
    const fieldName = contractNameToFieldName(contractName);
    contractsToFlatten.push({
      name: contractName,
      path: `contracts/8/router/${contractName}.sol`,
      address: addresses.libraries[fieldName] || '',
    });
  }
  
  const results = [];
  
  for (const contract of contractsToFlatten) {
    const outputPath = path.join(outputDir, `${contract.name}_flattened.sol`);
    const cmd = `forge flatten ${contract.path} > "${outputPath}"`;
    
    const addrInfo = contract.address ? ` (${contract.address})` : '';
    console.log(`Flattening ${contract.name}${addrInfo}...`);
    
    try {
      execSync(cmd, {
        cwd: PROJECT_ROOT,
        encoding: 'utf8',
        shell: true,
      });
      
      console.log(`  ✅ ${contract.name} flattened to: ${outputPath}`);
      results.push({ name: contract.name, success: true, path: outputPath, address: contract.address });
    } catch (error) {
      console.log(`  ❌ Failed to flatten ${contract.name}: ${error.message}`);
      results.push({ name: contract.name, success: false, error: error.message });
    }
  }
  
  return results;
}

/**
 * Main verification function - can be called by other scripts
 * @param {string} chainArg - Chain name argument
 * @param {Object} options - Options { dryRun: boolean }
 * @returns {Object} - Result object
 */
async function verifyContracts(chainArg, options = {}) {
  const { dryRun = false, env = 'prod', force = false } = options;
  
  // Resolve chain name (supports aliases and case-insensitive lookup)
  const chain = resolveChain(chainArg);
  
  if (!chain) {
    throw new Error(`Unknown chain "${chainArg}". Supported chains: ${Object.keys(CHAINS).join(', ')}`);
  }
  
  const chainConfig = CHAINS[chain];
  console.log(`\nProcessing ${chain.toUpperCase()} (Chain ID: ${chainConfig.chainId})`);
  console.log(`Verifier: ${chainConfig.verifier}`);
  console.log(`Verifier URL: ${chainConfig.verifierUrl}`);
  
  // Read addresses from the env's addresses file
  const addresses = readBaseJs(chain, env);

  // Regenerate ChainConfig.sol for THIS chain BEFORE flattening/compiling. Otherwise we verify
  // against whatever ChainConfig.sol is checked in (a stale per-chain seed), which publishes the
  // wrong constants on the explorer — e.g. eth's _WETH/_FF_FACTORY and _EXPECTED_CHAIN_ID=1 for a
  // non-eth chain. Mirrors deploy-and-verify Step 1 so the verified source matches on-chain bytecode.
  console.log(`\nRegenerating ChainConfig.sol for ${chain}/${normalizeEnv(env)} (match deployed bytecode) ...`);
  require('./gen-chainconfig').generate(chain, env); // lazy require — see note by the imports

  console.log('\nFound addresses:');
  console.log(`  newImpl: ${addresses.newImpl || '(not found)'}`);
  if (addresses.constructorArg) {
    console.log(`  Constructor arg (owner): ${addresses.constructorArg}`);
  }
  console.log('  Libraries:');
  for (const [name, addr] of Object.entries(addresses.libraries)) {
    console.log(`    ${name}: ${addr}`);
  }
  if (Object.keys(addresses.libraries).length === 0) {
    console.log('    (no libraries found)');
  }
  
  const result = {
    chain,
    verifier: chainConfig.verifier,
    addresses,
    commands: [],
    results: [],
  };
  
  // Handle manual verification via flattening
  // For manual, we always flatten contracts regardless of addresses
  if (chainConfig.verifier === 'manual') {
    const flattenResults = flattenContracts(chain, addresses);
    result.flattenResults = flattenResults;
    result.success = flattenResults.every(r => r.success);
    
    console.log(`\n${'='.repeat(60)}`);
    console.log('MANUAL VERIFICATION');
    console.log(`${'='.repeat(60)}`);
    console.log(`Flattened files are in: ${path.join(PROJECT_ROOT, 'verify', chain)}/`);
    console.log(`Please upload these files manually on the block explorer.`);
    
    return result;
  }
  
  // Check if there are contracts to verify (for etherscan/oklink/sourcify)
  if (!addresses.newImpl && Object.keys(addresses.libraries).length === 0) {
    console.log('\n⚠️  No contracts found to verify. Make sure base.js contains newImpl or library addresses.');
    return { success: false, message: 'No contracts to verify' };
  }
  
  // Generate verify commands for etherscan/oklink/sourcify
  const commands = generateVerifyCommands(chain, addresses, chainConfig, { force });
  result.commands = commands;
  
  if (dryRun) {
    console.log(`\n${'='.repeat(60)}`);
    console.log('VERIFY COMMANDS (dry run - not executing):');
    console.log(`${'='.repeat(60)}`);
    
    // Create output directory
    const outputDir = path.join(PROJECT_ROOT, 'verify', chain);
    if (!fs.existsSync(outputDir)) {
      fs.mkdirSync(outputDir, { recursive: true });
    }
    
    // Build commands content. API keys appear only as "$VAR" env references (and any stray
    // literal would be masked) — no secret is ever persisted to disk.
    let commandsContent = `# Verify commands for ${chain.toUpperCase()} (Chain ID: ${chainConfig.chainId})\n`;
    commandsContent += `# Generated at: ${new Date().toISOString()}\n`;
    commandsContent += `# Verifier: ${chainConfig.verifier}\n`;
    commandsContent += `# NOTE: API keys are "$VAR" env references — run \`set -a; source .env; set +a\` first when executing manually.\n\n`;

    for (const { name, command, sourcify } of commands) {
      // sourcify-api entries are HTTP submissions, not shell commands — describe the action.
      const line = sourcify
        ? `# (Sourcify v2 API) POST ${sourcify.serverUrl}/v2/verify/${sourcify.chainId}/${sourcify.address}  [${sourcify.contractId}]`
        : maskApiKeys(command);
      console.log(`\n# Verify ${name}`);
      console.log(line);

      commandsContent += `# Verify ${name}\n`;
      commandsContent += `${line}\n\n`;
    }
    
    // Save to file
    const outputFile = path.join(outputDir, 'verify_commands.sh');
    fs.writeFileSync(outputFile, commandsContent, 'utf8');
    console.log(`\n✅ Commands saved to: ${outputFile}`);
    
    result.success = true;
    result.outputFile = outputFile;
    return result;
  }
  
  // Execute verification commands
  console.log(`\n${'='.repeat(60)}`);
  console.log('EXECUTING VERIFICATION COMMANDS');
  console.log(`${'='.repeat(60)}`);
  
  // Explorer failures right after a deploy are frequently transient — the indexer hasn't
  // seen the new contract yet ("Unable to locate ContractCode") or the API is rate-limiting
  // ("Too many requests", e.g. merlin's L2scan). Retry those with a growing pause; anything
  // else (compile mismatch, bad config) fails fast.
  // "Cannot fetch bytecode" = Sourcify's own RPC transiently failed to read the deployed code
  // (observed on manta) — retryable, same as explorer indexing lag / rate limits.
  const TRANSIENT_RE = /Unable to locate ContractCode|Too many requests|not.{0,20}indexed|rate.?limit|Cannot fetch bytecode/i;
  const MAX_ATTEMPTS = 3;
  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
  const { verifyViaSourcify } = require('./sourcify');
  for (const entry of commands) {
    const { name, command, sourcify } = entry;
    let execResult;
    for (let attempt = 1; ; attempt++) {
      if (sourcify) {
        console.log(`\n${'='.repeat(60)}\nVerifying ${name} via Sourcify v2 (${sourcify.serverUrl})...\n${'='.repeat(60)}`);
        execResult = await verifyViaSourcify(sourcify.serverUrl, sourcify.chainId, sourcify.address, sourcify.contractId);
        console.log(execResult.success ? `✅ ${name}: ${execResult.output}` : `❌ ${name}: ${execResult.output}`);
      } else {
        execResult = executeCommand(command, name);
      }
      if (execResult.success || attempt >= MAX_ATTEMPTS || !TRANSIENT_RE.test(execResult.output || '')) break;
      const waitS = 45 * attempt;
      console.log(`⏳ ${name}: transient explorer failure (indexing lag / rate limit) — retrying in ${waitS}s (attempt ${attempt + 1}/${MAX_ATTEMPTS})...`);
      await sleep(waitS * 1000);
    }
    result.results.push({ name, ...execResult });
  }
  
  // Summary
  console.log(`\n${'='.repeat(60)}`);
  console.log('VERIFICATION SUMMARY');
  console.log(`${'='.repeat(60)}`);
  
  const successful = result.results.filter(r => r.success).length;
  const failed = result.results.filter(r => !r.success).length;
  
  console.log(`Total: ${result.results.length}`);
  console.log(`✅ Successful: ${successful}`);
  console.log(`❌ Failed: ${failed}`);
  
  for (const r of result.results) {
    const status = r.success ? '✅' : '❌';
    console.log(`  ${status} ${r.name}`);
  }
  
  result.success = failed === 0;
  return result;
}

// CLI interface
function main() {
  const args = process.argv.slice(2);
  
  if (args.length === 0 || args[0] === '--help' || args[0] === '-h') {
    console.log('Usage: node scripts/deploy/verify_via_foundry.js <chain> [options]');
    console.log('');
    console.log('Reads contract addresses from base.js and verifies contracts on block explorers.');
    console.log('');
    console.log('Options:');
    console.log('  --dry-run    Generate commands without executing them');
    console.log('  --env <e>    Target environment: prod (default) | stg');
    console.log('  --force,-f   Re-submit even if already verified (overwrite wrong published source)');
    console.log('');
    console.log('Verifier types:');
    console.log('  - etherscan: Generates and executes forge verify-contract commands');
    console.log('  - oklink: Generates and executes forge verify-contract commands');
    console.log('  - sourcify: Generates and executes forge verify-contract commands');
    console.log('  - sourcify-api: Submits to the Sourcify v2 API directly (bypasses Cloudflare-guarded explorers)');
    console.log('  - manual: Flattens contracts for manual web verification');
    console.log('');
    console.log('Supported chains:');
    console.log('  etherscan: ' + Object.entries(CHAINS).filter(([_, c]) => c.verifier === 'etherscan').map(([k]) => k).join(', '));
    console.log('  sourcify: ' + Object.entries(CHAINS).filter(([_, c]) => c.verifier === 'sourcify').map(([k]) => k).join(', '));
    console.log('  sourcify-api: ' + Object.entries(CHAINS).filter(([_, c]) => c.verifier === 'sourcify-api').map(([k]) => k).join(', '));
    console.log('  oklink: ' + Object.entries(CHAINS).filter(([_, c]) => c.verifier === 'oklink').map(([k]) => k).join(', '));
    console.log('  manual: ' + Object.entries(CHAINS).filter(([_, c]) => c.verifier === 'manual').map(([k]) => k).join(', '));
    process.exit(0);
  }
  
  const chainArg = args[0];
  const dryRun = args.includes('--dry-run');
  const force = args.includes('--force') || args.includes('-f');
  const envIdx = args.indexOf('--env');
  const env = envIdx !== -1 ? args[envIdx + 1] : 'prod';

  verifyContracts(chainArg, { dryRun, env, force })
    .then(result => {
      process.exit(result.success ? 0 : 1);
    })
    .catch(error => {
      console.error('Error:', error.message);
      process.exit(1);
    });
}

// Export for use as module
module.exports = {
  verifyContracts,
  CHAINS,
  resolveChain,
  ROUTER_LIBRARIES,
  contractNameToFieldName,
  fieldNameToContractName,
};

// Run CLI if called directly
if (require.main === module) {
  main();
}
