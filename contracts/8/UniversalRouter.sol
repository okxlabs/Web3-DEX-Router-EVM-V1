// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./interfaces/IDexRouter.sol";
import "./interfaces/IUniswapV3SwapCallback.sol";
import "./libraries/EthReceiver.sol";
import "./libraries/PMMLib.sol";
import "./libraries/PausableModuleV2.sol";

contract UniversalRouter is EthReceiver, IDexRouter, IUniswapV3SwapCallback, PausableModuleV2 {

    string public constant version = "v1.0.9-transfer-mode";

    address public immutable dexRouter;
    address public immutable dexRouterLegacy;

    constructor(address _owner, address _dexRouter, address _dexRouterLegacy) PausableModuleV2(_owner) {
        dexRouter = _dexRouter;
        dexRouterLegacy = _dexRouterLegacy;
    }

    /// ================================ smartSwap related ================================
    function smartSwapByOrderId(
        uint256 orderId,
        BaseRequest calldata baseRequest,
        uint256[] calldata batchesAmount,
        RouterPath[][] calldata batches,
        PMMLib.PMMSwapRequest[] calldata // extraData
    )
        external
        payable
        whenNotPaused()
        returns (uint256 returnAmount)
    {
        return abi.decode(_delegatecall(dexRouterLegacy), (uint256));
    }

    function smartSwapTo(
        uint256 orderId,
        address receiver,
        BaseRequest calldata baseRequest,
        uint256[] calldata batchesAmount,
        RouterPath[][] calldata batches,
        PMMLib.PMMSwapRequest[] calldata // extraData
    )
        external
        payable
        whenNotPaused()
        returns (uint256 returnAmount)
    {
        return abi.decode(_delegatecall(dexRouterLegacy), (uint256));
    }

    function smartSwapByInvestWithRefund(
        BaseRequest memory baseRequest,
        uint256[] memory batchesAmount,
        RouterPath[][] memory batches,
        PMMLib.PMMSwapRequest[] memory, // extraData
        address to,
        address refundTo
    )
        public
        payable
        whenNotPaused()
        returns (uint256 returnAmount)
    {
        return abi.decode(_delegatecall(dexRouterLegacy), (uint256));
    }

    /// ============================== uniswapV3Swap related ==============================
    function uniswapV3SwapTo(
        uint256 receiver,
        uint256 amount,
        uint256 minReturn,
        uint256[] calldata pools
    ) external payable whenNotPaused() returns (uint256 returnAmount) {
        return abi.decode(_delegatecall(dexRouter), (uint256));
    }

    function uniswapV3SwapToWithBaseRequest(
        uint256 orderId,
        address receiver,
        BaseRequest calldata baseRequest,
        uint256[] calldata pools
    )
        external
        payable
        whenNotPaused()
        returns (uint256 returnAmount)
    {
        return abi.decode(_delegatecall(dexRouter), (uint256));
    }

    /// @notice Uniswap V3 swap callback function
    /// @dev This callback intentionally does NOT have the whenNotPaused modifier because:
    ///      1. This is a callback function invoked by Uniswap V3 pools during an ongoing swap
    ///      2. Users cannot directly initiate swaps through this function
    ///      3. When paused, users cannot call entry functions (uniswapV3SwapTo, etc.),
    ///         so no new swaps can be initiated that would trigger this callback
    ///      4. The callback must complete for any in-flight swap to succeed
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external override {
        _delegatecall(dexRouter);
    }

    /// ============================== unxswap related ==============================
    function unxswapByOrderId(
        uint256 srcToken,
        uint256 amount,
        uint256 minReturn,
        bytes32[] calldata pools
    ) external payable whenNotPaused() returns (uint256 returnAmount) {
        return abi.decode(_delegatecall(dexRouter), (uint256));
    }

    function unxswapTo(
        uint256 srcToken,
        uint256 amount,
        uint256 minReturn,
        address receiver,
        bytes32[] calldata pools
    ) public payable whenNotPaused() returns (uint256 returnAmount) {
        return abi.decode(_delegatecall(dexRouter), (uint256));
    }

    function unxswapToWithBaseRequest(
        uint256 orderId,
        address receiver,
        BaseRequest calldata baseRequest,
        bytes32[] calldata pools
    )
        external
        payable
        whenNotPaused()
        returns (uint256 returnAmount)
    {
        return abi.decode(_delegatecall(dexRouter), (uint256));
    }

    /// ================================ swapWrap related ================================
    function swapWrap(uint256 orderId, uint256 rawdata) external payable whenNotPaused() {
        _delegatecall(dexRouterLegacy);
    }

    function swapWrapToWithBaseRequest(
        uint256 orderId,
        address receiver,
        BaseRequest calldata baseRequest
    )
        external
        payable
        whenNotPaused()
    {
        _delegatecall(dexRouterLegacy);
    }

    /// ================================ dagSwap related ================================
    function dagSwapByOrderId(
        uint256 orderId,
        BaseRequest calldata baseRequest,
        RouterPath[] calldata paths
    ) external payable whenNotPaused() returns (uint256 returnAmount) {
        return abi.decode(_delegatecall(dexRouter), (uint256));
    }

    function dagSwapTo(
        uint256 orderId,
        address receiver,
        BaseRequest calldata baseRequest,
        RouterPath[] calldata paths
    )
        public
        payable
        whenNotPaused()
        returns (uint256 returnAmount)
    {
        return abi.decode(_delegatecall(dexRouter), (uint256));
    }

    /// ================================ internal functions ================================
    function _delegatecall(address target) internal returns (bytes memory) {
        (bool success, bytes memory result) = target.delegatecall(msg.data);
        if (!success) {
            _revert(result);
        }
        return result;
    }

    /**
     * @dev Reverts with returndata if present. Otherwise reverts with custom string.
     * https://github.com/OpenZeppelin/openzeppelin-contracts/blob/c64a1edb67b6e3f4a15cca8909c9482ad33a02b0/contracts/utils/Address.sol#L135-L149
     */
    function _revert(bytes memory returndata) internal pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            assembly ("memory-safe") {
                revert(add(returndata, 0x20), mload(returndata))
            }
        } else {
            revert("router call failed");
        }
    }
}