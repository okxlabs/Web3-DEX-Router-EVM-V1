// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/script.sol";
import "forge-std/console2.sol";
import "@dex/adapter/XdockAdapter.sol";

// XdockAdapter deployment script for XLayer chain
contract Deploy is Script {
    address deployer = vm.rememberKey(vm.envUint("DEPLOY_PRIVATE_KEY"));

    function run() public {
        require(deployer == 0x399EfA78cAcD7784751CD9FBf2523eDf9EFDf6Ad, "wrong deployer! change the private key");

        // deploy on XLayer chain
        vm.createSelectFork("xlayer");
        vm.startBroadcast(deployer);

        console2.log("block.chainID", block.chainid);
      
        address AmmPool = 0xe6A5f4b8257BbAd4F033D3831ebF23E0F833961F;
        address WNATIVE = 0xe538905cf8410324e03A5A23C1c177a474D59b2b;
        address adapter = address(new XdockAdapter(AmmPool, WNATIVE));
        console2.log("XdockAdapter deployed on XLayer: %s", adapter);

        vm.stopBroadcast();
    }
}

