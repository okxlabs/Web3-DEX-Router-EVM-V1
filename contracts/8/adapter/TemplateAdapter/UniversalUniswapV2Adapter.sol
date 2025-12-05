// SPDX-License-Identifier: MIT
// solhint-disable
pragma solidity ^0.8.17;

import {IAdapter} from "../../interfaces/IAdapter.sol";
import {IERC20} from "../../interfaces/IERC20.sol";
import {SafeERC20} from "../../libraries/SafeERC20.sol";
import {IUniswapV2Pair} from "../../interfaces/IUniswapV2Pair.sol";

/**
 * @title UniversalUniswapV2Adapter
 * @notice Universal adapter for Uniswap V2-style DEX protocols
 * @dev Abstracts sellBase and sellQuote into a single optimized function
 * 
 * External Methods Used:
 *   - sync() -> void : Synchronizes reserves with actual token balances
 *   - token0() -> address : Returns the address of token0 in the pair
 *   - token1() -> address : Returns the address of token1 in the pair  
 *   - getReserves() -> (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) : Returns current reserves and last update timestamp
 *   - swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) -> void : Executes token swap
 *
 * Supported DEX Protocols:
 *   1. Uniswap V2 (0.3% fee: 997/1000)
 *   2. ApeSwap (0.2% fee: 998/1000)
 *   3. ArbSwap (0.3% fee: 997/1000)
 *   4. PancakeSwap (0.25% fee: 9975/10000)
 *   5. QuickSwap (0.3% fee: 997/1000)
 *   6. ArbDex (0.25% fee: 9975/10000)
 *   7. Netswap on Metis (likely 0.3% fee: 997/1000)
 *   8. Camelot V2 (if standard AMM: 997/1000)
 *   9. Rebase tokens (0.3% fee: 997/1000, may need sync)
 *   10. RDex V2 (0.3% fee: 997/1000)
 *   11. Lynex (0.5% fee: 995/1000)
 * 
 * Usage Examples:
 * ```solidity
 * // Uniswap V2 (0.3% fee)
 * bytes memory moreInfo = abi.encode(997, 1000);
 * adapter.sellBase(to, pool, moreInfo);
 * 
 * // PancakeSwap (0.25% fee)  
 * bytes memory moreInfo = abi.encode(9975, 10000);
 * adapter.sellBase(to, pool, moreInfo);
 * 
 * // ApeSwap (0.2% fee)
 * bytes memory moreInfo = abi.encode(998, 1000);
 * adapter.sellBase(to, pool, moreInfo);
 * ```
 */
contract UniversalUniswapV2Adapter is IAdapter {
    using SafeERC20 for IERC20;

    /// @inheritdoc IAdapter
    function sellBase(
        address to,
        address pool,
        bytes memory moreInfo
    ) external override {
        _universalSwap(to, pool, moreInfo, true); // true = selling token0 (base)
    }

    /// @inheritdoc IAdapter
    function sellQuote(
        address to,
        address pool,
        bytes memory moreInfo
    ) external override {
        _universalSwap(to, pool, moreInfo, false); // false = selling token1 (quote)
    }

    /**
     * @notice Universal swap function that handles both base and quote token swaps
     * @param to Recipient address
     * @param pool Pool address
     * @param moreInfo Additional configuration (optional)
     * @param isSellBase True if selling token0 (base), false if selling token1 (quote)
     */
    function _universalSwap(
        address to,
        address pool,
        bytes memory moreInfo,
        bool isSellBase
    ) internal {
        (uint256 feeNumerator, uint256 feeDenominator) = _decodeMoreInfo(moreInfo);
        require(feeNumerator > 0 && feeDenominator > 0, "Invalid fee configuration");
        
        _executeSwap(to, pool, isSellBase, feeNumerator, feeDenominator);
    }

    /**
     * @notice Execute the swap with minimal local variables
     * @param to Recipient address
     * @param pool Pool address
     * @param isSellBase True if selling token0 (base), false if selling token1 (quote)
     * @param feeNumerator Fee numerator
     * @param feeDenominator Fee denominator
     */
    function _executeSwap(
        address to,
        address pool,
        bool isSellBase,
        uint256 feeNumerator,
        uint256 feeDenominator
    ) internal {
        IUniswapV2Pair pair = IUniswapV2Pair(pool);
        pair.sync();

        address tokenIn = isSellBase ? pair.token0() : pair.token1();
        uint256 tokenInRemaining = IERC20(tokenIn).balanceOf(address(this));
        // if adapter has remaining tokenIn, transfer tokenIn to pool from this contract
        // and leave 1 token in this contract for reduce gas cost
        if (tokenInRemaining > 1) {
            IERC20(tokenIn).safeTransfer(pool, tokenInRemaining - 1);
        }

        _performSwap(to, pair, tokenIn, isSellBase, feeNumerator, feeDenominator);
    }

    /**
     * @notice Perform the actual swap calculation and execution
     * @param to Recipient address
     * @param pair Pair contract
     * @param tokenIn Input token address
     * @param isSellBase True if selling token0 (base), false if selling token1 (quote)
     * @param feeNumerator Fee numerator
     * @param feeDenominator Fee denominator
     */
    function _performSwap(
        address to,
        IUniswapV2Pair pair,
        address tokenIn,
        bool isSellBase,
        uint256 feeNumerator,
        uint256 feeDenominator
    ) internal {
        (uint112 reserveIn, uint112 reserveOut,) = pair.getReserves();
        require(reserveIn > 0 && reserveOut > 0, "UniAdapter: INSUFFICIENT_LIQUIDITY");

        (reserveIn, reserveOut) = isSellBase 
            ? (reserveIn, reserveOut)
            : (reserveOut, reserveIn);

        uint256 actualAmountIn = IERC20(tokenIn).balanceOf(address(pair)) - reserveIn;
        uint256 amountOut = _calculateAmountOut(
            actualAmountIn,
            reserveIn,
            reserveOut,
            feeNumerator,
            feeDenominator
        );

        if (isSellBase) {
            pair.swap(0, amountOut, to, new bytes(0));
        } else {
            pair.swap(amountOut, 0, to, new bytes(0));
        }
    }

    /**
     * @notice Calculate output amount using optimized assembly
     * @param amountIn Input amount
     * @param reserveIn Input token reserve
     * @param reserveOut Output token reserve
     * @param feeNumerator Fee numerator
     * @param feeDenominator Fee denominator
     * @return amountOut Calculated output amount
     */
    function _calculateAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 feeNumerator,
        uint256 feeDenominator
    ) internal pure returns (uint256 amountOut) {
        assembly {
            // amountInWithFee = amountIn * feeNumerator
            let amountInWithFee := mul(amountIn, feeNumerator)
            
            // numerator = amountInWithFee * reserveOut
            let numerator := mul(amountInWithFee, reserveOut)
            
            // denominator = reserveIn * feeDenominator + amountInWithFee
            let denominator := add(mul(reserveIn, feeDenominator), amountInWithFee)
            
            // amountOut = numerator / denominator
            amountOut := div(numerator, denominator)
        }
    }

     /**
      * @notice Decode moreInfo parameter into fee configuration
      * @param moreInfo Encoded fee configuration
      * @return feeNumerator Fee numerator (amount after fee)
      * @return feeDenominator Fee denominator (total amount)
      */
     function _decodeMoreInfo(bytes memory moreInfo) internal pure returns (uint256 feeNumerator, uint256 feeDenominator) {
         (feeNumerator, feeDenominator) = abi.decode(moreInfo, (uint256, uint256));
     }
}