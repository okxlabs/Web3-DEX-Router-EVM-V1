/**
 * Permit2 Bytecode Verification Script
 * 
 * Usage:
 *   node scripts/permit2_bytecode_compare.js
 * 
 * Prerequisites:
 *   Configure RPC URLs in .env file with format: {CHAIN_NAME}_RPC_URL
 *   Example:
 *     ETH_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/xxx
 *     ARB_RPC_URL=https://arb-mainnet.g.alchemy.com/v2/xxx
 * 
 * Purpose:
 *   Verify that Permit2 contracts deployed across multiple chains have identical
 *   logic by comparing their runtime bytecode, ignoring known chain-specific positions.
 * 
 * Verification Method (Position-Based):
 *   Instead of simple string replacement (which could accidentally replace unrelated
 *   bytes that happen to match), this script uses a more precise approach:
 *   
 *   1. Find exact byte positions of chainId and DOMAIN_SEPARATOR in ETH bytecode
 *   2. For each chain, verify that:
 *      - At those positions, the values equal the expected chainId/DOMAIN_SEPARATOR
 *      - All other bytes are identical to ETH
 *   
 *   This ensures we only compare at known immutable variable locations.
 * 
 * Immutable Variables in Permit2:
 *   1. chainId (32 bytes, uint256 encoded)
 *      - Stored as: chainId.toString(16).padStart(64, '0')
 *   
 *   2. DOMAIN_SEPARATOR (32 bytes, keccak256 hash)
 *      - keccak256(abi.encode(
 *          keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)"),
 *          keccak256("Permit2"),
 *          chainId,
 *          0x000000000022D473030F116dDEE9F6B43aC78BA3
 *        ))
 */

require('dotenv').config();
const { ethers } = require('ethers');

const SupportNetworks = {
    eth: 1, arb: 42161, base: 8453, bsc: 56, avax: 43114, manta: 169,
    mode: 34443, op: 10, polygon: 137, scroll: 534352, sonic: 146,
    zeta: 7000, zksync: 324, unichain: 130, ftm: 250, cro: 25,
    conflux: 1030, polyzkevm: 1101, linea: 59144, mantle: 5000,
    metis: 1088, merlin: 4200, blast: 81457, xlayer: 196, sei: 1329,
    apechain: 33139, iotex: 4689, plasma: 9745, ethw: 10001, monad: 143
};

const Permit2Address = "0x000000000022D473030F116dDEE9F6B43aC78BA3";

function computeDomainSeparator(chainId) {
    const typeHash = ethers.utils.keccak256(
        ethers.utils.toUtf8Bytes("EIP712Domain(string name,uint256 chainId,address verifyingContract)")
    );
    const nameHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("Permit2"));
    return ethers.utils.keccak256(
        ethers.utils.defaultAbiCoder.encode(
            ["bytes32", "bytes32", "uint256", "address"],
            [typeHash, nameHash, chainId, Permit2Address]
        )
    ).slice(2).toLowerCase();
}

/**
 * Find all positions of a 32-byte value in bytecode
 * Returns array of byte offsets (not hex char offsets)
 */
function findPositions(code, value32bytes) {
    const positions = [];
    const codeWithoutPrefix = code.startsWith('0x') ? code.slice(2) : code;
    let idx = 0;
    while ((idx = codeWithoutPrefix.indexOf(value32bytes, idx)) !== -1) {
        positions.push(idx / 2); // Convert hex char offset to byte offset
        idx += 64;
    }
    return positions;
}

/**
 * Get 32 bytes (64 hex chars) at a specific byte offset
 */
function getValueAt(code, byteOffset) {
    const codeWithoutPrefix = code.startsWith('0x') ? code.slice(2) : code;
    return codeWithoutPrefix.slice(byteOffset * 2, byteOffset * 2 + 64);
}

/**
 * Compare two bytecodes, ignoring specified byte ranges
 * Returns: { identical: boolean, diffCount: number }
 */
function compareIgnoringRanges(code1, code2, ignoreRanges) {
    if (code1.length !== code2.length) return { identical: false, diffCount: -1 };
    
    const c1 = code1.startsWith('0x') ? code1.slice(2) : code1;
    const c2 = code2.startsWith('0x') ? code2.slice(2) : code2;
    
    // Create a set of byte offsets to ignore
    const ignoreBytes = new Set();
    for (const [start, len] of ignoreRanges) {
        for (let i = start; i < start + len; i++) ignoreBytes.add(i);
    }
    
    let diffCount = 0;
    for (let i = 0; i < c1.length / 2; i++) {
        if (ignoreBytes.has(i)) continue;
        if (c1.slice(i*2, i*2+2) !== c2.slice(i*2, i*2+2)) diffCount++;
    }
    return { identical: diffCount === 0, diffCount };
}

