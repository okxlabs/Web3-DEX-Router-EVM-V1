// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import "@dex/DexRouter.sol";

/**
 * @dev Before running, use `npx hardhat run scripts/tools/ureplace.js --network <chain>` to set addresses
 */
contract Deploy is Script {
    function run() public {
        address owner = 0xAcE2B3E7c752d5deBca72210141d464371b3B9b1;

        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        console2.log("=== Deploying DexRouter ===");
        console2.log("Deployer:", deployer);
        console2.log("Chain ID:", block.chainid);

        vm.startBroadcast(deployerKey);
        
        DexRouter dexRouter = new DexRouter(owner);
        console2.log("DexRouter deployed at:", address(dexRouter));
        
        vm.stopBroadcast();
    }
}
