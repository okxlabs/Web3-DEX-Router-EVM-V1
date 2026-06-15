#!/bin/bash

NETWORK=${1}

# Generates the per-chain ChainConfig.sol for the target network (gen-chainconfig.js)
FILES_TO_TRACK="contracts/8/libraries/CommonUtils.sol contracts/8/UnxswapV3Router.sol"

echo "Saving file states before modifications..."
# Save the current state of files that will be modified
git stash push --include-untracked -- ${FILES_TO_TRACK} > /dev/null 2>&1

# Run the checks
echo "Running contract replacement for network: ${NETWORK}"
npx hardhat run scripts/deploy/gen-chainconfig.js --network ${NETWORK}

echo "Compiling contracts..."
npx hardhat compile

echo "Checking implementation differences..."
npx hardhat run scripts/31_check_bytecode_exactout_Impl.js --network ${NETWORK}

# Reset contract constants back to Ethereum values
echo "Resetting back to original values..."
npx hardhat run scripts/deploy/gen-chainconfig.js --network eth

# Restore the original files from git stash
echo "Restoring original files from git..."
git checkout -- ${FILES_TO_TRACK}
git stash drop > /dev/null 2>&1

echo "✅ Check completed for ${NETWORK}"
