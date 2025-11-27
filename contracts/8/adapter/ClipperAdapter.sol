// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IAdapter.sol";
import "../interfaces/IClipperExchangeInterface.sol";
import "../interfaces/IERC20.sol";
import "../libraries/UniversalERC20.sol";
import "../libraries/SafeERC20.sol";
import "../interfaces/IWETH.sol";

contract ClipperAdapter is IAdapter {
    address public immutable WETH_ADDRESS;
    address public CLIPPER_ROUTER ;

    constructor(address _weth,address _clipperRouter) {
        WETH_ADDRESS = _weth;
        CLIPPER_ROUTER = _clipperRouter;
    }

    function _clipperSwap(
        address to,
        address,
        bytes memory moreInfo
    ) internal {
        (address fromToken, address toToken, uint256 inputAmount, uint256 outputAmount, uint256 goodUntil, IClipperExchangeInterface.Signature memory sig, bytes memory auxiliaryData) = abi.decode(
            moreInfo,
            (address, address, uint256, uint256, uint256, IClipperExchangeInterface.Signature, bytes)
        );

        uint256 sellAmount = 0;
        if (fromToken == WETH_ADDRESS) {
            sellAmount = IWETH(WETH_ADDRESS).balanceOf(address(this));
            IWETH(WETH_ADDRESS).withdraw(sellAmount);
            IClipperExchangeInterface(CLIPPER_ROUTER).sellEthForToken{value: sellAmount}(
                toToken,
                inputAmount,
                outputAmount,
                goodUntil,
                address(this),
                sig,
                auxiliaryData
            );
        } else {
            sellAmount = IERC20(fromToken).balanceOf(address(this));
            SafeERC20.safeTransfer(IERC20(fromToken), CLIPPER_ROUTER, sellAmount);
            if (toToken == WETH_ADDRESS) {
                IClipperExchangeInterface(CLIPPER_ROUTER).sellTokenForEth(
                    fromToken,
                    inputAmount,
                    outputAmount,
                    goodUntil,
                    address(this),
                    sig,
                    auxiliaryData
                );
            } else {
                IClipperExchangeInterface(CLIPPER_ROUTER).swap(
                    fromToken,
                    toToken,
                    inputAmount,
                    outputAmount,
                    goodUntil,
                    address(this),
                    sig,
                    auxiliaryData
                );
            }
        }

        if (toToken == WETH_ADDRESS) {
            IWETH(WETH_ADDRESS).deposit{value: address(this).balance}();
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
        _clipperSwap(to, pool, moreInfo);
    }

    function sellQuote(
        address to,
        address pool,
        bytes memory moreInfo
    ) external override {
        _clipperSwap(to, pool, moreInfo);
    }

    event Received(address, uint256);

    receive() external payable {
        require(msg.value > 0, "receive error");
        emit Received(msg.sender, msg.value);
    }
}
