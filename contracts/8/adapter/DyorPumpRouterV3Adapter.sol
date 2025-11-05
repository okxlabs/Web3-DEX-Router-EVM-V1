// SPDX-License-Identifier: MIT
// solhint-disable
pragma solidity ^0.8.17;

import {IAdapter} from "../interfaces/IAdapter.sol";
import {IERC20} from "../interfaces/IERC20.sol";
import {SafeERC20} from "../libraries/SafeERC20.sol";
import {IUniswapV2Pair} from "../interfaces/IUniswapV2Pair.sol";
import {IDyorPumpRouterV3, IDyorPoolV3} from "../interfaces/IDyor.sol";
import {RestrictedLiquidityLib, RefundLib} from "../libraries/Adapters.sol";
import {IWETH} from "../interfaces/IWETH.sol";
/**
 * @title DyorPumpRouterV3Adapter
 * @notice DyorPumpRouterV3 adapter for DyorPumpRouterV3 DEX protocols
 * @dev Abstracts sellBase and sellQuote into a single optimized function
 * 
 * Supported DEX Protocols:
 *   1. DyorPumpRouterV3
 */
contract DyorPumpRouterV3Adapter is IAdapter {
    using SafeERC20 for IERC20;

    address private immutable dyorPumpRouterV3;
    address private immutable WETH;

    // direction: true for buy meme, false for sell meme
    event OrderRecord(bool direction, address fromToken, address toToken, uint256 fromAmount, uint256 toAmount);
    
    constructor(address _dyorPumpRouterV3, address _WETH) {
        dyorPumpRouterV3 = _dyorPumpRouterV3;
        WETH = _WETH;
    }

    /// @inheritdoc IAdapter
    function sellBase(
        address to, // to, not used, cause dyor will send token to tx.origin
        address pool,
        bytes memory moreInfo
    ) external override {
        _universalSwap(to, pool, true, moreInfo);
    }

    /// @inheritdoc IAdapter
    function sellQuote(
        address to,
        address pool,
        bytes memory moreInfo
    ) external override {
        _universalSwap(to, pool ,false, moreInfo);
    }

    /**
     * @notice Universal swap function that handles both base and quote token swaps
     * @param moreInfo Additional configuration containing swap parameters
     */
    function _universalSwap(
        address to,
        address pool,
        bool isSellBase,
        bytes memory moreInfo
    ) internal {
        address[] memory path = new address[](2);
        if (isSellBase) { // sell eth 
            path[0] = WETH;
            path[1] = pool;
            uint256 amountIn = IERC20(WETH).balanceOf(address(this));
            uint256 amountOutBefore = IERC20(pool).balanceOf(tx.origin);
            IWETH(WETH).withdraw(amountIn);
            IDyorPumpRouterV3(dyorPumpRouterV3).swapExactETHForTokensSupportingFeeOnTransferTokens{value: amountIn}(
                0,
                path,
                tx.origin, // must be tx.origin, and token will be received by tx.origin
                block.timestamp + 1000
            );
            /// @notice if dyorfun retrun eth, adapter will receive eth, so adapter will send eth to payerOrigin
            address payerOrigin = RefundLib.getPayerOrigin();
            uint256 remainAmount = address(this).balance;
            if (remainAmount > 0) {
                if (payerOrigin != address(0)) {
                    payable(payerOrigin).transfer(remainAmount);
                } else {
                    payable(tx.origin).transfer(remainAmount);
                }
            }
            emit OrderRecord(true, WETH, pool, amountIn, IERC20(pool).balanceOf(tx.origin) - amountOutBefore);
        } else { ///@notice sell dyor token is restricted liquidity, have to use tradeInfo to build moreinfo
            path[0] = pool;
            path[1] = WETH;
            uint256 amountOut = address(this).balance; // eth balance
            RestrictedLiquidityLib.TradeInfo memory tradeInfo = abi.decode(moreInfo, (RestrictedLiquidityLib.TradeInfo));
            require(tradeInfo.fundAddress == pool, "DyorPumpRouterV3Adapter: sell token is not meme");
            require(tradeInfo.tokenAddress == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE || 
            tradeInfo.tokenAddress == WETH, "DyorPumpRouterV3Adapter: buy token is not OKB");
            uint256 amountIn = tradeInfo.sellMemeAmount;

            /// @notice cause token will be transfer from tx.origin, so adapter can't use approve
            IDyorPumpRouterV3(dyorPumpRouterV3).swapExactTokensForETHSupportingFeeOnTransferTokens(
                amountIn,
                0,
                path,
                tx.origin, // must be tx.origin
                address(this), // must be address(this), and eth will be received by address(this)
                address(0),
                0,
                block.timestamp + 1000
            );
            amountOut = address(this).balance - amountOut;
            require(amountOut >= tradeInfo.minReturnAmount, "DyorPumpRouterV3Adapter: Min return not reached");
            
            // Wrap ETH to WETH and transfer to 'to' address for next swap step
            if (to != address(this)) {
                IWETH(WETH).deposit{value: amountOut}();
                SafeERC20.safeTransfer(IERC20(WETH), to, amountOut);
            }
            
            emit OrderRecord(false, tradeInfo.fundAddress, tradeInfo.tokenAddress, amountIn, amountOut);
        }
    }


    receive() external payable {}
}