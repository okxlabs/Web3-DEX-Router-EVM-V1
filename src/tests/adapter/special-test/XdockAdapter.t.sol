pragma solidity ^0.8.0;

import {XdockAdapter} from "@dex/adapter/XdockAdapter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Test} from "forge-std/Test.sol";

contract XdockAdapterSpecialTest is Test {
    
    function test_buyMeme() public {
        vm.createSelectFork("xlayer");
        
        address AmmPool = 0xe6A5f4b8257BbAd4F033D3831ebF23E0F833961F;
        address WOKB = 0xe538905cf8410324e03A5A23C1c177a474D59b2b;
        address memeToken = 0x26A406f6755d87414dC474e9472ED3917835a7B4;
        
        XdockAdapter adapter = new XdockAdapter(AmmPool, WOKB);
        
        address user = vm.rememberKey(1);
        uint256 wokbAmount = 1 * 10 ** 18;
        
        bytes memory moreInfo = abi.encode(
            WOKB,           // fundAddress
            memeToken,      // tokenAddress
            true,           // buyMeme
            0,              // sellMemeAmount (not used for buy)
            0,              // sellCommissionRate1
            address(0),     // sellCommissionReceiver1
            0,              // sellCommissionRate2
            address(0),     // sellCommissionReceiver2
            1               // minReturnAmount
        );
        
        // Give user enough WOKB for testing
        deal(WOKB, address(adapter), wokbAmount);
        
        // Check balance before
        uint256 memeBalanceBefore = IERC20(memeToken).balanceOf(user);
                
        vm.startPrank(user, user);  // Set both msg.sender and tx.origin to user
        vm.txGasPrice(1);  // Set a consistent gas price
        
        // Call adapter to buy meme tokens
        adapter.sellBase(
            user,        // recipient for meme token output
            memeToken,   // pool/token address
            moreInfo
        );
        
        vm.stopPrank();
        
        // Check balances after
        uint256 memeBalanceAfter = IERC20(memeToken).balanceOf(user);
        
        // Verify that user received meme tokens
        require(memeBalanceAfter > memeBalanceBefore, "Should receive meme tokens");
    }
    
    function test_sellMeme() public {
        vm.createSelectFork("xlayer");
        
        address AmmPool = 0xe6A5f4b8257BbAd4F033D3831ebF23E0F833961F;
        address WOKB = 0xe538905cf8410324e03A5A23C1c177a474D59b2b;
        address memeToken = 0x26A406f6755d87414dC474e9472ED3917835a7B4;
        
        XdockAdapter adapter = new XdockAdapter(AmmPool, WOKB);
        
        address user = vm.rememberKey(1);
        uint256 memeAmount = 10000 * 10 ** 18; // 10000 meme tokens
        
        bytes memory moreInfo = abi.encode(
            WOKB,           // fundAddress
            memeToken,      // tokenAddress
            false,          // buyMeme (selling)
            memeAmount,     // sellMemeAmount
            0,              // sellCommissionRate1
            address(0),     // sellCommissionReceiver1
            0,              // sellCommissionRate2
            address(0),     // sellCommissionReceiver2
            1               // minReturnAmount
        );
        
        // Give user enough meme tokens for testing
        deal(memeToken, user, memeAmount);
        
        // Check balance before
        uint256 ethBalanceBefore = user.balance;
                
        vm.startPrank(user, user);  // Set both msg.sender and tx.origin to user
        vm.txGasPrice(1);  // Set a consistent gas price
        
        // User pre-approves the AMM pool to spend meme tokens
        // Note: This is done by user since adapter will transfer tokens to user first
        IERC20(memeToken).approve(AmmPool, memeAmount);
        
        // Call adapter to sell meme tokens
        adapter.sellQuote(
            user,        // recipient for ETH output (tx.origin)
            memeToken,   // pool/token address
            moreInfo
        );
        
        vm.stopPrank();
        
        // Check balances after
        uint256 ethBalanceAfter = user.balance;
        
        // Verify that user received ETH
        require(ethBalanceAfter > ethBalanceBefore, "Should receive ETH");
    }
}
