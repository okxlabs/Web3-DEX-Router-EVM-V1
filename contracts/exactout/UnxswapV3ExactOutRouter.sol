/// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./interfaces/IUniswapV3SwapCallback.sol";
import "./interfaces/IUniV3.sol";
import "./interfaces/uniV3/IUniswapV3Factory.sol";
import "./interfaces/IWETH.sol";
import "./interfaces/IWNativeRelayer.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IApproveProxy.sol";
import "./libraries/Address.sol";
import "./libraries/CommonUtils.sol";
import "./libraries/RouterErrors.sol";
import "./libraries/SafeCast.sol";
import "./libraries/TempStorage.sol";
contract UnxswapV3ExactOutRouter is IUniswapV3SwapCallback, CommonUtils {
    using Address for address payable;

    event Swap(
        address indexed srcToken,
        address indexed dstToken,
        address indexed payer,
        uint256 amount
    );

    uint256 internal constant _ONE_FOR_ZERO_MASK = 1 << 255; // Mask for identifying if the swap is one-for-zero
    uint256 private constant _WETH_UNWRAP_MASK = 1 << 253; // Mask for identifying if WETH should be unwrapped to ETH
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
    
    /// @notice Recursively executes an exact output swap using Uniswap V3 pools.
    /// @param payer The address paying the input tokens.
    /// @param receiver The address receiving the output tokens.
    /// @param amountOut The exact amount of output tokens to receive.
    /// @param maxConsume The maximum amount of input tokens allowed to be consumed.
    /// @param pools The array of pool data encoding the swap path and options.
    /// @return consumedAmount The actual amount of input tokens consumed.
    function _uniswapV3SwapExactOut(
        address payer,
        address payable receiver,
        uint256 amountOut,
        uint256 maxConsume,
        uint256[] calldata pools
    ) internal returns (uint256 consumedAmount) {
        require(pools.length > 0, "empty pools");

        // Get the last pool in the path and check if WETH should be unwrapped to ETH after the swap.
        uint256 lastPool = pools[pools.length - 1];
        bool unwrapWeth = (lastPool & _WETH_UNWRAP_MASK) > 0;
        // If WETH needs to be unwrapped, set the receiver to this contract temporarily.
        address middleReceiver = unwrapWeth ? address(this) : receiver;
        
        // Start the recursive swap process.
        _executeSwapRecursive(
            payer,
            middleReceiver,
            amountOut,
            pools
        );
        
        // If WETH needs to be unwrapped, unwrap and send ETH to the actual receiver.
        if (unwrapWeth) {
            _unwrapWETH(amountOut, receiver);
        }
        
        // Get the actual amount of input tokens consumed and reset the state variable to save gas.
        consumedAmount = TempStorage.getAmountConsumed();
        TempStorage.setAmountConsumed(0);
        // Ensure the consumed amount does not exceed the maximum allowed.
        require(consumedAmount <= maxConsume, "ExcessiveInputAmount");
        
        return consumedAmount;
    }
    
    /// @notice Recursively executes swaps through the provided Uniswap V3 pools to achieve the exact output amount.
    /// @param payer The address paying the input tokens.
    /// @param receiver The address receiving the output tokens for this swap step.
    /// @param amountOut The exact amount of output tokens to receive at this step.
    /// @param pools The array of pool data encoding the swap path and options.
    /// @return amount0 The change in token0 balance (negative for output, positive for input).
    /// @return amount1 The change in token1 balance (negative for output, positive for input).
    function _executeSwapRecursive(
        address payer,
        address receiver,
        uint256 amountOut,
        uint256[] memory pools
    ) private returns (int256 amount0, int256 amount1) {
        // Get the last pool in the path.
        uint256 pool = pools[pools.length - 1];
        address poolAddress = address(uint160(pool & _ADDRESS_MASK));
        bool zeroForOne = (pool & _ONE_FOR_ZERO_MASK) == 0;
        // Specify the amount as a negative value to indicate exact output.
        int256 amountSpecified = -SafeCast.toInt256(amountOut);

        // Prepare callback data for the swap callback.
        bytes memory callbackData;
        if (pools.length > 1) {
            uint256[] memory remainingPools = new uint256[](pools.length - 1);
            for (uint i = 0; i < pools.length - 1; i++) {
                remainingPools[i] = pools[i];
            }
            callbackData = abi.encode(payer, remainingPools);
        } else {
            callbackData = abi.encode(payer, new uint256[](0));
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

    /// @inheritdoc IUniswapV3SwapCallback
    /// @notice Handles the callback from Uniswap V3 pool during a swap, paying the required input tokens and continuing the swap path if needed.
    /// @param amount0Delta The change in token0 balance (positive means the contract must pay token0).
    /// @param amount1Delta The change in token1 balance (positive means the contract must pay token1).
    /// @param data Encoded callback data containing the payer and remaining pools.
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external override {
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
        (address payer, uint256[] memory remainingPools) = abi.decode(data, (address, uint256[]));
        bool isLastSwap = remainingPools.length == 0;
        
        if (isLastSwap) {
            // If this is the last swap in the path, pay the required token directly from the payer.
            _handleTokenPayment(payer, msg.sender, tokenToPay, amountToPay);
            TempStorage.setAmountConsumed(amountToPay);
        } else {
            // Otherwise, continue the swap recursively for the remaining pools.
            _executeSwapRecursive(
                payer,
                address(this),
                amountToPay,
                remainingPools
            );
            // After the recursive swap, pay the required token from this contract.
            _handleTokenPayment(address(this), msg.sender, tokenToPay, amountToPay);
        }
        
        // Emit an event to record the swap details.
        emit Swap(tokenToPay, tokenToPay == token0 ? token1 : token0, payer, amountToPay);
    }
    
    /// @notice Handles the payment of tokens for a swap step, supporting both ETH and ERC20 tokens.
    /// @param payer The address providing the tokens.
    /// @param recipient The address receiving the tokens (usually the pool).
    /// @param token The address of the token to pay.
    /// @param amount The amount of tokens to pay.
    function _handleTokenPayment(
        address payer,
        address recipient,
        address token,
        uint256 amount
    ) private {
        if (TempStorage.getEthAmount() > 0) {
            // If the swap started from ETH, wrap ETH to WETH and transfer to the recipient.
            _wrapETHAndTransfer(amount, payable(recipient));
            // Reset ethAmount after use.
            TempStorage.setEthAmount(0);
        } else {
            if (payer == address(this)) {
                IERC20(token).transfer(recipient, amount);
            } else {
                IApproveProxy(_APPROVE_PROXY).claimTokens(token, payer, recipient, amount);
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