async function getCode(chain) {
    const rpcUrl = process.env[`${chain.toUpperCase()}_RPC_URL`];
    if (!rpcUrl) return { chain, status: 'NO_RPC' };
    try {
        const provider = new ethers.providers.JsonRpcProvider(rpcUrl);
        const code = await provider.getCode(Permit2Address);
        return { chain, code: code.toLowerCase(), status: code === '0x' ? 'NOT_DEPLOYED' : 'OK', chainId: SupportNetworks[chain] };
    } catch (e) {
        return { chain, status: 'RPC_ERROR', error: e.message };
    }
}

async function main() {
    const chains = Object.keys(SupportNetworks);
    const results = await Promise.all(chains.map(getCode));
    
    const ethResult = results.find(r => r.chain === 'eth');
    if (!ethResult || ethResult.status !== 'OK') {
        console.log('❌ Failed to fetch ETH Permit2 bytecode');
        return;
    }

    // Step 1: Find positions of chainId and DOMAIN_SEPARATOR in ETH bytecode
    const ethChainIdHex = ethResult.chainId.toString(16).padStart(64, '0');
    const ethDomainSep = computeDomainSeparator(ethResult.chainId);
    
    const chainIdPositions = findPositions(ethResult.code, ethChainIdHex);
    const domainSepPositions = findPositions(ethResult.code, ethDomainSep);
    
    console.log(`\nPermit2 Contract Verification (Address: ${Permit2Address})`);
    console.log(`\n--- Step 1: Locate immutable variables in ETH bytecode ---`);
    console.log(`chainId (${ethResult.chainId}) found at byte offsets: [${chainIdPositions.join(', ')}]`);
    console.log(`DOMAIN_SEPARATOR found at byte offsets: [${domainSepPositions.join(', ')}]`);
    
    // Build ignore ranges (each is [offset, length=32])
    const allPositions = [...chainIdPositions, ...domainSepPositions];
    const ignoreRanges = allPositions.map(pos => [pos, 32]);
    
    console.log(`\n--- Step 2: Verify each chain ---`);
    console.log(`Method: Check values at known positions, compare all other bytes\n`);
    console.log(`${'Chain'.padEnd(12)} | ${'ChainId'.padEnd(8)} | ${'Status'.padEnd(12)} | ${'Result'}`);
    console.log('-'.repeat(70));
    
    let verified = 0, failed = 0, skipped = 0;
    
    for (const r of results) {
        let result = '-';
        if (r.status === 'OK') {
            const expectedChainIdHex = r.chainId.toString(16).padStart(64, '0');
            const expectedDomainSep = computeDomainSeparator(r.chainId);
            
            // Verify chainId at expected positions
            let chainIdOk = chainIdPositions.every(pos => getValueAt(r.code, pos) === expectedChainIdHex);
            // Verify DOMAIN_SEPARATOR at expected positions
            let domainSepOk = domainSepPositions.every(pos => getValueAt(r.code, pos) === expectedDomainSep);
            // Compare all other bytes
            const comparison = compareIgnoringRanges(ethResult.code, r.code, ignoreRanges);
            
            if (chainIdOk && domainSepOk && comparison.identical) {
                result = '✅ Logic identical';
                verified++;
            } else {
                const issues = [];
                if (!chainIdOk) issues.push('chainId mismatch');
                if (!domainSepOk) issues.push('DOMAIN_SEP mismatch');
                if (!comparison.identical) issues.push(`${comparison.diffCount} bytes differ`);
                result = `❌ ${issues.join(', ')}`;
                failed++;
            }
        } else {
            result = r.status;
            skipped++;
        }
        const chainIdStr = r.chainId?.toString() || '-';
        const statusText = r.status === 'OK' ? 'DEPLOYED' : r.status;
        console.log(`${r.chain.padEnd(12)} | ${chainIdStr.padEnd(8)} | ${statusText.padEnd(12)} | ${result}`);
    }

    console.log('-'.repeat(70));
    console.log(`\nSummary: ${verified} verified, ${failed} failed, ${skipped} skipped`);
    
    if (failed === 0 && verified > 0) {
        console.log('\n✅ Conclusion: All deployed Permit2 contracts have identical logic');
        console.log('   (Only chainId and DOMAIN_SEPARATOR differ at expected positions)');
    } else if (failed > 0) {
        console.log('\n⚠️  Warning: Some contracts have unexpected differences');
    }
}

main();
