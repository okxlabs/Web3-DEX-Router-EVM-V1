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
  scroll: { chainId: 534352, verifierUrl: 'https://blockscout.scroll.io/api/', verifier: 'blockscout' },
  sonic: { chainId: 146, verifierUrl: 'https://api.etherscan.io/v2/api?chainid=146', verifier: 'etherscan' },
  unichain: { chainId: 130, verifierUrl: 'https://api.etherscan.io/v2/api?chainid=130', verifier: 'etherscan' },
  linea: { chainId: 59144, verifierUrl: 'https://api.etherscan.io/v2/api?chainid=59144', verifier: 'etherscan' },
  mantle: { chainId: 5000, verifierUrl: 'https://api.etherscan.io/v2/api?chainid=5000', verifier: 'etherscan' },
  blast: { chainId: 81457, verifierUrl: 'https://api.etherscan.io/v2/api?chainid=81457', verifier: 'etherscan' },
  sei: { chainId: 1329, verifierUrl: 'https://api.etherscan.io/v2/api?chainid=1329', verifier: 'etherscan' },
  apechain: { chainId: 33139, verifierUrl: 'https://api.etherscan.io/v2/api?chainid=33139', verifier: 'etherscan' },
  plasma: { chainId: 9745, verifierUrl: 'https://api.etherscan.io/v2/api?chainid=9745', verifier: 'etherscan' },
  // verifier: sourcify or custom
  monad: { chainId: 143, verifierUrl: 'https://sourcify-api-monad.blockvision.org/', verifier: 'sourcify' },
  zksyncEra: { chainId: 324, verifierUrl: 'https://block-explorer-api.mainnet.zksync.io/api', verifier: 'custom', aliases: ['zksync'] },
  // verifier: oklink
  manta: { chainId: 169, verifierUrl: 'https://www.oklink.com/api/v5/explorer/contract/verify-source-code-plugin/manta', verifier: 'oklink' },
  ftm: { chainId: 250, verifierUrl: 'https://www.oklink.com/api/v5/explorer/contract/verify-source-code-plugin/ftm', verifier: 'oklink' },
  // OKLink's chain slug for Polygon zkEVM is `polygon_zkevm`, not the repo chain key `polyzkevm`
  // (a wrong slug makes forge's getabi pre-check return an undeserializable response).
  polyzkevm: { chainId: 1101, verifierUrl: 'https://www.oklink.com/api/v5/explorer/contract/verify-source-code-plugin/polygon_zkevm', verifier: 'oklink' },
  xlayer: { chainId: 196, verifierUrl: 'https://www.oklink.com/api/v5/explorer/contract/verify-source-code-plugin/xlayer', verifier: 'oklink' },
  ethw: { chainId: 10001, verifierUrl: 'https://www.oklink.com/api/v5/explorer/contract/verify-source-code-plugin/ethw', verifier: 'oklink' },
  // verifier: blockscout (no API key required)
  cro: { chainId: 25, verifierUrl: 'https://explorer-api.cronos.org/mainnet/api/', verifier: 'blockscout' },
  metis: { chainId: 1088, verifierUrl: 'https://andromeda-explorer.metis.io/api/', verifier: 'blockscout' },
  zeta: { chainId: 7000, verifierUrl: 'https://zetachain.blockscout.com/api/', verifier: 'blockscout' },
  mode: { chainId: 34443, verifierUrl: 'https://explorer.mode.network/api/', verifier: 'blockscout' },
  // verifier: custom — ConfluxScan eSpace is Etherscan-compatible; per Conflux docs any
  // ETHERSCAN_API_KEY value works as a dummy key.
  conflux: { chainId: 1030, verifierUrl: 'https://evmapi.confluxscan.org/api/', verifier: 'custom' },
  // hyperevm: HyperEVMScan is an Etherscan-family explorer on the Etherscan V2 multichain API.
  hyperevm: { chainId: 999, verifierUrl: 'https://api.etherscan.io/v2/api?chainid=999', verifier: 'etherscan' },
  // verifier: manual (flatten contracts for web verification)
  merlin: { chainId: 4200, verifier: 'manual' },
  iotex: { chainId: 4689, verifier: 'manual' },
  pharos: { chainId: 1672, verifier: 'manual' },
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
    const apiKey = ENV_VARS.ETHERSCAN_API_KEY || process.env.ETHERSCAN_API_KEY || '';
    if (!apiKey) {
      console.warn('⚠️  Warning: ETHERSCAN_API_KEY not found in .env file or environment');
    }
    cmd += ` \\\n  --etherscan-api-key ${apiKey}`;
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

  // Verify DexRouter
  if (addresses.newImpl) {
    const cmd = generateVerifyCommand(
      addresses.newImpl,
      'contracts/8/DexRouter.sol:DexRouter',
      chainConfig,
      chain,
      {
        constructorArgs: addresses.constructorArg,
        libraries: addresses.libraries,
        force,
      }
    );
    commands.push({ name: 'DexRouter', command: cmd });
  }

  // Verify each library contract
  for (const [libField, libAddr] of Object.entries(addresses.libraries)) {
    const contractName = fieldNameToContractName(libField);
    const contractPath = `contracts/8/router/${contractName}.sol:${contractName}`;

    const cmd = generateVerifyCommand(libAddr, contractPath, chainConfig, chain, { force });
    commands.push({ name: contractName, command: cmd });
  }
  
  return commands;
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
  console.log(`Command:\n${command}\n`);
  
  // Convert multiline command to single line for execution
  const singleLineCmd = command.replace(/\s*\\\n\s*/g, ' ');

  // forge auto-selects the etherscan verifier whenever ETHERSCAN_API_KEY is present — this
  // silently overrides an explicit `--verifier sourcify|blockscout` and then fails because the
  // host-only URL isn't a valid etherscan API endpoint (e.g. monad sourcify, cronos blockscout).
  // Blank the key for those verifications so forge honors the requested verifier.
  // NB: must set to '' (not delete) — forge auto-loads .env from the project root, so a deleted
  // var is re-populated from .env; an explicit empty value in the child env is NOT overridden.
  const env = { ...process.env };
  if (/--verifier\s+(sourcify|blockscout)\b/.test(singleLineCmd)) {
    env.ETHERSCAN_API_KEY = '';
  }

  try {
    const output = execSync(singleLineCmd, {
      cwd: PROJECT_ROOT,
      encoding: 'utf8',
      stdio: ['pipe', 'pipe', 'pipe'],
      env,
    });
    
    console.log(`✅ ${name} verification submitted successfully`);
    console.log('Output:', output);
    return { success: true, output };
  } catch (error) {
    console.log(`❌ ${name} verification failed`);
    console.log('Error:', error.message);
    if (error.stdout) console.log('stdout:', error.stdout);
    if (error.stderr) console.log('stderr:', error.stderr);
    return { success: false, output: error.message };
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
    
    // Build commands content
    let commandsContent = `# Verify commands for ${chain.toUpperCase()} (Chain ID: ${chainConfig.chainId})\n`;
    commandsContent += `# Generated at: ${new Date().toISOString()}\n`;
    commandsContent += `# Verifier: ${chainConfig.verifier}\n\n`;
    
    for (const { name, command } of commands) {
      console.log(`\n# Verify ${name}`);
      console.log(command);
      
      commandsContent += `# Verify ${name}\n`;
      commandsContent += `${command}\n\n`;
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
  
  for (const { name, command } of commands) {
    const execResult = executeCommand(command, name);
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
    console.log('  - manual: Flattens contracts for manual web verification');
    console.log('');
    console.log('Supported chains:');
    console.log('  etherscan: ' + Object.entries(CHAINS).filter(([_, c]) => c.verifier === 'etherscan').map(([k]) => k).join(', '));
    console.log('  sourcify: ' + Object.entries(CHAINS).filter(([_, c]) => c.verifier === 'sourcify').map(([k]) => k).join(', '));
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
