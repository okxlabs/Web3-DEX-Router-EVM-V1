// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFluidDexV2Router {
    struct DexKey {
        address token0;
        address token1;
        uint24 fee; // The fee here tells the fee if its a static fee pool or acts as a dynamic fee flag, i.e, type(uint24).max or 0xFFFFFF for dynamic fee pools.
        uint24 tickSpacing;
        address controller;
    }

    struct SwapInParams {
        DexKey dexKey;
        bool swap0To1;
        uint256 amountIn;
        uint256 amountOutMin;
        bytes controllerData;
    }

    /// @notice Swaps an exact amount of input tokens for a minimum amount of output tokens
    /// @dev Transfers input tokens from msg.sender and sends output tokens to the specified recipient
    /// @param dexType_ The DEX type (3 for D3, 4 for D4)
    /// @param swapInParams_ Struct containing swap parameters including dexKey, swap direction, amountIn, amountOutMin, and controller data
    /// @param to_ Address that will receive the output tokens
    /// @return amountOut_ The actual amount of output tokens received
    function swapIn(
        uint256 dexType_,
        SwapInParams calldata swapInParams_,
        address to_
    ) external payable returns (uint256 amountOut_);
}