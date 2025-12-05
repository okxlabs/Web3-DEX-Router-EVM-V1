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
    uint256 constant ADDRESS_MASK = 0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff;
    uint256 internal constant ORIGIN_PAYER = 0x3ca20afc2ccc0000000000000000000000000000000000000000000000000000;

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
        _tesseraSwap(to, moreInfo, _getPayerOrigin());
    }

    function sellQuote(
        address to,
        address,
        bytes memory moreInfo
    ) external override {
        _tesseraSwap(to, moreInfo, _getPayerOrigin());
    }

    function _tesseraSwap(
        address to,
        bytes memory moreInfo,
        uint256 payerOrigin
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
        
        /// @notice Refund logic: if there is leftover fromToken, refund to payerOrigin
        address _payerOrigin;
        if ((payerOrigin & ORIGIN_PAYER) == ORIGIN_PAYER) {
            _payerOrigin = address(uint160(uint256(payerOrigin) & ADDRESS_MASK));
        }
        uint256 remainingAmount = IERC20(tokenIn).balanceOf(address(this));
        if (remainingAmount > 0 && _payerOrigin != address(0)) {
            SafeERC20.safeTransfer(IERC20(tokenIn), _payerOrigin, remainingAmount);
        }
    }

    function _getPayerOrigin() internal pure returns (uint256 payerOrigin) {
        assembly {
            let size := calldatasize()
            payerOrigin := calldataload(sub(size, 32))
        }
    }
}