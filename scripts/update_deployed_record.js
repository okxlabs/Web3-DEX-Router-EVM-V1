/**
 * Update deployed records with deployment addresses from all chains
 * 
 * Usage:
 *   node scripts/update_deployed_record.js <version> [--chains chain1,chain2,...]
 * 
 * Examples:
 *   node scripts/update_deployed_record.js v1.0.8-transfer-mode
 *   node scripts/update_deployed_record.js v1.0.8-transfer-mode --chains eth,bsc,arb
 * 
 * This script reads deployment addresses from each chain's base.js file and:
 *   1. Updates all_in_one_record.json with all versions and all chains
 *   2. Updates individual chain files ({chainName}_{chainId}.json) with that chain's versions
 * 
 * Records: DexRouter and router/ library contracts (same as foundry_broadcast_record.js)
 */

const fs = require('fs');
const path = require('path');
const { CHAINS, ROUTER_LIBRARIES, contractNameToFieldName } = require('./deploy/verify_via_foundry');

const DEPLOYED_DIR = path.join(__dirname, 'deployed');
const RECORD_DIR = path.join(__dirname, 'deployed_record');
const ALL_IN_ONE_FILE = path.join(RECORD_DIR, 'all_in_one_record.json');

// All supported chains
const ALL_CHAINS = Object.keys(CHAINS);

/**
 * Build field mapping from ROUTER_LIBRARIES
 * Format: { base.js field name -> output contract name }
 */
function buildFieldMapping() {
  const mapping = {
    'newImpl': 'DexRouter', // DexRouter implementation
  };
  
  // Add all router libraries
  for (const contractName of ROUTER_LIBRARIES) {
    const fieldName = contractNameToFieldName(contractName);
    mapping[fieldName] = contractName;
  }
  
  return mapping;
}

const FIELD_MAPPING = buildFieldMapping();

/**
 * Get chain record file path
 * @param {string} chain - Chain name
 * @returns {string} - File path
 */
function getChainRecordPath(chain) {
  const chainConfig = CHAINS[chain];
  if (!chainConfig) return null;
  return path.join(RECORD_DIR, `${chain}_${chainConfig.chainId}.json`);
}

/**
 * Parse command line arguments
 */
function parseArgs() {
  const args = process.argv.slice(2);
  
  if (args.length === 0 || args[0] === '--help' || args[0] === '-h') {
    console.log('Usage: node scripts/update_deployed_record.js <version> [--chains chain1,chain2,...]');
    console.log('');
    console.log('Arguments:');
    console.log('  version              Version tag (e.g., v1.0.8-transfer-mode)');
    console.log('  --chains <chains>    Comma-separated list of chains to update (default: all)');
    console.log('');
    console.log('Examples:');
    console.log('  node scripts/update_deployed_record.js v1.0.8-transfer-mode');
    console.log('  node scripts/update_deployed_record.js v1.0.8-transfer-mode --chains eth,bsc,arb');
    console.log('');
    console.log('Output files:');
    console.log('  - scripts/deployed_record/all_in_one_record.json (all versions, all chains)');
    console.log('  - scripts/deployed_record/{chain}_{chainId}.json (per-chain records)');
    console.log('');
    console.log('Fields recorded (from base.js -> output):');
    for (const [src, out] of Object.entries(FIELD_MAPPING)) {
      console.log(`  ${src} -> ${out}`);
    }
    console.log('');
    console.log('Available chains:');
    console.log('  ' + ALL_CHAINS.join(', '));
    process.exit(0);
  }
  
  const version = args[0];
  let chains = ALL_CHAINS;
  
  // Parse --chains argument
  const chainsIndex = args.indexOf('--chains');
  if (chainsIndex !== -1 && args[chainsIndex + 1]) {
    chains = args[chainsIndex + 1].split(',').map(c => c.trim());
  }
  
  return { version, chains };
}

/**
 * Read and parse a base.js file
 * @param {string} chain - Chain name
 * @returns {Object|null} - Parsed config object or null if not found
 */
function readBaseJs(chain) {
  const basePath = path.join(DEPLOYED_DIR, chain, 'base.js');
  
  if (!fs.existsSync(basePath)) {
    return null;
  }
  
  try {
    // Clear require cache to get fresh data
    delete require.cache[require.resolve(basePath)];
    return require(basePath);
  } catch (e) {
    console.error(`  ⚠️  Error reading ${chain}/base.js: ${e.message}`);
    return null;
  }
}

/**
 * Extract relevant fields from base.js config
 * @param {Object} config - Parsed base.js config
 * @returns {Object} - Extracted fields with mapped names
 */
