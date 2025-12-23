/// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../libraries/Constants.sol";
import "../libraries/EventLib.sol";
import "../libraries/CommonLib.sol";
import "../libraries/ExtraDataLib.sol";
import "../libraries/CommissionLib.sol";
import "../libraries/TransferLib.sol";
import "../interfaces/IDexRouter.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/IWETH.sol";

library DagRouter {
    /// @notice Core DAG algorithm data structure
    /// @dev Maintains the state of the DAG during execution
    struct SwapState {
        /// @notice the number of nodes need to be processed
        uint256 nodeNum;
        /// @notice the refundTo address of the DAG
        address refundTo;
    }

    // ================================================================================
    // ============================== Public Functions ================================
    // ================================================================================
    /// @notice Executes a DAG swap to a specified receiver using structured base request parameters.
    /// @param orderId Unique identifier for the swap order, facilitating tracking and reference.
    /// @param receiver The address that will receive the swapped tokens.
    /// @param baseRequest Struct containing essential swap parameters including source token, destination token, amount, minimum return, and deadline.
    /// @param paths An array of RouterPath structs defining the DAG swap route.
    /// @return returnAmount The total amount of destination tokens received from the swap.
    /// @dev This function validates token compatibility with the provided pool route and ensures proper swap execution.
    function dagSwapTo(
        uint256 orderId,
        address receiver,
        IDexRouter.BaseRequest memory baseRequest,
        IDexRouter.RouterPath[] calldata paths
    )
        public
        returns (uint256 returnAmount)
    {
        CommonLib.validateDeadline(baseRequest.deadLine);
        require(paths.length > 0, "paths must be > 0");
        EventLib.emitSwapOrderId(orderId);

        receiver = receiver == address(0) ? msg.sender : receiver;

        IDexRouter.ExtraData memory extraData = ExtraDataLib.getDecodedExtraData();
        
        uint256 mode = paths[0].fromToken & _TRANSFER_MODE_MASK;
        
        CommissionLib.validateCommissionInfo(extraData.commissionInfo, CommonLib.bytes32ToAddress(baseRequest.fromToken), baseRequest.toToken, mode);
        extraData.commissionInfo.tokenWithMode = mode | extraData.commissionInfo.tokenWithMode;

        returnAmount = CommonLib.getBalanceOf(baseRequest.toToken, receiver);

        IDexRouter.SwapParams memory swapParams = IDexRouter.SwapParams({
            payer: msg.sender,
            refundTo: msg.sender,
            receiver: receiver,
            toToken: baseRequest.toToken
        });

        uint256 fromTokenCommissionAmount;
        {
            address onlyOneAssetTo = paths[0].assetTo.length == 1 ? paths[0].assetTo[0] : address(0);
            (
                swapParams.payer,
                baseRequest.fromTokenAmount,
                fromTokenCommissionAmount
            ) = TransferLib.handlePermit2SignatureModeWithCommission(
                paths[0].fromToken,
                swapParams.payer,
                baseRequest.fromTokenAmount,
                onlyOneAssetTo,
                extraData
            );
        }

        {
            uint256 balanceBefore;
            (
                swapParams.receiver,
                balanceBefore
            ) = CommissionLib.doCommissionFromToken(
                    extraData.commissionInfo,
                    swapParams,
                    fromTokenCommissionAmount,
                    extraData.trimInfo.hasTrim
                );

            _dagSwapInternal(
                baseRequest,
                paths,
                swapParams
            );

            CommissionLib.doCommissionAndTrimToToken(
                extraData.commissionInfo,
                receiver,
                balanceBefore,
                baseRequest.toToken,
                extraData.trimInfo
            );
        }

        // check minReturnAmount
        returnAmount =
            CommonLib.getBalanceOf(baseRequest.toToken, receiver) -
            returnAmount;
        require(
            returnAmount >= baseRequest.minReturnAmount,
            "Min return not reached"
        );

        EventLib.emitOrderRecord(
            CommonLib.bytes32ToAddress(baseRequest.fromToken),
            baseRequest.toToken,
            tx.origin,
            baseRequest.fromTokenAmount,
            returnAmount
        );
    }

    // ================================================================================
    // ============================== Private Functions ===============================
    // ================================================================================
    /// @notice The fromTokenAmount will not must be greater than 0, cause for some protocols the fromTokenAmount needs to be 0 to skip token transfer like fourmeme. 
    function _dagSwapInternal(
        IDexRouter.BaseRequest memory baseRequest,
        IDexRouter.RouterPath[] calldata paths,
        IDexRouter.SwapParams memory swapParams
    ) private {
        // 1. check and process ETH
        address fromToken = CommonLib.bytes32ToAddress(baseRequest.fromToken);

        address firstNodeToken = CommonLib.bytes32ToAddress(paths[0].fromToken);

        // In order to deal with ETH/WETH transfer rules in a unified manner,
        // we do not need to judge according to fromToken.
        if (fromToken == _ETH) {
            require(firstNodeToken == _WETH, "firstToken mismatch");
            IWETH(_WETH).deposit{
                value: baseRequest.fromTokenAmount
            }();
            swapParams.payer = address(this);
        } else {
            require(firstNodeToken == fromToken, "firstToken mismatch");
            require(msg.value == 0, "value must be 0");
        }

        // 2. execute dag swap
        _exeDagSwap(swapParams.payer, swapParams.receiver, swapParams.refundTo, baseRequest.fromTokenAmount, baseRequest.toToken == _ETH, paths);

        // 3. transfer tokens to receiver
        CommonLib.transferTokenToUser(baseRequest.toToken, swapParams.receiver);
    }

    /// @notice The core logic to execute the DAG swap. For the first node, the payer should use passed value.
    /// For the non-first node, the payer should always be address(this) cause the to address of the middle swap is address(this).
    function _exeDagSwap(
        address payer,
        address receiver,
        address refundTo,
        uint256 firstNodeBalance,
        bool isToNative,
        IDexRouter.RouterPath[] calldata paths
    ) private {
        uint256 nodeNum = paths.length;
        SwapState memory swapState = _initSwapState(nodeNum, refundTo);

        // execute nodes
        for (uint256 i = 0; i < nodeNum;) {
            if (i != 0) { // reset payer for non-first node
                payer = address(this);
            }

            _exeNode(payer, receiver, firstNodeBalance, i, isToNative, paths[i], swapState);

            unchecked {
                ++i;
            }
        }
    }

    /// @notice Initialize the swap state for the DAG execution
    function _initSwapState(
        uint256 _nodeNum,
        address _refundTo
    ) private pure returns (SwapState memory state) {
        state.nodeNum = _nodeNum;
        state.refundTo = _refundTo;
    }

    /// @notice The core logic to execute the each node
    function _exeNode(
        address payer,
        address receiver,
        uint256 nodeBalance,
        uint256 nodeIndex,
        bool isToNative,
        IDexRouter.RouterPath calldata path,
        SwapState memory swapState
    ) private {
        uint256 totalWeight;
        uint256 accAmount;
        address fromToken = CommonLib.bytes32ToAddress(path.fromToken);

        require(path.mixAdapters.length > 0, "edge length must be > 0");
        require(
            path.mixAdapters.length == path.rawData.length &&
            path.mixAdapters.length == path.extraData.length &&
            path.mixAdapters.length == path.assetTo.length,
            "path length mismatch"
        );

        // to get the nodeBalance for non-first node, the balance of the first node is the original passed value
        if (nodeIndex != 0) {
            nodeBalance = CommonLib.getBalanceOf(fromToken, address(this));
            require(nodeBalance > 0, "node balance must be > 0");
        }

        // execute edges
        for (uint256 i = 0; i < path.mixAdapters.length;) {
            uint256 inputIndex;
            uint256 outputIndex;
            uint256 weight;

            // 1. get inputIndex, outputIndex, weight and verify
            {
                bytes32 rawData = bytes32(path.rawData[i]);
                assembly {
                    weight := shr(160, and(rawData, _WEIGHT_MASK))
                    inputIndex := shr(184, and(rawData, _INPUT_INDEX_MASK))
                    outputIndex := shr(176, and(rawData, _OUTPUT_INDEX_MASK))
                }

                require(inputIndex == nodeIndex, "node inputIndex inconsistent");
                require(inputIndex < outputIndex && outputIndex <= swapState.nodeNum, "node index out of range");

                totalWeight += weight;
                if (i == path.mixAdapters.length - 1) {
                    require(
                        totalWeight == 10_000,
                        "totalWeight must be 10000"
                    );
                }
            }

            // 2. transfer fromToken from payer to assetTo of edge
            {
                uint256 _fromTokenAmount;
                if (i == path.mixAdapters.length - 1) {
                    _fromTokenAmount = nodeBalance - accAmount;
                } else {
                    _fromTokenAmount = (nodeBalance * weight) / 10_000;
                    accAmount += _fromTokenAmount;
                }
                if (_fromTokenAmount > 0) {
                    TransferLib.transferInternal(
                        payer,
                        path.assetTo[i],
                        path.fromToken,
                        _fromTokenAmount
                    );
                }
            }

            // 3. execute single swap
            {
                address to = address(this);
                if (outputIndex == swapState.nodeNum && !isToNative) {
                    to = receiver;
                }
                _exeEdge(
                    path.rawData[i],
                    path.mixAdapters[i],
                    path.extraData[i],
                    to,
                    swapState.refundTo
                );
            }

            unchecked {
                ++i;
            }
        }
    }

    function _exeEdge(
        uint256 rawData,
        address mixAdapter,
        bytes memory extraData,
        address to,
        address refundTo
    ) private {
        bool reverse;
        address poolAddress;
        assembly {
            poolAddress := and(rawData, _ADDRESS_MASK)
            reverse := and(rawData, _REVERSE_MASK)
        }

        CommonLib.exeAdapter(
            reverse,
            mixAdapter,
            to,
            poolAddress,
            extraData,
            refundTo
        );
    }
}