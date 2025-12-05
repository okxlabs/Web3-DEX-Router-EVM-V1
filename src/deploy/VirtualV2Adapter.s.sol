// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/script.sol";
import "forge-std/console2.sol";
import "@dex/adapter/VirtualsV2Adapter.sol";

//virtual internal trading
contract Deploy is Script {
    address deployer = vm.rememberKey(vm.envUint("DEPLOY_PRIVATE_KEY"));

    function run() public {
        require(deployer == 0x399EfA78cAcD7784751CD9FBf2523eDf9EFDf6Ad, "wrong deployer! change the private key");

        // deploy on BaseChain
        vm.createSelectFork(vm.envString("BASE_RPC_URL"));
        vm.startBroadcast(deployer);

        console2.log("block.chainID", block.chainid);
        require(block.chainid == 8453 , "must be BASE");
      
        address BONDING = 0xc3538DdD84619e761b4c03cAf2F785f79889958d;
        address virtualToken = 0x0b3e328455c4059EEb9e3f84b5543F74E24e7E1b;
        address FRouter = 0xBfCE3fbe9cE3a19adb8DbB096Ea2Cb2bb1073F95;
        address adapter = address(new VirtualsV2Adapter(BONDING, virtualToken, FRouter));
        console2.log("VirtualV2Adapter deployed on BASE: %s", adapter);

        vm.stopBroadcast();
    }
}

// forge verify-contract --chain-id 8453 --constructor-args $(cast abi-encode "constructor(address,address,address)" 0xc3538DdD84619e761b4c03cAf2F785f79889958d 0x0b3e328455c4059EEb9e3f84b5543F74E24e7E1b 0xBfCE3fbe9cE3a19adb8DbB096Ea2Cb2bb1073F95) --etherscan-api-key RHR62V453IQDKITNMIXCG69GEWFU92ZXX2 --compiler-version v0.8.20+commit.a1b79de6 <DEPLOYED_ADDRESS> contracts/8/adapter/VirtualsV2Adapter.sol:VirtualsV2Adapter
