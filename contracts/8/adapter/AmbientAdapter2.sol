// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IAdapter.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/IWETH.sol";
import "../libraries/SafeERC20.sol";
import "../interfaces/IAmbient.sol";

contract AmbientAdapter2 is IAdapter {
    address immutable CrocSwapDex;
    address internal constant _ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant _WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    constructor(address _CrocSwapDex) {
        //the only interacted contract
        CrocSwapDex = _CrocSwapDex;
    }

    function _crocSwap(address to, bytes memory moreInfo) internal {
        (address fromToken, address toToken, uint16 proxyIdx) = abi.decode(
            moreInfo,
            (address, address, uint16)
        );

        uint inputAmount = 0;
        uint ethAmount = 0;
        if (fromToken == address(0) || fromToken == _ETH) {
            //Ambient only supports ETH in address(0), same for toToken
            fromToken = address(0);
            IWETH(_WETH).withdraw(IWETH(_WETH).balanceOf(address(this)));
            inputAmount = address(this).balance;
            ethAmount = inputAmount;
        } else {
            inputAmount = IERC20(fromToken).balanceOf(address(this));
            //Approve
            SafeERC20.safeApprove(
                IERC20(fromToken),
                address(CrocSwapDex),
                inputAmount
            );
        }

        toToken = (toToken == _ETH) ? address(0) : toToken;

        (address base, address quote) = fromToken < toToken
            ? (fromToken, toToken)
            : (toToken, fromToken);

        //Swap
        //Currently Ambient only has one pool type index initialized and it is 420
        if (fromToken == base) {
            bytes memory cmd = abi.encode(
                base,
                quote,
                uint(420),
                true,
                true,
                uint128(inputAmount),
                uint16(0),
                type(uint128).max,
                0,
                0
            );
            IAmbient(CrocSwapDex).userCmd{value: ethAmount}(proxyIdx, cmd);
        } else {
            bytes memory cmd = abi.encode(
                base,
                quote,
                uint(420),
                false,
                false,
                uint128(inputAmount),
                uint16(0),
                0,
                0,
                0
            );
            IAmbient(CrocSwapDex).userCmd{value: ethAmount}(proxyIdx, cmd);
        }

        if (toToken == address(0)) {
            IWETH(_WETH).deposit{value: address(this).balance}();
            toToken = _WETH;
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
        _crocSwap(to, moreInfo);
    }

    function sellQuote(
        address to,
        address pool,
        bytes memory moreInfo
    ) external override {
        _crocSwap(to, moreInfo);
    }
    receive() external payable {}
}
