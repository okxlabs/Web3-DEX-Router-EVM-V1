// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import "@dex/DexRouter.sol";
// Brings _EXPECTED_CHAIN_ID (and the rest of the per-chain ChainConfig) into scope.
import "@dex/libraries/Constants.sol";

/**
 * @dev Before running, use `npx hardhat run scripts/deploy/gen-chainconfig.js --network <chain>` to set addresses
 */
contract Deploy is Script {
    function run() public {
        address owner = 0xAcE2B3E7c752d5deBca72210141d464371b3B9b1;

        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        console2.log("=== Deploying DexRouter ===");
        console2.log("Deployer:", deployer);
        console2.log("Chain ID:", block.chainid);

        // Anti-cross-chain guard: ChainConfig.sol is generated per target chain by
        // gen-chainconfig. Refuse to deploy if the live chain doesn't match the config the
        // contracts were compiled with (e.g. stale ChainConfig, or wrong --rpc-url).
        require(
            block.chainid == _EXPECTED_CHAIN_ID,
            "DeployDexRouter: chainId mismatch - run gen-chainconfig for the target chain"
        );

        vm.startBroadcast(deployerKey);
        
        DexRouter dexRouter = new DexRouter(owner);
        console2.log("DexRouter deployed at:", address(dexRouter));
        
        vm.stopBroadcast();
    }
}
