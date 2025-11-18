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

    /// @notice Transfers tokens internally within the contract.
    /// @param payer The address of the payer.
    /// @param to The address of the receiver.
    /// @param fromTokenWithMode FromToken with mode encoded in high bits
    /// @param amount The amount of tokens to be transferred.
    /// @param permit2Info The permit2 info for permitTransferFrom if mode is _MODE_PERMIT2_SIGNATURE
    /// @dev Handles the transfer of ERC20 tokens or native tokens within the contract.
    function _transferInternal(
        address payer,
        address to,
        uint256 fromTokenWithMode,
        uint256 amount,
        Permit2Info memory permit2Info
    ) internal {
        address token = address(uint160(fromTokenWithMode & _ADDRESS_MASK));
        uint256 mode = fromTokenWithMode & _TRANSFER_MODE_MASK;

        if (mode == _MODE_NO_TRANSFER) {
            return;
        } else if (mode == _MODE_BY_INVEST) {
            if (amount == 0) {
                if (token == _ETH) {
                    amount = address(this).balance;
                } else {
                    amount = IERC20(token).balanceOf(address(this));
                }
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
                    IPermit2.SignatureTransferDetails memory transferDetails = IPermit2.SignatureTransferDetails({
                        to: to,
                        requestedAmount: amount
                    });
                    permit2Info.permit.permitted.token = token;
                    IPermit2(_PERMIT2).permitTransferFrom(permit2Info.permit, transferDetails, permit2Info.owner, permit2Info.signature);
                } else {
                    IApproveProxy(_APPROVE_PROXY).claimTokens(token, payer, to, amount);
                }
            }
        }
    }
}