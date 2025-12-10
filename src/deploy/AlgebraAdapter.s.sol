// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/script.sol";
import "forge-std/console2.sol";
import "@dex/adapter/AlgebraAdapter.sol";

contract Deploy is Script {
    address deployer = vm.rememberKey(vm.envUint("DEPLOY_PRIVATE_KEY"));

    function run() public {
        require(
            deployer == 0x399EfA78cAcD7784751CD9FBf2523eDf9EFDf6Ad,
            "wrong deployer! change the private key"
        );

        // 根据需要选择链和对应的 WNATIVE 地址
        vm.createSelectFork("eth");
        address WNATIVE = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH

        vm.startBroadcast(deployer);
        console2.log("Deployer:", deployer);
        console2.log("Chain ID:", block.chainid);

        address adapter = address(new AlgebraAdapter(payable(WNATIVE)));
        console2.log("AlgebraAdapter deployed:", adapter);

        vm.stopBroadcast();
    }
}

