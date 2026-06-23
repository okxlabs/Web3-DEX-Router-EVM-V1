/**
 * Gas limit configuration for NATIVE_TOKEN_TRANSFER_GAS_LIMIT constant
 * 
 * Most chains use the default value (100000).
 * Only special chains with different gas requirements are listed here.
 */

// Default gas limit for most chains
const DEFAULT_GAS_LIMIT = 100000;

// Special chain gas limits (network name -> gas limit)
// Add chains here only if they need a different value than DEFAULT_GAS_LIMIT
const SPECIAL_GAS_LIMITS = {
    // Chains that need specific gas limits for native token transfers
    "conflux": 200000,
    "monad": 150000,
};

/**
 * Get the gas limit for a specific network
 * @param {string} networkName - The name of the network
 * @returns {number} - The gas limit for native token transfers
 */
function getGasLimit(networkName) {
    if (SPECIAL_GAS_LIMITS.hasOwnProperty(networkName)) {
        return SPECIAL_GAS_LIMITS[networkName];
    }
    return DEFAULT_GAS_LIMIT;
}

module.exports = {
    getGasLimit
};

