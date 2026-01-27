// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../../../../contracts/8/adapter/TraderJoeV2Adapter.sol";
import "../../../../contracts/8/interfaces/IERC20.sol";
import "../../../../contracts/8/interfaces/ITraderJoeV2.sol";

// Local interface to get tokenY
interface ILBPairExtended {
    function tokenY() external view returns (address);
}

contract TraderJoeV2AdapterTest is Test {
    TraderJoeV2Adapter adapter;
    address constant POOL = 0x22780C4D8EA5DE924E1A451c83273019EA644A7E;
    address tokenX;
    address testUser = vm.rememberKey(1);
    
    function setUp() public {
        string memory rpcUrl = vm.envString("ARB_RPC_URL");
        vm.createSelectFork(rpcUrl);
        
        adapter = new TraderJoeV2Adapter();
        
        tokenX = ILBPair(POOL).tokenX();
        console.log("Pool:", POOL, "TokenX:", tokenX);
    }
    
    function test_Pool_SellBase() public {
        _testSwap(POOL, tokenX, 1e18);
    }
    
    function _testSwap(address pool, address tokenIn, uint256 amountIn) internal {
        uint8 decimalsIn = IERC20(tokenIn).decimals();
        if (decimalsIn < 18) {
            amountIn = amountIn / (10 ** (18 - decimalsIn));
        }
        
        // Get tokenY from pool
        address tokenY = ILBPairExtended(pool).tokenY();
        
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

