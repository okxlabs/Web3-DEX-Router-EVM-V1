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
import "./router/swapWrapRouter.sol";
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

    /// ================================ uniswapV3Callback ==============================
    /// @notice callback function for both UnxswapV3Router and UnxswapV3ExactOutRouter
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external whenNotPaused override {
        if (data.length == 0) {
            UnxswapV3Router.uniswapV3SwapCallback(amount0Delta, amount1Delta, data);
        } else {
            UnxswapV3ExactOutRouter.uniswapV3SwapCallback(amount0Delta, amount1Delta, data);
        }
    }
}