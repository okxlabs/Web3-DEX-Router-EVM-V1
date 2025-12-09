/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./CommonUtils.sol";
import "./SafeERC20.sol";
import "./UniversalERC20.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/IPermit2.sol";
import "../interfaces/IApproveProxy.sol";
import "../interfaces/AbstractCommissionLib.sol";

/// @title Base contract to handle multi transfer modes including Permit2.
abstract contract TransferLib is AbstractCommissionLib, CommonUtils {
    using UniversalERC20 for IERC20;

    /// @notice Handle Permit2Signature/ByInvest mode and fromTokenCommission mainly.
    /// @param fromTokenWithMode The fromToken with mode encoded in high bits.
    /// @param payer The address of the payer.
    /// @param inputAmount The inputAmount of the fromToken.
    /// @param onlyOneAssetTo The address of the only one assetTo. If the assetTo is more than one, it should be set to address(0).
    /// @param extraData The extra data.
    /// @return The new payer, the new inputAmount, and the fromTokenCommissionAmount. The new payer can be (1) original payer, (2) address(this), or (3) address(0).
    ///         The address(0) means the fromToken has been paid and no need to pay later.
    /// @dev  Since the permitTransferFrom can only be called once in a transaction, this function is designed to handle multiple scenarios and call permitTransferFrom if necessary.
    function _handlePermit2SignatureModeWithCommission(
        uint256 fromTokenWithMode,
        address payer,
        uint256 inputAmount,
        address onlyOneAssetTo,
        ExtraData memory extraData
    ) internal returns (address, uint256, uint256) {
        uint256 mode = fromTokenWithMode & _TRANSFER_MODE_MASK;
        address token = address(uint160(fromTokenWithMode & _ADDRESS_MASK));
        uint256 totalRate = 0;
        uint256 fromTokenCommissionAmount = 0;

        if (extraData.commissionInfo.isFromTokenCommission) {
            assembly ("memory-safe") {
                let commissionInfo := mload(add(extraData, 0x00))
                let referrerNum := mload(add(commissionInfo, 0x80))
                for { let i := 0 } lt(i, referrerNum) { i := add(i, 1) } {
                    let rate := mload(add(commissionInfo, add(0xa0, mul(i, 0x40))))
                    totalRate := add(totalRate, rate)
                }
            }
            fromTokenCommissionAmount = inputAmount * totalRate / (DENOMINATOR - totalRate);
        }

        // For not _MODE_PERMIT2_SIGNATURE and _MODE_BY_INVEST mode, return directly.
        if (mode != _MODE_PERMIT2_SIGNATURE && mode != _MODE_BY_INVEST) {
            return (payer, inputAmount, fromTokenCommissionAmount);
        }

        // For _MODE_PERMIT2_SIGNATURE mode, token needs to be claimed to address `to` by calling permitTransferFrom. And the address `to` needs to be set according to the situation.
        // For following 2 situations, the address `to` should be set to address(this):
        // 1. onlyOneAssetTo=address(0): means the swap method needs the swapToken to be claimed to address(this).
        // 2. isFromTokenCommission=true && toBCommission=TO_B_MODE: means the fromToken needs to be claimed to address(this) and then transfer commission to referrers.
        // And when isFromTokenCommission=true && toBCommission=NO_TO_B_MODE, the commission needs to be transferred to referrers immediately.
        address to;
        uint256 toBCommission = extraData.commissionInfo.toBCommission;
        if (mode == _MODE_PERMIT2_SIGNATURE) {
            // Get the address `to` according to the situation.
            if (onlyOneAssetTo == address(0) || (extraData.commissionInfo.isFromTokenCommission && toBCommission == TO_B_MODE)) {
                to = address(this);
            } else {
                to = onlyOneAssetTo;
            }

            _executePermitTransferFrom(
                inputAmount,
                fromTokenCommissionAmount,
                token,
                to,
                totalRate,
                extraData
            );
        }

        if (to == address(this) || mode == _MODE_BY_INVEST) {
            // Get balance of token according to the mode.
            uint256 balance;
            if (mode == _MODE_BY_INVEST) {
                balance = inputAmount; // For BY_INVEST mode, inputAmount is already the token balance.
            } else {
                balance = IERC20(token).balanceOf(address(this)); // For other situations, the balance needs to be got because the token has been claimed to address(this).
            }

            // Calculate the inputAmount and fromTokenCommissionAmount according to the mode.
            if (mode == _MODE_PERMIT2_SIGNATURE && toBCommission == NO_TO_B_MODE) { // For Permit2Signature mode && ToC mode, the commission has been transferred to referrers so the newInputAmount is the balance.
                return (address(this), balance, fromTokenCommissionAmount);
            } else { // For other situations (Permit2Signature mode && ToB mode, ByInvest mode), the inputAmount and fromTokenCommissionAmount need to be calculated.
                inputAmount = inputAmount * balance / (inputAmount + fromTokenCommissionAmount);
                fromTokenCommissionAmount = balance - inputAmount;
                return (address(this), inputAmount, fromTokenCommissionAmount);   
            }
        } else {
            return (address(0), inputAmount, fromTokenCommissionAmount);
        }
    }

    function _executePermitTransferFrom(
        uint256 inputAmount,
        uint256 fromTokenCommissionAmount,
        address token,
        address to,
        uint256 totalRate,
        ExtraData memory extraData
    ) internal {
        CommissionInfo memory commissionInfo = extraData.commissionInfo;
        // Get permitTransferFrom parameters
        uint256 permitLength;
        if (commissionInfo.isFromTokenCommission && commissionInfo.toBCommission == NO_TO_B_MODE) {
            permitLength = commissionInfo.commissionLength + 1;
        } else {
            permitLength = 1;
        }
        require(permitLength == extraData.permit2Info.amounts.length, "permit2Info amount length mismatch");

        // Execute permitTransferFrom
        IPermit2.PermitBatchTransferFrom memory permitBatchTransferFrom = IPermit2.PermitBatchTransferFrom({
            permitted: new IPermit2.TokenPermissions[](permitLength),
            nonce: extraData.permit2Info.nonce,
            deadline: extraData.permit2Info.deadline
        });
        IPermit2.SignatureTransferDetails[] memory transferDetails = new IPermit2.SignatureTransferDetails[](permitLength);
        if (permitLength == 1) { // Generate permit params without ToC mode
            permitBatchTransferFrom.permitted[0] = IPermit2.TokenPermissions({
                token: token,
                amount: extraData.permit2Info.amounts[0]
            });
            transferDetails[0] = IPermit2.SignatureTransferDetails({
                to: to,
                requestedAmount: inputAmount + fromTokenCommissionAmount
            });
        } else { // Generate permit params with ToC mode
            for (uint256 i = 0; i < permitLength; i++) {
                permitBatchTransferFrom.permitted[i] = IPermit2.TokenPermissions({
                    token: token,
                    amount: extraData.permit2Info.amounts[i]
                });
            }
            // transferDetails[0] is swap part, and the rest are commission parts.
            transferDetails[0] = IPermit2.SignatureTransferDetails({
                to: to,
                requestedAmount: inputAmount
            });
            uint256 accumulatedAmount = 0;
            for (uint256 i = 0; i < permitLength - 1; i++) {
                uint256 commissionRate;
                address referrerAddress;
                assembly ("memory-safe") {
                    referrerAddress := mload(add(commissionInfo, add(0xc0, mul(i, 0x40))))
                    commissionRate := mload(add(commissionInfo, add(0xa0, mul(i, 0x40))))
                }
                uint256 commissionAmount;
                if (i == permitLength - 2) {
                    commissionAmount = fromTokenCommissionAmount - accumulatedAmount;
                } else {
                    commissionAmount = fromTokenCommissionAmount * commissionRate / totalRate;
                    accumulatedAmount += commissionAmount;
                }
                transferDetails[i + 1] = IPermit2.SignatureTransferDetails({
                    to: referrerAddress,
                    requestedAmount: commissionAmount
                });
            }
        }

        IPermit2(_PERMIT2).permitTransferFrom(permitBatchTransferFrom, transferDetails, extraData.permit2Info.owner, extraData.permit2Info.signature);
    }

    /// @notice Transfers tokens internally within the contract.
    /// @param payer The address of the payer.
    /// @param to The address of the receiver.
    /// @param fromTokenWithMode FromToken with mode encoded in high bits
    /// @param amount The amount of tokens to be transferred.
    /// @dev Handles the transfer of ERC20 tokens.
    function _transferInternal(
        address payer,
        address to,
        uint256 fromTokenWithMode,
        uint256 amount
    ) internal {
        address token = address(uint160(fromTokenWithMode & _ADDRESS_MASK));
        uint256 mode = fromTokenWithMode & _TRANSFER_MODE_MASK;

        if (mode == _MODE_NO_TRANSFER) {
            return;
        } else if (mode == _MODE_BY_INVEST) {
            SafeERC20.safeTransfer(IERC20(token), to, amount);
        } else { // For other modes, payer needs to be checked. If the payer is address(this), the transfer logic is same.
            if (payer == address(this)) {
                SafeERC20.safeTransfer(IERC20(token), to, amount);
            } else {
                if (mode == _MODE_DIRECT) {
                    SafeERC20.safeTransferFrom(IERC20(token), payer, to, amount);
                } else if (mode == _MODE_PERMIT2_ALLOWANCE) {
                    IPermit2(_PERMIT2).transferFrom(payer, to, uint160(amount), token);
                } else if (mode == _MODE_PERMIT2_SIGNATURE) {
                    /// @notice The permitTransferFrom should not be called here, and if payer is not reset to address(this), the payer must be address(0).
                    require(payer == address(0), "permitTransferFrom must be called before");
                } else {
                    IApproveProxy(_APPROVE_PROXY).claimTokens(token, payer, to, amount);
                }
            }
        }
    }
}