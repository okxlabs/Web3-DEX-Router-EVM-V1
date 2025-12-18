// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./UnxswapRouter.sol";
import "./UnxswapV3Router.sol";

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
    string public constant version = "v1.0.9-transfer-mode";
    using UniversalERC20 for IERC20;

    //-------------------------------
    //------- Users Functions -------
    //-------------------------------

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