function extractFields(config) {
  const result = {};
  
  for (const [sourceField, outputField] of Object.entries(FIELD_MAPPING)) {
    if (config[sourceField] && config[sourceField] !== '') {
      result[outputField] = config[sourceField];
    }
  }
  
  return result;
}

/**
 * Read existing JSON record file
 * @param {string} filePath - Path to JSON file
 * @returns {Object} - Existing records or empty object
 */
function readJsonRecord(filePath) {
  if (!fs.existsSync(filePath)) {
    return {};
  }
  
  try {
    const content = fs.readFileSync(filePath, 'utf8').trim();
    if (!content) return {};
    return JSON.parse(content);
  } catch (e) {
    console.error(`⚠️  Error reading ${filePath}: ${e.message}`);
    return {};
  }
}

/**
 * Write JSON record file
 * @param {string} filePath - Path to JSON file
 * @param {Object} record - Record object to write
 */
function writeJsonRecord(filePath, record) {
  const content = JSON.stringify(record, null, 2);
  fs.writeFileSync(filePath, content, 'utf8');
}

/**
 * Sort record by version keys (newest first)
 * @param {Object} record - Record object
 * @returns {Object} - Sorted record
 */
function sortRecordByVersion(record) {
  const sortedRecord = {};
  const sortedKeys = Object.keys(record).sort((a, b) => {
    // Try to extract version numbers for sorting
    const versionRegex = /v?(\d+)\.(\d+)\.(\d+)/;
    const matchA = a.match(versionRegex);
    const matchB = b.match(versionRegex);
    
    if (matchA && matchB) {
      // Compare major, minor, patch versions
      for (let i = 1; i <= 3; i++) {
        const diff = parseInt(matchB[i]) - parseInt(matchA[i]);
        if (diff !== 0) return diff;
      }
    }
    
    // Fallback to string comparison (reversed for desc order)
    return b.localeCompare(a);
  });
  
  for (const key of sortedKeys) {
    sortedRecord[key] = record[key];
  }
  
  return sortedRecord;
}

/**
 * Ensure record directory exists
 */
function ensureRecordDir() {
  if (!fs.existsSync(RECORD_DIR)) {
    fs.mkdirSync(RECORD_DIR, { recursive: true });
  }
}

/**
 * Main function
 */
function main() {
  const { version, chains } = parseArgs();
  
  console.log(`\n📝 Updating deployed records`);
  console.log(`   Version: ${version}`);
  console.log(`   Chains: ${chains.join(', ')}`);
  console.log('');
  
  // Ensure record directory exists
  ensureRecordDir();
  
  // Read existing all-in-one record
  const allInOneRecord = readJsonRecord(ALL_IN_ONE_FILE);
  
  // Initialize version entry if not exists
  if (!allInOneRecord[version]) {
    allInOneRecord[version] = {};
  }
  
  let updatedCount = 0;
  let skippedCount = 0;
  const updatedChainFiles = [];
  
  // Process each chain
  for (const chain of chains) {
    const config = readBaseJs(chain);
    
    if (!config) {
      console.log(`  ⏭️  ${chain}: skipped (base.js not found)`);
      skippedCount++;
      continue;
    }
    
    const fields = extractFields(config);
    
    if (Object.keys(fields).length === 0) {
      console.log(`  ⏭️  ${chain}: skipped (no relevant fields found)`);
      skippedCount++;
      continue;
    }
    
    // Update all-in-one record
    allInOneRecord[version][chain] = fields;
    
    // Update individual chain record
    const chainRecordPath = getChainRecordPath(chain);
    if (chainRecordPath) {
      const chainRecord = readJsonRecord(chainRecordPath);
      chainRecord[version] = fields;
      writeJsonRecord(chainRecordPath, sortRecordByVersion(chainRecord));
      updatedChainFiles.push(path.basename(chainRecordPath));
    }
    
    console.log(`  ✅ ${chain}: ${Object.keys(fields).length} fields recorded`);
    updatedCount++;
  }
  
  // Sort and write all-in-one record
  writeJsonRecord(ALL_IN_ONE_FILE, sortRecordByVersion(allInOneRecord));
  
  console.log('');
  console.log(`✅ Updated: ${updatedCount} chains`);
  console.log(`⏭️  Skipped: ${skippedCount} chains`);
  console.log('');
  console.log('📁 Output files:');
  console.log(`   - ${ALL_IN_ONE_FILE}`);
  for (const file of updatedChainFiles) {
    console.log(`   - ${path.join(RECORD_DIR, file)}`);
  }
}

main();
