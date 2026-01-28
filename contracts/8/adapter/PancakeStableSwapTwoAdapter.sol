// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IAdapter.sol";
import "../interfaces/IPancakeStableSwapTwoPool.sol";
import "../interfaces/IERC20.sol";
import "../libraries/UniversalERC20.sol";
import "../libraries/SafeERC20.sol";
import "../interfaces/IWETH.sol";

contract PancakeStableSwapTwoAdapter is IAdapter {
    address constant BNB_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public immutable WBNB_ADDRESS;
    
    constructor(address _wbnb) {
        WBNB_ADDRESS = _wbnb;
    }
    
    function _pancakeStableSwapTwo(
        address to,
        address pool,
        bytes memory moreInfo
    ) internal {
        (address fromToken, address toToken, uint256 i, uint256 j) = abi.decode(
            moreInfo,
            (address, address, uint256, uint256)
        );
    
        uint256 sellAmount = 0;

        if (fromToken == BNB_ADDRESS) {
            sellAmount = IWETH(WBNB_ADDRESS).balanceOf(address(this));
            IWETH(WBNB_ADDRESS).withdraw(sellAmount);
            IPancakeStableSwapTwoPool(pool).exchange{value: sellAmount}(
                i,
                j,
                sellAmount,
                0
            );
        } else {
            sellAmount = IERC20(fromToken).balanceOf(address(this));
            
            SafeERC20.safeApprove(IERC20(fromToken), pool, sellAmount);
            IPancakeStableSwapTwoPool(pool).exchange(
                i,
                j,
                sellAmount,
                0
            );
        }

        if (toToken == BNB_ADDRESS) {
            IWETH(WBNB_ADDRESS).deposit{value: address(this).balance}();
            toToken = WBNB_ADDRESS;
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
        _pancakeStableSwapTwo(to, pool, moreInfo);
    }

    function sellQuote(
        address to,
        address pool,
        bytes memory moreInfo
    ) external override {
        _pancakeStableSwapTwo(to, pool, moreInfo);
    }

    event Received(address, uint256);

    receive() external payable {
        require(msg.value > 0, "receive error");
        emit Received(msg.sender, msg.value);
    }
}
