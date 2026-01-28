/// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../libraries/Constants.sol";
import "../libraries/EventLib.sol";
import "../libraries/CommissionLib.sol";
import "../libraries/CommonLib.sol";
import "../libraries/TransferLib.sol";
import "../interfaces/IDexRouter.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/IWETH.sol";


library SwapWrapRouter {
    // ================================================================================
    // ============================== Public Functions ================================
    // ================================================================================
    /// @notice Executes a simple swap between ETH and WETH using encoded parameters.
    /// @param orderId Unique identifier for the swap order, facilitating tracking and reference.
    /// @param rawdata Encoded data containing swap direction, transfer mode and amount information using bit masks.
    /// @param extraData Additional data encoded in calldata.
    /// @dev This function supports bidirectional swaps between ETH and WETH with minimal gas overhead.
    /// The rawdata parameter encodes:
    /// - Transfer mode in bits [251:249], direction (reversed flag) in bit 255: false=ETH->WETH, true=WETH->ETH
    function swapWrap(uint256 orderId, uint256 rawdata, IDexRouter.ExtraData memory extraData) public {
        bool reversed;
        uint128 amount;
        uint256 mode;
        assembly {
            reversed := and(rawdata, _REVERSE_MASK)
            amount := and(rawdata, SWAP_AMOUNT)
            mode := and(rawdata, _TRANSFER_MODE_MASK)
        }
        _swapWrap(orderId, msg.sender, reversed, amount, mode, extraData);
    }

    /// @notice Executes a swap between ETH and WETH using structured base request parameters to a specified receiver.
    /// @param orderId Unique identifier for the swap order, facilitating tracking and reference.
    /// @param receiver The address that will receive the swapped tokens.
    /// @param baseRequest Struct containing essential swap parameters including source token (with mode in high bits [251:249]), destination token, amount, minimum return, and deadline.
    /// @param extraData Additional data encoded in calldata.
    /// @dev This function validates that the token pair is either ETH->WETH or WETH->ETH and executes the swap accordingly.
    /// It extracts the amount and mode from the baseRequest and determines the swap direction based on the token addresses.
    function swapWrapToWithBaseRequest(
        uint256 orderId,
        address receiver,
        IDexRouter.BaseRequest calldata baseRequest,
        IDexRouter.ExtraData memory extraData
    )
        public
    {
        CommonLib.validateDeadline(baseRequest.deadLine);

        bool reversed;
        address fromTokenAddr = CommonLib.bytes32ToAddress(baseRequest.fromToken);
        if (fromTokenAddr == _ETH && baseRequest.toToken == _WETH) {
            reversed = false;
        } else if (fromTokenAddr == _WETH && baseRequest.toToken == _ETH) {
            reversed = true;
        } else {
            revert("SwapWrap: invalid token pair");
        }

        _swapWrap(orderId, receiver == address(0) ? msg.sender : receiver, reversed, baseRequest.fromTokenAmount, baseRequest.fromToken & _TRANSFER_MODE_MASK, extraData);
    }

    // ================================================================================
    // ============================== Private Functions ===============================
    // ================================================================================
    /// @notice For commission validation, ETH needs to be 0xEeee.
    function _swapWrap(
        uint256 orderId,
        address receiver,
        bool reversed,
        uint256 amount,
        uint256 mode,
        IDexRouter.ExtraData memory extraData
    ) private {
        EventLib.emitSwapOrderId(orderId);
        EventLib.emitCommissionAndTrimInfoIfNeeded(extraData);

        require(amount > 0, "amount must be > 0");
        require(mode == _MODE_LEGACY || mode == _MODE_DIRECT || mode == _MODE_PERMIT2_ALLOWANCE || mode == _MODE_PERMIT2_SIGNATURE, "invalid transfer mode");

        require(!extraData.trimInfo.hasTrim, "trim is not supported in swapWrap");
        CommissionLib.validateCommissionInfo(extraData.commissionInfo, reversed ? _WETH : _ETH, reversed ? _ETH : _WETH, mode);
        extraData.commissionInfo.tokenWithMode = mode | extraData.commissionInfo.tokenWithMode;

        IDexRouter.SwapCache memory swapCache = IDexRouter.SwapCache({
            payer: msg.sender,
            refundTo: msg.sender,
            receiver: receiver,
            toToken: reversed ? _ETH : _WETH
        });

        uint256 fromTokenCommissionAmount;
        (
            swapCache.payer, 
            amount, 
            fromTokenCommissionAmount
        ) = TransferLib.handlePermit2SigModeWithCommission(
            reversed ? (mode | uint256(uint160(_WETH))) : (mode | uint256(uint160(_ETH))),
            swapCache.payer,
            amount,
            address(0),
            extraData
        );

        (
            address middleReceiver,
            uint256 balanceBefore
        ) = CommissionLib.doCommissionFromToken(
                extraData.commissionInfo,
                swapCache,
                fromTokenCommissionAmount,
                false // extraData.trimInfo.hasTrim
            );

        if (reversed) {
            TransferLib.transferInternal(
                swapCache.payer,
                address(this),
                mode | uint256(uint160(_WETH)),
                amount
            );
            IWETH(_WETH).withdraw(amount);
            if (middleReceiver != address(this)) {
                // Invariant: `middleReceiver != address(this)` implies no toToken commission and no trim
                (bool success, ) = payable(middleReceiver).call{
                    value: amount,
                    gas: NATIVE_TOKEN_TRANSFER_GAS_LIMIT
                }("");
                require(success, "transfer native token failed");
            }
        } else {
            require(msg.value >= amount + fromTokenCommissionAmount, "value not enough");
            IWETH(_WETH).deposit{value: amount}();
            if (middleReceiver != address(this)) {
                SafeERC20.safeTransfer(IERC20(_WETH), middleReceiver, amount);
            }
        }
        // emit return amount should be the amount after commission
        uint256 toTokenCommissionAndTrimAmount = CommissionLib.doCommissionAndTrimToToken(
            extraData.commissionInfo,
            receiver,
            balanceBefore,
            swapCache.toToken,
            extraData.trimInfo
        );

        // Refund unused fromToken
        if (!reversed) {
            TransferLib.refundToken(_ETH, swapCache.refundTo);
        }

        EventLib.emitOrderRecord(
            reversed ? _WETH : _ETH,
            swapCache.toToken,
            tx.origin,
            amount,
            amount - toTokenCommissionAndTrimAmount
        );
    }
}