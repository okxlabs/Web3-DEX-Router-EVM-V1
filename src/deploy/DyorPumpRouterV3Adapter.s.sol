// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/script.sol";
import "forge-std/console2.sol";
import "@dex/adapter/DyorPumpRouterV3Adapter.sol";

// DyorPumpRouterV3Adapter deployment script for BSC chain
contract Deploy is Script {
    address deployer = vm.rememberKey(vm.envUint("PRIVATE_KEY"));

    function run() public {
        require(deployer == 0x399EfA78cAcD7784751CD9FBf2523eDf9EFDf6Ad, "wrong deployer! change the private key");

        // deploy on BSC chain
        vm.createSelectFork("xlayer");
        vm.startBroadcast(deployer);

        console2.log("block.chainID", block.chainid);
        // require(block.chainid == , "must be XLayer");
      
        //   routers["xlayer"] = 0xD983C98D1522731146bAd34078dA0bD966D9EA08;
        // weth["xlayer"] = 0xe538905cf8410324e03A5A23C1c177a474D59b2b;
        address WNATIVE = 0xe538905cf8410324e03A5A23C1c177a474D59b2b;
        // address TOKENMANAGER2 = 0x5c952063c7fc8610FFDB798152D69F0B9550762b;
        address dyorPumpRouterV3 = 0xDf7143e86c919cb440e6e972bafe0ebD1bb26F56;
        address adapter = address(new DyorPumpRouterV3Adapter(dyorPumpRouterV3, WNATIVE));
        console2.log("DyorPumpRouterV3Adapter deployed on XLayer: %s", adapter);

        vm.stopBroadcast();
    }
}
