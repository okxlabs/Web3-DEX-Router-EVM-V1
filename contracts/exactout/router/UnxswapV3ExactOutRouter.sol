/// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../libraries/Constants.sol";
import "../libraries/EventLib.sol";
import "../libraries/ExactOutSwapHelper.sol";
import "../libraries/UniswapTokenInfoHelper.sol";
import "../libraries/TempStorage.sol";
import "../libraries/SafeCast.sol";
import "../interfaces/IDexRouter.sol";
import "../interfaces/IWETH.sol";
import "../interfaces/uniV3/IUniswapV3Factory.sol";

library UnxswapV3ExactOutRouter {
    using Address for address payable;

    event Swap(
        address indexed srcToken,
        address indexed dstToken,
        address indexed payer,
        uint256 amount
    );

    bytes32 private constant _POOL_INIT_CODE_HASH =
        0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54; // Pool init code hash
    /// @dev check the factory address when deploy on different chain
    address private constant _FF_FACTORY_ADDRESS = address(0x1F98431c8aD98523631AE4a59f267346ea31F984);
    // concatenation of token0(), token1() fee(), transfer() and claimTokens() selectors
    bytes32 private constant _SELECTORS =
        0x0dfe1681d21220a7ddca3f43a9059cbb0a5ea466000000000000000000000000;
    // concatenation of withdraw(uint),transfer()
    bytes32 private constant _SELECTORS2 =
        0x2e1a7d4da9059cbb000000000000000000000000000000000000000000000000;
    bytes32 private constant _SELECTORS3 =
        0xa9059cbb70a08231000000000000000000000000000000000000000000000000;
    uint160 private constant _MIN_SQRT_RATIO = 4_295_128_739 + 1;
    uint160 private constant _MAX_SQRT_RATIO =
        1_461_446_703_485_210_103_287_273_052_203_988_822_378_723_970_342 - 1;
    bytes32 private constant _SWAP_SELECTOR =
        0x128acb0800000000000000000000000000000000000000000000000000000000; // Swap function selector
    uint256 private constant _INT256_MAX =
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff; // Maximum int256
    uint256 private constant _INT256_MIN =
        0x8000000000000000000000000000000000000000000000000000000000000000; // Minimum int256

    // ================================================================================
    // ============================== Public Functions ================================
    // ================================================================================
    /// @notice Executes an exact output swap using the Uniswap V3 protocol, including commission handling.
    /// @param receiver The address to receive the output tokens (encoded as uint256 with order ID mask).
    /// @param amountOut The exact amount of output tokens to receive.
    /// @param maxConsume The maximum amount of source tokens to consume (slippage protection).
    /// @param pools The list of pool identifiers to use for the swap path.
    /// @param extraData Additional data encoded in calldata.
    /// @return consumeAmount The actual amount of source tokens consumed, including commission.
    function uniswapV3SwapExactOutTo(
        uint256 receiver,
        uint256 amountOut,
        uint256 maxConsume,
        uint256[] calldata pools,
        IDexRouter.ExtraData memory extraData
    ) public returns (uint256 consumeAmount) {
        EventLib.emitSwapOrderId((receiver & _ORDER_ID_MASK) >> 160);
        EventLib.emitCommissionAndTrimInfoIfNeeded(extraData);

        consumeAmount = _uniswapV3SwapExactOutTo(
            IDexRouter.ExactOutSwapCache({
                amountOut: amountOut,
                maxConsume: maxConsume,
                payer: msg.sender
            }),
            CommonLib.bytes32ToAddress(receiver),
            pools,
            extraData
        );
    }

    /// @notice Handles the callback from Uniswap V3 pool during a swap, paying the required input tokens and continuing the swap path if needed.
    /// @param amount0Delta The change in token0 balance (positive means the contract must pay token0).
    /// @param amount1Delta The change in token1 balance (positive means the contract must pay token1).
    /// @param data Encoded callback data containing the payer and remaining pools.
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) public {
        _uniswapV3SwapCallback(amount0Delta, amount1Delta, data);
    }


    // ================================================================================
    // ============================== Private Functions ===============================
    // ================================================================================
    /// @notice Internal function to perform an exact output swap using the Uniswap V3 protocol, handling commission logic for both source and target tokens.
    /// @param swapCache The cache of the exact out swap.
    /// @param receiver The address to receive the output tokens.
    /// @param pools The list of pool identifiers to use for the swap path.
    /// @param extraData The extra data for the exact out swap.
    /// @return consumeAmount The actual amount of source tokens consumed, including commission.
    function _uniswapV3SwapExactOutTo(
        IDexRouter.ExactOutSwapCache memory swapCache,
        address receiver,
        uint256[] calldata pools,
        IDexRouter.ExtraData memory extraData
    ) private returns (uint256 consumeAmount) {
        receiver = receiver == address(0) ? msg.sender : receiver;

        // Step 1: If the swap starts from ETH, the contract will wrap ETH to WETH in the last pool.
        TempStorage.setEthAmount(msg.value);

        // Step 2: Adjust the target output amount to include commission if commission is taken from the output token.
        uint256 targetTokenBefore = 0;
        address middleReceiver = receiver;
        (
            swapCache.amountOut,
            targetTokenBefore,
            middleReceiver
        ) = ExactOutSwapHelper.beforeSwap(swapCache.amountOut, middleReceiver, targetTokenBefore, extraData);

        // Step 3: Get token, transfer mode and validate.
        uint256 mode = pools[0] & _TRANSFER_MODE_MASK;
        require(
            mode == _MODE_LEGACY || mode == _MODE_DIRECT || mode == _MODE_PERMIT2_ALLOWANCE || mode == _MODE_PERMIT2_SIGNATURE,
            "invalid transfer mode"
        );
        extraData.commissionInfo.tokenWithMode = mode | extraData.commissionInfo.tokenWithMode;

        (address srcToken, address toToken) = UniswapTokenInfoHelper.getUniswapV3TokenInfo(msg.value > 0, pools);

        CommissionLib.validateCommissionInfo(extraData.commissionInfo, srcToken, toToken, mode);

        // Step 4: Execute the swap. If srcToken is ETH, any excess ETH will be refunded after the swap.
        uint256 fromTokenCommissionAmount;
        {
            (swapCache.payer, consumeAmount, fromTokenCommissionAmount) = _uniswapV3SwapExactOut(
                swapCache.payer,
                payable(middleReceiver),
                swapCache.amountOut,
                swapCache.maxConsume,
                mode,
                pools,
                extraData
            );
        }

        // Step 5: Handle commission from the source token if applicable.
        consumeAmount = ExactOutSwapHelper.afterSwap(
            IDexRouter.AfterSwapParams({
                commissionInfo: extraData.commissionInfo,
                consumeAmount: consumeAmount,
                targetTokenBefore: targetTokenBefore,
                srcToken: srcToken,
                toToken: toToken,
                receiver: receiver,
                payer: swapCache.payer,
                mode: mode,
                fromTokenCommissionAmount: fromTokenCommissionAmount
            })
        );

        // Step 6: Reset ethAmount to zero after the swap.
        TempStorage.setEthAmount(0);
        TempStorage.setNewPayer(address(0));
        TempStorage.setFromTokenCommissionAmount(0);
    }

    /// @notice Recursively executes an exact output swap using Uniswap V3 pools.
    /// @param payer The address paying the input tokens.
    /// @param receiver The address receiving the output tokens.
    /// @param amountOut The exact amount of output tokens to receive.
    /// @param maxConsume The maximum amount of input tokens allowed to be consumed.
    /// @param pools The array of pool data encoding the swap path and options.
    /// @return newPayer The address of the new payer.
    /// @return consumedAmount The actual amount of input tokens consumed.
    /// @return fromTokenCommissionAmount The amount of fromToken commission.
    function _uniswapV3SwapExactOut(
        address payer,
        address payable receiver,
        uint256 amountOut,
        uint256 maxConsume,
        uint256 mode,
        uint256[] calldata pools,
        IDexRouter.ExtraData memory extraData
    ) private returns (address, uint256, uint256) {
        require(pools.length > 0, "empty pools");

        {
            IDexRouter.ExtraData memory extraData_;
            extraData_.commissionInfo = extraData.commissionInfo;
            extraData_.permit2Info = extraData.permit2Info;
            (int256 amount0, int256 amount1) = _executeSwapRecursive(
                payer,
                (pools[pools.length - 1] & _WETH_UNWRAP_MASK) > 0 ? address(this) : receiver,
                amountOut,
                mode,
                pools,
                extraData_
            );
            // Guard against V3 partial fill: pick the output-side delta (amount1 when
            // zeroForOne, else amount0; it is negative), negate to uint256, and require
            // the receiver got at least amountOut.
            require(
                uint256(-((pools[pools.length - 1] & _ONE_FOR_ZERO_MASK) == 0 ? amount1 : amount0))
                    >= amountOut,
                "InsufficientOutputAmount"
            );
        }

        // If WETH needs to be unwrapped, unwrap and send ETH to the actual receiver.
        if ((pools[pools.length - 1] & _WETH_UNWRAP_MASK) > 0) {
            _unwrapWETH(amountOut, receiver);
        }
        
        // Get the actual amount of input tokens consumed and reset the state variable to save gas.
        uint256 consumedAmount = TempStorage.getAmountConsumed();
        TempStorage.setAmountConsumed(0);
        // Ensure the consumed amount does not exceed the maximum allowed.
        require(consumedAmount <= maxConsume, "ExcessiveInputAmount");
        
        return (TempStorage.getNewPayer(), consumedAmount, TempStorage.getFromTokenCommissionAmount());
    }
    
    /// @notice Recursively executes swaps through the provided Uniswap V3 pools to achieve the exact output amount.
    /// @param payer The address paying the input tokens.
    /// @param receiver The address receiving the output tokens for this swap step.
    /// @param amountOut The exact amount of output tokens to receive at this step.
    /// @param mode The mode of the token to pay.
    /// @param pools The array of pool data encoding the swap path and options.
    /// @param extraData The extra data for the swap.
    /// @return amount0 The change in token0 balance (negative for output, positive for input).
    /// @return amount1 The change in token1 balance (negative for output, positive for input).
    function _executeSwapRecursive(
        address payer,
        address receiver,
        uint256 amountOut,
        uint256 mode,
        uint256[] memory pools,
        IDexRouter.ExtraData memory extraData
    ) private returns (int256 amount0, int256 amount1) {
        // Get the last pool in the path.
        uint256 pool = pools[pools.length - 1];
        address poolAddress = address(uint160(pool & _ADDRESS_MASK));
        bool zeroForOne = (pool & _ONE_FOR_ZERO_MASK) == 0;
        // Specify the amount as a negative value to indicate exact output.
        int256 amountSpecified = -SafeCast.toInt256(amountOut);

        // Prepare callback data for the swap callback.
        // The first 32 bytes is V3_EXACT_OUT_CALLBACK_FLAG to identify this callback in DexRouter.
        bytes memory callbackData;
        if (pools.length > 1) {
            uint256[] memory remainingPools = new uint256[](pools.length - 1);
            for (uint i = 0; i < pools.length - 1; ++i) {
                remainingPools[i] = pools[i];
            }
            callbackData = abi.encodePacked(V3_EXACT_OUT_CALLBACK_FLAG, abi.encode(payer, mode, remainingPools, extraData));
        } else {
            callbackData = abi.encodePacked(V3_EXACT_OUT_CALLBACK_FLAG, abi.encode(payer, mode, new uint256[](0), extraData));
        }
        
        // Execute the swap on the current pool.
        return IUniV3(poolAddress).swap(
            receiver,
            zeroForOne,
            amountSpecified,
            zeroForOne ? _MIN_SQRT_RATIO : _MAX_SQRT_RATIO,
            callbackData
        );
    }

    /// @notice Handles the callback from Uniswap V3 pool during a swap, paying the required input tokens and continuing the swap path if needed.
    /// @param amount0Delta The change in token0 balance (positive means the contract must pay token0).
    /// @param amount1Delta The change in token1 balance (positive means the contract must pay token1).
    /// @param data Encoded callback data containing the payer and remaining pools.
    function _uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) private {
        // Validate that the caller is a legitimate Uniswap V3 pool.
        address token0 = IUniV3(msg.sender).token0();
        address token1 = IUniV3(msg.sender).token1();
        uint24 fee = IUniV3(msg.sender).fee();
        require (msg.sender == IUniswapV3Factory(_FF_FACTORY_ADDRESS).getPool(token0, token1, fee), "BadPool");
        
        // Determine which token and how much needs to be paid for this swap step.
        (address tokenToPay, uint256 amountToPay) = amount0Delta > 0 
            ? (token0, uint256(amount0Delta)) 
            : (token1, uint256(amount1Delta));
        
        // Decode the callback data to get the payer and the remaining pools.
        // Skip the first 32 bytes which is V3_EXACT_OUT_CALLBACK_FLAG.
        (address payer, uint256 mode, uint256[] memory remainingPools, IDexRouter.ExtraData memory extraData) = abi.decode(data[32:], (address, uint256, uint256[], IDexRouter.ExtraData));
        bool isLastSwap = remainingPools.length == 0;
        
        if (isLastSwap) {
            // If this is the last swap in the path, pay the required token directly from the payer.
            _handleTokenPayment(payer, msg.sender, tokenToPay, amountToPay, mode, extraData); // Gotten amountConsumed in TemStorage is zero
            TempStorage.setAmountConsumed(amountToPay);
        } else {
            // Otherwise, continue the swap recursively for the remaining pools.
            _executeSwapRecursive(
                payer,
                address(this),
                amountToPay,
                mode,
                remainingPools,
                extraData
            );
            // After the recursive swap, pay the required token from this contract.
            _handleTokenPayment(address(this), msg.sender, tokenToPay, amountToPay, mode, extraData); // Gotten amountConsumed in TemStorage is not zero
        }
        
        // Emit an event to record the swap details.
        emit Swap(tokenToPay, tokenToPay == token0 ? token1 : token0, payer, amountToPay);
    }
    
    /// @notice Handles the payment of tokens for a swap step, supporting both ETH and ERC20 tokens.
    /// @param payer The address providing the tokens.
    /// @param recipient The address receiving the tokens (usually the pool).
    /// @param token The address of the token to pay.
    /// @param amount The amount of tokens to pay.
    /// @param mode The mode of the token to pay.
    /// @param extraData The extra data for the payment.
    function _handleTokenPayment(
        address payer,
        address recipient,
        address token,
        uint256 amount,
        uint256 mode,
        IDexRouter.ExtraData memory extraData
    ) private {
        uint256 ethAmount = TempStorage.getEthAmount();
        uint256 tempAmount = TempStorage.getAmountConsumed(); // Used as a flag here to check if it is the last swap
        if (tempAmount == 0) { // Means it is the last swap
            uint256 fromTokenCommissionAmount = 0;
            (payer, amount, fromTokenCommissionAmount) = TransferLib.handlePermit2SigModeWithCommission(
                ethAmount > 0 ? (uint256(uint160(_ETH)) | mode) : (uint256(uint160(token)) | mode),
                payer,
                amount,
                recipient,
                extraData
            );
            TempStorage.setFromTokenCommissionAmount(fromTokenCommissionAmount);
            TempStorage.setNewPayer(payer);
        }

        if (ethAmount > 0) {
            // If the swap started from ETH, wrap ETH to WETH and transfer to the recipient.
            _wrapETHAndTransfer(amount, payable(recipient));
            // Reset ethAmount after use.
            TempStorage.setEthAmount(0);
        } else {
            if (payer != address(0)) {
                TransferLib.transferInternal(payer, recipient, uint256(uint160(token)) | mode, amount);
            }
        }
    }

    /// @notice Unwraps WETH to ETH and sends it to the receiver after the swap if required.
    /// @param amount The amount of WETH to unwrap.
    /// @param receiver The address to receive the unwrapped ETH.
    function _unwrapWETH(uint256 amount, address payable receiver) private {
        IWETH(_WETH).withdraw(amount);
        receiver.sendValue(amount);
    }

    /// @notice Wraps ETH into WETH and transfers it to the recipient.
    /// @param amount The amount of ETH to wrap.
    /// @param recipient The address to receive the WETH.
    function _wrapETHAndTransfer(uint256 amount, address payable recipient) private {
        IWETH(_WETH).deposit{value: amount}();
        IERC20(_WETH).transfer(recipient, amount);
    }
}