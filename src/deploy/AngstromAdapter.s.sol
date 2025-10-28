// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/test.sol";
import "forge-std/console2.sol";

import "@dex/adapter/AngstromAdapter.sol";

contract Deploy is Test {
    address deployer = vm.rememberKey(vm.envUint("DEPLOY_PRIVATE_KEY"));

    // eth
    address poolManager = 0x000000000004444c5dc75cB358380D2e3dE08A90;
    address payable WETH = payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    function run() public {
        console2.log("deployer", deployer);
        require(
            deployer == 0x399EfA78cAcD7784751CD9FBf2523eDf9EFDf6Ad,
            "wrong deployer! change the private key"
        );

        vm.createSelectFork(vm.envString("ETH_RPC_URL"));
        vm.startBroadcast(deployer);
        console2.log("block.chainID", block.chainid);

        address adapter = address(new AngstromAdapter(poolManager, WETH));
        console2.log("AngstromAdapter deployed: %s", adapter);
        vm.stopBroadcast();
    }
}
