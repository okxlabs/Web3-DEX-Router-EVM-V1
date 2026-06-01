// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IUni.sol";

import "./libraries/UniversalERC20.sol";
import "./libraries/CommonUtils.sol";
import "./interfaces/IWETH.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IApproveProxy.sol";

contract UnxswapExactOutRouter is CommonUtils {

    uint256 private constant _WETH_MASK =
        0x4000000000000000000000000000000000000000000000000000000000000000;
    uint256 private constant _NUMERATOR_MASK =
        0x0000000000000000ffffffff0000000000000000000000000000000000000000;

    uint256 private constant _DENOMINATOR = 1_000_000_000;
    uint256 private constant _NUMERATOR_OFFSET = 160;

    event Swap(
        address indexed srcToken,
        address indexed dstToken,
        address indexed payer,
        uint256 returnAmount,
        uint256 amount
    );

    /// @notice Executes an exact output swap (ExactOut mode) using the Unxswap protocol.
    /// @param srcToken The source token to be swapped.
    /// @param amount The exact amount of target tokens to receive.
    /// @param maxConsume The maximum amount of source tokens allowed to be consumed.
    /// @param pools The swap path, as an array of pool identifiers.
    /// @param payer The address providing the source tokens.
    /// @param receiver The address to receive the output tokens.
    /// @return returnAmount The amount of source tokens actually consumed.
    /// @dev This function calculates the required input for each pool in the path, performs the necessary token transfers, and executes the swaps in sequence. The final swap may unwrap WETH to ETH if required.
    function _unxswapExactOutInternal(
        IERC20 srcToken,
        uint256 amount,
        uint256 maxConsume,
        bytes32[] calldata pools,
        address payer,
        address receiver
    ) internal returns (uint256 returnAmount) {
        require(pools.length > 0, "empty pools");
        
        // Calculate the required input amount for each pool in the path, working backwards from the output.
        uint256[] memory amounts = new uint256[](pools.length + 1);
        amounts[pools.length] = amount; // Set the final required output amount.
        
        // Compute the required input for each pool, starting from the last pool and moving backwards.
        for(uint i = pools.length; i > 0; i--) {
            bytes32 poolData = pools[i-1];
            amounts[i-1] = _calculateRequiredInputAmount(poolData, amounts[i]);
        }
        
        returnAmount = amounts[0];
        require(returnAmount <= maxConsume, "excessive input amount"); // In ExactOut mode, input must not exceed maxConsume.
        
        // Handle the transfer of input tokens from the payer to the first pool.
        _handleTokenPaymentV2(
            payer,
            address(uint160(uint256(pools[0]) & _ADDRESS_MASK)),
            address(srcToken),
            returnAmount
        );
        
        // Execute all swaps in the path.
        address toToken;
        for(uint i = 0; i < pools.length; i++) {
            bytes32 poolData = pools[i];
            address to;
            
            // Determine the recipient address for this swap step.
            if(i == pools.length - 1) {
                (to, toToken) = _handleFinalSwap(poolData, amounts[i+1], receiver);
            } else {
                to = address(uint160(uint256(pools[i+1]) & _ADDRESS_MASK));
                _executeSwap(poolData, amounts[i+1], to);
            }
        }
        
        // Emit the swap event.
        emit Swap(
            address(srcToken),
            toToken,
            tx.origin,
            returnAmount,
            amount
        );
    }
    
    /// @notice Calculates the required input amount for a given pool to achieve a desired output amount.
    /// @param poolData The encoded pool data.
    /// @param amountOut The desired output amount for this pool.
    /// @return The required input amount for this pool.
    function _calculateRequiredInputAmount(bytes32 poolData, uint256 amountOut) private view returns (uint256) {
        address pair = address(uint160(uint256(poolData) & _ADDRESS_MASK));
        bool isReversed = (uint256(poolData) & _REVERSE_MASK) != 0;
        uint256 numerator = (uint256(poolData) & _NUMERATOR_MASK) >> _NUMERATOR_OFFSET;
        
        // Get the reserves of the pool.
        (uint256 reserve0, uint256 reserve1,) = IUni(pair).getReserves();
        require(reserve0 > 0 && reserve1 > 0, "insufficient liquidity");
        
        if(isReversed) {
            (reserve0, reserve1) = (reserve1, reserve0);
        }
        
        // Calculate the required input amount using the Uniswap formula for exact output swaps.
        // amountIn = (amountOut * reserve0 * 10000) / ((reserve1 - amountOut) * numerator) + 1
        return (amountOut * reserve0 * _DENOMINATOR) / ((reserve1 - amountOut) * numerator) + 1;
    }

    /// @notice Handles the payment of tokens for a swap, supporting both ETH and ERC20 tokens.
    /// @param payer The address providing the tokens.
    /// @param recipient The address receiving the tokens (usually the pool).
    /// @param token The address of the token to pay.
    /// @param amount The amount of tokens to pay.
    function _handleTokenPaymentV2(
        address payer,
        address recipient,
        address token,
        uint256 amount
    ) private {        
        if(token == address(0)) {
            require(msg.value >= amount, "insufficient ETH");
            IWETH(_WETH).deposit{value: amount}();
            require(IERC20(_WETH).transfer(recipient, amount), "WETH transfer failed");
        } else {
            require(msg.value == 0, "non-zero ETH");
            IApproveProxy(_APPROVE_PROXY).claimTokens(token, payer, recipient, amount);
        }
    }
    
    function _executeSwap(bytes32 poolData, uint256 amountOut, address to) private {
        address pair = address(uint160(uint256(poolData) & _ADDRESS_MASK));
        bool isReversed = (uint256(poolData) & _REVERSE_MASK) != 0;
        
        uint256 amount0Out = isReversed ? amountOut : 0;
        uint256 amount1Out = isReversed ? 0 : amountOut;
        IUni(pair).swap(amount0Out, amount1Out, to, new bytes(0));
    }
    
    function _handleFinalSwap(bytes32 poolData, uint256 amountOut, address receiver) private returns (address to, address toToken) {
        address pair = address(uint160(uint256(poolData) & _ADDRESS_MASK));
        bool isReversed = (uint256(poolData) & _REVERSE_MASK) != 0;
        bool isWeth = (uint256(poolData) & _WETH_MASK) != 0;
        
        to = isWeth ? address(this) : receiver;
        
        _executeSwap(poolData, amountOut, to);
        
        if(isWeth) {
            toToken = address(0);
            IWETH(_WETH).withdraw(amountOut);
            (bool success,) = receiver.call{value: amountOut}("");
            require(success, "ETH transfer failed");
        } else {
            toToken = isReversed ? IUni(pair).token0() : IUni(pair).token1();
        }
        
        return (to, toToken);
    }
}