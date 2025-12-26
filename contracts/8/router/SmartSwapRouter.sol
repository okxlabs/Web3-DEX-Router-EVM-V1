/// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../libraries/Constants.sol";
import "../libraries/EventLib.sol";
import "../libraries/CommissionLib.sol";
import "../libraries/CommonLib.sol";
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

    /// @notice Executes a swap tailored for investment purposes, adjusting swap amounts based on the contract's balance.
    /// @param baseRequest Struct containing essential swap parameters like source and destination tokens, amounts, and deadline.
    /// @param batchesAmount Array indicating how much of the source token to swap in each batch, facilitating diversified investments.
    /// @param batches Detailed routing information for executing the swap across different paths or protocols.
    /// @param to The address where the swapped tokens will be sent, typically an investment contract or pool.
    /// @return returnAmount The total amount of destination tokens received, ready for investment.
    /// @dev This function is designed for scenarios where investments are made in batches or through complex paths to optimize returns. Adjustments are made based on the contract's current token balance to ensure precise allocation.
    function smartSwapByInvestWithRefund(
        IDexRouter.BaseRequest memory baseRequest,
        uint256[] memory batchesAmount,
        IDexRouter.RouterPath[][] memory batches,
        address to,
        address refundTo
    )
        public
        returns (uint256 returnAmount)
    {
        CommonLib.validateDeadline(baseRequest.deadLine);

        address fromToken = CommonLib.bytes32ToAddress(baseRequest.fromToken);
        require(fromToken != _ETH, "Invalid source token");
        require(refundTo != address(0), "refundTo is address(0)");
        require(to != address(0), "to is address(0)");
        require(baseRequest.fromTokenAmount > 0, "fromTokenAmount is 0");
        uint256 amount = CommonLib.getBalanceOf(fromToken, address(this));
        for (uint256 i = 0; i < batchesAmount.length; ) {
            batchesAmount[i] =
                (batchesAmount[i] * amount) /
                baseRequest.fromTokenAmount;
            unchecked {
                ++i;
            }
        }
        baseRequest.fromTokenAmount = amount;

        returnAmount = CommonLib.getBalanceOf(baseRequest.toToken, to);
        _smartSwapInternal(
            baseRequest,
            batchesAmount,
            batches,
            address(this), // payer
            refundTo, // refundTo
            to // receiver
        );
        // check minReturnAmount
        returnAmount =
            CommonLib.getBalanceOf(baseRequest.toToken, to) -
            returnAmount;
        require(
            returnAmount >= baseRequest.minReturnAmount,
            "Min return not reached"
        );
        EventLib.emitOrderRecord(
            fromToken,
            baseRequest.toToken,
            tx.origin,
            baseRequest.fromTokenAmount,
            returnAmount
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
        
        address fromToken = CommonLib.bytes32ToAddress(baseRequest.fromToken);
        CommissionLib.validateCommissionInfo(extraData.commissionInfo, fromToken, baseRequest.toToken, mode);
        extraData.commissionInfo.tokenWithMode = mode | extraData.commissionInfo.tokenWithMode;

        returnAmount = CommonLib.getBalanceOf(baseRequest.toToken, swapCache.receiver);

        uint256 fromTokenCommissionAmount;
        {
            address onlyOneAssetTo = (batches.length == 1 && batches[0].length > 0 && batches[0][0].assetTo.length == 1)
                ? batches[0][0].assetTo[0]
                : address(0);
            (
                swapCache.payer,
                baseRequest.fromTokenAmount,
                fromTokenCommissionAmount
            ) = TransferLib.handlePermit2SignatureModeWithCommission(
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
                swapCache.payer,
                swapCache.refundTo,
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
            TransferLib.refundToken(fromToken, swapCache.refundTo);
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
            baseRequest.fromTokenAmount,
            returnAmount
        );
    }

    /// @notice Executes a complex swap based on provided parameters and paths.
    /// @param baseRequest Basic swap details including tokens, amounts, and deadline.
    /// @param batchesAmount Amounts for each swap batch.
    /// @param batches Detailed swap paths for execution.
    /// @param payer Address providing the tokens.
    /// @param receiver Address receiving the swapped tokens.
    function _smartSwapInternal(
        IDexRouter.BaseRequest memory baseRequest,
        uint256[] memory batchesAmount,
        IDexRouter.RouterPath[][] memory batches,
        address payer,
        address refundTo,
        address receiver
    ) private {
        // 1. transfer from token in
        IDexRouter.BaseRequest memory _baseRequest = baseRequest;

        address fromToken = CommonLib.bytes32ToAddress(_baseRequest.fromToken);

        // In order to deal with ETH/WETH transfer rules in a unified manner,
        // we do not need to judge according to fromToken.
        if (fromToken == _ETH) {
            IWETH(_WETH).deposit{
                value: _baseRequest.fromTokenAmount
            }();
            require(CommonLib.bytes32ToAddress(batches[0][0].fromToken) == _WETH, "firstToken mismatch");
            payer = address(this);
        } else {
            require(CommonLib.bytes32ToAddress(batches[0][0].fromToken) == fromToken, "firstToken mismatch");
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
            require(
                totalBatchAmount <= _baseRequest.fromTokenAmount,
                "Route: number of batches should be <= fromTokenAmount"
            );
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
                payer,
                refundTo,
                receiver,
                _baseRequest.toToken == _ETH,
                batchesAmount[i],
                batches[i]
            );
            unchecked {
                ++i;
            }
        }

        // 5. transfer tokens to user
        TransferLib.transferTokenToUser(_baseRequest.toToken, receiver);
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
        bool toNext;
        bool noTransfer;

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
            } else if (i < hopLength - 1 && hops[i + 1].assetTo.length == 1) {
                to = hops[i + 1].assetTo[0];
                toNext = true;
            } else {
                toNext = false;
            }

            // 3.2 execute forks
            _exeForks(payer, refundTo, to, batchAmount, hops[i], noTransfer);
            noTransfer = toNext;

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
    /// @param noTransfer A flag to indicate whether the token transfer should be skipped.
    /// @dev It includes checks for the total weight of the paths and executes the swapping through the adapters.
    function _exeForks(
        address payer,
        address refundTo,
        address to,
        uint256 batchAmount,
        IDexRouter.RouterPath memory path,
        bool noTransfer
    ) private {
        uint256 totalWeight;
        for (uint256 i = 0; i < path.mixAdapters.length; i++) {
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
                        totalWeight <= 10_000,
                        "totalWeight can not exceed 10000 limit"
                    );
                }

                if (!noTransfer) {
                    uint256 _fromTokenAmount = weight == 10_000
                        ? batchAmount
                        : (batchAmount * weight) / 10_000;
                    if (_fromTokenAmount > 0) {
                        TransferLib.transferInternal(
                            payer,
                            path.assetTo[i],
                            path.fromToken,
                            _fromTokenAmount
                        );
                    }
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