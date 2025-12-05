// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IAdapter.sol";
import "../interfaces/IUni.sol";
import "../interfaces/IERC20.sol";

/// @title UniAdapter
/// @notice Explain to an end user what this does
/// @dev Explain to a developer any extra details
contract DnyFeeAdapter is IAdapter {
    // fromToken == token0
    function sellBase(
        address to,
        address pool,
        bytes memory moreInfo
    ) external override {
        address baseToken = IUni(pool).token0();
        (uint256 reserveIn, uint256 reserveOut, ) = IUni(pool).getReserves();
        uint256 dnyFee = abi.decode(moreInfo, (uint256));
        require(
            reserveIn > 0 && reserveOut > 0,
            "DnyFeeAdapter: INSUFFICIENT_LIQUIDITY"
        );
        require(
            dnyFee < 10000,
            "DnyFeeAdapter: DNYFEE_MUST_BETWEEN_0_TO_10000"
        );

        uint256 balance0 = IERC20(baseToken).balanceOf(pool);
        uint256 sellBaseAmount = balance0 - reserveIn;

        uint256 sellBaseAmountWithFee = sellBaseAmount * (10000 - dnyFee);
        uint256 receiveQuoteAmount = sellBaseAmountWithFee * reserveOut / (reserveIn * 10000 + sellBaseAmountWithFee);
        IUni(pool).swap(0, receiveQuoteAmount, to, new bytes(0));
    }

    // fromToken == token1
    function sellQuote(
        address to,
        address pool,
        bytes memory moreInfo
    ) external override {
        address quoteToken = IUni(pool).token1();
        (uint256 reserveOut, uint256 reserveIn, ) = IUni(pool).getReserves();
        uint256 dnyFee = abi.decode(moreInfo, (uint256));
        require(
            reserveIn > 0 && reserveOut > 0,
            "DnyFeeAdapter: INSUFFICIENT_LIQUIDITY"
        );
        require(
            dnyFee < 10000,
            "DnyFeeAdapter: DNYFEE_MUST_BETWEEN_0_TO_10000"
        );

        uint256 balance1 = IERC20(quoteToken).balanceOf(pool);
        uint256 sellQuoteAmount = balance1 - reserveIn;

        uint256 sellQuoteAmountWithFee = sellQuoteAmount * (10000 - dnyFee);
        uint256 receiveBaseAmount = sellQuoteAmountWithFee * reserveOut / (reserveIn * 10000 + sellQuoteAmountWithFee);
        IUni(pool).swap(receiveBaseAmount, 0, to, new bytes(0));
    }
}