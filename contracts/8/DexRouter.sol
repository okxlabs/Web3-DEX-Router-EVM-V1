// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./libraries/EthReceiver.sol";
import "./libraries/PMMLib.sol";
import "./libraries/PausableModuleV2.sol";
import "./libraries/ExtraDataLib.sol";
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
    /// @notice Executes a smart swap directly to a specified receiver address.
    /// @param orderId Unique identifier for the swap order, facilitating tracking.
    /// @param baseRequest Contains essential parameters for the swap such as source and destination tokens, amounts, and deadline.
    /// @param batchesAmount Array indicating amounts for each batch in the swap, allowing for split operations.
    /// @param batches Detailed routing information for executing the swap across different paths or protocols.
    /// @param pmmRequests PMM swap requests (currently used only for calldata length calculation, not for swap logic).
    /// @return returnAmount The total amount of destination tokens received from the swap.
    function smartSwapByOrderId(
        uint256 orderId,
        BaseRequest calldata baseRequest,
        uint256[] calldata batchesAmount,
        RouterPath[][] calldata batches,
        PMMLib.PMMSwapRequest[] calldata pmmRequests
    )
        external
        payable
        nonReentrant
        whenNotPaused
        returns (uint256 returnAmount)
    {
        uint256 swapDataLength = 4 + abi.encode(orderId, baseRequest, batchesAmount, batches, pmmRequests).length;
        IDexRouter.ExtraData memory extraData = ExtraDataLib.getDecodedExtraData(swapDataLength);
        return SmartSwapRouter.smartSwapTo(orderId, msg.sender, baseRequest, batchesAmount, batches, extraData);
    }

    /// @notice Executes a smart swap directly to a specified receiver address.
    /// @param orderId Unique identifier for the swap order, facilitating tracking.
    /// @param receiver Address to receive the output tokens from the swap.
    /// @param baseRequest Contains essential parameters for the swap such as source and destination tokens, amounts, and deadline.
    /// @param batchesAmount Array indicating amounts for each batch in the swap, allowing for split operations.
    /// @param batches Detailed routing information for executing the swap across different paths or protocols.
    /// @param pmmRequests PMM swap requests (currently used only for calldata length calculation, not for swap logic).
    /// @return returnAmount The total amount of destination tokens received from the swap.
    function smartSwapTo(
        uint256 orderId,
        address receiver,
        BaseRequest calldata baseRequest,
        uint256[] calldata batchesAmount,
        RouterPath[][] calldata batches,
        PMMLib.PMMSwapRequest[] calldata pmmRequests
    )
        external
        payable
        nonReentrant
        whenNotPaused
        returns (uint256 returnAmount)
    {
        uint256 swapDataLength = 4 + abi.encode(orderId, receiver, baseRequest, batchesAmount, batches, pmmRequests).length;
        IDexRouter.ExtraData memory extraData = ExtraDataLib.getDecodedExtraData(swapDataLength);
        return SmartSwapRouter.smartSwapTo(orderId, receiver, baseRequest, batchesAmount, batches, extraData);
    }

    /// ================================ dagSwap related ================================
    /// @notice Executes a DAG swap to a specified receiver using structured base request parameters.
    /// @param orderId Unique identifier for the swap order, facilitating tracking and reference.
    /// @param baseRequest Struct containing essential swap parameters including source token, destination token, amount, minimum return, and deadline.
    /// @param paths An array of RouterPath structs defining the DAG swap route.
    /// @return returnAmount The total amount of destination tokens received from the swap.
    function dagSwapByOrderId(
        uint256 orderId,
        BaseRequest calldata baseRequest,
        RouterPath[] calldata paths
    ) external payable nonReentrant whenNotPaused returns (uint256 returnAmount) {
        uint256 swapDataLength = 4 + abi.encode(orderId, baseRequest, paths).length;
        IDexRouter.ExtraData memory extraData = ExtraDataLib.getDecodedExtraData(swapDataLength);
        return DagRouter.dagSwapTo(orderId, msg.sender, baseRequest, paths, extraData);
    }

    /// @notice Executes a DAG swap to a specified receiver using structured base request parameters.
    /// @param orderId Unique identifier for the swap order, facilitating tracking and reference.
    /// @param receiver The address that will receive the swapped tokens.
    /// @param baseRequest Struct containing essential swap parameters including source token, destination token, amount, minimum return, and deadline.
    /// @param paths An array of RouterPath structs defining the DAG swap route.
    /// @return returnAmount The total amount of destination tokens received from the swap.
    function dagSwapTo(
        uint256 orderId,
        address receiver,
        BaseRequest calldata baseRequest,
        RouterPath[] calldata paths
    )
        external
        payable
        nonReentrant
        whenNotPaused
        returns (uint256 returnAmount)
    {
        uint256 swapDataLength = 4 + abi.encode(orderId, receiver, baseRequest, paths).length;
        IDexRouter.ExtraData memory extraData = ExtraDataLib.getDecodedExtraData(swapDataLength);
        return DagRouter.dagSwapTo(orderId, receiver, baseRequest, paths, extraData);
    }

    /// ============================== uniswapV3Swap related ==============================
    /// @notice Executes a swap using the Uniswap V3 protocol.
    /// @param receiver The address that will receive the swap funds (encoded as uint256 with order ID mask).
    /// @param amount The amount of the source token to be swapped.
    /// @param minReturn The minimum acceptable amount of tokens to receive from the swap, guarding against excessive slippage.
    /// @param pools An array of pool identifiers used to define the swap route within Uniswap V3.
    /// @return returnAmount The amount of tokens received after the completion of the swap.
    function uniswapV3SwapTo(
        uint256 receiver,
        uint256 amount,
        uint256 minReturn,
        uint256[] calldata pools
    ) external payable nonReentrant whenNotPaused returns (uint256 returnAmount) {
        uint256 swapDataLength = 4 + abi.encode(receiver, amount, minReturn, pools).length;
        IDexRouter.ExtraData memory extraData = ExtraDataLib.getDecodedExtraData(swapDataLength);
        return UnxswapV3Router.uniswapV3SwapTo(receiver, amount, minReturn, pools, extraData);
    }

    /// @notice Executes a Uniswap V3 token swap to a specified receiver using structured base request parameters. For uniswapV3, if fromToken or toToken is ETH, the address needs to be 0xEeee.
    /// @param orderId Unique identifier for the swap order, facilitating tracking and reference.
    /// @param receiver The address that will receive the swapped tokens.
    /// @param baseRequest Struct containing essential swap parameters including source token, destination token, amount, minimum return, and deadline.
    /// @param pools An array of pool identifiers defining the Uniswap V3 swap route, with encoded swap direction and unwrap flags.
    /// @return returnAmount The total amount of destination tokens received from the swap.
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
        uint256 swapDataLength = 4 + abi.encode(orderId, receiver, baseRequest, pools).length;
        IDexRouter.ExtraData memory extraData = ExtraDataLib.getDecodedExtraData(swapDataLength);
        return UnxswapV3Router.uniswapV3SwapToWithBaseRequest(orderId, receiver, baseRequest, pools, extraData);
    }

    /// ============================== unxswap related ==============================
    /// @notice Executes a token swap using the Unxswap protocol, sending the output directly to a specified receiver.
    ///         The srcToken can be 0xEeee or address(0) for temporary use, the address(0) usage will removed in the future.
    /// @param srcToken The source token to be swapped.
    /// @param amount The amount of the source token to be swapped.
    /// @param minReturn The minimum amount of destination tokens expected from the swap, ensuring the trade does not proceed under unfavorable conditions.
    /// @param pools An array of pool identifiers to specify the swap route, optimizing for best rates.
    /// @return returnAmount The total amount of destination tokens received from the swap.
    function unxswapByOrderId(
        uint256 srcToken,
        uint256 amount,
        uint256 minReturn,
        bytes32[] calldata pools
    ) external payable nonReentrant whenNotPaused returns (uint256 returnAmount) {
        uint256 swapDataLength = 4 + abi.encode(srcToken, amount, minReturn, pools).length;
        IDexRouter.ExtraData memory extraData = ExtraDataLib.getDecodedExtraData(swapDataLength);
        return UnxswapRouter.unxswapTo(srcToken, amount, minReturn, msg.sender, pools, extraData);
    }

    /// @notice Executes a token swap using the Unxswap protocol, sending the output directly to a specified receiver.
    ///         The srcToken can be 0xEeee or address(0) for temporary use, the address(0) usage will removed in the future.
    /// @param srcToken The source token to be swapped.
    /// @param amount The amount of the source token to be swapped.
    /// @param minReturn The minimum amount of destination tokens expected from the swap, ensuring the trade does not proceed under unfavorable conditions.
    /// @param receiver The address where the swapped tokens will be sent.
    /// @param pools An array of pool identifiers to specify the swap route, optimizing for best rates.
    /// @return returnAmount The total amount of destination tokens received from the swap.
    function unxswapTo(
        uint256 srcToken,
        uint256 amount,
        uint256 minReturn,
        address receiver,
        bytes32[] calldata pools
    ) external payable nonReentrant whenNotPaused returns (uint256 returnAmount) {
        uint256 swapDataLength = 4 + abi.encode(srcToken, amount, minReturn, receiver, pools).length;
        IDexRouter.ExtraData memory extraData = ExtraDataLib.getDecodedExtraData(swapDataLength);
        return UnxswapRouter.unxswapTo(srcToken, amount, minReturn, receiver, pools, extraData);
    }

    /// @notice Executes a Unxswap token swap to a specified receiver using structured base request parameters. For unxswap, if fromToken or toToken is ETH, the address can be 0xEeee or address(0) for temporary use, the address(0) usage will removed in the future.
    /// @param orderId Unique identifier for the swap order, facilitating tracking and reference.
    /// @param receiver The address that will receive the swapped tokens.
    /// @param baseRequest Struct containing essential swap parameters including source token, destination token, amount, minimum return, and deadline.
    /// @param pools An array of pool identifiers defining the Unxswap route, with encoded swap direction and WETH unwrap flags.
    /// @return returnAmount The total amount of destination tokens received from the swap.
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
        uint256 swapDataLength = 4 + abi.encode(orderId, receiver, baseRequest, pools).length;
        IDexRouter.ExtraData memory extraData = ExtraDataLib.getDecodedExtraData(swapDataLength);
        return UnxswapRouter.unxswapToWithBaseRequest(orderId, receiver, baseRequest, pools, extraData);
    }

    /// ================================ swapWrap related ================================
    /// @notice Executes a simple swap between ETH and WETH using encoded parameters.
    /// @param orderId Unique identifier for the swap order, facilitating tracking and reference.
    /// @param rawdata Encoded data containing swap direction, transfer mode and amount information using bit masks.
    /// @dev This function supports bidirectional swaps between ETH and WETH with minimal gas overhead.
    /// The rawdata parameter encodes:
    /// - Transfer mode in bits [251:249], direction (reversed flag) in bit 255: false=ETH->WETH, true=WETH->ETH
    function swapWrap(uint256 orderId, uint256 rawdata) external payable nonReentrant whenNotPaused {
        uint256 swapDataLength = 4 + abi.encode(orderId, rawdata).length;
        IDexRouter.ExtraData memory extraData = ExtraDataLib.getDecodedExtraData(swapDataLength);
        return SwapWrapRouter.swapWrap(orderId, rawdata, extraData);
    }

    /// @notice Executes a swap between ETH and WETH using structured base request parameters to a specified receiver.
    /// @param orderId Unique identifier for the swap order, facilitating tracking and reference.
    /// @param receiver The address that will receive the swapped tokens.
    /// @param baseRequest Struct containing essential swap parameters including source token (with mode in high bits [251:249]), destination token, amount, minimum return, and deadline.
    /// @dev This function validates that the token pair is either ETH->WETH or WETH->ETH and executes the swap accordingly.
    /// It extracts the amount and mode from the baseRequest and determines the swap direction based on the token addresses.
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
        uint256 swapDataLength = 4 + abi.encode(orderId, receiver, baseRequest).length;
        IDexRouter.ExtraData memory extraData = ExtraDataLib.getDecodedExtraData(swapDataLength);
        return SwapWrapRouter.swapWrapToWithBaseRequest(orderId, receiver, baseRequest, extraData);
    }

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
        if (flag == V3_EXACT_IN_CALLBACK_FLAG) {
            UnxswapV3Router.uniswapV3SwapCallback(amount0Delta, amount1Delta, data);
        } else if (flag == V3_EXACT_OUT_CALLBACK_FLAG) {
            UnxswapV3ExactOutRouter.uniswapV3SwapCallback(amount0Delta, amount1Delta, data);
        } else {
            revert("Unknown V3 callback flag");
        }
    }
}