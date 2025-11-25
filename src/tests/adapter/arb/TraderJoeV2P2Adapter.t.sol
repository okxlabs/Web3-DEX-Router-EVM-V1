// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../../../../contracts/8/adapter/TraderJoeV2P2Adapter.sol";
import "../../../../contracts/8/interfaces/IERC20.sol";
import "../../../../contracts/8/interfaces/ITraderJoeV2P2.sol";

contract TraderJoeV2P2AdapterTest is Test {
    TraderJoeV2P2Adapter adapter;
    
    // Test pools (Arbitrum)
    // address constant POOL1 = 0xE1743b08F2F46bBdA8b48fDE06Ae38eC7936BCFB;
    address constant POOL2 = 0xb7236B927e03542AC3bE0A054F2bEa8868AF9508;
    // address constant POOL3 = 0x66315901ba2247f2497254930961637534572f15;
    
    // Pool tokens
    address tokenX2;
    
    // Test account (generated from private key)
    address testUser = vm.rememberKey(1);
    
    function setUp() public {
        // Fork Arbitrum mainnet
        string memory rpcUrl = vm.envString("ARB_RPC_URL");
        vm.createSelectFork(rpcUrl);
        
        // Set consistent gas price
        vm.txGasPrice(1 gwei);
        
        // Deploy adapter
        adapter = new TraderJoeV2P2Adapter();

        // Get tokenX from pools using getTokenX()
        // tokenX1 = address(ILBPair(POOL1).getTokenX());
        tokenX2 = address(ILBPair(POOL2).getTokenX());
        // tokenX3 = address(ILBPair(POOL3).getTokenX());
        
        // console.log("Pool 1:", POOL1, "TokenX:", tokenX1);
        console.log("Pool 2:", POOL2, "TokenX:", tokenX2);
        // console.log("Pool 3:", POOL3, "TokenX:", tokenX3);
    }
    
    // Pool 2 Test
    function test_Pool2_SellBase() public {
        _testSwap(POOL2, tokenX2, 1e10, "Pool2 X swap");
    }
    
    function _testSwap(
        address pool,
        address tokenIn,
        uint256 amountIn,
        string memory label
    ) internal {
        console.log("\n--- Testing:", label, "---");
        
        // Get decimals and adjust amount
        uint8 decimalsIn = IERC20(tokenIn).decimals();
        if (decimalsIn < 18) {
            amountIn = amountIn / (10 ** (18 - decimalsIn));
        }
        
        // Use deal to give testUser tokens
        deal(tokenIn, testUser, amountIn); // Give 2x to be safe
        
        console.log("Amount in:", amountIn);
        console.log("Token in balance:", IERC20(tokenIn).balanceOf(testUser));
        
        // Start as test user
        vm.startPrank(testUser);
        
        // Transfer tokens to pool
        IERC20(tokenIn).transfer(pool, amountIn);
        
        // Encode moreInfo (tokenIn address)
        bytes memory moreInfo = abi.encode(tokenIn);
        
        // Call sellBase (selling tokenX)
        adapter.sellBase(testUser, pool, moreInfo);
        
        console.log("Token in balance after:", IERC20(tokenIn).balanceOf(testUser));
        console.log("Swap completed successfully");
        
        vm.stopPrank();
    }
}

