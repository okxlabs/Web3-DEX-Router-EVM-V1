// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./libraries/EthReceiver.sol";
import "./libraries/PausableModuleV2.sol";
import "./libraries/ExtraDataLib.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./interfaces/IDexRouter.sol";
import "./interfaces/IUniswapV3SwapCallback.sol";

import "./router/UnxswapExactOutRouter.sol";
import "./router/UnxswapV3ExactOutRouter.sol";

contract DexRouterExactOut is EthReceiver, IDexRouter, IUniswapV3SwapCallback, PausableModuleV2, ReentrancyGuard {

    string public constant version = "v1.0.9-multi-funding-mode";

    constructor(address _owner) PausableModuleV2(_owner) ReentrancyGuard() {}

    /// ================================ unxswapExactOut related ==============================
    /// @notice Executes an exact output swap using the Unxswap protocol, including commission handling.
    ///         The srcToken can be 0xEeee or address(0) for ETH.
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
        bytes32[] calldata pools
    ) external payable nonReentrant whenNotPaused returns (uint256 consumeAmount) {
        uint256 swapDataLength = 4 + abi.encode(srcToken, amount, maxConsume, receiver, pools).length;
        IDexRouter.ExtraData memory extraData = ExtraDataLib.getDecodedExtraData(swapDataLength);
        return UnxswapExactOutRouter.unxswapExactOutTo(srcToken, amount, maxConsume, receiver, pools, extraData);
    }
    
    /// @notice Executes an exact output swap using the Unxswap protocol, including commission handling. The receiver is set to msg.sender.
    ///         The srcToken can be 0xEeee or address(0) for ETH.
    /// @param srcToken The source token as a uint256 (address encoded with order ID mask).
    /// @param amount The target output amount to receive.
    /// @param maxConsume The maximum amount of source tokens to consume (slippage protection).
    /// @param pools The list of pool identifiers to use for the swap path.
    /// @return consumeAmount The actual amount of source tokens consumed, including commission.
    function unxswapExactOutToByOrderId(
        uint256 srcToken,
        uint256 amount,
        uint256 maxConsume,
        bytes32[] calldata pools
    ) external payable nonReentrant whenNotPaused returns (uint256 consumeAmount) {
        uint256 swapDataLength = 4 + abi.encode(srcToken, amount, maxConsume, pools).length;
        IDexRouter.ExtraData memory extraData = ExtraDataLib.getDecodedExtraData(swapDataLength);
        return UnxswapExactOutRouter.unxswapExactOutToByOrderID(srcToken, amount, maxConsume, pools, extraData);
    }

    /// ================================ uniswapV3ExactOut related ==============================
    /// @notice Executes an exact output swap using the Uniswap V3 protocol, including commission handling.
    /// @param receiver The address to receive the output tokens (encoded as uint256 with order ID mask).
    /// @param amountOut The exact amount of output tokens to receive.
    /// @param maxConsume The maximum amount of source tokens to consume (slippage protection).
    /// @param pools The list of pool identifiers to use for the swap path.
    /// @return consumeAmount The actual amount of source tokens consumed, including commission.
    function uniswapV3SwapExactOutTo(
        uint256 receiver,
        uint256 amountOut,
        uint256 maxConsume,
        uint256[] calldata pools
    ) external payable nonReentrant whenNotPaused returns (uint256 consumeAmount) {
        uint256 swapDataLength = 4 + abi.encode(receiver, amountOut, maxConsume, pools).length;
        IDexRouter.ExtraData memory extraData = ExtraDataLib.getDecodedExtraData(swapDataLength);
        return UnxswapV3ExactOutRouter.uniswapV3SwapExactOutTo(receiver, amountOut, maxConsume, pools, extraData);
    }

    /// ================================ uniswapV3Callback ==============================
    /// @notice callback function for both UnxswapV3Router and UnxswapV3ExactOutRouter
    /// @dev The first 32 bytes of data is a flag to identify which router to call
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external whenNotPaused override {
        require(data.length >= 32, "Invalid callback data");
        bytes32 flag = bytes32(data[:32]);
        if (flag == V3_EXACT_OUT_CALLBACK_FLAG) {
            UnxswapV3ExactOutRouter.uniswapV3SwapCallback(amount0Delta, amount1Delta, data);
        } else {
            revert("Unknown V3 callback flag");
        }
    }
}