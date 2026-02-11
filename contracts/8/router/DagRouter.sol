/// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../libraries/Constants.sol";
import "../libraries/EventLib.sol";
import "../libraries/CommonLib.sol";
import "../libraries/CommissionLib.sol";
import "../libraries/TransferLib.sol";
import "../libraries/TrimLib.sol";
import "../interfaces/IDexRouter.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/IWETH.sol";

library DagRouter {
    // ================================================================================
    // ============================== Public Functions ================================
    // ================================================================================
    /// @notice Executes a DAG swap to a specified receiver using structured base request parameters.
    /// @param orderId Unique identifier for the swap order, facilitating tracking and reference.
    /// @param receiver The address that will receive the swapped tokens.
    /// @param baseRequest Struct containing essential swap parameters including source token, destination token, amount, minimum return, and deadline.
    /// @param paths An array of RouterPath structs defining the DAG swap route.
    /// @param extraData Additional data encoded in calldata.
    /// @return returnAmount The total amount of destination tokens received from the swap.
    /// @dev This function validates token compatibility with the provided pool route and ensures proper swap execution.
    function dagSwapTo(
        uint256 orderId,
        address receiver,
        IDexRouter.BaseRequest memory baseRequest,
        IDexRouter.RouterPath[] calldata paths,
        IDexRouter.ExtraData memory extraData
    )
        public
        returns (uint256 returnAmount)
    {
        CommonLib.validateDeadline(baseRequest.deadLine);
        require(paths.length > 0 && paths[0].assetTo.length > 0, "paths must be > 0");
        EventLib.emitSwapOrderId(orderId);
        EventLib.emitCommissionAndTrimInfoIfNeeded(extraData);

        receiver = receiver == address(0) ? msg.sender : receiver;

        uint256 mode = paths[0].fromToken & _TRANSFER_MODE_MASK;
        require(
            mode == _MODE_LEGACY || mode == _MODE_DIRECT || mode == _MODE_PERMIT2_ALLOWANCE || mode == _MODE_PERMIT2_SIGNATURE || mode == _MODE_BY_INVEST || mode == _MODE_NO_TRANSFER,
            "invalid transfer mode"
        );
        
        address fromToken = CommonLib.bytes32ToAddress(baseRequest.fromToken);
        CommissionLib.validateCommissionInfo(extraData.commissionInfo, fromToken, baseRequest.toToken, mode);
        TrimLib.validateTrimInfo(extraData.trimInfo);
        extraData.commissionInfo.tokenWithMode = mode | extraData.commissionInfo.tokenWithMode;

        returnAmount = CommonLib.getBalanceOf(baseRequest.toToken, receiver);

        IDexRouter.SwapCache memory swapCache = IDexRouter.SwapCache({
            payer: msg.sender,
            refundTo: (mode == _MODE_BY_INVEST && extraData.refundTo != address(0)) ? extraData.refundTo : msg.sender,
            receiver: receiver,
            toToken: baseRequest.toToken
        });

        uint256 fromTokenCommissionAmount;
        {
            address onlyOneAssetTo = paths[0].assetTo.length == 1 ? paths[0].assetTo[0] : address(0); // Output edge of node0 is only one
            (
                swapCache.payer,
                baseRequest.fromTokenAmount,
                fromTokenCommissionAmount
            ) = TransferLib.handlePermit2SigModeWithCommission(
                uint256(uint160(fromToken)) | mode,
                swapCache.payer,
                baseRequest.fromTokenAmount,
                onlyOneAssetTo,
                extraData
            );
        }

        {
            uint256 balanceBefore;
            (
                swapCache.receiver,
                balanceBefore
            ) = CommissionLib.doCommissionFromToken(
                    extraData.commissionInfo,
                    swapCache,
                    fromTokenCommissionAmount,
                    extraData.trimInfo.hasTrim
                );

            _dagSwapInternal(
                baseRequest,
                paths,
                swapCache
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

        // Refund unused fromToken. If fromToken is not ETH, no need to refund cause all `fromTokenAmount` will be used.
        if (fromToken == _ETH) {
            TransferLib.refundToken(_ETH, swapCache.refundTo); // In case of  msg.value > fromTokenAmount, the unused ETH will be refunded to refundTo
        }

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
        IDexRouter.SwapCache memory swapCache
    ) private {
        // 1. check and process ETH
        address fromToken = CommonLib.bytes32ToAddress(baseRequest.fromToken);

        address firstNodeToken = CommonLib.bytes32ToAddress(paths[0].fromToken);

        // In order to deal with ETH/WETH transfer rules in a unified manner,
        // we do not need to judge according to fromToken.
        if (fromToken == _ETH) {
            IWETH(_WETH).deposit{
                value: baseRequest.fromTokenAmount
            }();
            require(firstNodeToken == _WETH, "firstToken mismatch");
            require(swapCache.payer == address(this), "payer must be router");
        } else {
            require(firstNodeToken == fromToken, "firstToken mismatch");
            require(msg.value == 0, "value must be 0");
        }

        // 2. execute dag swap
        _exeDagSwap(swapCache, baseRequest.fromTokenAmount, baseRequest.toToken == _ETH, paths);

        // 3. transfer tokens to receiver
        TransferLib.transferTokenToUser(baseRequest.toToken, swapCache.receiver);
    }

    /// @notice The core logic to execute the DAG swap. For the first node, the payer should use passed value.
    /// For the non-first node, the payer should always be address(this) cause the to address of the middle swap is address(this).
    function _exeDagSwap(
        IDexRouter.SwapCache memory swapCache,
        uint256 firstNodeBalance,
        bool isToNative,
        IDexRouter.RouterPath[] calldata paths
    ) private {
        uint256 nodeNum = paths.length;

        // execute nodes
        for (uint256 i = 0; i < nodeNum;) {
            if (i != 0) { // reset payer for non-first node
                swapCache.payer = address(this);
            }

            _exeNode(swapCache, firstNodeBalance, i, isToNative, paths[i], nodeNum);

            unchecked {
                ++i;
            }
        }
    }

    /// @notice The core logic to execute the each node
    function _exeNode(
        IDexRouter.SwapCache memory swapCache,
        uint256 nodeBalance,
        uint256 nodeIndex,
        bool isToNative,
        IDexRouter.RouterPath calldata path,
        uint256 nodeNum
    ) private {
        uint256 totalWeight;
        uint256 accAmount;
        address fromToken = CommonLib.bytes32ToAddress(path.fromToken);

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
                require(inputIndex < outputIndex && outputIndex <= nodeNum, "node index out of range");

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
                        swapCache.payer,
                        path.assetTo[i],
                        path.fromToken,
                        _fromTokenAmount
                    );
                }
            }

            // 3. execute single swap
            {
                address to = address(this);
                if (outputIndex == nodeNum && !isToNative) {
                    to = swapCache.receiver;
                }
                address refundTo_ = swapCache.refundTo; // avoid stack too deep
                _exeEdge(
                    path.rawData[i],
                    path.mixAdapters[i],
                    path.extraData[i],
                    to,
                    refundTo_
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