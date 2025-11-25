// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../../../../contracts/8/adapter/TraderJoeV2P1Adapter.sol";
import "../../../../contracts/8/interfaces/IERC20.sol";
import "../../../../contracts/8/interfaces/ITraderJoeV2P1.sol";

// Local interface to get tokenY
interface ILBPairExtended {
    function getTokenY() external view returns (address);
}

contract TraderJoeV2P1AdapterTest is Test {
    TraderJoeV2P1Adapter adapter;
    
    address constant POOL1 = 0x0E6fef1FF23b1d9aB201F36e1a232EeB998c70F4;
    address constant POOL2 = 0x5D700264A4daED0C61a2205416De81b19AB63B02;
    
    address tokenX1;
    address tokenX2;

    address testUser = vm.rememberKey(1);
    
    function setUp() public {
        string memory rpcUrl = vm.envString("ARB_RPC_URL");
        vm.createSelectFork(rpcUrl); 
        
        adapter = new TraderJoeV2P1Adapter();
        
        tokenX1 = address(ILBPair(POOL1).getTokenX());
        tokenX2 = address(ILBPair(POOL2).getTokenX());
        
        console.log("Pool 1:", POOL1, "TokenX:", tokenX1);
        console.log("Pool 2:", POOL2, "TokenX:", tokenX2);
    }
    
    function test_Pool1_SellBase() public {
        _testSwap(POOL1, tokenX1, 1e18);
    }
    
    function test_Pool2_SellBase() public {
        _testSwap(POOL2, tokenX2, 1e18);
    }
    
    function _testSwap(address pool, address tokenIn, uint256 amountIn) internal {
        uint8 decimalsIn = IERC20(tokenIn).decimals();
        if (decimalsIn < 18) {
            amountIn = amountIn / (10 ** (18 - decimalsIn));
        }
        
        // Get tokenY from pool
        address tokenY = ILBPairExtended(pool).getTokenY();
        
        deal(tokenIn, testUser, amountIn);
        
        console.log("Amount in:", amountIn);
        console.log("TokenX balance before:", IERC20(tokenIn).balanceOf(testUser));
        console.log("TokenY balance before:", IERC20(tokenY).balanceOf(testUser));
        
        vm.startPrank(testUser);
        
        IERC20(tokenIn).transfer(pool, amountIn);
        
        bytes memory moreInfo = abi.encode(tokenIn);
        
        adapter.sellBase(testUser, pool, moreInfo);
        
        console.log("TokenX balance after:", IERC20(tokenIn).balanceOf(testUser));
        console.log("TokenY balance after:", IERC20(tokenY).balanceOf(testUser));
        console.log("Swap completed successfully");
        
        vm.stopPrank();
    }
}