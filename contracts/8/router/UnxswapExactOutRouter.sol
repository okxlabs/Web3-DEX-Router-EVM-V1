/// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../libraries/Constants.sol";
import "../libraries/ExactOutSwapHelper.sol";
import "../libraries/UniswapTokenInfoHelper.sol";
import "../libraries/EventLib.sol";
import "../interfaces/IDexRouter.sol";
import "../interfaces/IWETH.sol";

library UnxswapExactOutRouter {
    uint256 private constant _NUMERATOR_MASK =
        0x0000000000000000ffffffff0000000000000000000000000000000000000000;

    uint256 private constant _DENOMINATOR = 1_000_000_000;
    uint256 private constant _NUMERATOR_OFFSET = 160;

    struct ExactOutCache {
        uint256 amountOut;
        uint256 maxConsume;
        address payer;
        address receiver;
    }

    event Swap(
        address indexed srcToken,
        address indexed dstToken,
        address indexed payer,
        uint256 returnAmount,
        uint256 amount
    );

    // ================================================================================
    // ============================== Public Functions ================================
    // ================================================================================
    /// @notice Executes an exact output swap using the Unxswap protocol, including commission handling.
    /// @param srcToken The source token as a uint256 (address encoded with order ID mask).
    /// @param amount The target output amount to receive.
    /// @param maxConsume The maximum amount of source tokens to consume (slippage protection).
    /// @param receiver The address to receive the output tokens.
    /// @param pools The list of pool identifiers to use for the swap path.
    /// @return consumeAmount The actual amount of source tokens consumed, including commission.
    function unxswapExactOutTo(
        uint256 srcToken,
        uint256 amount,
        uint256 maxConsume,
        address receiver,
        bytes32[] calldata pools,
        IDexRouter.ExtraData memory extraData
    ) public returns (uint256 consumeAmount) {
        EventLib.emitSwapOrderId((srcToken & _ORDER_ID_MASK) >> 160);
        return
            _unxswapExactOutTo(
                srcToken,
                ExactOutCache({
                    amountOut: amount,
                    maxConsume: maxConsume,
                    payer: msg.sender,
                    receiver: receiver
                }),
                pools,
                extraData
            );
    }

    /// @notice Executes an exact output swap using the Unxswap protocol, including commission handling. The receiver is set to msg.sender.
    /// @param srcToken The source token as a uint256 (address encoded with order ID mask).
    /// @param amount The target output amount to receive.
    /// @param maxConsume The maximum amount of source tokens to consume (slippage protection).
    /// @param pools The list of pool identifiers to use for the swap path.
    /// @return consumeAmount The actual amount of source tokens consumed, including commission.
    function unxswapExactOutToByOrderID(
        uint256 srcToken,
        uint256 amount,
        uint256 maxConsume,
        bytes32[] calldata pools,
        IDexRouter.ExtraData memory extraData
    ) public returns (uint256 consumeAmount) {
        EventLib.emitSwapOrderId((srcToken & _ORDER_ID_MASK) >> 160);
        return
            _unxswapExactOutTo(
                srcToken,
                ExactOutCache({
                    amountOut: amount,
                    maxConsume: maxConsume,
                    payer: msg.sender,
                    receiver: msg.sender
                }),
                pools,
                extraData
            );
    }


    // ================================================================================
    // ============================== Private Functions ===============================
    // ================================================================================
    /// @notice Internal function to perform an exact output swap using the Unxswap protocol, handling commission logic for both source and target tokens.
    /// @notice ETH address on this parameter srcToken is 0x0000000000000000000000000000000000000000
    /// @param srcToken The source token as a uint256 (address encoded with order ID mask).
    /// @param cache The cache of the exact out swap.
    /// @param pools The list of pool identifiers to use for the swap path.
    /// @param extraData The extra data for the exact out swap.
    /// @return consumeAmount The actual amount of source tokens consumed, including commission.
    function _unxswapExactOutTo(
        uint256 srcToken,
        ExactOutCache memory cache,
        bytes32[] calldata pools,
        IDexRouter.ExtraData memory extraData
    ) private returns (uint256 consumeAmount) {
        require(cache.receiver != address(0), "not addr(0)");
        // Step 1: Adjust the target output amount to include commission if commission is taken from the output token.
        uint256 targetTokenBefore = 0;
        address middleReceiver = cache.receiver;
        IDexRouter.CommissionInfo memory commissionInfo;
        (
            commissionInfo,
            cache.amountOut,
            targetTokenBefore,
            middleReceiver
        ) = ExactOutSwapHelper.beforeSwap(cache.amountOut, middleReceiver, targetTokenBefore, extraData);

        // Step 2: Validate and execute the swap.
        // If srcToken is ETH, the user must prepay ETH; any excess will be refunded after the swap.
        address srcTokenAddress = address(uint160(srcToken & _ADDRESS_MASK));
        address toToken;
        {
            address fromToken;
            (fromToken, toToken) = UniswapTokenInfoHelper.getUnxswapTokenInfo(msg.value > 0, pools);
            require(
                (srcTokenAddress == fromToken && fromToken != _ETH) || (srcTokenAddress == address(0) && fromToken == _ETH),
                "unxswap: token mismatch"
            );
        }
        consumeAmount = _unxswapExactOutInternal(
            IERC20(srcTokenAddress),
            cache.amountOut,
            cache.maxConsume,
            pools,
            cache.payer,
            middleReceiver
        );

        // Step 3: Handle commission from the source token if applicable.
        ExactOutSwapHelper.afterSwap(
            IDexRouter.AfterSwapParams({
                commissionInfo: commissionInfo,
                consumeAmount: consumeAmount,
                targetTokenBefore: targetTokenBefore,
                srcToken: srcTokenAddress == address(0) ? _ETH : srcTokenAddress,
                toToken: toToken,
                receiver: cache.receiver,
                payer: cache.payer
            })
        );
    }

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
    ) private returns (uint256 returnAmount) {
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
            (bool success,) = receiver.call{value: amountOut, gas: NATIVE_TOKEN_TRANSFER_GAS_LIMIT}("");
            require(success, "ETH transfer failed");
        } else {
            toToken = isReversed ? IUni(pair).token0() : IUni(pair).token1();
        }
        
        return (to, toToken);
    }
}