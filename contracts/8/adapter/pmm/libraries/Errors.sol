// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

library Errors {
    error RFQ_InvalidMsgValue(uint256 rfqId);
    error RFQ_ETHTransferFailed(uint256 rfqId);
    error RFQ_EthDepositRejected();
    error RFQ_ZeroTargetIsForbidden(uint256 rfqId);
    error RFQ_BadSignature(uint256 rfqId);
    error RFQ_OrderExpired(uint256 rfqId);
    error RFQ_MakerAmountExceeded(uint256 rfqId);
    error RFQ_TakerAmountExceeded(uint256 rfqId);
    error RFQ_SwapWithZeroAmount(uint256 rfqId);
    error RFQ_InvalidatedOrder(uint256 rfqId);
    error RFQ_AmountTooLarge(uint256 rfqId);
    error RFQ_SettlementAmountTooSmall(uint256 rfqId);
    error RFQ_OrderAlreadyCancelledOrUsed(uint256 rfqId);
    error RFQ_ConfidenceCapExceeded(uint256 rfqId);
    error RFQ_BadSender(uint256 rfqId);
    error RFQ_InvalidRfqId(uint256 rfqId);
}
