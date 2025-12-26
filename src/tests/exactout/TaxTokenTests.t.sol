// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../common/BaseTestSetup.t.sol";

contract TaxTokenTests is BaseTestSetup {
    // 测试税点ERC20代币单池交换(fromToken为moonToken)
    function testMoonERC20TokenSinglePoolExchange() public {
        uint256 sourceTokenIndex = 4;
        uint256 targetTokenIndex = 1;
        uint256 amountOut = 400e18;
        uint256 amountInMax = 500e18;

        IUniswapV2Pair pair = IUniswapV2Pair(pairMatrix[4][1]);
        console2.log("pair:", address(pair));
        console2.log("before sourceToken balance:", tokens[sourceTokenIndex].balanceOf(amy));
        console2.log("before targetToken balance:", tokens[targetTokenIndex].balanceOf(amy));

        bytes32 pool0 = _buildPool(address(tokens[sourceTokenIndex]), address(tokens[targetTokenIndex]), address(pair), false);
        bytes32[] memory pools = new bytes32[](1);
        pools[0] = pool0;

        vm.startPrank(amy);
            tokens[sourceTokenIndex].approve(address(tokenApprove), amountInMax);
            dexRouter.unxswapExactOutTo(
                uint256(uint160(address(tokens[sourceTokenIndex]))),
                amountOut,
                amountInMax,
                amy,
                pools
            );
        vm.stopPrank();

        console2.log("after sourceToken balance:", tokens[sourceTokenIndex].balanceOf(amy));
        console2.log("after targetToken balance:", tokens[targetTokenIndex].balanceOf(amy));
    }

    // 测试税点ETH代币单池交换(toToken为moonToken)
    function testMoonETHTokenSinglePoolExchange() public {
        uint256 sourceTokenIndex = 1;
        uint256 targetTokenIndex = 4;
        uint256 amountOut = 400e18;
        uint256 amountInMax = 500e18;

        IUniswapV2Pair pair = IUniswapV2Pair(pairMatrix[1][4]);
        console2.log("pair:", address(pair));
        console2.log("before sourceToken balance:", tokens[sourceTokenIndex].balanceOf(amy));
        console2.log("before targetToken balance:", amy.balance);
        
        bytes32 pool0 = _buildPool(address(tokens[sourceTokenIndex]), address(tokens[targetTokenIndex]), address(pair), false);  
        bytes32[] memory pools = new bytes32[](1);
        pools[0] = pool0;

        vm.startPrank(amy);
            tokens[sourceTokenIndex].approve(address(tokenApprove), amountInMax);
            dexRouter.unxswapExactOutTo{value: 0}(
                uint256(uint160(address(tokens[sourceTokenIndex]))),
                amountOut,
                amountInMax,
                amy,
                pools
            );
        vm.stopPrank();

        console2.log("after sourceToken balance:", tokens[sourceTokenIndex].balanceOf(amy));
        console2.log("after targetToken balance:", amy.balance);
    }
} 