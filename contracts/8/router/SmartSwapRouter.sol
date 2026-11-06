/// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../libraries/Constants.sol";
import "../libraries/EventLib.sol";
import "../libraries/CommissionLib.sol";
import "../libraries/CommonLib.sol";
import "../libraries/TrimLib.sol";
import "../libraries/TransferLib.sol";
import "../libraries/PMMLib.sol";
import "../interfaces/IDexRouter.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/IWETH.sol";


library SmartSwapRouter {
    // ================================================================================
    // ============================== Public Functions ================================
    // ================================================================================
    /// @notice Executes a smart swap directly to a specified receiver address.
    /// @param orderId Unique identifier for the swap order, facilitating tracking.
    /// @param receiver Address to receive the output tokens from the swap.
    /// @param baseRequest Contains essential parameters for the swap such as source and destination tokens, amounts, and deadline.
    /// @param batchesAmount Array indicating amounts for each batch in the swap, allowing for split operations.
    /// @param batches Detailed routing information for executing the swap across different paths or protocols.
    /// @param extraData Additional data encoded in calldata.
    /// @return returnAmount The total amount of destination tokens received from the swap.
    /// @dev This function enables users to perform token swaps with complex routing directly to a specified address,
    /// optimizing for best returns and accommodating specific trading strategies.
    function smartSwapTo(
        uint256 orderId,
        address receiver,
        IDexRouter.BaseRequest calldata baseRequest,
        uint256[] calldata batchesAmount,
        IDexRouter.RouterPath[][] calldata batches,
        IDexRouter.ExtraData memory extraData
    )
        public
        returns (uint256 returnAmount)
    {
        CommonLib.validateDeadline(baseRequest.deadLine);
        EventLib.emitSwapOrderId(orderId);
        EventLib.emitCommissionAndTrimInfoIfNeeded(extraData);
        return
            _smartSwapTo(
                IDexRouter.SwapCache({
                    payer: msg.sender,
                    refundTo: msg.sender,
                    receiver: receiver == address(0) ? msg.sender : receiver,
                    toToken: baseRequest.toToken
                }),
                baseRequest,
                batchesAmount,
                batches,
                extraData
            );
    }

    // ================================================================================
    // ============================== Private Functions ===============================
    // ================================================================================
    /// @notice If fromToken or toToken is ETH, the address needs to be 0xEeee. And for commission validation, ETH needs to be 0xEeee.
    function _smartSwapTo(
        IDexRouter.SwapCache memory swapCache,
        IDexRouter.BaseRequest memory baseRequest,
        uint256[] memory batchesAmount,
        IDexRouter.RouterPath[][] memory batches,
        IDexRouter.ExtraData memory extraData
    ) private returns (uint256 returnAmount) {
        uint256 mode = batches[0][0].fromToken & _TRANSFER_MODE_MASK;
        require(
            mode == _MODE_LEGACY || mode == _MODE_DIRECT || mode == _MODE_PERMIT2_ALLOWANCE || mode == _MODE_PERMIT2_SIGNATURE || mode == _MODE_BY_INVEST || mode == _MODE_NO_TRANSFER,
            "invalid transfer mode"
        );

        address fromToken = CommonLib.bytes32ToAddress(baseRequest.fromToken);
        CommissionLib.validateCommissionInfo(extraData.commissionInfo, fromToken, baseRequest.toToken, mode);
        TrimLib.validateTrimInfo(extraData.trimInfo);
        extraData.commissionInfo.tokenWithMode = mode | extraData.commissionInfo.tokenWithMode;

        if (mode == _MODE_BY_INVEST && extraData.refundTo != address(0)) {
            swapCache.refundTo = extraData.refundTo;
        }

        // Stash the receiver's toToken balanceBefore in returnAmount; it is replaced by the actual delta after the swap.
        returnAmount = CommonLib.getBalanceOf(baseRequest.toToken, swapCache.receiver);

        // Snapshot for OrderRecord only; not for swap math.
        uint256 originalFromTokenAmount = baseRequest.fromTokenAmount;

        uint256 fromTokenCommissionAmount;
        {
            address onlyOneAssetTo = (batches.length == 1 && batches[0][0].assetTo.length == 1)
                ? batches[0][0].assetTo[0]
                : address(0);
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
            (
                address middleReceiver,
                uint256 balanceBefore
            ) = CommissionLib.doCommissionFromToken(
                    extraData.commissionInfo,
                    swapCache,
                    fromTokenCommissionAmount,
                    extraData.trimInfo.hasTrim
                );

            _smartSwapInternal(
                baseRequest,
                batchesAmount,
                batches,
                swapCache,
                middleReceiver
            );

            CommissionLib.doCommissionAndTrimToToken(
                extraData.commissionInfo,
                swapCache.receiver,
                balanceBefore,
                baseRequest.toToken,
                extraData.trimInfo
            );
        }

        // Refund unused fromToken
        if (fromToken == _ETH) {
            TransferLib.refundToken(_ETH, swapCache.refundTo); // In case of  msg.value > fromTokenAmount, the unused ETH will be refunded to refundTo
            TransferLib.refundToken(_WETH, swapCache.refundTo); // In case of fromTokenAmount > sum of batchesAmount, the unused WETH will be refunded to refundTo
        } else {
            TransferLib.refundToken(fromToken, swapCache.refundTo); // In case of fromTokenAmount > sum of batchesAmount, the unused fromToken will be refunded to refundTo
        }

        // check minReturnAmount
        returnAmount =
            CommonLib.getBalanceOf(baseRequest.toToken, swapCache.receiver) -
            returnAmount;
        require(
            returnAmount >= baseRequest.minReturnAmount,
            "Min return not reached"
        );

        EventLib.emitOrderRecord(
            CommonLib.bytes32ToAddress(baseRequest.fromToken),
            baseRequest.toToken,
            tx.origin,
            originalFromTokenAmount,
            returnAmount
        );
    }

    /// @notice Executes a complex swap based on provided parameters and paths.
    /// @param baseRequest Basic swap details including tokens, amounts, and deadline.
    /// @param batchesAmount Amounts for each swap batch.
    /// @param batches Detailed swap paths for execution.
    /// @param swapCache Provides payer and refundTo; swapCache.receiver is unused here.
    /// @param receiver Hop output recipient (middleReceiver when commission/trim is active).
    function _smartSwapInternal(
        IDexRouter.BaseRequest memory baseRequest,
        uint256[] memory batchesAmount,
        IDexRouter.RouterPath[][] memory batches,
        IDexRouter.SwapCache memory swapCache,
        address receiver
    ) private {
        // 1. transfer from token in
        address fromToken = CommonLib.bytes32ToAddress(baseRequest.fromToken);

        // In order to deal with ETH/WETH transfer rules in a unified manner,
        // we do not need to judge according to fromToken.
        if (fromToken == _ETH) {
            IWETH(_WETH).deposit{
                value: baseRequest.fromTokenAmount
            }();
            require(CommonLib.bytes32ToAddress(batches[0][0].fromToken) == _WETH, "firstToken mismatch");
            require(swapCache.payer == address(this), "payer must be router");
        } else {
            require(CommonLib.bytes32ToAddress(batches[0][0].fromToken) == fromToken, "firstToken mismatch");
            require(msg.value == 0, "value must be 0");
        }

        // 2. check total batch amount
        {
            // avoid stack too deep
            uint256 totalBatchAmount;
            for (uint256 i = 0; i < batchesAmount.length; ) {
                totalBatchAmount += batchesAmount[i];
                unchecked {
                    ++i;
                }
            }
            // payer == address(0) signals that fromTokenAmount has been transferred
            // directly to the pool via permit2 signature. The unused portion cannot
            // be refunded in this case (funds are already in the pool, where adapters
            // settle by balanceOf), so require exact match to prevent silent over-swap.
            if (swapCache.payer == address(0)) {
                require(
                    totalBatchAmount == baseRequest.fromTokenAmount,
                    "Route: total batch amount must equal fromTokenAmount"
                );
            } else {
                require(
                    totalBatchAmount <= baseRequest.fromTokenAmount,
                    "Route: total batch amount should be <= fromTokenAmount"
                );
            }
        }

        // 4. execute batch
        // check length, fix DRW-02: LACK OF LENGTH CHECK ON BATATCHES
        require(batchesAmount.length == batches.length, "length mismatch");
        for (uint256 i = 0; i < batches.length; ) {
            if (i > 0) {
                require(batches[i][0].fromToken == batches[0][0].fromToken, "Inconsistent fromToken across batches");
            }

            // execute hop, if the whole swap replacing by pmm fails, the funds will return to dexRouter
            _exeHop(
                swapCache.payer,
                swapCache.refundTo,
                receiver,
                baseRequest.toToken == _ETH,
                batchesAmount[i],
                batches[i]
            );
            unchecked {
                ++i;
            }
        }

        // 5. transfer tokens to user
        TransferLib.transferTokenToUser(baseRequest.toToken, receiver);
    }

    /// @notice Executes a series of swaps or operations defined by a set of routing paths, potentially across different protocols or pools.
    /// @param payer The address providing the tokens for the swap.
    /// @param receiver The address receiving the output tokens.
    /// @param isToNative Indicates whether the final asset should be converted to the native blockchain asset (e.g., ETH).
    /// @param batchAmount The total amount of the input token to be swapped.
    /// @param hops An array of RouterPath structures, each defining a segment of the swap route.
    /// @dev This function manages complex swap routes that might involve multiple hops through different liquidity pools or swapping protocols.
    /// It iterates through the provided `hops`, executing each segment of the route in sequence.
    function _exeHop(
        address payer,
        address refundTo,
        address receiver,
        bool isToNative,
        uint256 batchAmount,
        IDexRouter.RouterPath[] memory hops
    ) private {
        address fromToken = CommonLib.bytes32ToAddress(hops[0].fromToken);

        // execute hop
        uint256 hopLength = hops.length;
        for (uint256 i = 0; i < hopLength; ) {
            if (i > 0) {
                fromToken = CommonLib.bytes32ToAddress(hops[i].fromToken);
                batchAmount = CommonLib.getBalanceOf(fromToken, address(this));
                payer = address(this);
            }

            address to = address(this);
            if (i == hopLength - 1 && !isToNative) {
                to = receiver;
            }

            // 3.2 execute forks
            _exeForks(payer, refundTo, to, batchAmount, hops[i]);

            unchecked {
                ++i;
            }
        }
    }

    /// @notice Executes multiple adapters for a transaction pair.
    /// @param payer The address of the payer.
    /// @param to The address of the receiver.
    /// @param batchAmount The amount to be transferred in each batch.
    /// @param path The routing path for the swap.
    /// @dev It includes checks for the total weight of the paths and executes the swapping through the adapters.
    function _exeForks(
        address payer,
        address refundTo,
        address to,
        uint256 batchAmount,
        IDexRouter.RouterPath memory path
    ) private {
        uint256 totalWeight;
        uint256 accAmount;
        for (uint256 i = 0; i < path.mixAdapters.length; ++i) {
            bytes32 rawData = bytes32(path.rawData[i]);
            address poolAddress;
            bool reverse;
            {
                uint256 weight;
                assembly {
                    poolAddress := and(rawData, _ADDRESS_MASK)
                    reverse := and(rawData, _REVERSE_MASK)
                    weight := shr(160, and(rawData, _WEIGHT_MASK))
                }
                totalWeight += weight;
                if (i == path.mixAdapters.length - 1) {
                    require(
                        totalWeight == 10_000,
                        "totalWeight must be 10000"
                    );
                }

                uint256 _fromTokenAmount;
                if (i == path.mixAdapters.length - 1) {
                    _fromTokenAmount = batchAmount - accAmount;
                } else {
                    _fromTokenAmount = (batchAmount * weight) / 10_000;
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

            CommonLib.exeAdapter(
                reverse,
                path.mixAdapters[i],
                to,
                poolAddress,
                path.extraData[i],
                refundTo
            );
        }
    }
}