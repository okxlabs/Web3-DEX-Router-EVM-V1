// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAdapter} from "../interfaces/IAdapter.sol";
import {IERC20} from "../interfaces/IERC20.sol";
import {SafeERC20} from "../libraries/SafeERC20.sol";
import {IObricPool} from "../interfaces/IObricPool.sol";

/**
 * @title ObricAdapter
 */
contract ObricAdapter is IAdapter {
    using SafeERC20 for IERC20;

    uint256 internal constant ADDRESS_MASK =
        0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff;
    uint256 internal constant ORIGIN_PAYER =
        0x3ca20afc2ccc0000000000000000000000000000000000000000000000000000;

    function sellBase(
        address to,
        address pool,
        bytes memory moreInfo
    ) external override {
        _obricSwap(to, pool, moreInfo, _getPayerOrigin());
    }

    function sellQuote(
        address to,
        address pool,
        bytes memory moreInfo
    ) external override {
        _obricSwap(to, pool, moreInfo, _getPayerOrigin());
    }

    function _obricSwap(
        address to,
        address pool,
        bytes memory moreInfo,
        uint256 payerOrigin
    ) internal {
        (address tokenIn, address tokenOut) = abi.decode(moreInfo, (address, address));

        uint256 sellAmount = IERC20(tokenIn).balanceOf(address(this));
        require(sellAmount > 0, "ObricAdapter: INVALID_AMOUNT");

        address xToken = IObricPool(pool).xToken();
        address yToken = IObricPool(pool).yToken();
        bool isXtoY;
        if (tokenIn == xToken && tokenOut == yToken) {
            isXtoY = true;
        } else if (tokenIn == yToken && tokenOut == xToken) {
            isXtoY = false;
        } else {
            revert("ObricAdapter: TOKEN_MISMATCH");
        }

        SafeERC20.safeApprove(IERC20(tokenIn), pool, sellAmount);

        uint256 beforeOut = IERC20(tokenOut).balanceOf(address(this));
        IObricPool(pool).swap(sellAmount, isXtoY);
        uint256 outAmount = IERC20(tokenOut).balanceOf(address(this)) - beforeOut;

        if (outAmount > 0) {
            SafeERC20.safeTransfer(IERC20(tokenOut), to, outAmount);
        }

        /// @notice Refund logic: if there is leftover tokenIn, refund to payerOrigin
        address _payerOrigin;
        if ((payerOrigin & ORIGIN_PAYER) == ORIGIN_PAYER) {
            _payerOrigin = address(uint160(uint256(payerOrigin) & ADDRESS_MASK));
        }
        uint256 remainingIn = IERC20(tokenIn).balanceOf(address(this));
        if (remainingIn > 0 && _payerOrigin != address(0)) {
            SafeERC20.safeTransfer(IERC20(tokenIn), _payerOrigin, remainingIn);
        }
    }

    function _getPayerOrigin() internal pure returns (uint256 payerOrigin) {
        assembly {
            let size := calldatasize()
            payerOrigin := calldataload(sub(size, 32))
        }
    }
}


