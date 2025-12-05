// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/test.sol";
import "forge-std/console2.sol";

import "@dex/adapter/UniV4Adapter.sol";

contract Deploy is Test {
    address deployer = vm.rememberKey(vm.envUint("PRIVATE_KEY"));

    //eth
    // address poolManager = 0x000000000004444c5dc75cB358380D2e3dE08A90;
    // address payable WETH = payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    //op: 0x12e55236d0743999716ebacbd1fe07f63719b0df
    // address poolManager = 0x9a13F98Cb987694C9F086b1F5eB990EeA8264Ec3;
    // address payable WETH = payable(0x4200000000000000000000000000000000000006);

    //base
    // address poolManager = 0x498581fF718922c3f8e6A244956aF099B2652b2b;
    // address payable WETH = payable(0x4200000000000000000000000000000000000006);

    //arb
    // address poolManager = 0x360E68faCcca8cA495c1B759Fd9EEe466db9FB32;
    // address payable WETH = payable(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);

    //polygon
    // address poolManager = 0x67366782805870060151383F4BbFF9daB53e5cD6;
    // address payable WETH = payable(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270);

    //avax: 0x42170295F1173c9e5874ea9d00c6d137E1a4f53d
    // address poolManager = 0x06380C0e0912312B5150364B9DC4542BA0DbBc85;
    // address payable WETH = payable(0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7);

    //blast: 0x9Ac7b1FFEE0f58c0a3c89AA54Afb62efD25DC9fd
    // address poolManager = 0x1631559198A9e474033433b2958daBC135ab6446;
    // address payable WETH = payable(0x4300000000000000000000000000000000000004);

    //bsc: 0xDeEF773D61719a3181E35e9281600Db8bA063f71
    // address poolManager = 0x28e2Ea090877bF75740558f6BFB36A5ffeE9e9dF;
    // address payable WETH = payable(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);

    //monad
    address poolManager = 0x188d586Ddcf52439676Ca21A244753fA19F9Ea8e;
    address payable WETH = payable(0x3bd359C1119dA7Da1D913D1C4D2B7c461115433A);

    function run() public {
        console2.log("deployer", deployer);
        require(
            deployer == 0x399EfA78cAcD7784751CD9FBf2523eDf9EFDf6Ad,
            "wrong deployer! change the private key"
        );

        vm.createSelectFork(vm.envString("MONAD_RPC_URL"));
        vm.startBroadcast(deployer);
        console2.log("block.chainID", block.chainid);

        address adapter = address(new UniV4Adapter(poolManager, WETH));
        console2.log("UniV4Adapter deployed: %s", adapter);
        vm.stopBroadcast();
    }
}
