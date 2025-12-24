// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./libraries/EthReceiver.sol";
import "./libraries/PMMLib.sol";
import "./libraries/PausableModuleV2.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./interfaces/IDexRouter.sol";
import "./interfaces/IUniswapV3SwapCallback.sol";

import "./router/SmartSwapRouter.sol";
import "./router/DagRouter.sol";
import "./router/UnxswapRouter.sol";
import "./router/UnxswapV3Router.sol";
import "./router/SwapWrapRouter.sol";
import "./router/UnxswapExactOutRouter.sol";
import "./router/UnxswapV3ExactOutRouter.sol";

contract DexRouter is EthReceiver, IDexRouter, IUniswapV3SwapCallback, PausableModuleV2, ReentrancyGuard {

    string public constant version = "v1.0.9-transfer-mode";

    constructor(address _owner) PausableModuleV2(_owner) ReentrancyGuard() {}

    /// ================================ smartSwap related ================================
    function smartSwapByOrderId(
        uint256 orderId,
        BaseRequest calldata baseRequest,
        uint256[] calldata batchesAmount,
        RouterPath[][] calldata batches,
        PMMLib.PMMSwapRequest[] calldata extraData
    )
        external
        payable
        nonReentrant
        whenNotPaused
        returns (uint256 returnAmount)
    {
        return SmartSwapRouter.smartSwapTo(orderId, msg.sender, baseRequest, batchesAmount, batches, extraData);
    }

    function smartSwapTo(
        uint256 orderId,
        address receiver,
        BaseRequest calldata baseRequest,
        uint256[] calldata batchesAmount,
        RouterPath[][] calldata batches,
        PMMLib.PMMSwapRequest[] calldata extraData
    )
        external
        payable
        nonReentrant
        whenNotPaused
        returns (uint256 returnAmount)
    {
        return SmartSwapRouter.smartSwapTo(orderId, receiver, baseRequest, batchesAmount, batches, extraData);
    }

    function smartSwapByInvestWithRefund(
        BaseRequest memory baseRequest,
        uint256[] memory batchesAmount,
        RouterPath[][] memory batches,
        PMMLib.PMMSwapRequest[] memory extraData,
        address to,
        address refundTo
    )
        public
        payable
        nonReentrant
        whenNotPaused
        returns (uint256 returnAmount)
    {
        return SmartSwapRouter.smartSwapByInvestWithRefund(baseRequest, batchesAmount, batches, extraData, to, refundTo);
    }

    /// ================================ dagSwap related ================================
    function dagSwapByOrderId(
        uint256 orderId,
        BaseRequest calldata baseRequest,
        RouterPath[] calldata paths
    ) external payable nonReentrant whenNotPaused returns (uint256 returnAmount) {
        return DagRouter.dagSwapTo(orderId, msg.sender, baseRequest, paths);
    }

    function dagSwapTo(
        uint256 orderId,
        address receiver,
        BaseRequest calldata baseRequest,
        RouterPath[] calldata paths
    )
        public
        payable
        nonReentrant
        whenNotPaused
        returns (uint256 returnAmount)
    {
        return DagRouter.dagSwapTo(orderId, receiver, baseRequest, paths);
    }

    /// ============================== uniswapV3Swap related ==============================
    function uniswapV3SwapTo(
        uint256 receiver,
        uint256 amount,
        uint256 minReturn,
        uint256[] calldata pools
    ) external payable nonReentrant whenNotPaused returns (uint256 returnAmount) {
        return UnxswapV3Router.uniswapV3SwapTo(receiver, amount, minReturn, pools);
    }

    function uniswapV3SwapToWithBaseRequest(
        uint256 orderId,
        address receiver,
        BaseRequest calldata baseRequest,
        uint256[] calldata pools
    )
        external
        payable
        nonReentrant
        whenNotPaused
        returns (uint256 returnAmount)
    {
        return UnxswapV3Router.uniswapV3SwapToWithBaseRequest(orderId, receiver, baseRequest, pools);
    }

    /// ============================== unxswap related ==============================
    function unxswapByOrderId(
        uint256 srcToken,
        uint256 amount,
        uint256 minReturn,
        bytes32[] calldata pools
    ) external payable nonReentrant whenNotPaused returns (uint256 returnAmount) {
        return UnxswapRouter.unxswapTo(srcToken, amount, minReturn, msg.sender, pools);
    }

    function unxswapTo(
        uint256 srcToken,
        uint256 amount,
        uint256 minReturn,
        address receiver,
        bytes32[] calldata pools
    ) public payable nonReentrant whenNotPaused returns (uint256 returnAmount) {
        return UnxswapRouter.unxswapTo(srcToken, amount, minReturn, receiver, pools);
    }

    function unxswapToWithBaseRequest(
        uint256 orderId,
        address receiver,
        BaseRequest calldata baseRequest,
        bytes32[] calldata pools
    )
        external
        payable
        nonReentrant
        whenNotPaused
        returns (uint256 returnAmount)
    {
        return UnxswapRouter.unxswapToWithBaseRequest(orderId, receiver, baseRequest, pools);
    }

    /// ================================ swapWrap related ================================
    function swapWrap(uint256 orderId, uint256 rawdata) external payable nonReentrant whenNotPaused {
        return SwapWrapRouter.swapWrap(orderId, rawdata);
    }

    function swapWrapToWithBaseRequest(
        uint256 orderId,
        address receiver,
        BaseRequest calldata baseRequest
    )
        external
        payable
        nonReentrant
        whenNotPaused
    {
        return SwapWrapRouter.swapWrapToWithBaseRequest(orderId, receiver, baseRequest);
    }

    /// ================================ unxswapExactOut related ==============================
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
        bytes32[] calldata pools
    ) external payable nonReentrant whenNotPaused returns (uint256 consumeAmount) {
        return UnxswapExactOutRouter.unxswapExactOutTo(srcToken, amount, maxConsume, receiver, pools);
    }
    
    /// @notice Executes an exact output swap using the Unxswap protocol, including commission handling. The receiver is set to msg.sender.
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
        return UnxswapExactOutRouter.unxswapExactOutToByOrderID(srcToken, amount, maxConsume, pools);
    }

    /// ================================ uniswapV3ExactOut related ==============================
    /// @notice Executes an exact output swap using the Uniswap V3 protocol, including commission handling.
    /// @param receiver The address to receive the output tokens (encoded as uint256).
    /// @param amountOut The exact amount of output tokens to receive.
    /// @param maxConsume The maximum amount of source tokens to consume (slippage protection).
    /// @param pools The list of pool identifiers to use for the swap path.
    /// @return consumeAmount The actual amount of source tokens consumed.
    function uniswapV3SwapExactOutTo(
        uint256 receiver,
        uint256 amountOut,
        uint256 maxConsume,
        uint256[] calldata pools
    ) external payable nonReentrant whenNotPaused returns (uint256 consumeAmount) {
        return UnxswapV3ExactOutRouter.uniswapV3SwapExactOutTo(receiver, amountOut, maxConsume, pools);
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
        if (flag == V3_EXACT_IN_CALLBACK_FLAG) {
            UnxswapV3Router.uniswapV3SwapCallback(amount0Delta, amount1Delta, data);
        } else if (flag == V3_EXACT_OUT_CALLBACK_FLAG) {
            UnxswapV3ExactOutRouter.uniswapV3SwapCallback(amount0Delta, amount1Delta, data);
        } else {
            revert("Unknown V3 callback flag");
        }
    }
}