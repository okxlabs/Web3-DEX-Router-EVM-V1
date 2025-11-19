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

    /// @notice Handle Permit2Signature mode and fromTokenCommission mainly.
    /// @param fromTokenWithMode The fromToken with mode encoded in high bits.
    /// @param payer The address of the payer.
    /// @param inputAmount The inputAmount of the fromToken.
    /// @param commissionInfo The commission info.
    /// @param onlyOneAssetTo The address of the only one assetTo. If the assetTo is more than one, it should be set to address(0).
    /// @param permit2Info The permit2 info.
    /// @return The new payer, the new inputAmount, and the fromTokenCommissionAmount. The new payer can be (1) original payer, (2) address(this), or (3) address(0).
    ///         The address(0) means the fromToken has been paid and no need to pay later.
    /// @dev  Since the permitTransferFrom can only be called once in a transaction, this function is designed to handle multiple scenarios and call permitTransferFrom if necessary.
    function _handlePermit2SignatureModeWithCommission(
        uint256 fromTokenWithMode,
        address payer,
        uint256 inputAmount,
        CommissionInfo memory commissionInfo,
        address onlyOneAssetTo,
        Permit2Info memory permit2Info
    ) internal returns (address, uint256, uint256) {
        uint256 mode = fromTokenWithMode & _TRANSFER_MODE_MASK;
        address token = address(uint160(fromTokenWithMode & _ADDRESS_MASK));
        uint256 totalRate = 0;
        uint256 fromTokenCommissionAmount = 0;

        if (commissionInfo.isFromTokenCommission) {
            assembly ("memory-safe") {
                let referrerNum := mload(add(commissionInfo, 0x80))
                for { let i := 0 } lt(i, referrerNum) { i := add(i, 1) } {
                    let rate := mload(add(commissionInfo, add(0xa0, mul(i, 0x40))))
                    totalRate := add(totalRate, rate)
                }
            }
            fromTokenCommissionAmount = inputAmount * totalRate / (DENOMINATOR - totalRate);
        }

        // For not _MODE_PERMIT2_SIGNATURE mode, return directly.
        if (mode != _MODE_PERMIT2_SIGNATURE) {
            return (payer, inputAmount, fromTokenCommissionAmount);
        }

        // For _MODE_PERMIT2_SIGNATURE mode, token needs to be claimed to address `to` by calling permitTransferFrom. And the address `to` needs to be set according to the situation.
        address to;
        if (onlyOneAssetTo == address(0) || commissionInfo.isFromTokenCommission) {
            to = address(this);
        } else {
            to = onlyOneAssetTo;
        }
        IPermit2.SignatureTransferDetails memory transferDetails = IPermit2.SignatureTransferDetails({
            to: to,
            requestedAmount: inputAmount + fromTokenCommissionAmount
        });
        permit2Info.permit.permitted.token = token;
        IPermit2(_PERMIT2).permitTransferFrom(permit2Info.permit, transferDetails, permit2Info.owner, permit2Info.signature);

        // If the to address is address(this), scale the inputAmount and fromTokenCommissionAmount according to the token balance.
        // If not, return directly. The payer should be set to address(0), which means the fromToken has been paid and no need to pay later.
        if (to == address(this)) {
            uint256 balance = IERC20(token).balanceOf(address(this));
            inputAmount = inputAmount * balance / (inputAmount + fromTokenCommissionAmount);
            fromTokenCommissionAmount = balance - inputAmount;
            return (address(this), inputAmount, fromTokenCommissionAmount);
        } else {
            return (address(0), inputAmount, 0);
        }
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
            if (amount == 0) {
                amount = IERC20(token).balanceOf(address(this));
            }
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