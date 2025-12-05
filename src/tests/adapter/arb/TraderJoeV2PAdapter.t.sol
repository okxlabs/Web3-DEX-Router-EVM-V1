// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../../../../contracts/8/adapter/TraderJoeV2PAdapter.sol";
import "../../../../contracts/8/interfaces/IERC20.sol";
import "../../../../contracts/8/interfaces/ITraderJoeV2P.sol";

/// @title TraderJoe V2 Plus (V2.1 & V2.2) Adapter Test
/// @notice Test unified adapter with both V2.1 and V2.2 pools
// Local interface to get tokenY
interface ILBPairExtended {
    function getTokenY() external view returns (address);
}

contract TraderJoeV2PAdapterTest is Test {
    TraderJoeV2PAdapter adapter;
    
    // V2.1 Pools
    address constant POOL_V21_1 = 0x0E6fef1FF23b1d9aB201F36e1a232EeB998c70F4;
    address constant POOL_V21_2 = 0x5D700264A4daED0C61a2205416De81b19AB63B02;
    
    // V2.2 Pool
    address constant POOL_V22 = 0xb7236B927e03542AC3bE0A054F2bEa8868AF9508;
    
    address tokenX_V21_1;
    address tokenX_V21_2;
    address tokenX_V22;
    
    address testUser = vm.rememberKey(1);
    
    function setUp() public {
        vm.createSelectFork(vm.envString("ARB_RPC_URL"));
        vm.txGasPrice(1 gwei);
        
        adapter = new TraderJoeV2PAdapter();
        
        tokenX_V21_1 = address(ILBPair(POOL_V21_1).getTokenX());
        tokenX_V21_2 = address(ILBPair(POOL_V21_2).getTokenX());
        tokenX_V22 = address(ILBPair(POOL_V22).getTokenX());
        
        console.log("=== TraderJoe V2 Plus Adapter Test ===");
        console.log("V2.1 Pool 1:", POOL_V21_1, "TokenX:", tokenX_V21_1);
        console.log("V2.1 Pool 2:", POOL_V21_2, "TokenX:", tokenX_V21_2);
        console.log("V2.2 Pool:", POOL_V22, "TokenX:", tokenX_V22);
    }
    
    function test_V21_Pool1_SellBase() public {
        console.log("\n>>> Testing V2.1 Pool 1");
        _testSwap(POOL_V21_1, tokenX_V21_1, 1e18);
    }
    
    function test_V21_Pool2_SellBase() public {
        console.log("\n>>> Testing V2.1 Pool 2");
        _testSwap(POOL_V21_2, tokenX_V21_2, 1e18);
    }
    
    function test_V22_Pool_SellBase() public {
        console.log("\n>>> Testing V2.2 Pool");
        _testSwap(POOL_V22, tokenX_V22, 1e10);
    }
    
    function _testSwap(address pool, address tokenIn, uint256 amountIn) internal {
        uint8 decimalsIn = IERC20(tokenIn).decimals();
        if (decimalsIn < 18) {
            amountIn = amountIn / (10 ** (18 - decimalsIn));
        }
        
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
        
        assertEq(IERC20(tokenIn).balanceOf(testUser), 0, "TokenX should be 0");
        assertGt(IERC20(tokenY).balanceOf(testUser), 0, "TokenY should be > 0");
        
        console.log("Swap completed successfully");
        
        vm.stopPrank();
    }
}

