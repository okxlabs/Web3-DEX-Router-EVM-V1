// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console2} from "forge-std/Script.sol";
import "@dex/adapter/SavingsPoolAdapter.sol";

contract Deploy is Script {
    address deployer = vm.rememberKey(vm.envUint("PRIVATE_KEY"));

    function run() public {
        // require(deployer == 0x399EfA78cAcD7784751CD9FBf2523eDf9EFDf6Ad, "wrong deployer! change the private key");

        // deploy on eth
        vm.createSelectFork(vm.rpcUrl("unichain"));
        vm.startBroadcast(deployer);

        console2.log("block.chainID", block.chainid);
        // require(block.chainid == 1 , "must be eth");
      
        address adapter = address(new SavingsPoolAdapter());
        // console2.log("SavingsPoolAdapter deployed on eth: %s", adapter);

        vm.stopBroadcast();
    }
}
