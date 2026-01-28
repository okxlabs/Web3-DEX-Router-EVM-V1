// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IERC20.sol";
import "../interfaces/IAdapter.sol";
import "../interfaces/IXdock.sol";
import "../interfaces/IWETH.sol";
import "../libraries/SafeERC20.sol";

contract XdockAdapter is IAdapter {
    address public immutable AMM_POOL;
    address public immutable WNATIVE;

    struct TradeInfo {
        address fundAddress;
        address tokenAddress;
        bool buyMeme;
        uint256 sellMemeAmount;
        uint256 sellCommissionRate1;
        address sellCommissionReceiver1;
        uint256 sellCommissionRate2;
        address sellCommissionReceiver2;
        uint256 minReturnAmount;
    }

    event Received(address sender, uint256 amount);
    event OrderRecord(bool direction, address fromToken, address toToken, uint256 fromAmount, uint256 toAmount);

    constructor(address _ammPool, address _wnative) {
        AMM_POOL = _ammPool;
        WNATIVE = _wnative;
    }

    function _xdockMemeTrading(
        address to, 
        bytes memory moreInfo
    ) private {
        uint256 amountIn;
        uint256 amountOut;
        TradeInfo memory tradeInfo = abi.decode(moreInfo, (TradeInfo));

        if (tradeInfo.buyMeme) {
            amountIn = IERC20(WNATIVE).balanceOf(address(this));
            IWETH(WNATIVE).withdraw(amountIn);

            IXdock(AMM_POOL).buyExactIn{value: amountIn}(tradeInfo.tokenAddress, 0);

            uint256 dust = address(this).balance;
            if (dust > 0) {
                (bool success, ) = to.call{value: dust}("");
                require(success, "Transfer failed");
            }
            amountOut = IERC20(tradeInfo.tokenAddress).balanceOf(address(this));
            SafeERC20.safeTransfer(IERC20(tradeInfo.tokenAddress), to, amountOut);
            emit OrderRecord(true, tradeInfo.fundAddress, tradeInfo.tokenAddress, amountIn, amountOut);
        } else {
            amountIn = tradeInfo.sellMemeAmount;
            address fundToken = address(0);
            amountOut = _getBalance(fundToken, address(tx.origin));

            IXdock(AMM_POOL).sellExactIn(tradeInfo.tokenAddress, tx.origin, amountIn, tradeInfo.minReturnAmount);

            amountOut = _getBalance(fundToken, tx.origin) - amountOut;
            require(amountOut >= tradeInfo.minReturnAmount, "XdockAdapter: Min return not reached");
            emit OrderRecord(false, tradeInfo.tokenAddress, tradeInfo.fundAddress, tradeInfo.sellMemeAmount, amountOut);
        }
    }

    function _getBalance(address token, address user) internal view returns (uint256) {
        if (token == address(0)) {
            return address(user).balance;
        } else {
            return IERC20(token).balanceOf(user);
        }
    }

    function _safeTransfer(address token, address receiver, uint256 amount) internal {
        if (token == address(0)) {
            (bool success, ) = payable(receiver).call{value: amount}("");
            require(success, "ETH transfer failed");
        } else {
            SafeERC20.safeTransfer(IERC20(token), receiver, amount);
        }
    }

    function sellBase(
        address to,
        address ,
        bytes memory moreInfo
    ) external override {
        _xdockMemeTrading(to, moreInfo);
    }

    function sellQuote(
        address to,
        address ,
        bytes memory moreInfo
    ) external override {
        _xdockMemeTrading(to, moreInfo);
    }

    function supportsInterface(bytes4) external pure returns (bool) {
        return true;
    }

    receive() external payable {
       emit Received(msg.sender, msg.value);
    }
}