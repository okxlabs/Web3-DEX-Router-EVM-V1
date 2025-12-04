// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IAdapter.sol";
import {ICurve, ICurveForETH} from "../interfaces/ICurve.sol";
import "../interfaces/IERC20.sol";
import "../libraries/UniversalERC20.sol";
import "../libraries/SafeERC20.sol";
import "../interfaces/IWETH.sol";



contract CurveAdapter is IAdapter {
    address constant ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public immutable WETH_ADDRESS;

    constructor(address _WETH) {
        WETH_ADDRESS = _WETH;
    }

    function _curveSwap(
        address to,
        address pool,
        bytes memory moreInfo
    ) internal {
        (
            address fromToken,
            address toToken,
            int128 i,
            int128 j,
            bool is_underlying
        ) = abi.decode(moreInfo, (address, address, int128, int128, bool));

        // get sellAmount
        uint256 sellAmount;
        if (fromToken == ETH_ADDRESS) {
            sellAmount = IERC20(WETH_ADDRESS).balanceOf(address(this));
        } else {
            // approve
            sellAmount = IERC20(fromToken).balanceOf(address(this));
            SafeERC20.safeApprove(IERC20(fromToken), pool, sellAmount);
        }
        
        // swap
        if (is_underlying) {
            ICurve(pool).exchange_underlying(i, j, sellAmount, 0);
        } else {
            if (fromToken == ETH_ADDRESS) {
                IWETH(WETH_ADDRESS).withdraw(sellAmount);
                ICurveForETH(pool).exchange{value: sellAmount}(i, j, sellAmount, 0);
            } else {
                ICurve(pool).exchange(i, j, sellAmount, 0);
            }
        }

        if (toToken == ETH_ADDRESS) {
            IWETH(WETH_ADDRESS).deposit{value: address(this).balance}();
            toToken = WETH_ADDRESS;
        }

        if (to != address(this)) {
            SafeERC20.safeTransfer(
                IERC20(toToken),
                to,
                IERC20(toToken).balanceOf(address(this))
            );
        }
    }

    function sellBase(
        address to,
        address pool,
        bytes memory moreInfo
    ) external override {
        _curveSwap(to, pool, moreInfo);
    }

    function sellQuote(
        address to,
        address pool,
        bytes memory moreInfo
    ) external override {
        _curveSwap(to, pool, moreInfo);
    }

    event Received(address, uint256);

    receive() external payable {
        require(msg.value > 0, "receive error");
        emit Received(msg.sender, msg.value);
    }
}
