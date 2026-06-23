// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IDexRouter {
    /// =============================================================
    /// ======================= Structs =============================
    /// =============================================================
    struct BaseRequest {
        uint256 fromToken;
        address toToken;
        uint256 fromTokenAmount;
        uint256 minReturnAmount;
        uint256 deadLine;
    }

    struct RouterPath {
        address[] mixAdapters;
        address[] assetTo;
        uint256[] rawData;
        bytes[] extraData;
        uint256 fromToken;
    }

    struct CommissionInfo {
        bool isFromTokenCommission; //0x00
        bool isToTokenCommission; //0x20
        uint256 tokenWithMode; // 0x40, if isToTokenCommission, tokenWithMode is only the token address, otherwise tokenWithMode is the token address with mode encoded in high bits
        uint256 toBCommission; // 0x60, 0 for no encoded commission data, 1 for no-toB commission, 2 for toB commission
        uint256 commissionLength; // 0x80
        uint256 commissionRate; // 0xa0
        address referrerAddress; // 0xc0
        uint256 commissionRate2; // 0xe0
        address referrerAddress2; // 0x100
        uint256 commissionRate3; // 0x120
        address referrerAddress3; // 0x140
        uint256 commissionRate4; // 0x160
        address referrerAddress4; // 0x180
        uint256 commissionRate5; // 0x1a0
        address referrerAddress5; // 0x1c0
        uint256 commissionRate6; // 0x1e0
        address referrerAddress6; // 0x200
        uint256 commissionRate7; // 0x220
        address referrerAddress7; // 0x240
        uint256 commissionRate8; // 0x260
        address referrerAddress8; // 0x280
    }

    struct TrimInfo {
        bool hasTrim; // 0x00
        uint256 trimRate; // 0x20
        address trimAddress; // 0x40
        uint256 toBTrim; // 0x60, 0 for no encoded trim data, 1 for no-toB trim, 2 for toB trim
        uint256 expectAmountOut; // 0x80
        uint256 chargeRate; // 0xa0
        address chargeAddress; // 0xc0
    }

    struct Permit2Info {
        address owner; // 0x00
        uint256 nonce; // 0x20
        uint256 deadline; // 0x40
        bytes signature; // 0x60
        uint256[] amounts; // 0x80
    }

    struct ExtraData {
        CommissionInfo commissionInfo;
        TrimInfo trimInfo;
        Permit2Info permit2Info;
        address refundTo;
    }

    struct SwapCache {
        address payer;
        address refundTo;
        address receiver;
        address toToken;
    }

    struct AfterSwapParams {
        CommissionInfo commissionInfo;
        uint256 consumeAmount;
        uint256 targetTokenBefore;
        address srcToken;
        address toToken;
        address receiver;
        address payer;
        uint256 mode;
        uint256 fromTokenCommissionAmount;
    }

    struct ExactOutSwapCache {
        uint256 amountOut;
        uint256 maxConsume;
        address payer;
    }
}