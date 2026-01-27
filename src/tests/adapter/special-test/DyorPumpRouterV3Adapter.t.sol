pragma solidity ^0.8.0;

import {DyorPumpRouterV3Adapter} from "contracts/8/adapter/DyorPumpRouterV3Adapter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Test} from "forge-std/Test.sol";

contract DyorPumpRouterV3AdapterSpecialTest is Test {
    // https://www.oklink.com/zh-hans/x-layer/tx/0x88173dce1960c58a4908d9cec4ffa133a6bb28708ff664d7962cdd6df08a5f8e
    function test_sellQuote() public {
        vm.createSelectFork(
            "xlayer", 
            43477105 - 1
        );
        address WETH = 0xe538905cf8410324e03A5A23C1c177a474D59b2b;
        address dyorPumpRouterV3 = 0xDf7143e86c919cb440e6e972bafe0ebD1bb26F56;

        DyorPumpRouterV3Adapter adapter = new DyorPumpRouterV3Adapter(dyorPumpRouterV3, WETH);

        address okb = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
        address fftq = 0x2c557300CdC5a4a5665920096A986f055a1EAA18;
        address user = address(0x8B3997e0a91DDF63585aBbC032C406F47ad45633);
        uint256 amount = 1000 * 10 ** 18;
        bytes memory moreInfo = abi.encode(
            fftq,  // fundAddress
            okb, // tokenAddress
            false, // buyMeme
            amount, // sellMemeAmount
            0, // sellCommissionRate1
            address(0), // sellCommissionReceiver1
            0, // sellCommissionRate2
            address(0), // sellCommissionReceiver2
            0 // minReturnAmount
        );

        // Give user enough tokens for testing
        deal(fftq, user, amount);
        
        // Check balance before
        uint256 balanceBefore = IERC20(fftq).balanceOf(user);
        require(balanceBefore >= amount, "Insufficient balance");

        vm.startPrank(user, user);  // Set both msg.sender and tx.origin to user
        vm.txGasPrice(1);  // Set a consistent gas price
            // Since DyorPumpRouterV3 transfers from tx.origin, user needs to:
            // 1. Have the tokens in their account (done with deal above)
            // 2. Approve the router to spend tokens
            IERC20(fftq).approve(dyorPumpRouterV3, amount);
            
            // Call adapter - router will transfer from to address
            adapter.sellQuote(
                user, // recipient for WETH output
                fftq, // pool/token address
                moreInfo
            );
        vm.stopPrank();
    }
}