// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/test.sol";
import "forge-std/console2.sol";

import "@dex/adapter/NativePmmAdapterV3.sol";

contract Deploy is Test {
    address deployer = vm.rememberKey(vm.envUint("PRIVATE_KEY"));

    function run() public {
        // require(
        //     deployer == 0xEA522Fe3A65874bA3CEC38e912220282b7C71E97,
        //     "wrong deployer! change the private key"
        // );
        deploy_robinhood();
    }
    function deploy_robinhood() internal {
        vm.createSelectFork(vm.envString("ROBINHOOD_RPC_URL"));

        console2.log("block.chainID", block.chainid);
        require(block.chainid == 4663, "must be robinhood");
        address WETH = 0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73;
        vm.broadcast(deployer);
        address adapter = address(new NativePmmAdapterV3(WETH));
        console2.log("NativePmmAdapterV3 deployed robinhood: %s", adapter);
    }
    function deploy_eth() internal {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));

        console2.log("block.chainID", block.chainid);
        require(block.chainid == 1, "must be ethereum");
        address WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        vm.broadcast(deployer);
        address adapter = address(new NativePmmAdapterV3(WETH));
        console2.log("NativePmmAdapterV3 deployed ethereum: %s", adapter);
    }
    function deploy_bsc() internal {
        vm.createSelectFork(vm.envString("BSC_RPC_URL"));

        console2.log("block.chainID", block.chainid);
        require(block.chainid == 56, "must be bsc");
        address WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
        vm.broadcast(deployer);
        address adapter = address(new NativePmmAdapterV3(WBNB));
        console2.log("NativePmmAdapterV3 deployed ethereum: %s", adapter);
    }
    function deploy_base() internal {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"));

        console2.log("block.chainID", block.chainid);
        require(block.chainid == 8453, "must be bsc");
        address WETH = 0x4200000000000000000000000000000000000006;
        vm.broadcast(deployer);
        address adapter = address(new NativePmmAdapterV3(WETH));
        console2.log("NativePmmAdapterV3 deployed base: %s", adapter);
    }
    function deploy_arb() internal {
        vm.createSelectFork(vm.envString("ARBI_RPC_URL"));

        console2.log("block.chainID", block.chainid);
        require(block.chainid == 42161, "must be bsc");
        address WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
        vm.broadcast(deployer);
        address adapter = address(new NativePmmAdapterV3(WETH));
        console2.log("NativePmmAdapterV3 deployed arbi: %s", adapter);
    }
}
