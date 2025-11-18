// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/test.sol";
import "forge-std/console2.sol";

import "@dex/adapter/TesseraAdapter.sol";

contract Deploy is Test {
    address internal deployer = vm.rememberKey(vm.envUint("PRIVATE_KEY"));

    function run() public {
        require(deployer == 0x399EfA78cAcD7784751CD9FBf2523eDf9EFDf6Ad, "wrong deployer! change the private key");

        vm.createSelectFork(vm.envString("BASE_RPC_URL"));
        vm.startBroadcast(deployer);
        require(block.chainid == 8453, "must be basechain");

        address tesseraSwap = 0x55555522005BcAE1c2424D474BfD5ed477749E3e;
        address adapter = address(new TesseraAdapter(tesseraSwap));
        console2.log("TesseraAdapter deployed on base: %s", adapter);

        vm.stopBroadcast();
    }
}

