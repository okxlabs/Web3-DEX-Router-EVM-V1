// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../interfaces/IAdapter.sol";
import "../interfaces/IUni.sol";
import "../interfaces/IOkoswapRouter.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/IWETH.sol";
import "../libraries/SafeERC20.sol";

/// @title OkoswapAdapter
/// @notice Adapter for OkoSwap DEX
contract OkoswapAdapter is IAdapter {
    address public immutable router;
    address public immutable WOKB;

    constructor(address _router, address _wokb) {
        router = _router;
        WOKB = _wokb;
    }

    function _swap(address fromToken, address toToken, address to) internal {
        uint256 amountIn = IERC20(fromToken).balanceOf(address(this));

        address[] memory path = new address[](2);
        path[0] = fromToken;
        path[1] = toToken;

        if(fromToken == WOKB) { // OKB -> Token
            IWETH(WOKB).withdraw(amountIn);

            IOkoswapRouter(router).swapExactETHForTokens{value: amountIn}(
                0,
                path, // (must start with WETH)
                to,
                block.timestamp
            );

            SafeERC20.safeTransfer(IERC20(toToken), to, IERC20(toToken).balanceOf(address(this)));
        } else if(toToken == WOKB) { // Token -> OKB
            SafeERC20.safeApprove(IERC20(fromToken), router, amountIn);

            IOkoswapRouter(router).swapExactTokensForETH(
                amountIn,
                0,
                path, // (must end with WETH)
                address(this),
                block.timestamp
            );

            uint256 amountOut = address(this).balance;
            IWETH(WOKB).deposit{value: amountOut}();

            SafeERC20.safeTransfer(IERC20(WOKB), to, amountOut);
        } else { // Token -> Token
            SafeERC20.safeApprove(IERC20(fromToken), router, amountIn);

            IOkoswapRouter(router).swapExactTokensForTokens(
                amountIn,
                0,
                path,
                to,
                block.timestamp
            );

            SafeERC20.safeTransfer(IERC20(toToken), to, IERC20(toToken).balanceOf(address(this)));
        }
    }

    // fromToken == token0
    function sellBase(
        address to,
        address pool,
        bytes memory
    ) external override {
        address fromToken = IUni(pool).token0();
        address toToken = IUni(pool).token1();
        _swap(fromToken, toToken, to);
    }

    // fromToken == token1
    function sellQuote(
        address to,
        address pool,
        bytes memory
    ) external override {
        address fromToken = IUni(pool).token1();
        address toToken = IUni(pool).token0();
        _swap(fromToken, toToken, to);
    }

    receive() external payable {
        assert(msg.sender == WOKB || msg.sender == router);
    }
}