const fs = require('fs');
const path = require('path');
const { CHAINS, resolveChain, ROUTER_LIBRARIES, contractNameToFieldName } = require('./verify_via_foundry');

const BROADCAST_DIR = path.join(__dirname, '../broadcast');
const DEPLOYED_DIR = path.join(__dirname, 'deployed');

/**
 * Update a field in base.js file
 * @param {string} baseBasePath - Path to base.js file
 * @param {string} fieldName - Field name
 * @param {string} fieldValue - Field value
 */
function updateBaseJsField(baseBasePath, fieldName, fieldValue) {
    let baseContent = fs.readFileSync(baseBasePath, 'utf8');
  
    const fieldRegex = new RegExp(`${fieldName}:\\s*["'][^"']*["']`);
  
    if (fieldRegex.test(baseContent)) {
      // Field exists, replace it
      baseContent = baseContent.replace(
        fieldRegex,
        `${fieldName}: "${fieldValue}"`
      );
    } else {
      // Field does not exist, add it as the last field before closing brace
      // Check if the last field already has a trailing comma
      if (/,\s*\n}(\s*)$/.test(baseContent)) {
        // Last field has trailing comma, just add new field
        baseContent = baseContent.replace(
          /(\n})(\s*)$/,
          `\n    ${fieldName}: "${fieldValue}",\n}$2`
        );
      } else {
        // Last field has no trailing comma, add comma before new field
        baseContent = baseContent.replace(
          /(\n})(\s*)$/,
          `,\n    ${fieldName}: "${fieldValue}",\n}$2`
        );
      }
    }
  
    fs.writeFileSync(baseBasePath, baseContent);
    console.log(`Updated ${fieldName} to: ${fieldValue}`);
}

function readBroadcast(scriptName, chainId) {
  const broadcastPath = path.join(BROADCAST_DIR, scriptName, String(chainId), 'run-latest.json');
  if (!fs.existsSync(broadcastPath)) {
    return null;
  }
  return JSON.parse(fs.readFileSync(broadcastPath, 'utf8'));
}

function extractAddresses(broadcast) {
  const addresses = {
    newImpl: '',
    libraries: {},
  };

  if (!broadcast) return addresses;

  // Extract DexRouter address from transactions
  if (broadcast.transactions) {
    for (const tx of broadcast.transactions) {
      if (!tx.contractName || !tx.contractAddress) continue;
      if (tx.transactionType !== 'CREATE') continue;
      
      if (tx.contractName === 'DexRouter') {
        addresses.newImpl = tx.contractAddress;
        break;
      }
    }
  }

  // Extract library addresses from libraries array
  // Format: "contracts/8/router/SwapWrapRouter.sol:SwapWrapRouter:0x..."
  if (broadcast.libraries && Array.isArray(broadcast.libraries)) {
    for (const lib of broadcast.libraries) {
      const parts = lib.split(':');
      if (parts.length >= 3) {
        const contractName = parts[1]; // e.g., "SwapWrapRouter"
        const address = parts[2]; // e.g., "0x..."
        
        // Check if this is a known router library
        if (ROUTER_LIBRARIES.includes(contractName)) {
          const fieldName = contractNameToFieldName(contractName);
          addresses.libraries[fieldName] = address;
        }
      }
    }
  }

  return addresses;
}

function updateBaseJs(chain, addresses) {
  const basePath = path.join(DEPLOYED_DIR, chain, 'base.js');
  
  if (!fs.existsSync(basePath)) {
    console.error(`Error: ${basePath} not found`);
    return false;
  }

  // Update newImpl address (DexRouter contract)
  if (addresses.newImpl) {
    updateBaseJsField(basePath, 'newImpl', addresses.newImpl);
  }
  
  // Update library addresses (camelCase format, e.g., dagRouterLibrary)
  for (const [libName, libAddr] of Object.entries(addresses.libraries)) {
    updateBaseJsField(basePath, libName, libAddr);
  }
  
  return true;
}

function extractConstructorArgs(broadcast) {
  if (!broadcast || !broadcast.transactions) return null;

  for (const tx of broadcast.transactions) {
    if (tx.contractName === 'DexRouter' && tx.transactionType === 'CREATE') {
      // arguments 数组的第一个元素是 owner 地址
      if (tx.arguments && tx.arguments.length > 0) {
        return tx.arguments[0];
      }
    }
  }
  return null;
}

function main() {
  const args = process.argv.slice(2);

  if (args.length === 0 || args[0] === '--help' || args[0] === '-h') {
    console.log('Usage: node scripts/foundry_broadcast_record.js <chain>');
    console.log('');
    console.log('Reads DexRouter deployment data from broadcast/ and updates base.js');
    console.log('');
    console.log('Fields updated in base.js:');
    console.log('  - newImpl: DexRouter contract address');
    for (const contractName of ROUTER_LIBRARIES) {
      const fieldName = contractNameToFieldName(contractName);
      console.log(`  - ${fieldName}: ${contractName} library address`);
    }
    console.log('');
    console.log('After updating base.js, run verify_via_foundry.js to verify contracts:');
    console.log('  node scripts/verify_via_foundry.js <chain>');
    console.log('');
    console.log('Supported chains:');
    console.log('  ' + Object.keys(CHAINS).join(', '));
    process.exit(0);
  }

  const chainArg = args[0];
  // Resolve chain name (supports aliases and case-insensitive lookup)
  const chain = resolveChain(chainArg);

  if (!chain) {
    console.error(`Error: Unknown chain "${chainArg}"`);
    console.error(`Supported chains: ${Object.keys(CHAINS).join(', ')}`);
    process.exit(1);
  }

  const chainConfig = CHAINS[chain];
  console.log(`Processing ${chain.toUpperCase()} (Chain ID: ${chainConfig.chainId})`);
  console.log('');

  // Read DexRouter deployment broadcast
  const broadcast = readBroadcast('DeployDexRouter.s.sol', chainConfig.chainId);
  
  if (!broadcast) {
    console.error(`Error: Broadcast file not found for DeployDexRouter.s.sol on chain ${chainConfig.chainId}`);
    console.error(`Expected path: broadcast/DeployDexRouter.s.sol/${chainConfig.chainId}/run-latest.json`);
    process.exit(1);
  }

  const addresses = extractAddresses(broadcast);
  const constructorArg = extractConstructorArgs(broadcast);

  console.log('Found addresses:');
  console.log(`  newImpl: ${addresses.newImpl || '(not found)'}`);
  if (constructorArg) {
    console.log(`  Constructor arg (owner): ${constructorArg}`);
    // Also save the constructorArg to base.js for verify script to use
    const basePath = path.join(DEPLOYED_DIR, chain, 'base.js');
    if (fs.existsSync(basePath)) {
      updateBaseJsField(basePath, 'constructorArg', constructorArg);
    }
  }
  console.log('  Libraries:');
  for (const [name, addr] of Object.entries(addresses.libraries)) {
    console.log(`    ${name}: ${addr}`);
  }
  if (Object.keys(addresses.libraries).length === 0) {
    console.log('    (no libraries found)');
  }
  console.log('');

  // Update base.js
  if (updateBaseJs(chain, addresses)) {
    console.log(`✅ Updated scripts/deployed/${chain}/base.js`);
    console.log('');
    console.log('Next step: Run verification script');
    console.log(`  node scripts/verify_via_foundry.js ${chain}`);
    console.log('');
  }
}

main();
