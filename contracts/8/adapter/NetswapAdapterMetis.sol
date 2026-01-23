// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../interfaces/IAdapter.sol";
import "../interfaces/IUni.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/IWETH.sol";
import "../libraries/SafeERC20.sol";

/// @title UniAdapter
/// @notice Explain to an end user what this does
/// @dev Explain to a developer any extra details
contract NetswapAdapter is IAdapter {
    IWETH WETH = IWETH(payable(0x75cb093E4D61d2A2e65D8e0BBb01DE8d89b53481));
    address ETH = 0xDeadDeAddeAddEAddeadDEaDDEAdDeaDDeAD0000;
    // fromToken == token0
    function sellBase(
        address to,
        address pool,
        bytes memory moreInfo
    ) external override {
        address baseToken = IUni(pool).token0();
        
        if (baseToken == ETH) {
            uint amount = WETH.balanceOf(address(this));
            WETH.withdraw(amount);
            IERC20(ETH).transfer(pool, IERC20(ETH).balanceOf(address(this)));
        } else {
            SafeERC20.safeTransfer(IERC20(baseToken), pool, IERC20(baseToken).balanceOf(address(this)));
        }
        

        (uint256 reserveIn, uint256 reserveOut, ) = IUni(pool).getReserves();
        uint256 dnyFee = abi.decode( moreInfo, (uint256));
        require(
            reserveIn > 0 && reserveOut > 0,
            "NetswapAdapter: INSUFFICIENT_LIQUIDITY"
        );
        require(
            dnyFee > 0 && dnyFee < 10000,
            "NetswapAdapter: DNYFEE_MUST_BETWEEN_0_TO_10000"
        );

        uint256 balance0 = IERC20(baseToken).balanceOf(pool);
        uint256 sellBaseAmount = balance0 - reserveIn;

        uint256 sellBaseAmountWithFee = sellBaseAmount * (10000 - dnyFee);
        uint256 receiveQuoteAmount = sellBaseAmountWithFee * reserveOut / (reserveIn * 10000 + sellBaseAmountWithFee);
        IUni(pool).swap(0, receiveQuoteAmount, address(this), new bytes(0));
        
        address quoteToken = IUni(pool).token1();

        if (quoteToken == ETH) {
            WETH.deposit{value: address(this).balance}();
            quoteToken = address(WETH);
        } 

        if (to != address(this)) {
            SafeERC20.safeTransfer(IERC20(quoteToken), to, IERC20(quoteToken).balanceOf(address(this)));
        }
    }

    // fromToken == token1
    function sellQuote(
        address to,
        address pool,
        bytes memory moreInfo
    ) external override {
        address quoteToken = IUni(pool).token1();
        if (quoteToken == ETH) {
            uint amount = WETH.balanceOf(address(this));
            WETH.withdraw(amount);
            IERC20(ETH).transfer(pool, IERC20(ETH).balanceOf(address(this)));
        } else {
            SafeERC20.safeTransfer(IERC20(quoteToken), pool, IERC20(quoteToken).balanceOf(address(this)));
        }
        (uint256 reserveOut, uint256 reserveIn, ) = IUni(pool).getReserves();
        uint256 dnyFee = abi.decode( moreInfo, (uint256));
        require(
            reserveIn > 0 && reserveOut > 0,
            "NetswapAdapter: INSUFFICIENT_LIQUIDITY"
        );
        require(
            dnyFee > 0 && dnyFee < 10000,
            "NetswapAdapter: DNYFEE_MUST_BETWEEN_0_TO_10000"
        );

        uint256 balance1 = IERC20(quoteToken).balanceOf(pool);
        uint256 sellQuoteAmount = balance1 - reserveIn;

        uint256 sellQuoteAmountWithFee = sellQuoteAmount * (10000 - dnyFee);
        uint256 receiveBaseAmount = sellQuoteAmountWithFee * reserveOut / (reserveIn * 10000 + sellQuoteAmountWithFee);
        IUni(pool).swap(receiveBaseAmount, 0, to, new bytes(0));

        address baseToken = IUni(pool).token0();
        if (baseToken == ETH) {
            WETH.deposit{value: address(this).balance}();
            baseToken = address(WETH);
        }

        if (to != address(this)) {
            SafeERC20.safeTransfer(IERC20(baseToken), to, IERC20(baseToken).balanceOf(address(this)));
        }
    }
    receive() external payable {}
}