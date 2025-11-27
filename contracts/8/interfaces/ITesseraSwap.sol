// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface ITesseraSwap {
    function tesseraSwapWithAllowances(
        address tokenIn,
        address tokenOut,
        int256 amountSpecified,
        uint256 amountCheck,
        address recipient,
        bytes calldata swapData
    ) external;
}