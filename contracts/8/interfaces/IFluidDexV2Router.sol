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

    struct SwapInConfig {
        uint256 dexType;
        DexKey dexKey;
        uint256 amountOutMin;
        bytes controllerData;
    }

    /// @notice Executes a multi-hop swap with an exact input amount across multiple DEX pools
    /// @dev Swaps through a sequence of pools defined by path and configs. Supports mixing D3 and D4 pools.
    /// @param path_ Array of token addresses defining the swap route. Length must be swapInConfigs.length + 1.
    ///              Example: [TokenA, TokenB, TokenC] for swapping A→B→C
    /// @param swapInConfigs_ Array of swap configurations for each hop, including DEX type, dex key, amount out min, and controller data
    /// @param amountIn_ The exact amount of input tokens (first token in path) to swap
    /// @param to_ Address that will receive the final output tokens
    /// @return amountOut_ The actual amount of output tokens (last token in path) received
    function swapInMulti(
        address[] calldata path_,
        SwapInConfig[] calldata swapInConfigs_,
        uint256 amountIn_,
        address to_
    ) external payable returns (uint256 amountOut_);
}