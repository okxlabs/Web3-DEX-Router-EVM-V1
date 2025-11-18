// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAdapter} from "../interfaces/IAdapter.sol";
import {IERC20} from "../interfaces/IERC20.sol";
import {SafeERC20} from "../libraries/SafeERC20.sol";
import {ITesseraSwap} from "../interfaces/ITesseraSwap.sol";

/**
 * @title TesseraAdapter
 */
contract TesseraAdapter is IAdapter {
    using SafeERC20 for IERC20;
    address public immutable TESSERA_SWAP;

    constructor (
        address _tesseraSwap
    ) {
        TESSERA_SWAP = _tesseraSwap;
    }

    function sellBase(
        address to,
        address,
        bytes memory moreInfo
    ) external override {
        _tesseraSwap(to, moreInfo);
    }

    function sellQuote(
        address to,
        address,
        bytes memory moreInfo
    ) external override {
        _tesseraSwap(to, moreInfo);
    }

    function _tesseraSwap(
        address to,
        bytes memory moreInfo
    ) internal {
        (address tokenIn, address tokenOut) = abi.decode(
            moreInfo,   
            (address, address)
        );

        uint256 sellAmount = IERC20(tokenIn).balanceOf(address(this));
        require(sellAmount > 0 && sellAmount <= uint256(type(int256).max), "TesseraAdapter: INVALID_AMOUNT");

        SafeERC20.safeApprove(
            IERC20(tokenIn),
            TESSERA_SWAP,
            sellAmount
        );

        ITesseraSwap(TESSERA_SWAP).tesseraSwapWithAllowances(
            tokenIn,
            tokenOut,
            int256(sellAmount), // positive for exactInput
            0, // minimum output will be checked by router
            to,
            ""
        );
    }
}