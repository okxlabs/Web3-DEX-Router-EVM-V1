// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "@dex/adapter/VenusAdapter.sol";

/**
 * @title VenusAdapter Deployment Script
 * @notice Deploys VenusAdapter on multiple chains with correct WETH addresses
 * 
 * Usage:
 *   # Deploy on specific chain (dry run)
 *   forge script src/deploy/VenusAdapter.s.sol --rpc-url <chain> -vvvv
 * 
 *   # Deploy and broadcast
 *   forge script src/deploy/VenusAdapter.s.sol --rpc-url <chain> --broadcast -vvvv
 * 
 *   # Deploy, broadcast and verify
 *   forge script src/deploy/VenusAdapter.s.sol --rpc-url <chain> --broadcast --verify -vvvv
 * 
 * Supported chains: eth, bsc, arb, zksync, op, base, unichain
 */
contract DeployVenusAdapter is Script {
    // Chain IDs
    uint256 constant CHAIN_ETH = 1;
    uint256 constant CHAIN_BSC = 56;
    uint256 constant CHAIN_ARB = 42161;
    uint256 constant CHAIN_ZKSYNC = 324;
    uint256 constant CHAIN_OP = 10;
    uint256 constant CHAIN_BASE = 8453;
    uint256 constant CHAIN_UNICHAIN = 130;

    // WETH/WBNB addresses per chain
    address constant WETH_ETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant WBNB_BSC = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address constant WETH_ARB = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address constant WETH_ZKSYNC = 0x5AEa5775959fBC2557Cc8789bC1bf90A239D9a91;
    address constant WETH_OP = 0x4200000000000000000000000000000000000006;
    address constant WETH_BASE = 0x4200000000000000000000000000000000000006;
    address constant WETH_UNICHAIN = 0x4200000000000000000000000000000000000006;

    // vNative addresses per chain (vToken for native asset like vBNB, vETH)
    address constant VNATIVE_BSC = 0xA07c5b74C9B40447a954e1466938b865b6BBea36; // vBNB

    function run() public {
        address deployer = vm.rememberKey(vm.envUint("PRIVATE_KEY"));
        console2.log("Deployer:", deployer);
        console2.log("Chain ID:", block.chainid);

        address weth = getWETH(block.chainid);
        require(weth != address(0), "Unsupported chain");

        address vNative = getVNative(block.chainid);

        console2.log("WETH address:", weth);
        console2.log("vNative address:", vNative);

        vm.startBroadcast(deployer);

        VenusAdapter adapter = new VenusAdapter(weth, vNative);

        console2.log("==========================================");
        console2.log("VenusAdapter deployed successfully!");
        console2.log("Chain ID:", block.chainid);
        console2.log("Chain name:", getChainName(block.chainid));
        console2.log("Adapter address:", address(adapter));
        console2.log("WETH address:", weth);
        console2.log("vNative address:", vNative);
        console2.log("==========================================");

        vm.stopBroadcast();
    }

    function getWETH(uint256 chainId) internal pure returns (address) {
        if (chainId == CHAIN_ETH) return WETH_ETH;
        if (chainId == CHAIN_BSC) return WBNB_BSC;
        if (chainId == CHAIN_ARB) return WETH_ARB;
        if (chainId == CHAIN_ZKSYNC) return WETH_ZKSYNC;
        if (chainId == CHAIN_OP) return WETH_OP;
        if (chainId == CHAIN_BASE) return WETH_BASE;
        if (chainId == CHAIN_UNICHAIN) return WETH_UNICHAIN;
        return address(0);
    }

    function getVNative(uint256 chainId) internal pure returns (address) {
        if (chainId == CHAIN_BSC) return VNATIVE_BSC;
        // Other chains: address(0) - no native vToken or not yet configured
        return address(0);
    }

    function getChainName(uint256 chainId) internal pure returns (string memory) {
        if (chainId == CHAIN_ETH) return "Ethereum";
        if (chainId == CHAIN_BSC) return "BSC";
        if (chainId == CHAIN_ARB) return "Arbitrum";
        if (chainId == CHAIN_ZKSYNC) return "zkSync Era";
        if (chainId == CHAIN_OP) return "Optimism";
        if (chainId == CHAIN_BASE) return "Base";
        if (chainId == CHAIN_UNICHAIN) return "Unichain";
        return "Unknown";
    }
}

