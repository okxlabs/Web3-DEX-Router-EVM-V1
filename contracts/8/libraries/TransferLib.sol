/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Constants.sol";
import "./CommonLib.sol";
import "./SafeERC20.sol";
import "./CommissionLib.sol";
import "../interfaces/IDexRouter.sol";
import "../interfaces/IWETH.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/permit2/IPermit2.sol";
import "../interfaces/permit2/ISignatureTransfer.sol";
import "../interfaces/IApproveProxy.sol";

/// @title Library to handle multi transfer modes including Permit2.
library TransferLib {
    /// @notice Handle Permit2Signature mode and fromTokenCommission mainly.
    /// @param fromTokenWithMode The fromToken with mode encoded in high bits.
    /// @param payer The address of the payer.
    /// @param inputAmount The inputAmount of the fromToken.
    /// @param onlyOneAssetTo The address of the only one assetTo. If the assetTo is more than one, it should be set to address(0).
    /// @param extraData The extra data, only commissionInfo and permit2Info are used.
    /// @return The new payer, new inputAmount, and fromTokenCommissionAmount. The new payer can be (1) original payer, (2) address(this), or (3) address(0).
    ///         The address(0) means the fromToken has been paid and no need to pay later.
    /// @dev  Since the permitTransferFrom can only be called once in a transaction, this function is designed to handle multiple scenarios and call permitTransferFrom if necessary.
    function handlePermit2SigModeWithCommission(
        uint256 fromTokenWithMode,
        address payer,
        uint256 inputAmount,
        address onlyOneAssetTo,
        IDexRouter.ExtraData memory extraData
    ) internal returns (address, uint256, uint256) {
        uint256 mode = fromTokenWithMode & _TRANSFER_MODE_MASK;
        address token = CommonLib.bytes32ToAddress(fromTokenWithMode);
        uint256 totalRate = 0;
        uint256 fromTokenCommissionAmount = 0;

        // For _MODE_BY_INVEST mode, the inputAmount is already the token balance according to agreement, and fromToken can not be ETH, commission is not allowed.
        if (mode == _MODE_BY_INVEST) {
            require(token != _ETH, "Invalid source token");
            return (address(this), inputAmount, 0);
        }

        if (extraData.commissionInfo.isFromTokenCommission) {
            totalRate = CommissionLib.calculateTotalRate(extraData.commissionInfo);
            fromTokenCommissionAmount = inputAmount * totalRate / (COMMISSION_DENOMINATOR_1E9 - totalRate);
        }

        if (token == _ETH) {
            require(mode == _MODE_LEGACY, "ETH as fromToken is not allowed for non-legacy mode");
            return (address(this), inputAmount, fromTokenCommissionAmount);
        }

        // For other modes (not _MODE_PERMIT2_SIGNATURE), return the original payer, inputAmount, and calculated fromTokenCommissionAmount.
        if (mode != _MODE_PERMIT2_SIGNATURE) {
            return (payer, inputAmount, fromTokenCommissionAmount);
        }

        require(inputAmount + fromTokenCommissionAmount <= type(uint160).max, "amount too large");

        // For _MODE_PERMIT2_SIGNATURE mode, the owner is constrained to router's msg.sender for now, but it still need to be encoded in the permit2Info calldata for future compatibility.
        // But we use payer instead of msg.sender here, because all passed in payer is router's msg.sender and for UnxswapV3ExactOutRouter the msg.sender got here is not router's msg.sender but pool address.
        require(extraData.permit2Info.owner == payer, "permit2Info owner mismatch");

        // For _MODE_PERMIT2_SIGNATURE mode, token needs to be claimed to address `to` by calling permitTransferFrom. And the address `to` needs to be set according to the situation.
        // For following 2 situations, the address `to` should be set to address(this):
        // 1. onlyOneAssetTo=address(0): means the swap method needs the swapToken to be claimed to address(this).
        // 2. isFromTokenCommission=true && toBCommission=TO_B_MODE: means the fromToken needs to be claimed to address(this) and then transfer commission to referrers.
        // And when isFromTokenCommission=true && toBCommission=NO_TO_B_MODE, the commission needs to be transferred to referrers immediately.
        address to;
        uint256 toBCommission = extraData.commissionInfo.toBCommission;
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

        if (to == address(this)) {
            // Get balance of token because the token has been claimed to address(this).
            uint256 balance = CommonLib.getBalanceOf(token, address(this));

            // Calculate the inputAmount and fromTokenCommissionAmount according to the mode.
            if (extraData.commissionInfo.isFromTokenCommission && toBCommission == TO_B_MODE) { // For Permit2Signature mode && ToB mode, the inputAmount and fromTokenCommissionAmount need to be calculated.
                inputAmount = inputAmount * balance / (inputAmount + fromTokenCommissionAmount);
                fromTokenCommissionAmount = balance - inputAmount;
                return (address(this), inputAmount, fromTokenCommissionAmount);
            } else { // For other situations (NoToB mode or no fromTokenCommission), the new inputAmount is the balance.
                return (address(this), balance, fromTokenCommissionAmount);
            }
        } else {
            return (address(0), inputAmount, fromTokenCommissionAmount);
        }
    }

    /// @notice Private function to execute permitTransferFrom.
    function _executePermitTransferFrom(
        uint256 inputAmount,
        uint256 fromTokenCommissionAmount,
        address token,
        address to,
        uint256 totalRate,
        IDexRouter.ExtraData memory extraData
    ) private {
        IDexRouter.CommissionInfo memory commissionInfo = extraData.commissionInfo;
        // Get permitTransferFrom parameters
        uint256 permitLength;
        if (commissionInfo.isFromTokenCommission && commissionInfo.toBCommission == NO_TO_B_MODE) {
            permitLength = commissionInfo.commissionLength + 1;
        } else {
            permitLength = 1;
        }
        require(permitLength == extraData.permit2Info.amounts.length, "permit2Info amount length mismatch");

        // Execute permitTransferFrom
        ISignatureTransfer.PermitBatchTransferFrom memory permitBatchTransferFrom = ISignatureTransfer.PermitBatchTransferFrom({
            permitted: new ISignatureTransfer.TokenPermissions[](permitLength),
            nonce: extraData.permit2Info.nonce,
            deadline: extraData.permit2Info.deadline
        });
        ISignatureTransfer.SignatureTransferDetails[] memory transferDetails = new ISignatureTransfer.SignatureTransferDetails[](permitLength);
        if (permitLength == 1) { // Generate permit params with permit2 array length = 1
            permitBatchTransferFrom.permitted[0] = ISignatureTransfer.TokenPermissions({
                token: token,
                amount: extraData.permit2Info.amounts[0]
            });
            transferDetails[0] = ISignatureTransfer.SignatureTransferDetails({
                to: to,
                requestedAmount: inputAmount + fromTokenCommissionAmount
            });
        } else { // Generate permit params with permit2 array length > 1 (fromTokenCommission with NoToB mode)
            for (uint256 i = 0; i < permitLength; ++i) {
                permitBatchTransferFrom.permitted[i] = ISignatureTransfer.TokenPermissions({
                    token: token,
                    amount: extraData.permit2Info.amounts[i]
                });
            }
            // transferDetails[0] is swap part, and the rest are commission parts.
            transferDetails[0] = ISignatureTransfer.SignatureTransferDetails({
                to: to,
                requestedAmount: inputAmount
            });
            uint256 accumulatedAmount = 0;
            for (uint256 i = 0; i < permitLength - 1; ++i) {
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
                transferDetails[i + 1] = ISignatureTransfer.SignatureTransferDetails({
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
    function transferInternal(
        address payer,
        address to,
        uint256 fromTokenWithMode,
        uint256 amount
    ) internal {
        if (payer == to) {
            return;
        }

        address token = address(uint160(fromTokenWithMode & _ADDRESS_MASK));
        uint256 mode = fromTokenWithMode & _TRANSFER_MODE_MASK;

        // For modes other than _MODE_NO_TRANSFER, payer needs to be checked. If the payer is address(this), the transfer logic is same.
        // If mode is _MODE_BY_INVEST, the payer passed in must be address(this).
        if (mode != _MODE_NO_TRANSFER) {
            if (payer == address(this)) {
                SafeERC20.safeTransfer(IERC20(token), to, amount);
            } else {
                if (mode == _MODE_DIRECT) {
                    SafeERC20.safeTransferFrom(IERC20(token), payer, to, amount);
                } else if (mode == _MODE_PERMIT2_ALLOWANCE) {
                    require(amount <= type(uint160).max, "amount too large");
                    IPermit2(_PERMIT2).transferFrom(payer, to, uint160(amount), token);
                } else if (mode == _MODE_PERMIT2_SIGNATURE) {
                    /// @notice The permitTransferFrom should not be called here, and if payer is not reset to address(this), the payer must be address(0).
                    require(payer == address(0), "permitTransferFrom must be called before");
                } else if (mode == _MODE_LEGACY) {
                    IApproveProxy(_APPROVE_PROXY).claimTokens(token, payer, to, amount);
                } else {
                    revert("invalid transfer mode");
                }
            }
        }
        // For _MODE_NO_TRANSFER mode, do nothing.
    }

    /// @notice Transfers the specified token to the user.
    /// @param token The address of the token to be transferred.
    /// @param to The address of the receiver.
    /// @dev Handles the withdrawal of tokens to the user, converting WETH to ETH if necessary.
    function transferTokenToUser(address token, address to) internal {
        if (token == _ETH) {
            uint256 wethBal = CommonLib.getBalanceOf(_WETH, address(this));
            if (wethBal > 0) {
                IWETH(_WETH).withdraw(wethBal);
            }
            if (to != address(this)) {
                uint256 ethBal = address(this).balance;
                if (ethBal > 0) {
                    (bool success, ) = payable(to).call{value: ethBal, gas: NATIVE_TOKEN_TRANSFER_GAS_LIMIT}("");
                    require(success, "transfer native token failed");
                }
            }
        } else {
            if (to != address(this)) {
                uint256 bal = CommonLib.getBalanceOf(token, address(this));
                if (bal > 0) {
                    SafeERC20.safeTransfer(IERC20(token), to, bal);
                }
            }
        }
    }

    /// @notice Refunds the specified token to the refundTo address.
    /// @param token The address of the token to be refunded.
    /// @param refundTo The address of the receiver.
    /// @dev Handles the refund of tokens to the refundTo address.
    function refundToken(address token, address refundTo) internal {
        if (token == _ETH) {
            if (refundTo != address(this)) {
                uint256 ethBal = address(this).balance;
                if (ethBal > 0) {
                    (bool success, ) = payable(refundTo).call{value: ethBal, gas: NATIVE_TOKEN_TRANSFER_GAS_LIMIT}("");
                    require(success, "refund native token failed");
                }
            }
        } else {
            uint256 bal = CommonLib.getBalanceOf(token, address(this));
            if (bal > 0) {
                SafeERC20.safeTransfer(IERC20(token), refundTo, bal);
            }
        }
    }
}