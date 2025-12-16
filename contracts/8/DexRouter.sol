// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./UnxswapRouter.sol";
import "./UnxswapV3Router.sol";

import "./interfaces/IWETH.sol";
import "./interfaces/IApproveProxy.sol";
import "./interfaces/IWNativeRelayer.sol";

import "./libraries/PMMLib.sol";
import "./libraries/CommissionLib.sol";
import "./libraries/EthReceiver.sol";
import "./libraries/UniswapTokenInfoHelper.sol";
import "./libraries/CommonLib.sol";
import "./libraries/ExtraDataLib.sol";
import "./DagRouter.sol";

/// @title DexRouterV1
/// @notice Entrance of Split trading in Dex platform
/// @dev Entrance of Split trading in Dex platform
contract DexRouter is
    EthReceiver,
    UnxswapRouter,
    UnxswapV3Router,
    CommissionLib,
    UniswapTokenInfoHelper,
    DagRouter,
    ExtraDataLib
{
    string public constant version = "v1.0.7-multi-commission";
    using UniversalERC20 for IERC20;

    //-------------------------------
    //------- Modifier --------------
    //-------------------------------
    /// @notice Ensures a function is called before a specified deadline.
    /// @param deadLine The UNIX timestamp deadline.
    modifier isExpired(uint256 deadLine) {
        require(deadLine >= block.timestamp, "Route: expired");
        _;
    }

    //-------------------------------
    //------- Internal Functions ----
    //-------------------------------
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
        RouterPath memory path,
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
                        _transferInternal(
                            payer,
                            path.assetTo[i],
                            path.fromToken,
                            _fromTokenAmount
                        );
                    }
                }
            }

            _exeAdapter(
                reverse,
                path.mixAdapters[i],
                to,
                poolAddress,
                path.extraData[i],
                refundTo
            );
        }
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
        RouterPath[] memory hops
    ) private {
        address fromToken = _bytes32ToAddress(hops[0].fromToken);
        bool toNext;
        bool noTransfer;

        // execute hop
        uint256 hopLength = hops.length;
        for (uint256 i = 0; i < hopLength; ) {
            if (i > 0) {
                fromToken = _bytes32ToAddress(hops[i].fromToken);
                batchAmount = _getBalanceOf(fromToken, address(this));
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

    /// @notice Executes a complex swap based on provided parameters and paths.
    /// @param baseRequest Basic swap details including tokens, amounts, and deadline.
    /// @param batchesAmount Amounts for each swap batch.
    /// @param batches Detailed swap paths for execution.
    /// @param payer Address providing the tokens.
    /// @param receiver Address receiving the swapped tokens.

    function _smartSwapInternal(
        BaseRequest memory baseRequest,
        uint256[] memory batchesAmount,
        RouterPath[][] memory batches,
        address payer,
        address refundTo,
        address receiver
    ) private {
        // 1. transfer from token in
        BaseRequest memory _baseRequest = baseRequest;

        address fromToken = _bytes32ToAddress(_baseRequest.fromToken);

        // In order to deal with ETH/WETH transfer rules in a unified manner,
        // we do not need to judge according to fromToken.
        if (UniversalERC20.isETH(IERC20(fromToken))) {
            IWETH(_WETH).deposit{
                value: _baseRequest.fromTokenAmount
            }();
            require(_bytes32ToAddress(batches[0][0].fromToken) == _WETH, "firstToken mismatch");
            payer = address(this);
        } else {
            require(_bytes32ToAddress(batches[0][0].fromToken) == fromToken, "firstToken mismatch");
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
                IERC20(_baseRequest.toToken).isETH(),
                batchesAmount[i],
                batches[i]
            );
            unchecked {
                ++i;
            }
        }

        // 5. transfer tokens to user
        _transferTokenToUser(_baseRequest.toToken, receiver);
    }

    //-------------------------------
    //------- Users Functions -------
    //-------------------------------

    /// @notice Executes a smart swap based on the given order ID, supporting complex multi-path swaps. For smartSwap, if fromToken or toToken is ETH, the address needs to be 0xEeee.
    /// @param orderId The unique identifier for the swap order, facilitating tracking and reference.
    /// @param baseRequest Struct containing the base parameters for the swap, including the source and destination tokens, amount, minimum return, and deadline.
    /// @param batchesAmount An array specifying the amount to be swapped in each batch, allowing for split operations.
    /// @param batches An array of RouterPath structs defining the routing paths for each batch, enabling swaps through multiple protocols or liquidity pools.
    /// @return returnAmount The total amount of destination tokens received from executing the swap.
    /// @dev This function orchestrates a swap operation that may involve multiple steps, routes, or protocols based on the provided parameters.
    /// It's designed to ensure flexibility and efficiency in finding the best swap paths.

    function smartSwapByOrderId(
        uint256 orderId,
        BaseRequest calldata baseRequest,
        uint256[] calldata batchesAmount,
        RouterPath[][] calldata batches,
        PMMLib.PMMSwapRequest[] calldata // extraData
    )
        external
        payable
        isExpired(baseRequest.deadLine)
        returns (uint256 returnAmount)
    {
        emit SwapOrderId(orderId);
        return
            _smartSwapTo(
                SwapParams({
                    payer: msg.sender,
                    refundTo: msg.sender,
                    receiver: msg.sender,
                    toToken: baseRequest.toToken
                }),
                baseRequest,
                batchesAmount,
                batches
            );
    }
    /// @notice Executes a token swap using the Unxswap protocol based on a specified order ID.
    /// @param srcToken The source token involved in the swap.
    /// @param amount The amount of the source token to be swapped.
    /// @param minReturn The minimum amount of tokens expected to be received to ensure the swap does not proceed under unfavorable conditions.
    /// @param pools An array of pool identifiers specifying the pools to use for the swap, allowing for optimized routing.
    /// @return returnAmount The amount of destination tokens received from the swap.
    /// @dev This function allows users to perform token swaps based on predefined orders, leveraging the Unxswap protocol's liquidity pools. It ensures that the swap meets the user's specified minimum return criteria, enhancing trade efficiency and security.

    function unxswapByOrderId(
        uint256 srcToken,
        uint256 amount,
        uint256 minReturn,
        // solhint-disable-next-line no-unused-vars
        bytes32[] calldata pools
    ) external payable returns (uint256 returnAmount) {
        return unxswapTo(
            srcToken,
            amount,
            minReturn,
            msg.sender,
            pools
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
        BaseRequest memory baseRequest,
        uint256[] memory batchesAmount,
        RouterPath[][] memory batches,
        PMMLib.PMMSwapRequest[] memory, // extraData
        address to,
        address refundTo
    )
        public
        payable
        isExpired(baseRequest.deadLine)
        returns (uint256 returnAmount)
    {
        address fromToken = _bytes32ToAddress(baseRequest.fromToken);
        require(fromToken != _ETH, "Invalid source token");
        require(refundTo != address(0), "refundTo is address(0)");
        require(to != address(0), "to is address(0)");
        require(baseRequest.fromTokenAmount > 0, "fromTokenAmount is 0");
        uint256 amount = IERC20(fromToken).balanceOf(address(this));
        for (uint256 i = 0; i < batchesAmount.length; ) {
            batchesAmount[i] =
                (batchesAmount[i] * amount) /
                baseRequest.fromTokenAmount;
            unchecked {
                ++i;
            }
        }
        baseRequest.fromTokenAmount = amount;

        returnAmount = _getBalanceOf(baseRequest.toToken, to);
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
            _getBalanceOf(baseRequest.toToken, to) -
            returnAmount;
        require(
            returnAmount >= baseRequest.minReturnAmount,
            "Min return not reached"
        );
        emit OrderRecord(
            fromToken,
            baseRequest.toToken,
            tx.origin,
            baseRequest.fromTokenAmount,
            returnAmount
        );
    }

    /// @notice Executes a swap using the Uniswap V3 protocol.
    /// @param receiver The address that will receive the swap funds.
    /// @param amount The amount of the source token to be swapped.
    /// @param minReturn The minimum acceptable amount of tokens to receive from the swap, guarding against excessive slippage.
    /// @param pools An array of pool identifiers used to define the swap route within Uniswap V3.
    /// @return returnAmount The amount of tokens received after the completion of the swap.
    /// @dev This function wraps and unwraps ETH as required, ensuring the transaction only accepts non-zero `msg.value` for ETH swaps. It invokes `_uniswapV3Swap` to execute the actual swap and handles commission post-swap.
    function uniswapV3SwapTo(
        uint256 receiver,
        uint256 amount,
        uint256 minReturn,
        uint256[] calldata pools
    ) external payable returns (uint256 returnAmount) {
        emit SwapOrderId((receiver & _ORDER_ID_MASK) >> 160);
        (address srcToken, address toToken) = _getUniswapV3TokenInfo(msg.value > 0, pools);
        SwapParams memory swapParams = SwapParams({
            payer: msg.sender,
            refundTo: msg.sender,
            receiver: (receiver & _ADDRESS_MASK) == 0 ? msg.sender : _bytes32ToAddress(receiver),
            toToken: toToken
        });
        return
            _uniswapV3SwapTo(
                swapParams,
                srcToken,
                amount,
                minReturn,
                pools
            );
    }

    /// @notice If srcToken or toToken is ETH, the address needs to be 0xEeee. And for commission validation, ETH needs to be 0xEeee.
    function _uniswapV3SwapTo(
        SwapParams memory swapParams,
        address srcToken,
        uint256 amount,
        uint256 minReturn,
        uint256[] calldata pools
    ) internal returns (uint256 returnAmount) {
        ExtraData memory extraData = getDecodedExtraData();
        // add permit2
        _validateCommissionInfo(extraData.commissionInfo, srcToken, swapParams.toToken, _MODE_LEGACY);
        // TODO add mode to commissionInfo.tokenWithMode

        returnAmount = _getBalanceOf(swapParams.toToken, swapParams.receiver);

        // TODO call _handlePermit2SignatureModeWithCommission to handle permit2Signature mode and fromTokenCommission
        // (swapParams.payer, amount, fromTokenCommissionAmount) = _handlePermit2SignatureModeWithCommission();
        _doUniswapV3Swap(
            swapParams,
            amount,
            minReturn,
            pools,
            extraData.commissionInfo,
            extraData.trimInfo
        );

        // check minReturnAmount
        returnAmount = _getBalanceOf(swapParams.toToken, swapParams.receiver) - returnAmount;
        require(
            returnAmount >= minReturn,
            "Min return not reached"
        );

        emit OrderRecord(
            srcToken,
            swapParams.toToken,
            tx.origin,
            amount,
            returnAmount
        );
    }

    function _doUniswapV3Swap(
        SwapParams memory swapParams,
        uint256 amount,
        uint256 minReturn,
        uint256[] calldata pools,
        CommissionInfo memory commissionInfo,
        TrimInfo memory trimInfo
    ) private {
        (
            address middleReceiver,
            uint256 balanceBefore
        ) = _doCommissionFromToken(
                commissionInfo,
                swapParams,
                amount, // TODO should be fromTokenCommissionAmount gotten from _handlePermit2SignatureModeWithCommission
                trimInfo.hasTrim
            );

        _uniswapV3Swap(
            swapParams.payer,
            payable(middleReceiver),
            amount,
            minReturn,
            pools
        );

        _doCommissionAndTrimToToken(
            commissionInfo,
            swapParams.receiver,
            balanceBefore,
            swapParams.toToken,
            trimInfo
        );
    }

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
        BaseRequest calldata baseRequest,
        uint256[] calldata batchesAmount,
        RouterPath[][] calldata batches,
        PMMLib.PMMSwapRequest[] calldata // extraData
    )
        external
        payable
        isExpired(baseRequest.deadLine)
        returns (uint256 returnAmount)
    {
        emit SwapOrderId(orderId);
        return
            _smartSwapTo(
                SwapParams({
                    payer: msg.sender,
                    refundTo: msg.sender,
                    receiver: receiver == address(0) ? msg.sender : receiver,
                    toToken: baseRequest.toToken
                }),
                baseRequest,
                batchesAmount,
                batches
            );
    }

    /// @notice If fromToken or toToken is ETH, the address needs to be 0xEeee. And for commission validation, ETH needs to be 0xEeee.
    function _smartSwapTo(
        SwapParams memory swapParams,
        BaseRequest memory baseRequest,
        uint256[] memory batchesAmount,
        RouterPath[][] memory batches
    ) internal returns (uint256 returnAmount) {
        ExtraData memory extraData = getDecodedExtraData();
        
        uint256 mode = batches[0][0].fromToken & _TRANSFER_MODE_MASK;
        
        _validateCommissionInfo(extraData.commissionInfo, _bytes32ToAddress(baseRequest.fromToken), baseRequest.toToken, mode);
        extraData.commissionInfo.tokenWithMode = mode | extraData.commissionInfo.tokenWithMode;

        returnAmount = _getBalanceOf(baseRequest.toToken, swapParams.receiver);
        // call _handlePermit2SignatureModeWithCommission to handle permit2Signature mode and fromTokenCommission
        // TODO (swapParams.payer, baseRequest.fromTokenAmount, fromTokenCommissionAmount) = _handlePermit2SignatureModeWithCommission();
        {
            (
                address middleReceiver,
                uint256 balanceBefore
            ) = _doCommissionFromToken(
                    extraData.commissionInfo,
                    swapParams,
                    baseRequest.fromTokenAmount, // TODO should be fromTokenCommissionAmount gotten from _handlePermit2SignatureModeWithCommission
                    extraData.trimInfo.hasTrim
                );

            _smartSwapInternal(
                baseRequest,
                batchesAmount,
                batches,
                swapParams.payer,
                swapParams.refundTo,
                middleReceiver
            );

            _doCommissionAndTrimToToken(
                extraData.commissionInfo,
                swapParams.receiver,
                balanceBefore,
                baseRequest.toToken,
                extraData.trimInfo
            );
        }

        // check minReturnAmount
        returnAmount =
            _getBalanceOf(baseRequest.toToken, swapParams.receiver) -
            returnAmount;
        require(
            returnAmount >= baseRequest.minReturnAmount,
            "Min return not reached"
        );

        emit OrderRecord(
            _bytes32ToAddress(baseRequest.fromToken),
            baseRequest.toToken,
            tx.origin,
            baseRequest.fromTokenAmount,
            returnAmount
        );
    }
    /// @notice Executes a token swap using the Unxswap protocol, sending the output directly to a specified receiver.
    ///         The srcToken can be 0xEeee or address(0) for temporary use, the address(0) usage will removed in the future.
    /// @param srcToken The source token to be swapped.
    /// @param amount The amount of the source token to be swapped.
    /// @param minReturn The minimum amount of destination tokens expected from the swap, ensuring the trade does not proceed under unfavorable conditions.
    /// @param receiver The address where the swapped tokens will be sent.
    /// @param pools An array of pool identifiers to specify the swap route, optimizing for best rates.
    /// @return returnAmount The total amount of destination tokens received from the swap.
    /// @dev This function facilitates direct swaps using Unxswap, allowing users to specify custom swap routes and ensuring that the output is sent to a predetermined address. It is designed for scenarios where the user wants to directly receive the tokens in their wallet or another contract.
    function unxswapTo(
        uint256 srcToken,
        uint256 amount,
        uint256 minReturn,
        address receiver,
        // solhint-disable-next-line no-unused-vars
        bytes32[] calldata pools
    ) public payable returns (uint256 returnAmount) {
        emit SwapOrderId((srcToken & _ORDER_ID_MASK) >> 160);

        // validate token info
        (address fromToken, address toToken) = _getUnxswapTokenInfo(msg.value > 0, pools);
        address srcTokenAddr = _bytes32ToAddress(srcToken);
        require(
            (srcTokenAddr == fromToken) || (srcTokenAddr == address(0) && fromToken == _ETH),
            "unxswap: token mismatch"
        );
        
        return
            _unxswapTo(
                fromToken,
                toToken,
                amount,
                minReturn,
                msg.sender,
                receiver,
                pools
            );
    }

    /// @notice If srcToken is ETH, srcToken needs to be 0xEeee for commission validation and _unxswapInternal.
    function _unxswapTo(
        address srcToken,
        address toToken,
        uint256 amount,
        uint256 minReturn,
        address payer,
        address receiver,
        // solhint-disable-next-line no-unused-vars
        bytes32[] calldata pools
    ) internal returns (uint256 returnAmount) {
        receiver = receiver == address(0) ? msg.sender : receiver;
        ExtraData memory extraData = getDecodedExtraData();

        _validateCommissionInfo(extraData.commissionInfo, srcToken, toToken, _MODE_LEGACY);
        returnAmount = _getBalanceOf(toToken, receiver);

        SwapParams memory swapParams = SwapParams({
            payer: payer,
            refundTo: msg.sender,
            receiver: receiver,
            toToken: toToken
        });
        // call _handlePermit2SignatureModeWithCommission to handle permit2Signature mode and fromTokenCommission
        // (swapParams.payer, amount, fromTokenCommissionAmount) = _handlePermit2SignatureModeWithCommission();
        _doUnxswap(
            swapParams,
            srcToken,
            amount,
            minReturn,
            pools,
            extraData.commissionInfo,
            extraData.trimInfo
        );

        // check minReturnAmount
        returnAmount = _getBalanceOf(toToken, receiver) - returnAmount;
        require(
            returnAmount >= minReturn,
            "Min return not reached"
        );

        emit OrderRecord(
            srcToken,
            toToken,
            tx.origin,
            amount,
            returnAmount
        );

        return returnAmount;
    }

    function _doUnxswap(
        SwapParams memory swapParams,
        address srcToken,
        uint256 amount,
        uint256 minReturn,
        bytes32[] calldata pools,
        CommissionInfo memory commissionInfo,
        TrimInfo memory trimInfo
    ) private {
        (
            address middleReceiver,
            uint256 balanceBefore
        ) = _doCommissionFromToken(
                commissionInfo,
                swapParams,
                amount, // TODO should be fromTokenCommissionAmount gotten from _handlePermit2SignatureModeWithCommission
                trimInfo.hasTrim
            );

        _unxswapInternal(
            IERC20(srcToken),
            amount,
            minReturn,
            pools,
            swapParams.payer,
            middleReceiver
        );

        _doCommissionAndTrimToToken(
            commissionInfo,
            swapParams.receiver,
            balanceBefore,
            swapParams.toToken,
            trimInfo
        );
    }

    /// @notice Executes a Uniswap V3 token swap to a specified receiver using structured base request parameters. For uniswapV3, if fromToken or toToken is ETH, the address needs to be 0xEeee.
    /// @param orderId Unique identifier for the swap order, facilitating tracking and reference.
    /// @param receiver The address that will receive the swapped tokens.
    /// @param baseRequest Struct containing essential swap parameters including source token, destination token, amount, minimum return, and deadline.
    /// @param pools An array of pool identifiers defining the Uniswap V3 swap route, with encoded swap direction and unwrap flags.
    /// @return returnAmount The total amount of destination tokens received from the swap.
    /// @dev This function validates token compatibility with the provided pool route and ensures proper swap execution.
    /// It supports both ETH and ERC20 token swaps, with automatic WETH wrapping/unwrapping as needed.
    /// The function verifies that fromToken matches the first pool and toToken matches the last pool in the route.
    function uniswapV3SwapToWithBaseRequest(
        uint256 orderId,
        address receiver,
        BaseRequest calldata baseRequest,
        uint256[] calldata pools
    )
        external
        payable
        isExpired(baseRequest.deadLine)
        returns (uint256 returnAmount)
    {
        emit SwapOrderId(orderId);

        (address srcToken, address toToken) = _getUniswapV3TokenInfo(msg.value > 0, pools);

        // validate fromToken and toToken from baseRequest
        require(
            _bytes32ToAddress(baseRequest.fromToken) == srcToken && baseRequest.toToken == toToken,
            "uniswapV3: token mismatch"
        );

        SwapParams memory swapParams = SwapParams({
            payer: msg.sender,
            refundTo: msg.sender,
            receiver: receiver == address(0) ? msg.sender : receiver,
            toToken: toToken
        });
        return
            _uniswapV3SwapTo(
                swapParams,
                srcToken,
                baseRequest.fromTokenAmount,
                baseRequest.minReturnAmount,
                pools
            );
    }

    /// @notice Executes a Unxswap token swap to a specified receiver using structured base request parameters. For unxswap, if fromToken or toToken is ETH, the address can be 0xEeee or address(0) for temporary use, the address(0) usage will removed in the future.
    /// @param orderId Unique identifier for the swap order, facilitating tracking and reference.
    /// @param receiver The address that will receive the swapped tokens.
    /// @param baseRequest Struct containing essential swap parameters including source token, destination token, amount, minimum return, and deadline.
    /// @param pools An array of pool identifiers defining the Unxswap route, with encoded swap direction and WETH unwrap flags.
    /// @return returnAmount The total amount of destination tokens received from the swap.
    /// @dev This function validates token compatibility with the provided pool route and ensures proper swap execution.
    /// It supports both ETH and ERC20 token swaps, with automatic WETH wrapping/unwrapping as needed.
    /// The function verifies that toToken matches the expected output token from the last pool in the route.
    function unxswapToWithBaseRequest(
        uint256 orderId,
        address receiver,
        BaseRequest calldata baseRequest,
        bytes32[] calldata pools
    )
        external
        payable
        isExpired(baseRequest.deadLine)
        returns (uint256 returnAmount)
    {
        emit SwapOrderId(orderId);

        (address fromToken, address toToken) = _getUnxswapTokenInfo(msg.value > 0, pools);

        // validate fromToken and toToken from baseRequest
        address fromTokenAddr = _bytes32ToAddress(baseRequest.fromToken);
        require((fromTokenAddr == fromToken) || (fromTokenAddr == address(0) && fromToken == _ETH), "unxswap: fromToken mismatch");
        require((baseRequest.toToken == toToken) || (baseRequest.toToken == address(0) && toToken == _ETH), "unxswap: toToken mismatch");

        return
            _unxswapTo(
                fromToken,
                toToken,
                baseRequest.fromTokenAmount,
                baseRequest.minReturnAmount,
                msg.sender,
                receiver,
                pools
            );
    }

    /// @notice For commission validation, ETH needs to be 0xEeee.
    function _swapWrap(
        uint256 orderId,
        address receiver,
        bool reversed,
        uint256 amount,
        uint256 mode
    ) internal {
        emit SwapOrderId(orderId);

        require(amount > 0, "amount must be > 0");
        require(
            mode == _MODE_LEGACY || 
            mode == _MODE_DIRECT || 
            mode == _MODE_PERMIT2_ALLOWANCE || 
            mode == _MODE_PERMIT2_SIGNATURE,
            "SwapWrap: invalid mode"
        );
        
        receiver = receiver == address(0) ? msg.sender : receiver;

        ExtraData memory extraData = getDecodedExtraData();

        _validateCommissionInfo(extraData.commissionInfo, reversed ? _WETH : _ETH, reversed ? _ETH : _WETH, mode);
        extraData.commissionInfo.tokenWithMode = mode | extraData.commissionInfo.tokenWithMode;

        SwapParams memory swapParams = SwapParams({
            payer: msg.sender,
            refundTo: msg.sender,
            receiver: receiver,
            toToken: reversed ? _ETH : _WETH
        });

        uint256 fromTokenCommissionAmount;
        (
            swapParams.payer, 
            amount, 
            fromTokenCommissionAmount
        ) = _handlePermit2SignatureModeWithCommission(
            reversed ? (mode | uint256(uint160(_WETH))) : uint256(uint160(_ETH)),
            swapParams.payer,
            amount,
            address(0),
            extraData
        );

        (
            address middleReceiver,
            uint256 balanceBefore
        ) = _doCommissionFromToken(
                extraData.commissionInfo,
                swapParams,
                fromTokenCommissionAmount,
                extraData.trimInfo.hasTrim
            );

        if (reversed) {
            _transferInternal(
                swapParams.payer,
                address(this),
                mode | uint256(uint160(_WETH)),
                amount
            );
            IWETH(_WETH).withdraw(amount);
            if (middleReceiver != address(this)) {
                // External ETH call - Reentrancy is safe here because:
                // 1. Router is stateless (no user state stored)
                // 2. Subsequent operations (_doCommissionAndTrimToToken) use `balanceBefore` to calculate delta
                // 3. No exploitable state inconsistency even if reentered
                (bool success, ) = payable(middleReceiver).call{
                    value: amount
                }("");
                require(success, "transfer native token failed");
            }
        } else {
            require(msg.value >= amount + fromTokenCommissionAmount, "SwapWrap: value not enough");
            IWETH(_WETH).deposit{value: amount}();
            if (middleReceiver != address(this)) {
                SafeERC20.safeTransfer(IERC20(_WETH), middleReceiver, amount);
            }
        }
        // emit return amount should be the amount after commission
        uint256 toTokenCommissionAndTrimAmount = _doCommissionAndTrimToToken(
            extraData.commissionInfo,
            receiver,
            balanceBefore,
            swapParams.toToken,
            extraData.trimInfo
        );

        // Refund unused fromToken
        uint256 refundAmount = reversed 
            ? IERC20(_WETH).balanceOf(address(this)) 
            : address(this).balance;
        
        if (refundAmount > 0) {
            if (reversed) {
                SafeERC20.safeTransfer(IERC20(_WETH), swapParams.refundTo, refundAmount);
            } else {
                (bool success, ) = payable(swapParams.refundTo).call{value: refundAmount}("");
                require(success, "SwapWrap: refund failed");
            }
        }

        emit OrderRecord(
            reversed ? _WETH : _ETH,
            swapParams.toToken,
            tx.origin,
            amount,
            amount - toTokenCommissionAndTrimAmount
        );
    }

    /// @notice Executes a simple swap between ETH and WETH using encoded parameters.
    /// @param orderId Unique identifier for the swap order, facilitating tracking and reference.
    /// @param rawdata Encoded data containing swap direction, transfer mode and amount information using bit masks.
    /// @dev This function supports bidirectional swaps between ETH and WETH with minimal gas overhead.
    /// The rawdata parameter encodes:
    /// - Transfer mode in bits [251:249]: LEGACY(0b000), PERMIT2_ALLOWANCE(0b001), PERMIT2_SIGNATURE(0b011), DIRECT(0b101)
    /// - Direction (reversed flag) in bit 255: false=ETH->WETH, true=WETH->ETH
    function swapWrap(uint256 orderId, uint256 rawdata) external payable {
        bool reversed;
        uint128 amount;
        uint256 mode;
        assembly {
            reversed := and(rawdata, _REVERSE_MASK)
            amount := and(rawdata, SWAP_AMOUNT)
            mode := and(rawdata, _TRANSFER_MODE_MASK)
        }
        _swapWrap(orderId, msg.sender, reversed, amount, mode);
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
        isExpired(baseRequest.deadLine)
    {
        bool reversed;
        address fromTokenAddr = _bytes32ToAddress(baseRequest.fromToken);
        if (fromTokenAddr == _ETH && baseRequest.toToken == _WETH) {
            reversed = false;
        } else if (fromTokenAddr == _WETH && baseRequest.toToken == _ETH) {
            reversed = true;
        } else {
            revert("SwapWrap: invalid token pair");
        }

        _swapWrap(orderId, receiver, reversed, baseRequest.fromTokenAmount, baseRequest.fromToken & _TRANSFER_MODE_MASK);
    }

    function dagSwapByOrderId(
        uint256 orderId,
        BaseRequest calldata baseRequest,
        RouterPath[] calldata paths
    ) external payable  returns (uint256 returnAmount) {
        return dagSwapTo(orderId, msg.sender, baseRequest, paths);
    }

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
        BaseRequest memory baseRequest,
        RouterPath[] calldata paths
    )
        public
        payable
        isExpired(baseRequest.deadLine)
        returns (uint256 returnAmount)
    {
        require(paths.length > 0, "paths must be > 0");
        emit SwapOrderId(orderId);

        receiver = receiver == address(0) ? msg.sender : receiver;

        ExtraData memory extraData = getDecodedExtraData();
        
        uint256 mode = paths[0].fromToken & _TRANSFER_MODE_MASK;
        
        _validateCommissionInfo(extraData.commissionInfo, _bytes32ToAddress(baseRequest.fromToken), baseRequest.toToken, mode);
        extraData.commissionInfo.tokenWithMode = mode | extraData.commissionInfo.tokenWithMode;

        returnAmount = _getBalanceOf(baseRequest.toToken, receiver);

        SwapParams memory swapParams = SwapParams({
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
            ) = _handlePermit2SignatureModeWithCommission(
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
            ) = _doCommissionFromToken(
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

            _doCommissionAndTrimToToken(
                extraData.commissionInfo,
                receiver,
                balanceBefore,
                baseRequest.toToken,
                extraData.trimInfo
            );
        }

        // check minReturnAmount
        returnAmount =
            _getBalanceOf(baseRequest.toToken, receiver) -
            returnAmount;
        require(
            returnAmount >= baseRequest.minReturnAmount,
            "Min return not reached"
        );

        emit OrderRecord(
            _bytes32ToAddress(baseRequest.fromToken),
            baseRequest.toToken,
            tx.origin,
            baseRequest.fromTokenAmount,
            returnAmount
        );
    }
}