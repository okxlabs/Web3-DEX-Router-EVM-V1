// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/test.sol";
import "forge-std/console2.sol";
import "@dex/adapter/CurveCryptoSwapAdapter.sol";

contract Deploy is Test {
    address deployer = vm.rememberKey(vm.envUint("PRIVATE_KEY"));

    function run() public {
        require(deployer == 0x399EfA78cAcD7784751CD9FBf2523eDf9EFDf6Ad, "wrong deployer! change the private key");

        vm.createSelectFork(vm.envString("MONAD_RPC_URL"));
        vm.startBroadcast(deployer);

        console2.log("block.chainID", block.chainid);
        require(block.chainid == 143 , "must be monad");
      
        address adapter = address(new CurveCryptoSwapAdapter());
        console2.log("CurveCryptoSwapAdapter deployed monad: %s", adapter);

        vm.stopBroadcast();
    }
}
