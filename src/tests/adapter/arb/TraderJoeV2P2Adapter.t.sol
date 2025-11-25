// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../../../../contracts/8/adapter/TraderJoeV2P2Adapter.sol";
import "../../../../contracts/8/interfaces/IERC20.sol";
import "../../../../contracts/8/interfaces/ITraderJoeV2P2.sol";

// Local interface to get tokenY
interface ILBPairExtended {
    function getTokenY() external view returns (address);
}

contract TraderJoeV2P2AdapterTest is Test {
    TraderJoeV2P2Adapter adapter;
    
    address constant POOL = 0xb7236B927e03542AC3bE0A054F2bEa8868AF9508;
    address tokenX;
    
    address testUser = vm.rememberKey(1);
    
    function setUp() public {
        string memory rpcUrl = vm.envString("ARB_RPC_URL");
        vm.createSelectFork(rpcUrl);
        
        adapter = new TraderJoeV2P2Adapter();

        tokenX = address(ILBPair(POOL).getTokenX());
        console.log("Pool:", POOL, "TokenX:", tokenX);
    }
    
    function test_Pool_SellBase() public {
        _testSwap(POOL, tokenX, 1e10);
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

