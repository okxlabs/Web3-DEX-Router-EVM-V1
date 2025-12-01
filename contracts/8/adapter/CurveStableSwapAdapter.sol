// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IAdapter.sol";
import {ICurveStableSwap, ICurveStableSwapMeta} from "../interfaces/ICurveStableSwap.sol";
import "../interfaces/IERC20.sol";
import "../libraries/SafeERC20.sol";

contract CurveStableSwapAdapter is IAdapter {
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

        uint256 sellAmount = IERC20(fromToken).balanceOf(address(this));
        SafeERC20.safeApprove(IERC20(fromToken), pool, sellAmount);

        if (is_underlying) {
            ICurveStableSwapMeta(pool).exchange_underlying(i, j, sellAmount, 0, to);
        } else {
            ICurveStableSwap(pool).exchange(i, j, sellAmount, 0, to);
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
}