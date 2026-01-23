// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IERC20.sol";
import "../interfaces/IAdapter.sol";
import "../interfaces/IVenusToken.sol";
import "../interfaces/IWETH.sol";
import "../libraries/SafeERC20.sol";
import {RefundLib} from "../libraries/Adapters.sol";

contract VenusAdapter is IAdapter {
    address constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public immutable WETH;
    address public immutable vNative;

    event Received(address sender, uint256 amount);

    constructor(address _weth, address _vNative) {
        WETH = _weth;
        vNative = _vNative;
    }

    function sellQuote(
        address to,
        address pool,
        bytes memory
    ) external override {
        // pool = vToken
        require(IVenusToken(pool).isVToken(), "VenusAdapter: pool is not a vToken");
        uint256 amountIn = IERC20(pool).balanceOf(address(this));

        // If the pool is vNative, the underlying is ETH, otherwise it's the underlying token
        address underlying;
        if (pool == vNative) {
            underlying = ETH;
        } else {
            underlying = IVenusToken(pool).underlying();
        }

        IVenusToken(pool).redeem(amountIn);

        address tokenOut = underlying;
        if (underlying == ETH) {
            IWETH(WETH).deposit{value: address(this).balance}();
            tokenOut = WETH;
        }
        uint256 amountOut = IERC20(tokenOut).balanceOf(address(this));
        SafeERC20.safeTransfer(IERC20(tokenOut), to, amountOut);

        refund(pool);
    }

    function sellBase(
        address to,
        address pool,
        bytes memory
    ) external override {
        // pool = vToken
        require(IVenusToken(pool).isVToken(), "VenusAdapter: pool is not a vToken");
        
        // If the pool is vNative, the underlying is ETH, otherwise it's the underlying token
        address underlying;
        if (pool == vNative) {
            underlying = ETH;
        } else {
            underlying = IVenusToken(pool).underlying();
        }

        uint256 amountIn;
        if (underlying == ETH) {
            amountIn = IERC20(WETH).balanceOf(address(this));
            IWETH(WETH).withdraw(amountIn);
            IVenusToken(pool).mint{value: amountIn}();
        } else {
            amountIn = IERC20(underlying).balanceOf(address(this));
            SafeERC20.safeApprove(IERC20(underlying), pool, amountIn);
            IVenusToken(pool).mint(amountIn);
        }
        SafeERC20.safeTransfer(
            IERC20(pool),
            to,
            IERC20(pool).balanceOf(address(this))
        );

        refund(underlying);
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    function refund(address token) internal {
        address payerOrigin = RefundLib.getPayerOrigin();
        if (payerOrigin == address(0)) return;
        
        if (token == ETH) {
            uint256 remainAmount = address(this).balance;
            if (remainAmount > 0) {
                (bool success, ) = payerOrigin.call{value: remainAmount}("");
                require(success, "VenusAdapter: ETH refund failed");
            }
        } else {
            uint256 remainAmount = IERC20(token).balanceOf(address(this));
            if (remainAmount > 0) {
                SafeERC20.safeTransfer(
                    IERC20(token),
                    payerOrigin,
                    remainAmount
                );
            }
        }
    }
}