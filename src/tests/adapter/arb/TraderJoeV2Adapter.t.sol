// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../../../../contracts/8/adapter/TraderJoeV2Adapter.sol";
import "../../../../contracts/8/interfaces/IERC20.sol";
import "../../../../contracts/8/interfaces/ITraderJoeV2.sol";

contract TraderJoeV2AdapterTest is Test {
    TraderJoeV2Adapter adapter;
    
    // Test pools (Arbitrum)
    address constant POOL1 = 0xE71Fd21a901F3d105de7760bb6F07C6aF204D908;
    address constant POOL2 = 0x22780C4D8EA5DE924E1A451c83273019EA644A7E;
    address constant POOL3 = 0xcba0B8384AdfDDF2Fa4B99B29F0145E8979beb29;
    
    // Pool tokens
    address tokenX1;
    address tokenX2;
    address tokenX3;
    
    // Test account (generated from private key)
    address testUser = vm.rememberKey(1);
    
    function setUp() public {
        // Fork Arbitrum mainnet
        string memory rpcUrl = vm.envString("ARB_RPC_URL");
        vm.createSelectFork(rpcUrl);
        
        // Set consistent gas price
        vm.txGasPrice(1 gwei);
        
        // Deploy adapter
        adapter = new TraderJoeV2Adapter();
        
        // Get tokenX from pools
        tokenX1 = ILBPair(POOL1).tokenX();
        tokenX2 = ILBPair(POOL2).tokenX();
        tokenX3 = ILBPair(POOL3).tokenX();
        
        console.log("Pool 1:", POOL1, "TokenX:", tokenX1);
        console.log("Pool 2:", POOL2, "TokenX:", tokenX2);
        console.log("Pool 3:", POOL3, "TokenX:", tokenX3);
    }
    
    // Pool 2 Test
    function test_Pool2_SellBase() public {
        _testSwap(POOL2, tokenX2, 1e18, "Pool2 X swap");
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
        deal(tokenIn, testUser, amountIn * 2); // Give 2x to be safe
        
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

