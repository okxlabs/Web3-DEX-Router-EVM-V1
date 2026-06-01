// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/test.sol";
import "forge-std/console2.sol";
import "@dex/adapter/VirtualsAdapter.sol";
import "@dex/interfaces/IERC20.sol";
import "@dex/interfaces/IVirtuals.sol";

contract VirtualsAdapterRefundTest is Test {
    string network = "base";
    
    // Base mainnet addresses - actual Virtuals protocol addresses
    address constant BONDING = 0xF66DeA7b3e897cD44A5a231c61B6B4423d613259;
    address constant VIRTUALTOKEN = 0x0b3e328455c4059EEb9e3f84b5543F74E24e7E1b;
    address constant FROUTER = 0x8292B43aB73EfAC11FAF357419C38ACF448202C5;
    address constant MEME_TOKEN = 0x8cCA61B50443f8997654bfc578fA1CbA3Eac2CDF; // fun AI COACH
    
    VirtualsAdapter adapter;

    function logBalances(string memory title) internal view {
        console2.log("=== %s ===", title);
        console2.log("User    - VIRTUAL: %d, MEME: %d", 
            IERC20(VIRTUALTOKEN).balanceOf(address(this)),
            IERC20(MEME_TOKEN).balanceOf(address(this))
        );
        console2.log("Adapter - VIRTUAL: %d, MEME: %d", 
            IERC20(VIRTUALTOKEN).balanceOf(address(adapter)),
            IERC20(MEME_TOKEN).balanceOf(address(adapter))
        );
    }

    function setUp() public {
        vm.createSelectFork(network, 30508146); // Block with Virtuals activity
        adapter = new VirtualsAdapter(BONDING, VIRTUALTOKEN, FROUTER);
    }

    // Tests Covers:
    // - Virtual token buy operation (VIRTUALTOKEN -> MEME_TOKEN) with refund logic
    // - Virtual token sell operation (MEME_TOKEN -> VIRTUALTOKEN) with refund logic
    // - Balance verification for both tokens and both parties
    // - Refund mechanism for remaining tokens
    //
    // Note: The refund logic in VirtualsAdapter automatically returns any remaining tokens
    // to the origin payer if there are leftover tokens due to high slippage settings.

    function test_virtual_buy() public {
        // User wants to buy MEME_TOKEN using VIRTUALTOKEN
        uint256 virtualTokenAmount = 10 * 10**18;
        deal(VIRTUALTOKEN, address(this), virtualTokenAmount);

        logBalances("Before Buy Operation");

        // Transfer VIRTUALTOKEN to adapter (simulating DexRouter transferring user's tokens)
        IERC20(VIRTUALTOKEN).transfer(address(adapter), virtualTokenAmount);

        // Execute buy operation: adapter trades VIRTUALTOKEN for MEME_TOKEN via bonding contract
        adapter.sellBase(
            address(this),
            address(0),
            abi.encode(MEME_TOKEN, true, block.timestamp + 300)
        );

        logBalances("After Buy Operation");

        // Verify swap worked correctly
        uint256 memeTokenBalance = IERC20(MEME_TOKEN).balanceOf(address(this));
        assertGt(memeTokenBalance, 0, "User should receive MEME_TOKEN");
        
        // Verify adapter has no remaining VIRTUALTOKEN (refund logic should clear it)
        assertEq(IERC20(VIRTUALTOKEN).balanceOf(address(adapter)), 0, "Adapter should have no remaining VIRTUALTOKEN");
    }

    function test_virtual_sell() public {
        // Sell MEME_TOKEN for VIRTUALTOKEN
        uint256 memeTokenAmount = 1 * 10**18;
        deal(MEME_TOKEN, address(this), memeTokenAmount);

        logBalances("Before Sell Operation");

        // Transfer MEME_TOKEN to adapter (simulating DexRouter behavior)
        IERC20(MEME_TOKEN).transfer(address(adapter), memeTokenAmount);

        // Execute sell operation (sellQuote for sell)
        adapter.sellQuote(
            address(this),
            address(0),
            abi.encode(MEME_TOKEN, false, block.timestamp + 300)
        );

        logBalances("After Sell Operation");

        // Verify swap worked correctly
        uint256 virtualTokenBalance = IERC20(VIRTUALTOKEN).balanceOf(address(this));
        assertGt(virtualTokenBalance, 0, "Should receive VIRTUALTOKEN");
        
        // Verify adapter has no remaining MEME_TOKEN (refund logic should clear it)
        assertEq(IERC20(MEME_TOKEN).balanceOf(address(adapter)), 0, "Adapter should have no remaining MEME_TOKEN");
    }

    function test_virtual_buy_with_refund() public {
        // User wants to buy MEME_TOKEN using VIRTUALTOKEN
        uint256 virtualTokenAmount = 100;
        deal(VIRTUALTOKEN, address(this), virtualTokenAmount);

        // Generate some tokens to the adapter
        deal(VIRTUALTOKEN, address(adapter), 1*10**18);

        logBalances("Before Buy Operation");

        // Transfer VIRTUALTOKEN to adapter (simulating DexRouter transferring user's tokens)
        IERC20(VIRTUALTOKEN).transfer(address(adapter), virtualTokenAmount);

        // Execute buy operation: adapter trades VIRTUALTOKEN for MEME_TOKEN via bonding contract
        adapter.sellBase(
            address(this),
            address(0),
            abi.encode(MEME_TOKEN, true, block.timestamp + 300)
        );

        logBalances("After Buy Operation");

        // Verify swap worked correctly
        uint256 memeTokenBalance = IERC20(MEME_TOKEN).balanceOf(address(this));
        assertGt(memeTokenBalance, 0, "User should receive MEME_TOKEN");
        
        // Verify adapter has no remaining VIRTUALTOKEN (refund logic should clear it)
        assertEq(IERC20(VIRTUALTOKEN).balanceOf(address(adapter)), 0, "Adapter should have no remaining VIRTUALTOKEN");
    }

    function test_virtual_sell_with_refund() public {
        // Sell MEME_TOKEN for VIRTUALTOKEN
        uint256 memeTokenAmount = 100;
        deal(MEME_TOKEN, address(this), memeTokenAmount);

        deal(MEME_TOKEN, address(adapter), 1*10**18);

        logBalances("Before Sell Operation");

        // Transfer MEME_TOKEN to adapter (simulating DexRouter behavior)
        IERC20(MEME_TOKEN).transfer(address(adapter), memeTokenAmount);

        // Execute sell operation (sellQuote for sell)
        adapter.sellQuote(
            address(this),
            address(0),
            abi.encode(MEME_TOKEN, false, block.timestamp + 300)
        );

        logBalances("After Sell Operation");

        // Verify swap worked correctly
        uint256 virtualTokenBalance = IERC20(VIRTUALTOKEN).balanceOf(address(this));
        assertGt(virtualTokenBalance, 0, "Should receive VIRTUALTOKEN");
        
        // Verify adapter has no remaining MEME_TOKEN (refund logic should clear it)
        assertEq(IERC20(MEME_TOKEN).balanceOf(address(adapter)), 0, "Adapter should have no remaining MEME_TOKEN");
    }
    
}