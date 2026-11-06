/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library PMMLib {

  // ============ Struct ============
  struct PMMSwapRequest {
      uint256 pathIndex;
      address payer;
      address fromToken;
      address toToken;
      uint256 fromTokenAmountMax;
      uint256 toTokenAmountMax;
      uint256 salt;
      uint256 deadLine;
      bool isPushOrder;
      bytes extension;
      // address marketMaker;
      // uint256 subIndex;
      // bytes signature;
      // uint256 source;  1byte type + 1byte bool（reverse） + 0...0 + 20 bytes address
  }

  struct PMMBaseRequest {
    uint256 fromTokenAmount;
    uint256 minReturnAmount;
    uint256 deadLine;
    bool fromNative;
    bool toNative;
  }

  enum PMM_ERROR {
      NO_ERROR,
      INVALID_OPERATOR,
      QUOTE_EXPIRED,
      ORDER_CANCELLED_OR_FINALIZED,
      REMAINING_AMOUNT_NOT_ENOUGH,
      INVALID_AMOUNT_REQUEST,
      FROM_TOKEN_PAYER_ERROR,
      TO_TOKEN_PAYER_ERROR,
      WRONG_FROM_TOKEN
  }

  event PMMSwap(
    uint256 pathIndex,
    uint256 subIndex,
    uint256 errorCode
  );

  error PMMErrorCode(uint256 errorCode);

}