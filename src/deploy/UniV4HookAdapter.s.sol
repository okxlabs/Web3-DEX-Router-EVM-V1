// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/test.sol";
import "forge-std/console2.sol";

import "@dex/adapter/UniV4HookAdapter.sol";

contract Deploy is Test {
    address deployer = vm.rememberKey(vm.envUint("PRIVATE_KEY"));

    //unichain
    address poolManager = 0x1F98400000000000000000000000000000000004;
    address payable WETH = payable(0x4200000000000000000000000000000000000006);

    function run() public {
        console2.log("deployer", deployer);
        require(
            deployer == 0x67711047df98Df68e0dbCc2e72e41Bd3e80990E1,
            "wrong deployer! change the private key"
        );

        vm.createSelectFork(vm.envString("UNICHAIN_RPC_URL"));
        vm.startBroadcast(deployer);
        console2.log("block.chainID", block.chainid);

        address adapter = address(new UniV4HookAdapter(poolManager, WETH));
        console2.log("UniV4HookAdapter deployed: %s", adapter);
        vm.stopBroadcast();
    }
}
