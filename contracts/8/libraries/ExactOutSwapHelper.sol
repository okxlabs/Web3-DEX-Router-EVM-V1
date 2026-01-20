/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Constants.sol";
import "../libraries/ExtraDataLib.sol";
import "../libraries/CommonLib.sol";
import "../libraries/CommissionLib.sol";
import "../libraries/TransferLib.sol";
import "../interfaces/IDexRouter.sol";

library ExactOutSwapHelper {
    // Ensure no trim, and adjusts the target output amount to include commission if commission is taken from the output token.
    function beforeSwap(
        uint256 amountOut,
        address middleReceiver,
        uint256 targetTokenBefore,
        IDexRouter.ExtraData memory extraData
    ) internal view returns (uint256, uint256, address) {
        // Ensure no trim.
        require(!extraData.trimInfo.hasTrim, "trim is not supported in exact out swap");

        IDexRouter.CommissionInfo memory commissionInfo = extraData.commissionInfo;
        uint256 totalRate = CommissionLib.calculateTotalRate(commissionInfo);
        if (
            commissionInfo.isToTokenCommission &&
            totalRate > 0
        ) {
            amountOut = (amountOut * DENOMINATOR) / (DENOMINATOR - totalRate);
            targetTokenBefore = CommonLib.getBalanceOf(
                /// @notice commissionInfo.token ETH address is 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE
                CommonLib.bytes32ToAddress(commissionInfo.tokenWithMode),
                address(this)
            );
            middleReceiver = address(this);
        }
        return (amountOut, targetTokenBefore, middleReceiver);
    }

    // Only handle commission.
    function afterSwap(IDexRouter.AfterSwapParams memory afterSwapParams) internal {
        // Validate commission info
        CommissionLib.validateCommissionInfo(afterSwapParams.commissionInfo, afterSwapParams.srcToken, afterSwapParams.toToken, afterSwapParams.mode); /// @notice For commission validation, ETH needs to be 0xEeee.

        // Handle commission from the source token if applicable.
        if (
            afterSwapParams.commissionInfo.isFromTokenCommission &&
            afterSwapParams.commissionInfo.commissionRate > 0
        ) {
            CommissionLib.doCommissionFromToken(
                afterSwapParams.commissionInfo,
                IDexRouter.SwapCache({
                    payer: afterSwapParams.payer,
                    refundTo: address(0),
                    receiver: afterSwapParams.receiver,
                    toToken: afterSwapParams.toToken
                }),
                afterSwapParams.fromTokenCommissionAmount,
                false
            );
            // Add the commission to the total consumed amount.
            afterSwapParams.consumeAmount += afterSwapParams.fromTokenCommissionAmount;
        }
        
        // Refund any excess ETH to the payer if the source token is ETH.
        if (afterSwapParams.srcToken == _ETH) {
            TransferLib.refundToken(_ETH, msg.sender);
        }

        // Handle commission from the output token if applicable.
        if (
            afterSwapParams.commissionInfo.isToTokenCommission &&
            afterSwapParams.commissionInfo.commissionRate > 0
        ) {
            IDexRouter.TrimInfo memory trimInfo;
            CommissionLib.doCommissionAndTrimToToken(
                afterSwapParams.commissionInfo,
                afterSwapParams.receiver,
                afterSwapParams.targetTokenBefore,
                afterSwapParams.toToken,
                trimInfo
            );
        }
    }
}