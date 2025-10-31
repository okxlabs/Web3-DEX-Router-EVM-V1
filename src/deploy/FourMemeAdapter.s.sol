// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/script.sol";
import "forge-std/console2.sol";
import "@dex/adapter/FourMemeAdapter.sol";

// FourMemeAdapter deployment script for BSC chain
contract Deploy is Script {
    address deployer = vm.rememberKey(vm.envUint("DEPLOY_PRIVATE_KEY"));

    function run() public {
        // require(deployer == 0x399EfA78cAcD7784751CD9FBf2523eDf9EFDf6Ad, "wrong deployer! change the private key");

        // deploy on BSC chain
        vm.createSelectFork(vm.envString("BSC_RPC_URL"));
        vm.startBroadcast(deployer);

        console2.log("block.chainID", block.chainid);
        require(block.chainid == 56 , "must be BSC");
      
        address WNATIVE = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
        address TOKENMANAGER2 = 0x5c952063c7fc8610FFDB798152D69F0B9550762b;
        address adapter = address(new FourMemeAdapter(WNATIVE, TOKENMANAGER2));
        console2.log("FourMemeAdapter deployed on BSC: %s", adapter);

        vm.stopBroadcast();
    }
}
