// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IAdapter.sol";
import "../interfaces/ICurveCryptoSwap.sol";
import "../interfaces/IERC20.sol";

contract CurveCryptoSwapAdapter is IAdapter {
    function _curveCryptoSwap(
        address to,
        address pool,
        bytes memory moreInfo
    ) internal {
        (
            address fromToken,
            ,  // toToken not needed for exchange_received
            uint256 i,
            uint256 j
        ) = abi.decode(moreInfo, (address, address, uint256, uint256));

        uint256 reserveIn = ICurveCryptoSwap(pool).balances(i);
        uint256 currentBalance = IERC20(fromToken).balanceOf(pool);
        uint256 dx = currentBalance - reserveIn;
        ICurveCryptoSwap(pool).exchange_received(i, j, dx, 0, to);
    }

    function sellBase(
        address to,
        address pool,
        bytes memory moreInfo
    ) external override {
        _curveCryptoSwap(to, pool, moreInfo);
    }

    function sellQuote(
        address to,
        address pool,
        bytes memory moreInfo
    ) external override {
        _curveCryptoSwap(to, pool, moreInfo);
    }
}
