/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Constants.sol";
import "../libraries/ExtraDataLib.sol";
import "../libraries/CommonLib.sol";
import "../libraries/CommissionLib.sol";
import "../interfaces/IDexRouter.sol";

library ExactOutSwapHelper {
    // Adjusts the target output amount to include commission if commission is taken from the output token.
    function beforeSwap(
        uint256 amountOut,
        address middleReceiver,
        uint256 targetTokenBefore,
        IDexRouter.ExtraData memory extraData
    ) internal returns (IDexRouter.CommissionInfo memory, uint256, uint256, address) {
        IDexRouter.CommissionInfo memory commissionInfo = extraData.commissionInfo;
        if (
            commissionInfo.isToTokenCommission &&
            commissionInfo.commissionRate > 0
        ) {
            uint256 totalRate = commissionInfo.commissionRate +
                commissionInfo.commissionRate2;
            // DENOMINATOR is defined in the CommissionLib.sol
            amountOut = (amountOut * DENOMINATOR) / (DENOMINATOR - totalRate);
            targetTokenBefore = CommonLib.getBalanceOf(
                /// @notice commissionInfo.token ETH address is 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE
                address(uint160(commissionInfo.tokenWithMode & _ADDRESS_MASK)),
                address(this)
            );
            middleReceiver = address(this);
        }
        return (commissionInfo, amountOut, targetTokenBefore, middleReceiver);
    }

    // Handles commission.
    function afterSwap(IDexRouter.AfterSwapParams memory afterSwapParams) internal {
        // validate commission info
        CommissionLib.validateCommissionInfo(afterSwapParams.commissionInfo, afterSwapParams.srcToken, afterSwapParams.toToken, _MODE_LEGACY); // @notice For commission validation, ETH needs to be 0xEeee.

        // Handle commission from the source token if applicable.
        if (
            afterSwapParams.commissionInfo.isFromTokenCommission &&
            afterSwapParams.commissionInfo.commissionRate > 0
        ) {
            uint256 commissionAmount = 0;
            // Calculate the commission amount by checking the contract's balance before and after commission transfer.
            if (
                afterSwapParams.srcToken == _ETH &&
                msg.value > afterSwapParams.consumeAmount
            ) {
                commissionAmount = CommonLib.getBalanceOf(
                    /// @notice commissionInfo.token ETH address is 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE
                    address(uint160(afterSwapParams.commissionInfo.tokenWithMode & _ADDRESS_MASK)),
                    address(this)
                );
            }
            CommissionLib.doCommissionFromToken(
                afterSwapParams.commissionInfo,
                IDexRouter.SwapParams({
                    payer: afterSwapParams.payer,
                    refundTo: address(0),
                    receiver: afterSwapParams.receiver,
                    toToken: afterSwapParams.toToken
                }),
                afterSwapParams.consumeAmount, // TODO should be fromTokenCommissionAmount gotten from _handleTransferModeWithCommission
                false
            );
            if (
                afterSwapParams.srcToken == _ETH &&
                msg.value > afterSwapParams.consumeAmount
            ) {
                commissionAmount =
                    commissionAmount -
                    CommonLib.getBalanceOf(
                        address(uint160(afterSwapParams.commissionInfo.tokenWithMode & _ADDRESS_MASK)),
                        address(this)
                    );
            }
            // Add the commission to the total consumed amount.
            afterSwapParams.consumeAmount += commissionAmount;
        }

        // Refund any excess ETH to the payer if the source token is ETH.
        if (
            afterSwapParams.srcToken == _ETH &&
            msg.value > afterSwapParams.consumeAmount
        ) {
            payable(afterSwapParams.payer).transfer(
                msg.value - afterSwapParams.consumeAmount
            );
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